#!/usr/bin/env bash
# aws-cli/lib/common.sh - Shared functions library
#
# ONLY functions here. ALL configuration lives in environments/{env}/env.properties.
#
# Usage in module scripts:
#   source "${SCRIPT_DIR}/../lib/common.sh"
#   ENV="${1:?Usage: $0 <dev|prod>}"
#   load_env "$ENV"

set -euo pipefail

# =============================================================================
# === Environment Validation ===
# =============================================================================
validate_env() {
  local env="$1"
  if [[ "$env" != "dev" && "$env" != "prod" ]]; then
    log_error "Invalid environment: $env. Must be 'dev' or 'prod'."
    exit 1
  fi
}

# =============================================================================
# === Logging ===
# =============================================================================
log_info()    { echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_error()   { echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2; }
log_skip()    { echo "[SKIP] $(date '+%Y-%m-%d %H:%M:%S') $* - already exists"; }
log_created() { echo "[CREATED] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_deleted() { echo "[DELETED] $(date '+%Y-%m-%d %H:%M:%S') $*"; }
log_updated() { echo "[UPDATED] $(date '+%Y-%m-%d %H:%M:%S') $*"; }

# =============================================================================
# === Environment Loader ===
# =============================================================================
load_env() {
  local env="$1"
  validate_env "$env"

  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local env_file="${lib_dir}/../environments/${env}/env.properties"

  if [ ! -f "$env_file" ]; then
    log_error "Environment file not found: $env_file"
    exit 1
  fi

  # shellcheck disable=SC1090
  source "$env_file"

  # Derived variables
  export ENV="$env"
  export ECR_URI="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"

  # Derived resource names: {ambiente}-{recurso}-{tipo}
  export ALB_NAME="${ENV}-${APP_NAME}-alb"
  export ECS_TG_NAME="${ENV}-${APP_NAME}-tg"
  export ECS_SERVICE_NAME="${ENV}-${APP_NAME}-svc"
  export ECS_TASK_FAMILY="${ENV}-${APP_NAME}-task"
  export WAF_NAME="${ENV}-${APP_NAME}-waf"
  export VPN_NAME="${ENV}-${APP_NAME}-vpn"
  export VGW_NAME="${ENV}-${APP_NAME}-vgw"
  export CGW_NAME="${ENV}-${APP_NAME}-cgw"
  export ACM_NAME="${ENV}-${APP_NAME}-acm"

  log_info "Loaded environment: $env (APP_NAME: $APP_NAME)"
}

# =============================================================================
# === Naming Helper ===
# =============================================================================
generate_name() {
  local env="$1" resource="$2" type="$3" zone="${4:-}"
  if [ -z "$zone" ]; then
    echo "${env}-${resource}-${type}"
  else
    echo "${env}-${resource}-${type}-${zone}"
  fi
}

# =============================================================================
# === Idempotency Helper ===
# =============================================================================
check_exists() {
  local describe_cmd="$1"
  if eval "$describe_cmd" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# =============================================================================
# === Dependency Validation ===
# =============================================================================
require_resource() {
  local resource_name="$1"
  local check_command="$2"
  local hint="${3:-}"

  if ! eval "$check_command" > /dev/null 2>&1; then
    log_error "Dependency not met: $resource_name does not exist."
    if [ -n "$hint" ]; then
      log_error "Run first: $hint"
    fi
    exit 1
  fi
}

# =============================================================================
# === Tags Helper ===
# =============================================================================
# Tag values defined once, formatted per AWS service requirements.
# To add/remove a tag, edit only this section.

# Standard tags (Key=Value format) - for ALB, ACM, SSM, Secrets, WAF
# Usage: eval "aws ... --tags $(get_tags \"\$RESOURCE_NAME\")"
# Or:    aws ... --tags "Key=Name,Value=$NAME" "Key=Project,Value=$PROJECT_NAME" "Key=Environment,Value=$ENV" "Key=Service,Value=$APP_NAME"
get_tags() {
  local name="$1"
  echo "Key=Name,Value=${name}" "Key=Project,Value=${PROJECT_NAME}" "Key=Environment,Value=${ENV}" "Key=Service,Value=${APP_NAME}"
}

# Shared resource tags (Environment=shared) - for resources shared across environments (ACM, Route53)
get_shared_tags() {
  local name="$1"
  echo "Key=Name,Value=${name}" "Key=Project,Value=${PROJECT_NAME}" "Key=Environment,Value=shared" "Key=Service,Value=${APP_NAME}"
}

# ECS tags (lowercase) - for task definitions and services
get_ecs_tags() {
  local name="$1"
  echo "key=Name,value=${name}" "key=Project,value=${PROJECT_NAME}" "key=Environment,value=${ENV}" "key=Service,value=${APP_NAME}"
}

# EC2 tag-specifications (JSON-like) - for VPN, CGW, VGW
get_tag_spec() {
  local name="$1"
  echo "{Key=Name,Value=${name}},{Key=Project,Value=${PROJECT_NAME}},{Key=Environment,Value=${ENV}},{Key=Service,Value=${APP_NAME}}"
}

# =============================================================================
# === Certs Path Helper ===
# =============================================================================
get_certs_dir() {
  local lib_dir
  lib_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  echo "${lib_dir}/../environments/${ENV}/certs"
}
