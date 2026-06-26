#!/usr/bin/env bash
# aws-cli/route53/delete.sh - Delete Route 53 alias record and hosted zone
#
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

BASE_DOMAIN=$(echo "$DOMAIN" | sed 's/^\*\.//')
ALB_RECORD="api.${BASE_DOMAIN}"
# ALB_NAME from env.properties

log_info "Deleting Route 53 resources for $ENV"

# Find hosted zone
ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "$BASE_DOMAIN" \
  --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id | [0]" \
  --output text 2>/dev/null | sed 's|/hostedzone/||')

if [ -z "$ZONE_ID" ] || [ "$ZONE_ID" == "None" ]; then
  log_skip "Hosted zone $BASE_DOMAIN - does not exist"
  exit 0
fi

# Delete alias record
ALB_DNS=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].DNSName' --output text 2>/dev/null || true)
ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].CanonicalHostedZoneId' --output text 2>/dev/null || true)

if [ -n "$ALB_DNS" ] && [ "$ALB_DNS" != "None" ]; then
  CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "DELETE",
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
  aws route53 change-resource-record-sets --hosted-zone-id "$ZONE_ID" --change-batch "$CHANGE_BATCH" 2>/dev/null
  log_deleted "Alias record $ALB_RECORD"
fi

# Delete hosted zone (only if empty of custom records)
aws route53 delete-hosted-zone --id "$ZONE_ID" 2>/dev/null
if [ $? -eq 0 ]; then
  log_deleted "Hosted zone $BASE_DOMAIN ($ZONE_ID)"
else
  log_info "Could not delete hosted zone (may have other records). Delete manually."
fi

log_info "Route 53 deletion complete for $ENV"
