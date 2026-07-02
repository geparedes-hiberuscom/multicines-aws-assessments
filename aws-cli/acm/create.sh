#!/usr/bin/env bash
# aws-cli/acm/create.sh - Create or import SSL/TLS certificate in ACM
#
# Modes (controlled by ACM_MODE in env.properties):
#   request - Request certificate via ACM with DNS validation (free, auto-renew)
#   import  - Import from PEM files in environments/{env}/certs/
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# Default to import if ACM_MODE not set (backwards compatible)
ACM_MODE="${ACM_MODE:-import}"
CERT_NAME="${APP_NAME}-acm"

log_info "ACM certificate: $CERT_NAME (domain: $DOMAIN, mode: $ACM_MODE)"

# === Check if certificate already exists ===
EXISTING_CERT_ARN=$(aws acm list-certificates --region "$AWS_REGION" \
  --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].CertificateArn | [0]" \
  --output text 2>/dev/null || true)

if [ -n "$EXISTING_CERT_ARN" ] && [ "$EXISTING_CERT_ARN" != "None" ]; then
  log_skip "ACM certificate for ${DOMAIN} (ARN: $EXISTING_CERT_ARN)"
  exit 0
fi

# === Mode: request (ACM generates via DNS validation) ===
if [ "$ACM_MODE" == "request" ]; then
  log_info "Requesting certificate via ACM DNS validation..."

  # Validate hosted zone exists (required for DNS validation)
  BASE_DOMAIN="${HOSTED_ZONE_NAME}"
  HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
    --dns-name "${BASE_DOMAIN}" \
    --query "HostedZones[?Name=='${BASE_DOMAIN}.'].Id | [0]" \
    --output text 2>/dev/null || true)

  if [ -z "$HOSTED_ZONE_ID" ] || [ "$HOSTED_ZONE_ID" == "None" ]; then
    log_error "Hosted zone '${BASE_DOMAIN}' not found. Required for DNS validation."
    log_error "Run first: route53/create-zone.sh"
    exit 1
  fi
  HOSTED_ZONE_ID=$(echo "$HOSTED_ZONE_ID" | sed 's|/hostedzone/||')
  log_info "Hosted zone found: ${BASE_DOMAIN} (ID: $HOSTED_ZONE_ID)"

  CERT_ARN=$(aws acm request-certificate \
    --domain-name "${DOMAIN}" \
    --validation-method DNS \
    --tags $(get_shared_tags "$CERT_NAME") \
    --region "$AWS_REGION" \
    --query 'CertificateArn' --output text)

  if [ -z "$CERT_ARN" ]; then
    log_error "Failed to request certificate"
    exit 1
  fi

  log_created "ACM certificate requested: $CERT_ARN"
  log_info "Waiting for DNS validation details..."
  sleep 5

  # Get the CNAME validation record
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

  if [ -z "$VALIDATION_CNAME_NAME" ] || [ "$VALIDATION_CNAME_NAME" == "None" ]; then
    log_error "Could not retrieve DNS validation record. Check ACM console."
    log_info "Certificate ARN: $CERT_ARN"
    log_info "Create the CNAME validation record manually in Route53."
    exit 1
  fi

  log_info "DNS validation record:"
  log_info "  Name:  $VALIDATION_CNAME_NAME"
  log_info "  Value: $VALIDATION_CNAME_VALUE"

  if [ -n "$HOSTED_ZONE_ID" ]; then
    # Auto-create CNAME validation record in Route53
    log_info "Creating DNS validation record in Route53 (zone: $HOSTED_ZONE_ID)..."

    CHANGE_BATCH=$(cat <<EOF
{
  "Changes": [{
    "Action": "UPSERT",
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
      --change-batch "$CHANGE_BATCH" > /dev/null

    log_created "DNS validation CNAME record in Route53"

    # Wait for certificate to be issued
    log_info "Waiting for certificate validation (may take 2-5 minutes)..."
    if aws acm wait certificate-validated \
        --certificate-arn "$CERT_ARN" \
        --region "$AWS_REGION" 2>/dev/null; then
      log_info "Certificate validated and issued!"
    else
      log_info "Validation timeout — check ACM console. Certificate may still be pending."
      log_info "ARN: $CERT_ARN"
    fi
  fi

# === Mode: import (from PEM files) ===
elif [ "$ACM_MODE" == "import" ]; then
  CERTS_DIR=$(get_certs_dir)
  CERT_FILE="${CERTS_DIR}/certificate.pem"
  KEY_FILE="${CERTS_DIR}/private-key.pem"
  CHAIN_FILE="${CERTS_DIR}/certificate-chain.pem"

  log_info "Importing certificate from: $CERTS_DIR"

  for file in "$CERT_FILE" "$KEY_FILE" "$CHAIN_FILE"; do
    if [ ! -f "$file" ]; then
      log_error "Required file not found: $file"
      log_error "Place certificate files in: $CERTS_DIR"
      exit 1
    fi
  done

  CERT_ARN=$(aws acm import-certificate \
    --certificate "fileb://${CERT_FILE}" \
    --private-key "fileb://${KEY_FILE}" \
    --certificate-chain "fileb://${CHAIN_FILE}" \
    --tags $(get_shared_tags "$CERT_NAME") \
    --region "$AWS_REGION" --query 'CertificateArn' --output text)

  if [ $? -ne 0 ] || [ -z "$CERT_ARN" ]; then
    log_error "Failed to import certificate"
    exit 1
  fi
  log_created "ACM certificate imported: $CERT_NAME (ARN: $CERT_ARN)"

else
  log_error "Invalid ACM_MODE: $ACM_MODE. Must be 'request' or 'import'."
  exit 1
fi
