#!/usr/bin/env bash
# aws-cli/route53/update-record.sh - Update DNS record (UPSERT is idempotent)
#
# Since create-record.sh uses UPSERT, calling it again updates the record.
#
# Usage: ./update-record.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Updating DNS record for $ENV (UPSERT)"
"${SCRIPT_DIR}/create-record.sh" "$ENV"
log_updated "DNS record ${DNS_RECORD_NAME}"
