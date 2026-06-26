#!/usr/bin/env bash
# aws-cli/alb/update.sh - Update ALB (health check, certificate)
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

TG_NAME="$ECS_TG_NAME"
log_info "Updating ALB for $ENV"

# Update Target Group health check
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)

if [ -z "$TG_ARN" ] || [ "$TG_ARN" == "None" ]; then
  log_error "Target Group $TG_NAME not found"; exit 1
fi

aws elbv2 modify-target-group --target-group-arn "$TG_ARN" \
  --health-check-path "$HEALTH_CHECK_PATH" --health-check-port "$HEALTH_CHECK_PORT" \
  --region "$AWS_REGION" > /dev/null

log_updated "Target Group $TG_NAME health check (port: $HEALTH_CHECK_PORT, path: $HEALTH_CHECK_PATH)"
