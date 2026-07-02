#!/usr/bin/env bash
# aws-cli/route53/delete-record.sh - Delete DNS A record for the environment
#
# Usage: ./delete-record.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

ZONE_NAME="${HOSTED_ZONE_NAME}"
RECORD_NAME="${DNS_RECORD_NAME}"

log_info "Deleting DNS record: ${RECORD_NAME}"

# Find hosted zone
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ZONE_NAME}" \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id | [0]" \
  --output text 2>/dev/null || true)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  log_skip "Hosted zone ${ZONE_NAME} — does not exist"
  exit 0
fi

HOSTED_ZONE_ID=$(echo "$HOSTED_ZONE_ID" | sed 's|/hostedzone/||')

# Find the A record alias target
ALB_DNS=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && Type=='A'].AliasTarget.DNSName | [0]" \
  --output text 2>/dev/null || true)

ALB_ZONE_ID=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "ResourceRecordSets[?Name=='${RECORD_NAME}.' && Type=='A'].AliasTarget.HostedZoneId | [0]" \
  --output text 2>/dev/null || true)

if [ -z "$ALB_DNS" ] || [ "$ALB_DNS" == "None" ]; then
  log_skip "DNS record ${RECORD_NAME} — does not exist"
  exit 0
fi

# Delete the record
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": "${RECORD_NAME}",
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
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --change-batch "$CHANGE_BATCH" > /dev/null

log_deleted "DNS record ${RECORD_NAME}"
