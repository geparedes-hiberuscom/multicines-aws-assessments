#!/usr/bin/env bash
# aws-cli/route53/delete-zone.sh - Delete shared hosted zone
#
# WARNING: Only run when BOTH environments have been cleaned (records deleted).
# This script does NOT require an environment parameter.
#
# Usage: ./delete-zone.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Load any env to get HOSTED_ZONE_NAME
load_env "dev"

ZONE_NAME="${HOSTED_ZONE_NAME}"

log_info "Deleting hosted zone: ${ZONE_NAME}"

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

# Check for remaining records (other than NS and SOA)
RECORD_COUNT=$(aws route53 list-resource-record-sets \
  --hosted-zone-id "$HOSTED_ZONE_ID" \
  --query "length(ResourceRecordSets[?Type!='NS' && Type!='SOA'])" \
  --output text 2>/dev/null || echo "0")

if [ "$RECORD_COUNT" -gt 0 ]; then
  log_error "Hosted zone ${ZONE_NAME} still has ${RECORD_COUNT} records (besides NS/SOA)."
  log_error "Delete all records first (run delete-record.sh for each environment)."
  exit 1
fi

# Delete the hosted zone
aws route53 delete-hosted-zone --id "$HOSTED_ZONE_ID" > /dev/null
log_deleted "Hosted zone ${ZONE_NAME} (ID: $HOSTED_ZONE_ID)"
