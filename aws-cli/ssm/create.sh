#!/usr/bin/env bash
# aws-cli/ssm/create.sh Create SSM parameters from secrets.txt
#
# Reads environments/${ENV}/secrets/secrets.txt and creates one SSM parameter
# per key/value block. Also creates OTEL_TRACES_EXPORTER as a fixed param.
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

PARAM_BASE_PATH="/multicines/integrator/${ENV}"
SECRETS_FILE="${SCRIPT_DIR}/../environments/${ENV}/secrets/secrets.txt"

log_info "Provisioning SSM parameters: ${PARAM_BASE_PATH}/"

# === Validate secrets file exists ===
if [ ! -f "$SECRETS_FILE" ]; then
 log_error "Secrets file not found: $SECRETS_FILE"
 exit 1
fi

# === Helper: create or skip SSM parameter ===
create_ssm_parameter() {
 local param_name="$1" param_value="$2" param_type="$3"
 local full_path="${PARAM_BASE_PATH}/${param_name}"
 if check_exists "aws ssm get-parameter --name '${full_path}' --region ${AWS_REGION}"; then
 log_skip "SSM ${full_path}"; return 0
 fi
 aws ssm put-parameter --name "${full_path}" --value "${param_value}" \
 --type "${param_type}" \
 --tags $(get_tags "$full_path") \
 --region "${AWS_REGION}" > /dev/null
 if [ $? -ne 0 ]; then log_error "Failed: ${full_path}"; exit 1; fi
 log_created "SSM ${full_path}"
}

# === Parse secrets.txt and create parameters ===
# Format: key: <path>\n value:\n { ...JSON... }
current_key=""
in_value=false
brace_count=0
json_content=""

while IFS= read -r line || [ -n "$line" ]; do
 # Detect key: line
 if echo "$line" | grep -qiE "^key[[:space:]]*:"; then
 current_key=$(echo "$line" | sed -E 's/^[Kk][Ee][Yy][[:space:]]*:[[:space:]]*//' | tr -d '"')
 in_value=false
 json_content=""
 brace_count=0
 continue
 fi

 # Detect value: line
 if echo "$line" | grep -qiE "^v[a-z]*ue[[:space:]]*:"; then
 in_value=true
 continue
 fi

 # Collect JSON content
 if [ "$in_value" = true ] && [ -n "$current_key" ]; then
 open=$(echo "$line" | tr -cd '{' | wc -c)
 close=$(echo "$line" | tr -cd '}' | wc -c)

 if [ "$brace_count" -eq 0 ] && [ "$open" -gt 0 ]; then
 json_content="$line"
 brace_count=$((open - close))
 if [ "$brace_count" -le 0 ]; then
 # Single-line or complete JSON process it
 param_name=$(echo "$current_key" | awk -F'/' '{print $NF}')
 compact_json=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 create_ssm_parameter "$param_name" "$compact_json" "SecureString"
 current_key=""
 in_value=false
 fi
 elif [ "$brace_count" -gt 0 ]; then
 json_content="${json_content}${line}"
 brace_count=$((brace_count + open - close))
 if [ "$brace_count" -le 0 ]; then
 # Complete JSON block process it
 param_name=$(echo "$current_key" | awk -F'/' '{print $NF}')
 compact_json=$(echo "$json_content" | python3 -c "import sys,json;print(json.dumps(json.load(sys.stdin),separators=(',',':')))" 2>/dev/null || echo "$json_content" | tr -d '\n')
 create_ssm_parameter "$param_name" "$compact_json" "SecureString"
 current_key=""
 in_value=false
 fi
 fi
 fi
done < "$SECRETS_FILE"

# === Fixed parameter: OTEL ===
create_ssm_parameter "OTEL_TRACES_EXPORTER" "otlp" "String"

log_info "SSM provisioning complete for $ENV"
