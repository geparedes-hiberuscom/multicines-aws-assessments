#!/usr/bin/env bash
# aws-cli/route53/create.sh - Create Route 53 hosted zone and ALB alias record
#
# Creates a hosted zone for the domain and an alias record pointing to the ALB.
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# Extract base domain from wildcard (*.test.multicines.com.ec -> test.multicines.com.ec)
BASE_DOMAIN=$(echo "$DOMAIN" | sed 's/^\*\.//')
# Subdomain for the ALB record (e.g., dev-integration.test.multicines.com.ec)
ALB_RECORD="${ENV}-integration.${BASE_DOMAIN}"
# ALB_NAME from env.properties

log_info "Provisioning Route 53 for $ENV (domain: $BASE_DOMAIN)"

# === Dependency: ALB must exist ===
require_resource "ALB $ALB_NAME" \
  "aws elbv2 describe-load-balancers --names $ALB_NAME --region $AWS_REGION" \
  "alb/create.sh $ENV"

# Get ALB DNS name and hosted zone ID
ALB_DNS=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].DNSName' --output text)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text)

log_info "ALB DNS: $ALB_DNS (Zone ID: $ALB_ZONE_ID)"

# === 1. Create Hosted Zone (idempotent) ===
EXISTING_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$BASE_DOMAIN" \
  --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id | [0]" \
  --output text 2>/dev/null || true)

if [ -n "$EXISTING_ZONE_ID" ] && [ "$EXISTING_ZONE_ID" != "None" ]; then
  ZONE_ID=$(echo "$EXISTING_ZONE_ID" | sed 's|/hostedzone/||')
  log_skip "Hosted zone $BASE_DOMAIN (ID: $ZONE_ID)"
else
  ZONE_ID=$(aws route53 create-hosted-zone \
    --name "$BASE_DOMAIN" \
    --caller-reference "$(date +%s)-${ENV}" \
    --query 'HostedZone.Id' --output text | sed 's|/hostedzone/||')
  if [ $? -ne 0 ] || [ -z "$ZONE_ID" ]; then
    log_error "Failed to create hosted zone for $BASE_DOMAIN"
    exit 1
  fi
  log_created "Hosted zone $BASE_DOMAIN (ID: $ZONE_ID)"
  log_info "NOTE: Update your domain registrar NS records with:"
  aws route53 get-hosted-zone --id "$ZONE_ID" --query 'DelegationSet.NameServers' --output text
fi

# === 2. Create Alias Record (ALB) ===
log_info "Creating alias record: $ALB_RECORD -> $ALB_DNS"

CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
    "ResourceRecordSet": {
      "Name": "${ALB_RECORD}",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "${ALB_ZONE_ID}",
        "DNSName": "${ALB_DNS}",
        "EvaluateTargetHealth": true
      }
    }
  }]
}
EOF
)

aws route53 change-resource-record-sets \
  --hosted-zone-id "$ZONE_ID" \
  --change-batch "$CHANGE_BATCH" > /dev/null

if [ $? -ne 0 ]; then
  log_error "Failed to create alias record $ALB_RECORD"
  exit 1
fi

log_created "Alias record: $ALB_RECORD -> $ALB_DNS"
log_info "Route 53 provisioning complete for $ENV"
log_info "Access your service at: https://${ALB_RECORD}/"
