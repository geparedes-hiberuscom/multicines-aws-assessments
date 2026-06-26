#!/usr/bin/env bash
# aws-cli/alb/delete.sh - Delete ALB, listeners, and target group
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# ALB_NAME from env.properties
TG_NAME="$ECS_TG_NAME"

log_info "Deleting ALB infrastructure for $ENV"

# Get ALB ARN
ALB_ARN=$(aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" \
  --query 'LoadBalancers[0].LoadBalancerArn' --output text 2>/dev/null || true)

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" == "None" ]; then
  log_skip "ALB $ALB_NAME - does not exist"
else
  # Delete listeners first
  LISTENERS=$(aws elbv2 describe-listeners --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION" \
    --query 'Listeners[].ListenerArn' --output text 2>/dev/null || true)
  for arn in $LISTENERS; do
    aws elbv2 delete-listener --listener-arn "$arn" --region "$AWS_REGION"
    log_deleted "Listener $arn"
  done
  # Delete ALB
  aws elbv2 delete-load-balancer --load-balancer-arn "$ALB_ARN" --region "$AWS_REGION"
  log_deleted "ALB $ALB_NAME"
fi

# Delete Target Group
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
  --query 'TargetGroups[0].TargetGroupArn' --output text 2>/dev/null || true)

if [ -n "$TG_ARN" ] && [ "$TG_ARN" != "None" ]; then
  aws elbv2 delete-target-group --target-group-arn "$TG_ARN" --region "$AWS_REGION"
  log_deleted "Target Group $TG_NAME"
else
  log_skip "Target Group $TG_NAME - does not exist"
fi

log_info "ALB deletion complete for $ENV"
