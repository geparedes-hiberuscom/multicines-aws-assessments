#!/usr/bin/env bash
# aws-cli/vpn/update.sh - Update VPN resource tags (names, project, environment)
#
# VPN connections cannot be updated in-place (IPSec config is immutable).
# This script updates tags/names on existing resources without recreating them.
#
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

if [ "$VPN_CUSTOMER_IP" == "0.0.0.0" ]; then
  log_error "VPN_CUSTOMER_IP is placeholder (0.0.0.0). Update environments/$ENV/env.properties with a real IP before executing."
  exit 0
fi

log_info "Updating VPN resource tags for $ENV"

# === Find existing VPN Connection ===
VPN_ID=$(aws ec2 describe-vpn-connections \
  --filters "Name=state,Values=available" \
  --region "$AWS_REGION" \
  --query "VpnConnections[?VpnGatewayId!=null].VpnConnectionId | [0]" \
  --output text 2>/dev/null || echo "")

# Try by tag name first
VPN_ID_BY_TAG=$(aws ec2 describe-vpn-connections \
  --filters "Name=tag:Name,Values=${VPN_NAME}" "Name=state,Values=available" \
  --region "$AWS_REGION" \
  --query "VpnConnections[0].VpnConnectionId" \
  --output text 2>/dev/null || echo "")

if [ -n "$VPN_ID_BY_TAG" ] && [ "$VPN_ID_BY_TAG" != "None" ]; then
  VPN_ID="$VPN_ID_BY_TAG"
fi

if [ -z "$VPN_ID" ] || [ "$VPN_ID" == "None" ]; then
  log_error "No VPN Connection found for $ENV. Run vpn/create.sh first."
  exit 1
fi

# Get associated VGW and CGW
VGW_ID=$(aws ec2 describe-vpn-connections --vpn-connection-ids "$VPN_ID" \
  --region "$AWS_REGION" --query "VpnConnections[0].VpnGatewayId" --output text)

CGW_ID=$(aws ec2 describe-vpn-connections --vpn-connection-ids "$VPN_ID" \
  --region "$AWS_REGION" --query "VpnConnections[0].CustomerGatewayId" --output text)

log_info "Found: VPN=$VPN_ID, VGW=$VGW_ID, CGW=$CGW_ID"

# === Update tags on VPN Connection ===
aws ec2 create-tags --resources "$VPN_ID" \
  --tags Key=Name,Value="${VPN_NAME}" Key=Project,Value="${PROJECT_NAME}" Key=Environment,Value="${ENV}" Key=Service,Value="${APP_NAME}" \
  --region "$AWS_REGION"
log_updated "Tags on VPN Connection $VPN_ID → ${VPN_NAME}"

# === Update tags on VGW ===
if [ -n "$VGW_ID" ] && [ "$VGW_ID" != "None" ]; then
  aws ec2 create-tags --resources "$VGW_ID" \
    --tags Key=Name,Value="${VGW_NAME}" Key=Project,Value="${PROJECT_NAME}" Key=Environment,Value="${ENV}" Key=Service,Value="${APP_NAME}" \
    --region "$AWS_REGION"
  log_updated "Tags on VGW $VGW_ID → ${VGW_NAME}"
fi

# === Update tags on CGW ===
if [ -n "$CGW_ID" ] && [ "$CGW_ID" != "None" ]; then
  aws ec2 create-tags --resources "$CGW_ID" \
    --tags Key=Name,Value="${CGW_NAME}" Key=Project,Value="${PROJECT_NAME}" Key=Environment,Value="${ENV}" Key=Service,Value="${APP_NAME}" \
    --region "$AWS_REGION"
  log_updated "Tags on CGW $CGW_ID → ${CGW_NAME}"
fi

log_info "VPN tags update complete for $ENV"
log_info ""
log_info "NOTE: To change VPN IPSec configuration (IP, ASN), you must:"
log_info "  1. Delete: vpn/delete.sh $ENV"
log_info "  2. Recreate: vpn/create.sh $ENV"
log_info "  3. Download new configuration and reconfigure on-premise router"
