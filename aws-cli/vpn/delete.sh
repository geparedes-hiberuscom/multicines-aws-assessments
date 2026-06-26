#!/usr/bin/env bash
# aws-cli/vpn/delete.sh - Delete VPN connection, VGW, and CGW
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# CGW_NAME from load_env
# VGW_NAME from load_env
# VPN_NAME from load_env

log_info "Deleting VPN resources for $ENV"

# Delete VPN Connection
VPN_ID=$(aws ec2 describe-vpn-connections \
  --filters "Name=tag:Name,Values=${VPN_NAME}" "Name=state,Values=available,pending" \
  --region "$AWS_REGION" --query 'VpnConnections[0].VpnConnectionId' --output text 2>/dev/null || true)

if [ -n "$VPN_ID" ] && [ "$VPN_ID" != "None" ]; then
  aws ec2 delete-vpn-connection --vpn-connection-id "$VPN_ID" --region "$AWS_REGION"
  log_deleted "VPN Connection $VPN_ID"
else
  log_skip "VPN Connection $VPN_NAME"
fi

# Detach and delete VGW
VGW_ID=$(aws ec2 describe-vpn-gateways \
  --filters "Name=tag:Name,Values=${VGW_NAME}" "Name=state,Values=available" \
  --region "$AWS_REGION" --query 'VpnGateways[0].VpnGatewayId' --output text 2>/dev/null || true)

if [ -n "$VGW_ID" ] && [ "$VGW_ID" != "None" ]; then
  aws ec2 detach-vpn-gateway --vpn-gateway-id "$VGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION" 2>/dev/null
  aws ec2 delete-vpn-gateway --vpn-gateway-id "$VGW_ID" --region "$AWS_REGION"
  log_deleted "VGW $VGW_ID"
else
  log_skip "VGW $VGW_NAME"
fi

# Delete CGW
CGW_ID=$(aws ec2 describe-customer-gateways \
  --filters "Name=tag:Name,Values=${CGW_NAME}" "Name=state,Values=available" \
  --region "$AWS_REGION" --query 'CustomerGateways[0].CustomerGatewayId' --output text 2>/dev/null || true)

if [ -n "$CGW_ID" ] && [ "$CGW_ID" != "None" ]; then
  aws ec2 delete-customer-gateway --customer-gateway-id "$CGW_ID" --region "$AWS_REGION"
  log_deleted "CGW $CGW_ID"
else
  log_skip "CGW $CGW_NAME"
fi

log_info "VPN deletion complete for $ENV"
