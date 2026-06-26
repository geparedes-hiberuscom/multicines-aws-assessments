#!/usr/bin/env bash
# aws-cli/secrets/create.sh Create Secrets Manager secrets from secrets.txt
#
# The secret NAME is the key from secrets.txt (e.g. "platform/dev/resilience")
# The secret VALUE is the complete JSON block from the value: section
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Provisioning Secrets Manager from: $SECRETS_FILE"

if [ ! -f "$SECRETS_FILE" ]; then
 log_error "Secrets file not found: $SECRETS_FILE"
 exit 1
fi

create_secret() {
 local secret_name="$1" secret_value="$2"
 if check_exists "aws secretsmanager describe-secret --secret-id '${secret_name}' --region ${AWS_REGION}"; then
 log_skip "Secret ${secret_name}"; return 0
 fi
 aws secretsmanager create-secret --name "$secret_name" \
 --description "Secret for ${PROJECT_NAME} (${ENV})" \
 --secret-string "$secret_value" --region "$AWS_REGION" \
 --tags $(get_tags "${1}") > /dev/null
 if [ $? -ne 0 ]; then log_error "Failed: ${secret_name}"; exit 1; fi
 log_created "Secret ${secret_name}"
}

# === Parse secrets.txt ===
current_key=""
in_value=false
brace_count=0
json_content=""

while IFS= read -r line || [ -n "$line" ]; do
 if echo "$line" | grep -qiE "^key[[:space:]]*:"; then
 current_key=$(echo "$line" | sed -E 's/^[Kk][Ee][Yy][[:space:]]*:[[:space:]]*//' | tr -d '"')
 in_value=false; json_content=""; brace_count=0; continue
 fi
 if echo "$line" | grep -qiE "^v[a-z]*ue[[:space:]]*:"; then
 in_value=true; continue
 fi
 if [ "$in_value" = true ] && [ -n "$current_key" ]; then
 open=$(echo "$line" | tr -cd '{' | wc -c)
 close=$(echo "$line" | tr -cd '}' | wc -c)
 if [ "$brace_count" -eq 0 ] && [ "$open" -gt 0 ]; then
 json_content="$line"; brace_count=$((open - close))
 if [ "$brace_count" -le 0 ]; then
 compact=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 create_secret "$current_key" "$compact"
 current_key=""; in_value=false
 fi
 elif [ "$brace_count" -gt 0 ]; then
 json_content="${json_content}${line}"
 brace_count=$((brace_count + open - close))
 if [ "$brace_count" -le 0 ]; then
 compact=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 create_secret "$current_key" "$compact"
 current_key=""; in_value=false
 fi
 fi
 fi
done < "$SECRETS_FILE"

log_info "Secrets Manager provisioning complete for $ENV"
