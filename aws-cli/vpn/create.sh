#!/usr/bin/env bash
# aws-cli/vpn/create.sh Create VPN Site-to-Site resources
#
# VPN_CUSTOMER_IP and VPN_BGP_ASN in env.properties are PLACEHOLDERS.
# Change them before running this script.
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# === Dependency validation ===
require_resource "VPC $VPC_ID" \
 "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION" \
 "VPC must exist"

# === Generate resource names ===
# CGW_NAME from load_env
# VGW_NAME from load_env
# VPN_NAME from load_env

log_info "Provisioning VPN for $ENV (IP: $VPN_CUSTOMER_IP, ASN: $VPN_BGP_ASN)"
if [ "$VPN_CUSTOMER_IP" == "0.0.0.0" ]; then
 log_error "VPN_CUSTOMER_IP is placeholder (0.0.0.0). Update environments/$ENV/env.properties with a real IP before executing."
 log_info "Skipping VPN creation — no valid Customer Gateway IP configured."
 exit 0
fi

# === 1. Customer Gateway ===
CGW_ID=""
EXISTING_CGW=$(aws ec2 describe-customer-gateways \
 --filters "Name=tag:Name,Values=${CGW_NAME}" "Name=state,Values=available" \
 --region "$AWS_REGION" --query 'CustomerGateways[0].CustomerGatewayId' --output text 2>/dev/null || true)

if [ -n "$EXISTING_CGW" ] && [ "$EXISTING_CGW" != "None" ]; then
 CGW_ID="$EXISTING_CGW"; log_skip "CGW $CGW_NAME ($CGW_ID)"
else
 CGW_ID=$(aws ec2 create-customer-gateway --type ipsec.1 \
 --public-ip "$VPN_CUSTOMER_IP" --bgp-asn "$VPN_BGP_ASN" --region "$AWS_REGION" \
 --tag-specifications "ResourceType=customer-gateway,Tags=[$(get_tag_spec "$CGW_NAME")]" \
 --query 'CustomerGateway.CustomerGatewayId' --output text)
 if [ $? -ne 0 ] || [ -z "$CGW_ID" ]; then log_error "Failed CGW"; exit 1; fi
 log_created "CGW $CGW_NAME ($CGW_ID)"
fi

# === 2. Virtual Private Gateway ===
VGW_ID=""
EXISTING_VGW=$(aws ec2 describe-vpn-gateways \
 --filters "Name=tag:Name,Values=${VGW_NAME}" "Name=state,Values=available" \
 --region "$AWS_REGION" --query 'VpnGateways[0].VpnGatewayId' --output text 2>/dev/null || true)

if [ -n "$EXISTING_VGW" ] && [ "$EXISTING_VGW" != "None" ]; then
 VGW_ID="$EXISTING_VGW"; log_skip "VGW $VGW_NAME ($VGW_ID)"
else
 VGW_ID=$(aws ec2 create-vpn-gateway --type ipsec.1 --region "$AWS_REGION" \
 --tag-specifications "ResourceType=vpn-gateway,Tags=[$(get_tag_spec "$VGW_NAME")]" \
 --query 'VpnGateway.VpnGatewayId' --output text)
 if [ $? -ne 0 ] || [ -z "$VGW_ID" ]; then log_error "Failed VGW"; exit 1; fi
 log_created "VGW $VGW_NAME ($VGW_ID)"
fi

# === 3. Attach VGW to VPC ===
ATTACHED=$(aws ec2 describe-vpn-gateways --vpn-gateway-ids "$VGW_ID" --region "$AWS_REGION" \
 --query "VpnGateways[0].VpcAttachments[?VpcId=='${VPC_ID}'&&State=='attached'].VpcId|[0]" --output text 2>/dev/null || true)
if [ -n "$ATTACHED" ] && [ "$ATTACHED" != "None" ]; then
 log_skip "VGW attached to VPC"
else
 aws ec2 attach-vpn-gateway --vpn-gateway-id "$VGW_ID" --vpc-id "$VPC_ID" --region "$AWS_REGION"
 log_created "VGW attached to VPC $VPC_ID"
fi

# === 4. VPN Connection ===
VPN_ID=""
EXISTING_VPN=$(aws ec2 describe-vpn-connections \
 --filters "Name=tag:Name,Values=${VPN_NAME}" "Name=state,Values=available,pending" \
 --region "$AWS_REGION" --query 'VpnConnections[0].VpnConnectionId' --output text 2>/dev/null || true)

if [ -n "$EXISTING_VPN" ] && [ "$EXISTING_VPN" != "None" ]; then
 VPN_ID="$EXISTING_VPN"; log_skip "VPN $VPN_NAME ($VPN_ID)"
else
 VPN_ID=$(aws ec2 create-vpn-connection --type ipsec.1 \
 --customer-gateway-id "$CGW_ID" --vpn-gateway-id "$VGW_ID" --region "$AWS_REGION" \
 --tag-specifications "ResourceType=vpn-connection,Tags=[$(get_tag_spec "$VPN_NAME")]" \
 --query 'VpnConnection.VpnConnectionId' --output text)
 if [ $? -ne 0 ] || [ -z "$VPN_ID" ]; then log_error "Failed VPN"; exit 1; fi
 log_created "VPN $VPN_NAME ($VPN_ID)"
fi

# === 5. Route Propagation ===
PRIVATE_RT_IDS=$(aws ec2 describe-route-tables \
 --filters "Name=vpc-id,Values=${VPC_ID}" "Name=association.subnet-id,Values=${PRIVATE_SUBNETS}" \
 --region "$AWS_REGION" --query 'RouteTables[].RouteTableId' --output text 2>/dev/null || true)

for RT_ID in $PRIVATE_RT_IDS; do
 PROP=$(aws ec2 describe-route-tables --route-table-ids "$RT_ID" --region "$AWS_REGION" \
 --query "RouteTables[0].PropagatingVgws[?GatewayId=='${VGW_ID}'].GatewayId|[0]" --output text 2>/dev/null || true)
 if [ -n "$PROP" ] && [ "$PROP" != "None" ]; then
 log_skip "Route propagation on $RT_ID"
 else
 aws ec2 enable-vgw-route-propagation --route-table-id "$RT_ID" --gateway-id "$VGW_ID" --region "$AWS_REGION"
 log_created "Route propagation on $RT_ID"
 fi
done

log_info "VPN provisioning complete: CGW=$CGW_ID VGW=$VGW_ID VPN=$VPN_ID"
