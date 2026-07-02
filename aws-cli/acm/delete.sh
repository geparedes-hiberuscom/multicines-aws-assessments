#!/usr/bin/env bash
# aws-cli/acm/delete.sh - Delete ACM certificate
#
# Works for both modes (request and import) — deletes the certificate by ARN.
# Note: If the certificate is in use by an ALB listener, deletion will fail.
#
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

ACM_MODE="${ACM_MODE:-import}"

log_info "Deleting ACM certificate for $DOMAIN (mode: $ACM_MODE)"

CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" \
  --output text 2>/dev/null || true)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  log_skip "ACM certificate for $DOMAIN — does not exist"
  exit 0
fi

# If mode is request, also clean up the DNS validation CNAME record
if [ "$ACM_MODE" == "request" ]; then
  VALIDATION_CNAME_NAME=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region "$AWS_REGION" \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord.Name" \
    --output text 2>/dev/null || true)

  VALIDATION_CNAME_VALUE=$(aws acm describe-certificate \
    --certificate-arn "$CERT_ARN" \
    --region "$AWS_REGION" \
    --query "Certificate.DomainValidationOptions[0].ResourceRecord.Value" \
    --output text 2>/dev/null || true)

  if [ -n "$VALIDATION_CNAME_NAME" ] && [ "$VALIDATION_CNAME_NAME" != "None" ]; then
    BASE_DOMAIN="${HOSTED_ZONE_NAME}"
    HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
      --dns-name "${BASE_DOMAIN}" \
      --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id | [0]" \
      --output text 2>/dev/null || true)

    if [ -n "$HOSTED_ZONE_ID" ] && [ "$HOSTED_ZONE_ID" != "None" ]; then
      HOSTED_ZONE_ID=$(echo "$HOSTED_ZONE_ID" | sed 's|/hostedzone/||')
      log_info "Removing DNS validation CNAME record from Route53..."

      CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "DELETE",
    "ResourceRecordSet": {
      "Name": "${VALIDATION_CNAME_NAME}",
      "Type": "CNAME",
      "TTL": 300,
      "ResourceRecords": [{"Value": "${VALIDATION_CNAME_VALUE}"}]
    }
  }]
}
EOF
)
      aws route53 change-resource-record-sets \
        --hosted-zone-id "$HOSTED_ZONE_ID" \
        --change-batch "$CHANGE_BATCH" > /dev/null 2>&1 || true

      log_deleted "DNS validation CNAME record"
    fi
  fi
fi

# Delete the certificate
aws acm delete-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION"
if [ $? -ne 0 ]; then
  log_error "Failed to delete certificate (may be in use by ALB — remove ALB listener first)"
  exit 1
fi
log_deleted "ACM certificate (ARN: $CERT_ARN)"
