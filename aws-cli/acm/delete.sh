#!/usr/bin/env bash
# aws-cli/acm/delete.sh - Delete ACM certificate
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Deleting ACM certificate for $DOMAIN"

CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" --output text 2>/dev/null || true)

if [ -z "$CERT_ARN" ] || [ "$CERT_ARN" == "None" ]; then
  log_skip "ACM certificate for $DOMAIN - does not exist"; exit 0
fi

aws acm delete-certificate --certificate-arn "$CERT_ARN" --region "$AWS_REGION"
if [ $? -ne 0 ]; then log_error "Failed (may be in use by ALB)"; exit 1; fi
log_deleted "ACM certificate (ARN: $CERT_ARN)"
