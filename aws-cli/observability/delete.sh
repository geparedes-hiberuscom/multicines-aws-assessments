#!/usr/bin/env bash
# aws-cli/observability/delete.sh — Delete observability resources
#
# Deletes IAM X-Ray policy, CloudWatch Dashboard, Log Metric Filters,
# CloudWatch Alarms, SNS subscriptions and SNS Topic for the specified environment.
#
# Resources are deleted in REVERSE order of creation (safest).
#
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "=== Observability: deleting resources for ${ENV} ==="

# =============================================================================
# === 1. Delete IAM Inline Policy (X-Ray) ===
# =============================================================================

XRAY_POLICY_NAME="${ENV}-${APP_NAME}-xray-policy"
TASK_ROLE_NAME="${TASK_ROLE_ARN##*/}"

log_info "--- IAM Inline Policy: ${XRAY_POLICY_NAME} on role ${TASK_ROLE_NAME} ---"

if aws iam get-role-policy \
    --role-name "${TASK_ROLE_NAME}" \
    --policy-name "${XRAY_POLICY_NAME}" > /dev/null 2>&1; then
  aws iam delete-role-policy \
    --role-name "${TASK_ROLE_NAME}" \
    --policy-name "${XRAY_POLICY_NAME}"
  if [ $? -ne 0 ]; then
    log_error "Failed to delete IAM inline policy ${XRAY_POLICY_NAME}"
    exit 1
  fi
  log_deleted "IAM inline policy ${XRAY_POLICY_NAME} from role ${TASK_ROLE_NAME}"
else
  log_skip "IAM inline policy ${XRAY_POLICY_NAME}"
fi

# =============================================================================
# === 2. Delete CloudWatch Dashboard ===
# =============================================================================

DASHBOARD_NAME="${ENV}-${APP_NAME}-dashboard"

log_info "--- CloudWatch Dashboard: ${DASHBOARD_NAME} ---"

# Check if dashboard exists
if aws cloudwatch get-dashboard \
    --dashboard-name "${DASHBOARD_NAME}" \
    --region "${AWS_REGION}" > /dev/null 2>&1; then
  aws cloudwatch delete-dashboards \
    --dashboard-names "${DASHBOARD_NAME}" \
    --region "${AWS_REGION}"
  if [ $? -ne 0 ]; then
    log_error "Failed to delete dashboard ${DASHBOARD_NAME}"
    exit 1
  fi
  log_deleted "Dashboard ${DASHBOARD_NAME}"
else
  log_skip "Dashboard ${DASHBOARD_NAME}"
fi

# =============================================================================
# === 3. Delete Log Metric Filters ===
# =============================================================================

log_info "--- Log Metric Filters ---"

FILTER_5XX_NAME="${ENV}-${APP_NAME}-filter-5xx-errors"
FILTER_LATENCY_NAME="${ENV}-${APP_NAME}-filter-latency"

for FILTER_NAME in "$FILTER_5XX_NAME" "$FILTER_LATENCY_NAME"; do
  # Check if metric filter exists
  EXISTING_FILTER=$(aws logs describe-metric-filters \
    --log-group-name "${LOG_GROUP}" \
    --filter-name-prefix "${FILTER_NAME}" \
    --region "${AWS_REGION}" \
    --query "metricFilters[?filterName=='${FILTER_NAME}'].filterName | [0]" \
    --output text 2>/dev/null || echo "")

  if [ -n "$EXISTING_FILTER" ] && [ "$EXISTING_FILTER" != "None" ]; then
    aws logs delete-metric-filter \
      --log-group-name "${LOG_GROUP}" \
      --filter-name "${FILTER_NAME}" \
      --region "${AWS_REGION}"
    if [ $? -ne 0 ]; then
      log_error "Failed to delete metric filter ${FILTER_NAME}"
      exit 1
    fi
    log_deleted "Metric filter ${FILTER_NAME}"
  else
    log_skip "Metric filter ${FILTER_NAME}"
  fi
done

