#!/usr/bin/env bash
# aws-cli/observability/update.sh — Update observability resources
#
# Re-applies all observability resources. Since put-metric-alarm,
# put-metric-filter, put-dashboard, and put-role-policy are idempotent,
# invoking create.sh effectively updates all resources.
#
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Updating observability resources for $ENV — running create (all APIs are idempotent)"
"${SCRIPT_DIR}/create.sh" "$ENV"
log_updated "Observability resources for $ENV"
