#!/usr/bin/env bash
# aws-cli/route53/create-record.sh - Create DNS A record alias to ALB
#
# Creates an A record (alias) pointing DNS_RECORD_NAME to the ALB.
# Uses UPSERT for idempotency.
#
# Usage: ./create-record.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

ZONE_NAME="${HOSTED_ZONE_NAME}"
RECORD_NAME="${DNS_RECORD_NAME}"

log_info "Creating DNS record: ${RECORD_NAME} → ALB ${ALB_NAME}"

# Validate ALB exists
require_resource "ALB ${ALB_NAME}" \
  "aws elbv2 describe-load-balancers --names ${ALB_NAME} --region ${AWS_REGION}" \
  "alb/create.sh ${ENV}"

# Get ALB DNS name and hosted zone ID
ALB_DNS=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[0].DNSName" --output text)

ALB_ZONE_ID=$(aws elbv2 describe-load-balancers --names "${ALB_NAME}" \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[0].CanonicalHostedZoneId" --output text)

# Find hosted zone ID
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ZONE_NAME}" \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id | [0]" \
  --output text 2>/dev/null || true)

if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
  log_error "Hosted zone ${ZONE_NAME} not found. Run route53/create-zone.sh first."
  exit 1
fi

HOSTED_ZONE_ID=$(echo "$HOSTED_ZONE_ID" | sed 's|/hostedzone/||')

# UPSERT alias record
CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
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

log_created "DNS record: ${RECORD_NAME} → ${ALB_DNS}"
