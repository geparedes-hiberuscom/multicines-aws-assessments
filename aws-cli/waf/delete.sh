#!/usr/bin/env bash
# aws-cli/waf/delete.sh - Delete WAF Web ACL
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

WEB_ACL_NAME="$WAF_NAME"
log_info "Deleting WAF: $WEB_ACL_NAME"

ACL_INFO=$(aws wafv2 list-web-acls --scope REGIONAL --region "$AWS_REGION" \
  --query "WebACLs[?Name=='${WEB_ACL_NAME}'].[ARN,Id] | [0]" --output text 2>/dev/null || true)
ACL_ARN=$(echo "$ACL_INFO" | awk '{print $1}')
ACL_ID=$(echo "$ACL_INFO" | awk '{print $2}')

if [ -z "$ACL_ARN" ] || [ "$ACL_ARN" == "None" ]; then
  log_skip "WAF $WEB_ACL_NAME - does not exist"; exit 0
fi

# Disassociate from ALB first
# ALB_NAME from env.properties
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)

if [ -n "$ALB_ARN" ] && [ "$ALB_ARN" != "None" ]; then
  aws wafv2 disassociate-web-acl --resource-arn "$ALB_ARN" --region "$AWS_REGION" 2>/dev/null
  log_info "Disassociated WAF from ALB"
fi

LOCK_TOKEN=$(aws wafv2 get-web-acl --name "$WEB_ACL_NAME" --scope REGIONAL --id "$ACL_ID" \
  --region "$AWS_REGION" --query 'LockToken' --output text)

aws wafv2 delete-web-acl --name "$WEB_ACL_NAME" --scope REGIONAL --id "$ACL_ID" \
  --lock-token "$LOCK_TOKEN" --region "$AWS_REGION"
if [ $? -ne 0 ]; then log_error "Failed to delete WAF"; exit 1; fi
log_deleted "WAF $WEB_ACL_NAME"
