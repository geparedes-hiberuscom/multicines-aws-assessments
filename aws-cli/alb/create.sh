#!/usr/bin/env bash
# aws-cli/alb/create.sh - Create ALB, Target Group, and Listeners
#
# REQUIRES: ACM certificate must exist before running this script.
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# === Dependency validations (FAIL-FAST) ===
require_resource "ALB Security Group $ALB_SG_ID" \
  "aws ec2 describe-security-groups --group-ids $ALB_SG_ID --region $AWS_REGION" \
  "Security Group must exist in AWS"

# Validate ACM certificate exists BEFORE creating anything
CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" \
  --output text 2>/dev/null || true)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  log_error "ACM certificate for domain '${DOMAIN}' NOT FOUND."
  log_error "Cannot create ALB without a valid certificate."
  log_error "Run first: acm/create.sh $ENV"
  exit 1
fi

log_info "ACM certificate found: $CERT_ARN"

# === Resource names from env.properties ===
TG_NAME="${ECS_TG_NAME}"

log_info "Provisioning ALB for environment: $ENV"

# === 1. ALB ===
ALB_ARN=""
if check_exists "aws elbv2 describe-load-balancers --names $ALB_NAME --region $AWS_REGION"; then
  ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  log_skip "ALB $ALB_NAME"
else
  SUBNETS=$(echo "$PUBLIC_SUBNETS" | tr ',' ' ')
  ALB_ARN=$(aws elbv2 create-load-balancer --name "$ALB_NAME" --type application \
    --subnets $SUBNETS --security-groups "$ALB_SG_ID" --scheme internet-facing \
    --region "$AWS_REGION" --tags $(get_tags "$ALB_NAME") \
    --query 'LoadBalancers[0].LoadBalancerArn' --output text)
  if [ $? -ne 0 ] || [ -z "$ALB_ARN" ]; then log_error "Failed to create ALB"; exit 1; fi
  log_created "ALB $ALB_NAME (ARN: $ALB_ARN)"
fi

# === 2. Target Group ===
TG_ARN=""
EXISTING_TG=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)

if [ -n "$EXISTING_TG" ] && [ "$EXISTING_TG" != "None" ]; then
  TG_ARN="$EXISTING_TG"
  log_skip "Target Group $TG_NAME"
else
  TG_ARN=$(aws elbv2 create-target-group --name "$TG_NAME" --protocol HTTP \
    --port "$CONTAINER_PORT" --vpc-id "$VPC_ID" --target-type ip \
    --health-check-protocol HTTP --health-check-port "$HEALTH_CHECK_PORT" \
    --health-check-path "$HEALTH_CHECK_PATH" --health-check-interval-seconds 30 \
    --healthy-threshold-count 3 --unhealthy-threshold-count 3 \
    --region "$AWS_REGION" --tags $(get_tags "$ECS_TG_NAME") \
    --query 'TargetGroups[0].TargetGroupArn' --output text)
  if [ $? -ne 0 ] || [ -z "$TG_ARN" ]; then log_error "Failed to create TG"; exit 1; fi
  log_created "Target Group $TG_NAME (ARN: $TG_ARN)"
fi

# === 3. HTTPS:443 Listener ===
EXISTING_HTTPS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
  --query "Listeners[?Port==\`443\`].ListenerArn | [0]" --output text 2>/dev/null || true)

if [ -n "$EXISTING_HTTPS" ] && [ "$EXISTING_HTTPS" != "None" ]; then
  log_skip "HTTPS:443 listener on $ALB_NAME"
else
  log_info "Creating HTTPS:443 listener (cert: $CERT_ARN)"
  aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTPS --port 443 \
    --ssl-policy "$ALB_SSL_POLICY" --certificates "CertificateArn=${CERT_ARN}" \
    --default-actions "Type=forward,TargetGroupArn=${TG_ARN}" --region "$AWS_REGION" \
    --tags $(get_tags "${ALB_NAME}-https") > /dev/null
  if [ $? -ne 0 ]; then log_error "Failed to create HTTPS listener"; exit 1; fi
  log_created "HTTPS:443 listener on $ALB_NAME"
fi

# === 4. HTTP:80 Redirect ===
EXISTING_HTTP=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
  --query "Listeners[?Port==\`80\`].ListenerArn | [0]" --output text 2>/dev/null || true)

if [ -n "$EXISTING_HTTP" ] && [ "$EXISTING_HTTP" != "None" ]; then
  log_skip "HTTP:80 listener on $ALB_NAME"
else
  aws elbv2 create-listener --load-balancer-arn "$ALB_ARN" --protocol HTTP --port 80 \
    --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
    --region "$AWS_REGION" > /dev/null
  if [ $? -ne 0 ]; then log_error "Failed to create HTTP redirect"; exit 1; fi
  log_created "HTTP:80 redirect listener on $ALB_NAME"
fi

log_info "ALB provisioning complete for $ENV (ALB: $ALB_ARN, TG: $TG_ARN)"
