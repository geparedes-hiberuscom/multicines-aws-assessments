#!/usr/bin/env bash
# aws-cli/ecs/delete.sh - Delete ECS service and deregister ALL task definitions
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Deleting ECS resources for $ENV"

# === 1. Delete ECS Service ===
SERVICE_STATUS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" \
  --services "$ECS_SERVICE_NAME" --region "$AWS_REGION" \
  --query 'services[0].status' --output text 2>/dev/null || true)

if [ "$SERVICE_STATUS" == "ACTIVE" ]; then
  # Force delete service (stops all tasks immediately)
  aws ecs delete-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE_NAME" \
    --force --region "$AWS_REGION" > /dev/null
  log_deleted "ECS service $ECS_SERVICE_NAME (force deleted)"
else
  log_skip "ECS service $ECS_SERVICE_NAME - not active"
fi

# === 2. Deregister ALL task definition revisions ===
log_info "Deregistering all task definition revisions for: $ECS_TASK_FAMILY"

ALL_TDS=$(aws ecs list-task-definitions --family-prefix "$ECS_TASK_FAMILY" \
  --region "$AWS_REGION" --query 'taskDefinitionArns[]' --output text 2>/dev/null || true)

if [ -n "$ALL_TDS" ] && [ "$ALL_TDS" != "None" ]; then
  for TD_ARN in $ALL_TDS; do
    aws ecs deregister-task-definition --task-definition "$TD_ARN" --region "$AWS_REGION" > /dev/null 2>&1 || true
    log_deleted "Task definition $TD_ARN"
  done
else
  log_skip "No task definitions found for $ECS_TASK_FAMILY"
fi

# === 3. Delete task definitions permanently (INACTIVE ones) ===
INACTIVE_TDS=$(aws ecs list-task-definitions --family-prefix "$ECS_TASK_FAMILY" \
  --status INACTIVE --region "$AWS_REGION" --query 'taskDefinitionArns[]' --output text 2>/dev/null || true)

if [ -n "$INACTIVE_TDS" ] && [ "$INACTIVE_TDS" != "None" ]; then
  for TD_ARN in $INACTIVE_TDS; do
    aws ecs delete-task-definitions --task-definitions "$TD_ARN" --region "$AWS_REGION" > /dev/null 2>&1 || true
    log_deleted "Permanently deleted $TD_ARN"
  done
fi

log_info "ECS deletion complete for $ENV"
