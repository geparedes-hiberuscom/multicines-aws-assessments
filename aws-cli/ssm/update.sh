#!/usr/bin/env bash
# aws-cli/ssm/update.sh Update SSM parameters from secrets.txt (--overwrite)
#
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

PARAM_BASE_PATH="/multicines/integrator/${ENV}"
SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Updating SSM parameters: ${PARAM_BASE_PATH}/"

if [ ! -f "$SECRETS_FILE" ]; then
 log_error "Secrets file not found: $SECRETS_FILE"; exit 1
fi

update_ssm_parameter() {
 local param_name="$1" param_value="$2" param_type="$3"
 local full_path="${PARAM_BASE_PATH}/${param_name}"
 aws ssm put-parameter --name "${full_path}" --value "${param_value}" \
 --type "${param_type}" --overwrite \
 --region "${AWS_REGION}" > /dev/null
 if [ $? -ne 0 ]; then log_error "Failed: ${full_path}"; exit 1; fi
 log_updated "SSM ${full_path}"
}

# === Parse and update ===
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
 param_name=$(echo "$current_key" | awk -F'/' '{print $NF}')
 compact=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 update_ssm_parameter "$param_name" "$compact" "SecureString"
 current_key=""; in_value=false
 fi
 elif [ "$brace_count" -gt 0 ]; then
 json_content="${json_content}${line}"
 brace_count=$((brace_count + open - close))
 if [ "$brace_count" -le 0 ]; then
 param_name=$(echo "$current_key" | awk -F'/' '{print $NF}')
 compact=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 update_ssm_parameter "$param_name" "$compact" "SecureString"
 current_key=""; in_value=false
 fi
 fi
 fi
done < "$SECRETS_FILE"

log_info "SSM update complete for $ENV"
