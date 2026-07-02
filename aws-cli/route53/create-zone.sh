#!/usr/bin/env bash
# aws-cli/route53/create-zone.sh - Create shared hosted zone
#
# Creates the hosted zone "cloudmulticines.com" (shared across environments).
# This script does NOT require an environment parameter.
#
# Usage: ./create-zone.sh

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

# Load any env to get AWS_REGION and HOSTED_ZONE_NAME (they're the same in both)
load_env "dev"

ZONE_NAME="${HOSTED_ZONE_NAME}"

log_info "Creating hosted zone: ${ZONE_NAME}"

# Check if domain is registered (needed for ACM DNS validation to work)
DOMAIN_STATUS=$(aws route53domains get-domain-detail --domain-name "${ZONE_NAME}" \
  --region us-east-1 --query "DomainName" --output text 2>/dev/null || echo "NOT_REGISTERED")

if [ "$DOMAIN_STATUS" == "NOT_REGISTERED" ]; then
  log_info "WARNING: Domain '${ZONE_NAME}' does not appear to be registered."
  log_info "ACM DNS validation will NOT work until the domain is registered."
  log_info "Register it via: Route53 console → Registered domains → Register domains"
fi

# Check if hosted zone already exists
EXISTING_ZONE_ID=$(aws route53 list-hosted-zones-by-name \
  --dns-name "${ZONE_NAME}" \
  --query "HostedZones[?Name=='${ZONE_NAME}.'].Id | [0]" \
  --output text 2>/dev/null || true)

if [ -n "$EXISTING_ZONE_ID" ] && [ "$EXISTING_ZONE_ID" != "None" ]; then
  EXISTING_ZONE_ID=$(echo "$EXISTING_ZONE_ID" | sed 's|/hostedzone/||')
  log_skip "Hosted zone ${ZONE_NAME} (ID: $EXISTING_ZONE_ID)"
else
  # Create hosted zone with unique caller reference
  CALLER_REF="create-zone-$(date +%s)"
  ZONE_RESULT=$(aws route53 create-hosted-zone \
    --name "${ZONE_NAME}" \
    --caller-reference "$CALLER_REF" \
    --query "HostedZone.Id" --output text)

  EXISTING_ZONE_ID=$(echo "$ZONE_RESULT" | sed 's|/hostedzone/||')
  log_created "Hosted zone ${ZONE_NAME} (ID: $EXISTING_ZONE_ID)"

  # Show nameservers for delegation
  NS_RECORDS=$(aws route53 get-hosted-zone --id "$EXISTING_ZONE_ID" \
    --query "DelegationSet.NameServers" --output text)

  log_info "=== NAMESERVERS FOR DELEGATION ==="
  log_info "Configure these in your domain registrar for ${ZONE_NAME}:"
  echo "$NS_RECORDS" | tr '\t' '\n' | while read ns; do
    log_info "  $ns"
  done
  log_info "==================================="
fi