# =============================================================================
# === 4. Delete CloudWatch Alarms ===
# =============================================================================

log_info "--- CloudWatch Alarms ---"

ALARM_NAMES=(
  "${ENV}-${APP_NAME}-alarm-cpu-high"
  "${ENV}-${APP_NAME}-alarm-memory-high"
  "${ENV}-${APP_NAME}-alarm-5xx"
  "${ENV}-${APP_NAME}-alarm-unhealthy-hosts"
  "${ENV}-${APP_NAME}-alarm-vpn-tunnel-down"
  "${ENV}-${APP_NAME}-alarm-no-running-tasks"
  "${ENV}-${APP_NAME}-alarm-4xx"
  "${ENV}-${APP_NAME}-alarm-response-time-high"
)

# Check which alarms exist before deleting
EXISTING_ALARMS=$(aws cloudwatch describe-alarms \
  --alarm-names "${ALARM_NAMES[@]}" \
  --region "${AWS_REGION}" \
  --query "MetricAlarms[].AlarmName" \
  --output text 2>/dev/null || echo "")

if [ -n "$EXISTING_ALARMS" ] && [ "$EXISTING_ALARMS" != "None" ]; then
  aws cloudwatch delete-alarms \
    --alarm-names "${ALARM_NAMES[@]}" \
    --region "${AWS_REGION}"
  if [ $? -ne 0 ]; then
    log_error "Failed to delete CloudWatch alarms"
    exit 1
  fi
  for ALARM in $EXISTING_ALARMS; do
    log_deleted "Alarm ${ALARM}"
  done
else
  log_skip "CloudWatch alarms (none found)"
fi

# =============================================================================
# === 5. Delete SNS Subscriptions ===
# =============================================================================

SNS_TOPIC_NAME="${ENV}-${APP_NAME}-alarms"

log_info "--- SNS Subscriptions for topic: ${SNS_TOPIC_NAME} ---"

# Find topic ARN
SNS_TOPIC_ARN=$(aws sns list-topics --region "${AWS_REGION}" --output text \
  --query "Topics[?ends_with(TopicArn, ':${SNS_TOPIC_NAME}')].TopicArn | [0]" 2>/dev/null || echo "")

if [ -n "$SNS_TOPIC_ARN" ] && [ "$SNS_TOPIC_ARN" != "None" ]; then
  # List all subscriptions for this topic
  SUBSCRIPTIONS=$(aws sns list-subscriptions-by-topic \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --region "${AWS_REGION}" \
    --query "Subscriptions[].SubscriptionArn" \
    --output text 2>/dev/null || echo "")

  if [ -n "$SUBSCRIPTIONS" ] && [ "$SUBSCRIPTIONS" != "None" ]; then
    for SUB_ARN in $SUBSCRIPTIONS; do
      # Skip PendingConfirmation subscriptions (they can't be unsubscribed)
      if [ "$SUB_ARN" == "PendingConfirmation" ]; then
        log_skip "Subscription (PendingConfirmation)"
        continue
      fi
      aws sns unsubscribe \
        --subscription-arn "${SUB_ARN}" \
        --region "${AWS_REGION}" 2>/dev/null || true
      log_deleted "SNS subscription ${SUB_ARN}"
    done
  else
    log_skip "SNS subscriptions (none found)"
  fi

  # ==========================================================================
  # === 6. Delete SNS Topic ===
  # ==========================================================================

  log_info "--- SNS Topic: ${SNS_TOPIC_NAME} ---"

  aws sns delete-topic \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --region "${AWS_REGION}"
  if [ $? -ne 0 ]; then
    log_error "Failed to delete SNS topic ${SNS_TOPIC_NAME}"
    exit 1
  fi
  log_deleted "SNS Topic ${SNS_TOPIC_NAME} (${SNS_TOPIC_ARN})"
else
  log_skip "SNS Topic ${SNS_TOPIC_NAME} - does not exist"
fi

log_info "=== Observability: deletion complete for ${ENV} ==="
