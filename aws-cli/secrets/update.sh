#!/usr/bin/env bash
# aws-cli/secrets/update.sh - Update Secrets Manager from secrets.txt
#
# The secret NAME is the key from secrets.txt (literal path)
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Updating Secrets Manager from: $SECRETS_FILE"

if [ ! -f "$SECRETS_FILE" ]; then
  log_error "Secrets file not found: $SECRETS_FILE"; exit 1
fi

update_secret() {
  local secret_name="$1" secret_value="$2"
  aws secretsmanager put-secret-value --secret-id "$secret_name" \
    --secret-string "$secret_value" --region "$AWS_REGION" > /dev/null
  if [ $? -ne 0 ]; then log_error "Failed: ${secret_name}"; exit 1; fi
  log_updated "Secret ${secret_name}"
}

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
        update_secret "$current_key" "$compact"
        current_key=""; in_value=false
      fi
    elif [ "$brace_count" -gt 0 ]; then
      json_content="${json_content}${line}"
      brace_count=$((brace_count + open - close))
      if [ "$brace_count" -le 0 ]; then
        compact=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
        update_secret "$current_key" "$compact"
        current_key=""; in_value=false
      fi
    fi
  fi
done < "$SECRETS_FILE"

log_info "Secrets Manager update complete for $ENV"
