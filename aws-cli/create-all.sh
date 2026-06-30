#!/usr/bin/env bash
# aws-cli/create-all.sh Orchestrator: Create all resources
#
# Usage: ./create-all.sh <dev|prod>

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "=== Creating all infrastructure for: $ENV ==="

MODULES=(
 "acm/create.sh"
 "waf/create.sh"
 "security-groups/create.sh"
 "alb/create.sh"
 "route53/create.sh"
 "ssm/create.sh"
 "secrets/create.sh"
 "ecs/create.sh"
 "observability/create.sh"
 "vpn/create.sh"
)

for module in "${MODULES[@]}"; do
 log_info "--- $module ---"
 "${SCRIPT_DIR}/${module}" "$ENV"
 if [ $? -ne 0 ]; then
 log_error "$module failed. Stopping."
 exit 1
 fi
done

log_info "=== All modules completed for $ENV ==="
