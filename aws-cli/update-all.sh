#!/usr/bin/env bash
# aws-cli/update-all.sh Orchestrator: Update all updatable resources
#
# Usage: ./update-all.sh <dev|prod>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "=== Updating infrastructure for: $ENV ==="

MODULES=(
 "ssm/update.sh"
 "secrets/update.sh"
 "security-groups/update.sh"
 "waf/update.sh"
 "ecs/update.sh"
 "acm/update.sh"
)

for module in "${MODULES[@]}"; do
 log_info "--- $module ---"
 "${SCRIPT_DIR}/${module}" "$ENV"
 if [ $? -ne 0 ]; then
 log_error "$module failed. Continuing..."
 fi
done

log_info "=== Update complete for $ENV ==="
