#!/usr/bin/env bash
# aws-cli/vpn/update.sh - VPN connections cannot be updated in-place
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "VPN connections cannot be updated in-place."
log_info "To change VPN parameters:"
log_info "  1. Update VPN_CUSTOMER_IP and VPN_BGP_ASN in environments/$ENV/env.properties"
log_info "  2. Run: vpn/delete.sh $ENV"
log_info "  3. Run: vpn/create.sh $ENV"
