#!/usr/bin/env bash
# aws-cli/acm/create.sh - Import SSL/TLS certificate to ACM
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

CERTS_DIR=$(get_certs_dir)
CERT_FILE="${CERTS_DIR}/certificate.pem"
KEY_FILE="${CERTS_DIR}/private-key.pem"
CHAIN_FILE="${CERTS_DIR}/certificate-chain.pem"
CERT_NAME="$ACM_NAME"

log_info "Importing ACM certificate: $CERT_NAME (domain: $DOMAIN)"

for file in "$CERT_FILE" "$KEY_FILE" "$CHAIN_FILE"; do
  if [ ! -f "$file" ]; then
    log_error "Required file not found: $file"
    log_error "Place certificate files in: $CERTS_DIR"
    exit 1
  fi
done

EXISTING_CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" --output text 2>/dev/null || true)

if [ -n "$EXISTING_CERT_ARN" ] && [ "$EXISTING_CERT_ARN" != "None" ]; then
  log_skip "ACM certificate for ${DOMAIN} - ARN: $EXISTING_CERT_ARN"
  exit 0
fi

CERT_ARN=$(aws acm import-certificate \
  --certificate "fileb://${CERT_FILE}" \
  --private-key "fileb://${KEY_FILE}" \
  --certificate-chain "fileb://${CHAIN_FILE}" \
  --tags $(get_tags "$ACM_NAME") \
  --region "$AWS_REGION" --query 'CertificateArn' --output text)

if [ $? -ne 0 ] || [ -z "$CERT_ARN" ]; then log_error "Failed to import certificate"; exit 1; fi
log_created "ACM certificate $CERT_NAME (ARN: $CERT_ARN)"
