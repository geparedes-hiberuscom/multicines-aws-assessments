#!/usr/bin/env bash
# aws-cli/acm/update.sh - Re-import (renew) certificate in ACM
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

CERTS_DIR=$(get_certs_dir)
CERT_FILE="${CERTS_DIR}/certificate.pem"
KEY_FILE="${CERTS_DIR}/private-key.pem"
CHAIN_FILE="${CERTS_DIR}/certificate-chain.pem"

log_info "Updating ACM certificate for $DOMAIN"

for file in "$CERT_FILE" "$KEY_FILE" "$CHAIN_FILE"; do
  if [ ! -f "$file" ]; then log_error "Not found: $file"; exit 1; fi
done

EXISTING_CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" --output text 2>/dev/null || true)

if [ -z "$EXISTING_CERT_ARN" ] || [ "$EXISTING_CERT_ARN" == "None" ]; then
  log_error "No existing certificate for $DOMAIN. Run create.sh first."; exit 1
fi

aws acm import-certificate --certificate-arn "$EXISTING_CERT_ARN" \
  --certificate "fileb://${CERT_FILE}" --private-key "fileb://${KEY_FILE}" \
  --certificate-chain "fileb://${CHAIN_FILE}" --region "$AWS_REGION" > /dev/null

if [ $? -ne 0 ]; then log_error "Failed to update certificate"; exit 1; fi
log_updated "ACM certificate (ARN: $EXISTING_CERT_ARN)"
