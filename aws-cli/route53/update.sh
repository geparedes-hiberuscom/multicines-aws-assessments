#!/usr/bin/env bash
# aws-cli/route53/update.sh - Update Route 53 alias record to current ALB
#
# Re-applies the UPSERT (same as create - idempotent)
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Updating Route 53 for $ENV - running create (UPSERT is idempotent)"
"${SCRIPT_DIR}/create.sh" "$ENV"
