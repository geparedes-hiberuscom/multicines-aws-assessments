#!/usr/bin/env bash
# aws-cli/delete-all.sh Orchestrator: Delete all resources (REVERSE order)
#
# Usage: ./delete-all.sh <dev|prod>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

echo ""
echo ""
echo " WARNING DESTRUCTIVE OPERATION "
echo " This will DELETE all resources for: $ENV "
echo " This action CANNOT be undone. "
echo ""
echo ""
read -rp "Are you sure? (yes/no): " CONFIRMATION

if [ "$CONFIRMATION" != "yes" ]; then
 log_info "Aborted."; exit 0
fi

log_info "=== Deleting infrastructure for: $ENV ==="

MODULES=(
 "vpn/delete.sh"
 "ecs/delete.sh"
 "secrets/delete.sh"
 "ssm/delete.sh"
 "route53/delete.sh"
 "alb/delete.sh"
 "security-groups/delete.sh"
 "waf/delete.sh"
 "acm/delete.sh"
)

for module in "${MODULES[@]}"; do
 log_info "--- $module ---"
 "${SCRIPT_DIR}/${module}" "$ENV" || log_error "$module failed. Continuing..."
done

log_info "=== Deletion complete for $ENV ==="
