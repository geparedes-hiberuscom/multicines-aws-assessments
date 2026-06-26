#!/usr/bin/env bash
# aws-cli/waf/create.sh - Create WAF Web ACL with rate-based rule
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

WEB_ACL_NAME="$WAF_NAME"
log_info "Provisioning WAF: $WEB_ACL_NAME (rate limit: $WAF_RATE_LIMIT)"

EXISTING_ACL_ARN=$(aws wafv2 list-web-acls --scope REGIONAL --region "$AWS_REGION" \
  --query "WebACLs[?Name=='${WEB_ACL_NAME}'].ARN | [0]" --output text 2>/dev/null || true)

if [ -n "$EXISTING_ACL_ARN" ] && [ "$EXISTING_ACL_ARN" != "None" ]; then
  log_skip "$WEB_ACL_NAME"; WEB_ACL_ARN="$EXISTING_ACL_ARN"
else
  WEB_ACL_ARN=$(aws wafv2 create-web-acl --name "$WEB_ACL_NAME" --scope REGIONAL \
    --region "$AWS_REGION" --default-action '{"Allow":{}}' \
    --rules "[{\"Name\":\"${WEB_ACL_NAME}-rate-limit\",\"Priority\":1,\"Statement\":{\"RateBasedStatement\":{\"Limit\":${WAF_RATE_LIMIT},\"AggregateKeyType\":\"IP\"}},\"Action\":{\"Block\":{}},\"VisibilityConfig\":{\"SampledRequestsEnabled\":true,\"CloudWatchMetricsEnabled\":true,\"MetricName\":\"${WEB_ACL_NAME}-rate-limit\"}}]" \
    --visibility-config "{\"SampledRequestsEnabled\":true,\"CloudWatchMetricsEnabled\":true,\"MetricName\":\"${WEB_ACL_NAME}\"}" \
    --query 'Summary.ARN' --output text)
  if [ $? -ne 0 ] || [ -z "$WEB_ACL_ARN" ]; then log_error "Failed WAF"; exit 1; fi
  aws wafv2 tag-resource --resource-arn "$WEB_ACL_ARN" \
    --tags $(get_tags "$WAF_NAME") \
    --region "$AWS_REGION"
  log_created "$WEB_ACL_NAME (ARN: $WEB_ACL_ARN)"
fi

# Associate with ALB if exists
# ALB_NAME from env.properties
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
  log_info "ALB not found - skipping WAF association"
else
  CURRENT_ACL=$(aws wafv2 get-web-acl-for-resource --resource-arn "$ALB_ARN" \
    --region "$AWS_REGION" --query 'WebACL.ARN' --output text 2>/dev/null || true)
  if [ "$CURRENT_ACL" == "$WEB_ACL_ARN" ]; then
    log_skip "WAF->ALB association"
  else
    aws wafv2 associate-web-acl --web-acl-arn "$WEB_ACL_ARN" --resource-arn "$ALB_ARN" --region "$AWS_REGION"
    log_created "WAF->ALB association"
  fi
fi
log_info "WAF provisioning complete for $ENV"
