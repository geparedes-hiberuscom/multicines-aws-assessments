#!/usr/bin/env bash
# aws-cli/security-groups/update.sh - Re-apply hardening (same as create)
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Updating SGs - re-applying hardening"
"${SCRIPT_DIR}/create.sh" "$ENV"
