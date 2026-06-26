#!/usr/bin/env bash
# aws-cli/secrets/delete.sh - Delete Secrets Manager secrets listed in secrets.txt
#
# Deletes each secret whose name matches the key in secrets.txt
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Deleting Secrets Manager secrets for $ENV"

if [ ! -f "$SECRETS_FILE" ]; then
  log_error "Secrets file not found: $SECRETS_FILE"; exit 1
fi

delete_secret() {
  local secret_name="$1"
  if ! check_exists "aws secretsmanager describe-secret --secret-id '${secret_name}' --region ${AWS_REGION}"; then
    log_skip "Secret ${secret_name} - does not exist"; return 0
  fi
  aws secretsmanager delete-secret --secret-id "$secret_name" \
    --force-delete-without-recovery --region "$AWS_REGION" > /dev/null
  if [ $? -ne 0 ]; then log_error "Failed to delete: ${secret_name}"; exit 1; fi
  log_deleted "Secret ${secret_name}"
}

# Parse keys from secrets.txt
while IFS= read -r line || [ -n "$line" ]; do
  if echo "$line" | grep -qiE "^key[[:space:]]*:"; then
    current_key=$(echo "$line" | sed -E 's/^[Kk][Ee][Yy][[:space:]]*:[[:space:]]*//' | tr -d '"')
    if [ -n "$current_key" ]; then
      delete_secret "$current_key"
    fi
  fi
done < "$SECRETS_FILE"

log_info "Secrets Manager deletion complete for $ENV"
