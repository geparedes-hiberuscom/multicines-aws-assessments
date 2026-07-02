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

# === Phase 1: Environment-specific resources (reverse order) ===
MODULES=(
 "vpn/delete.sh"
 "observability/delete.sh"
 "ecs/delete.sh"
 "secrets/delete.sh"
 "route53/delete-record.sh"
 "alb/delete.sh"
 "acm/delete.sh"
)

for module in "${MODULES[@]}"; do
 log_info "--- $module ---"
 "${SCRIPT_DIR}/${module}" "$ENV" || log_error "$module failed. Continuing..."
done

# === Phase 2: Shared resources (only delete zone if empty) ===
log_info "--- route53/delete-zone.sh (shared — only if empty) ---"
"${SCRIPT_DIR}/route53/delete-zone.sh" || log_error "route53/delete-zone.sh failed or zone not empty."

log_info "=== Deletion complete for $ENV ==="
