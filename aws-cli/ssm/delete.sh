#!/usr/bin/env bash
# aws-cli/ssm/delete.sh - Delete SSM parameters listed in secrets.txt
#
# Deletes parameters under /multicines/integrator/{env}/ that correspond
# to keys in secrets.txt, plus the fixed OTEL parameter.
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

PARAM_BASE_PATH="/multicines/integrator/${ENV}"
SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Deleting SSM parameters: ${PARAM_BASE_PATH}/"

if [ ! -f "$SECRETS_FILE" ]; then
  log_error "Secrets file not found: $SECRETS_FILE"; exit 1
fi

delete_ssm_parameter() {
  local full_path="$1"
  if ! check_exists "aws ssm get-parameter --name '${full_path}' --region ${AWS_REGION}"; then
    log_skip "SSM ${full_path} - does not exist"; return 0
  fi
  aws ssm delete-parameter --name "${full_path}" --region "${AWS_REGION}" > /dev/null
  if [ $? -ne 0 ]; then log_error "Failed to delete: ${full_path}"; exit 1; fi
  log_deleted "SSM ${full_path}"
}

# Parse keys from secrets.txt and delete corresponding SSM params
while IFS= read -r line || [ -n "$line" ]; do
  if echo "$line" | grep -qiE "^key[[:space:]]*:"; then
    current_key=$(echo "$line" | sed -E 's/^[Kk][Ee][Yy][[:space:]]*:[[:space:]]*//' | tr -d '"')
    if [ -n "$current_key" ]; then
      param_name=$(echo "$current_key" | awk -F'/' '{print $NF}')
      delete_ssm_parameter "${PARAM_BASE_PATH}/${param_name}"
    fi
  fi
done < "$SECRETS_FILE"

# Delete fixed OTEL parameter
delete_ssm_parameter "${PARAM_BASE_PATH}/OTEL_TRACES_EXPORTER"

log_info "SSM deletion complete for $ENV"
