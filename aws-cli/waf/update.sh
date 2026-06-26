#!/usr/bin/env bash
# aws-cli/waf/update.sh - Update WAF rate limit
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

WEB_ACL_NAME="$WAF_NAME"
log_info "Updating WAF: $WEB_ACL_NAME (rate limit: $WAF_RATE_LIMIT)"

# Get current Web ACL ARN and lock token
ACL_INFO=$(aws wafv2 list-web-acls --scope REGIONAL --region "$AWS_REGION" \
  --query "WebACLs[?Name=='${WEB_ACL_NAME}'].[ARN,Id] | [0]" --output text 2>/dev/null || true)
ACL_ARN=$(echo "$ACL_INFO" | awk '{print $1}')
ACL_ID=$(echo "$ACL_INFO" | awk '{print $2}')

if [ -z "$ACL_ARN" ] || [ "$ACL_ARN" == "None" ]; then
  log_error "WAF $WEB_ACL_NAME not found. Run create.sh first."; exit 1
fi

LOCK_TOKEN=$(aws wafv2 get-web-acl --name "$WEB_ACL_NAME" --scope REGIONAL --id "$ACL_ID" \
  --region "$AWS_REGION" --query 'LockToken' --output text)

aws wafv2 update-web-acl --name "$WEB_ACL_NAME" --scope REGIONAL --id "$ACL_ID" \
  --lock-token "$LOCK_TOKEN" --region "$AWS_REGION" --default-action '{"Allow":{}}' \
  --rules "[{\"Name\":\"${WEB_ACL_NAME}-rate-limit\",\"Priority\":1,\"Statement\":{\"RateBasedStatement\":{\"Limit\":${WAF_RATE_LIMIT},\"AggregateKeyType\":\"IP\"}},\"Action\":{\"Block\":{}},\"VisibilityConfig\":{\"SampledRequestsEnabled\":true,\"CloudWatchMetricsEnabled\":true,\"MetricName\":\"${WEB_ACL_NAME}-rate-limit\"}}]" \
  --visibility-config "{\"SampledRequestsEnabled\":true,\"CloudWatchMetricsEnabled\":true,\"MetricName\":\"${WEB_ACL_NAME}\"}" > /dev/null

if [ $? -ne 0 ]; then log_error "Failed to update WAF"; exit 1; fi
log_updated "WAF $WEB_ACL_NAME"
