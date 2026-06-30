#!/usr/bin/env bash
# aws-cli/observability/create.sh — Create observability resources
#
# Creates SNS Topic, CloudWatch Alarms, Log Metric Filters, Dashboard,
# and X-Ray IAM Policy for the specified environment.
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "=== Observability: provisioning resources for ${ENV} ==="

# =============================================================================
# === Section: SNS Topic for Alarms ===
# =============================================================================

SNS_TOPIC_NAME="${ENV}-${APP_NAME}-alarms"

log_info "--- SNS Topic: ${SNS_TOPIC_NAME} ---"

# Check if topic already exists
EXISTING_TOPIC_ARN=$(aws sns list-topics --region "${AWS_REGION}" --output text \
  --query "Topics[?ends_with(TopicArn, ':${SNS_TOPIC_NAME}')].TopicArn | [0]" 2>/dev/null || echo "")

if [ -n "$EXISTING_TOPIC_ARN" ] && [ "$EXISTING_TOPIC_ARN" != "None" ]; then
  log_skip "SNS Topic ${SNS_TOPIC_NAME}"
  SNS_TOPIC_ARN="$EXISTING_TOPIC_ARN"
else
  # Create SNS Topic
  SNS_TOPIC_ARN=$(aws sns create-topic \
    --name "${SNS_TOPIC_NAME}" \
    --tags $(get_tags "${SNS_TOPIC_NAME}") \
    --region "${AWS_REGION}" \
    --output text --query "TopicArn")

  if [ -z "$SNS_TOPIC_ARN" ]; then
    log_error "Failed to create SNS Topic ${SNS_TOPIC_NAME}"
    exit 1
  fi

  log_created "SNS Topic ${SNS_TOPIC_NAME} (${SNS_TOPIC_ARN})"

  # Subscribe email endpoint
  aws sns subscribe \
    --topic-arn "${SNS_TOPIC_ARN}" \
    --protocol email \
    --notification-endpoint "${SNS_ALARM_EMAIL}" \
    --region "${AWS_REGION}" > /dev/null

  log_info "Email subscription created: ${SNS_ALARM_EMAIL} (pending confirmation)"
fi

export SNS_TOPIC_ARN
log_info "SNS_TOPIC_ARN=${SNS_TOPIC_ARN}"

# =============================================================================
# === Section: CloudWatch Alarms ===
# =============================================================================

log_info "--- CloudWatch Alarms ---"

# --- 15.1: CPU High Alarm ---
ALARM_CPU_NAME="${ENV}-${APP_NAME}-alarm-cpu-high"
log_info "Creating/updating alarm: ${ALARM_CPU_NAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_CPU_NAME}" \
  --alarm-description "CPU utilization exceeds ${ALARM_CPU_THRESHOLD}% for ECS service ${ECS_SERVICE_NAME}" \
  --namespace "AWS/ECS" \
  --metric-name "CPUUtilization" \
  --dimensions Name=ServiceName,Value="${ECS_SERVICE_NAME}" Name=ClusterName,Value="${ECS_CLUSTER}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${ALARM_CPU_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_CPU_NAME}"

# --- 15.2: Memory High Alarm ---
ALARM_MEMORY_NAME="${ENV}-${APP_NAME}-alarm-memory-high"
log_info "Creating/updating alarm: ${ALARM_MEMORY_NAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_MEMORY_NAME}" \
  --alarm-description "Memory utilization exceeds ${ALARM_MEMORY_THRESHOLD}% for ECS service ${ECS_SERVICE_NAME}" \
  --namespace "AWS/ECS" \
  --metric-name "MemoryUtilization" \
  --dimensions Name=ServiceName,Value="${ECS_SERVICE_NAME}" Name=ClusterName,Value="${ECS_CLUSTER}" \
  --statistic "Average" \
  --period 300 \
  --evaluation-periods 2 \
  --threshold "${ALARM_MEMORY_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_MEMORY_NAME}"

# --- 15.3: 5xx Errors Alarm ---
ALARM_5XX_NAME="${ENV}-${APP_NAME}-alarm-5xx"
log_info "Creating/updating alarm: ${ALARM_5XX_NAME}"

# Get ALB ARN to extract the full name for the LoadBalancer dimension
ALB_ARN=$(aws elbv2 describe-load-balancers \
  --names "${ALB_NAME}" \
  --region "${AWS_REGION}" \
  --query "LoadBalancers[0].LoadBalancerArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$ALB_ARN" ] || [ "$ALB_ARN" = "None" ]; then
  log_error "ALB ${ALB_NAME} not found. Cannot create 5xx alarm."
  exit 1
fi

# Extract "app/{alb-name}/{id}" suffix from ARN for the LoadBalancer dimension
ALB_FULL_NAME=$(echo "$ALB_ARN" | sed 's|.*:loadbalancer/||')

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_5XX_NAME}" \
  --alarm-description "5xx errors exceed ${ALARM_5XX_THRESHOLD} on ALB ${ALB_NAME}" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_Target_5XX_Count" \
  --dimensions Name=LoadBalancer,Value="${ALB_FULL_NAME}" \
  --statistic "Sum" \
  --period 60 \
  --evaluation-periods 3 \
  --threshold "${ALARM_5XX_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_5XX_NAME}"

# --- 15.4: Unhealthy Hosts Alarm ---
ALARM_UNHEALTHY_NAME="${ENV}-${APP_NAME}-alarm-unhealthy-hosts"
log_info "Creating/updating alarm: ${ALARM_UNHEALTHY_NAME}"

# Get Target Group ARN to extract the full name for the TargetGroup dimension
TG_ARN=$(aws elbv2 describe-target-groups \
  --names "${ECS_TG_NAME}" \
  --region "${AWS_REGION}" \
  --query "TargetGroups[0].TargetGroupArn" \
  --output text 2>/dev/null || echo "")

if [ -z "$TG_ARN" ] || [ "$TG_ARN" = "None" ]; then
  log_error "Target Group ${ECS_TG_NAME} not found. Cannot create unhealthy hosts alarm."
  exit 1
fi

# Extract "targetgroup/{tg-name}/{id}" suffix from ARN for the TargetGroup dimension
TG_FULL_NAME=$(echo "$TG_ARN" | sed 's|.*:targetgroup|targetgroup|')

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_UNHEALTHY_NAME}" \
  --alarm-description "Unhealthy hosts detected in Target Group ${ECS_TG_NAME}" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "UnHealthyHostCount" \
  --dimensions Name=TargetGroup,Value="${TG_FULL_NAME}" Name=LoadBalancer,Value="${ALB_FULL_NAME}" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_UNHEALTHY_NAME}"

# --- VPN Tunnel Down Alarm (only when real IP configured) ---
ALARM_VPN_NAME="${ENV}-${APP_NAME}-alarm-vpn-tunnel-down"

if [ "${VPN_CUSTOMER_IP}" != "0.0.0.0" ]; then
  log_info "Creating/updating alarm: ${ALARM_VPN_NAME}"

  # Get VPN Connection ID
  VPN_CONN_ID=$(aws ec2 describe-vpn-connections \
    --filters "Name=tag:Name,Values=${VPN_NAME}" "Name=state,Values=available" \
    --region "${AWS_REGION}" \
    --query "VpnConnections[0].VpnConnectionId" \
    --output text 2>/dev/null || echo "")

  if [ -n "$VPN_CONN_ID" ] && [ "$VPN_CONN_ID" != "None" ]; then
    aws cloudwatch put-metric-alarm \
      --alarm-name "${ALARM_VPN_NAME}" \
      --alarm-description "VPN tunnel is DOWN for connection ${VPN_NAME}" \
      --namespace "AWS/VPN" \
      --metric-name "TunnelState" \
      --dimensions Name=VpnId,Value="${VPN_CONN_ID}" \
      --statistic "Maximum" \
      --period 60 \
      --evaluation-periods 2 \
      --threshold 1 \
      --comparison-operator "LessThanThreshold" \
      --treat-missing-data "breaching" \
      --alarm-actions "${SNS_TOPIC_ARN}" \
      --region "${AWS_REGION}"
    log_created "Alarm ${ALARM_VPN_NAME}"
  else
    log_info "VPN connection ${VPN_NAME} not found — skipping VPN tunnel alarm"
  fi
else
  log_info "VPN_CUSTOMER_IP is placeholder (0.0.0.0) — skipping VPN tunnel alarm"
fi

# --- ECS Running Task Count = 0 Alarm ---
ALARM_TASKS_NAME="${ENV}-${APP_NAME}-alarm-no-running-tasks"
log_info "Creating/updating alarm: ${ALARM_TASKS_NAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_TASKS_NAME}" \
  --alarm-description "No running tasks for ECS service ${ECS_SERVICE_NAME} — service is DOWN" \
  --namespace "ECS/ContainerInsights" \
  --metric-name "RunningTaskCount" \
  --dimensions Name=ServiceName,Value="${ECS_SERVICE_NAME}" Name=ClusterName,Value="${ECS_CLUSTER}" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 2 \
  --threshold 1 \
  --comparison-operator "LessThanThreshold" \
  --treat-missing-data "notBreaching" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_TASKS_NAME}"

# --- ALB 4xx High Alarm ---
ALARM_4XX_NAME="${ENV}-${APP_NAME}-alarm-4xx"
log_info "Creating/updating alarm: ${ALARM_4XX_NAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_4XX_NAME}" \
  --alarm-description "4xx errors exceed ${ALARM_4XX_THRESHOLD} on ALB ${ALB_NAME}" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "HTTPCode_Target_4XX_Count" \
  --dimensions Name=LoadBalancer,Value="${ALB_FULL_NAME}" \
  --statistic "Sum" \
  --period 60 \
  --evaluation-periods 3 \
  --threshold "${ALARM_4XX_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_4XX_NAME}"

# --- ALB Response Time High Alarm ---
ALARM_RESPONSE_TIME_NAME="${ENV}-${APP_NAME}-alarm-response-time-high"
log_info "Creating/updating alarm: ${ALARM_RESPONSE_TIME_NAME}"

aws cloudwatch put-metric-alarm \
  --alarm-name "${ALARM_RESPONSE_TIME_NAME}" \
  --alarm-description "Target response time exceeds ${ALARM_RESPONSE_TIME_THRESHOLD}s on ALB ${ALB_NAME}" \
  --namespace "AWS/ApplicationELB" \
  --metric-name "TargetResponseTime" \
  --dimensions Name=LoadBalancer,Value="${ALB_FULL_NAME}" \
  --statistic "Average" \
  --period 60 \
  --evaluation-periods 3 \
  --threshold "${ALARM_RESPONSE_TIME_THRESHOLD}" \
  --comparison-operator "GreaterThanOrEqualToThreshold" \
  --treat-missing-data "notBreaching" \
  --alarm-actions "${SNS_TOPIC_ARN}" \
  --region "${AWS_REGION}"

log_created "Alarm ${ALARM_RESPONSE_TIME_NAME}"

# =============================================================================
# === Section: Log Metric Filters ===
# =============================================================================

log_info "--- Log Metric Filters ---"

# --- 16.1: 5xx Error Metric Filter ---
FILTER_5XX_NAME="${ENV}-${APP_NAME}-filter-5xx-errors"
log_info "Creating/updating metric filter: ${FILTER_5XX_NAME}"

aws logs put-metric-filter \
  --log-group-name "${LOG_GROUP}" \
  --filter-name "${FILTER_5XX_NAME}" \
  --filter-pattern '{ $.status >= 500 }' \
  --metric-transformations \
    metricName=5xxErrors,metricNamespace="Multicines/${ENV}",metricValue=1 \
  --region "${AWS_REGION}"

log_created "Metric filter ${FILTER_5XX_NAME}"

# --- 16.2: Latency Metric Filter ---
FILTER_LATENCY_NAME="${ENV}-${APP_NAME}-filter-latency"
log_info "Creating/updating metric filter: ${FILTER_LATENCY_NAME}"

aws logs put-metric-filter \
  --log-group-name "${LOG_GROUP}" \
  --filter-name "${FILTER_LATENCY_NAME}" \
  --filter-pattern '{ $.duration_ms = * }' \
  --metric-transformations \
    metricName=Latency,metricNamespace="Multicines/${ENV}",metricValue='$.duration_ms' \
  --region "${AWS_REGION}"

log_created "Metric filter ${FILTER_LATENCY_NAME}"

# =============================================================================
# === Section: CloudWatch Dashboard ===
# =============================================================================

DASHBOARD_NAME="${ENV}-${APP_NAME}-dashboard"

log_info "--- CloudWatch Dashboard: ${DASHBOARD_NAME} ---"

# Build dashboard body JSON using heredoc
DASHBOARD_BODY=$(cat <<EOF
{
  "widgets": [
    {
      "type": "metric",
      "x": 0,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ECS", "CPUUtilization", "ServiceName", "${ECS_SERVICE_NAME}", "ClusterName", "${ECS_CLUSTER}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ECS CPU Utilization",
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 0,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ECS", "MemoryUtilization", "ServiceName", "${ECS_SERVICE_NAME}", "ClusterName", "${ECS_CLUSTER}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ECS Memory Utilization",
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 6,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "RequestCount", "LoadBalancer", "${ALB_FULL_NAME}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ALB Request Count",
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 8,
      "y": 6,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count", "LoadBalancer", "${ALB_FULL_NAME}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ALB 5xx Error Rate",
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 16,
      "y": 6,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "TargetResponseTime", "LoadBalancer", "${ALB_FULL_NAME}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ALB Target Response Time",
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HealthyHostCount", "TargetGroup", "${TG_FULL_NAME}", "LoadBalancer", "${ALB_FULL_NAME}"],
          ["AWS/ApplicationELB", "UnHealthyHostCount", "TargetGroup", "${TG_FULL_NAME}", "LoadBalancer", "${ALB_FULL_NAME}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "Healthy / Unhealthy Hosts",
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 12,
      "y": 12,
      "width": 12,
      "height": 6,
      "properties": {
        "metrics": [
          ["Multicines/${ENV}", "5xxErrors"],
          ["Multicines/${ENV}", "Latency"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "Custom Metrics (5xx Errors & Latency)",
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 0,
      "y": 18,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["ECS/ContainerInsights", "RunningTaskCount", "ServiceName", "${ECS_SERVICE_NAME}", "ClusterName", "${ECS_CLUSTER}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ECS Running Task Count",
        "stat": "Average"
      }
    },
    {
      "type": "metric",
      "x": 8,
      "y": 18,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/ApplicationELB", "HTTPCode_Target_4XX_Count", "LoadBalancer", "${ALB_FULL_NAME}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "ALB 4xx Error Count",
        "stat": "Sum"
      }
    },
    {
      "type": "metric",
      "x": 16,
      "y": 18,
      "width": 8,
      "height": 6,
      "properties": {
        "metrics": [
          ["AWS/VPN", "TunnelState", "VpnId", "${VPN_CONN_ID:-N/A}"]
        ],
        "period": 300,
        "region": "${AWS_REGION}",
        "title": "VPN Tunnel State",
        "stat": "Maximum"
      }
    }
  ]
}
EOF
)

# put-dashboard is idempotent — creates or updates the dashboard
aws cloudwatch put-dashboard \
  --dashboard-name "${DASHBOARD_NAME}" \
  --dashboard-body "${DASHBOARD_BODY}" \
  --region "${AWS_REGION}"

log_created "Dashboard ${DASHBOARD_NAME}"

# =============================================================================
# === Section: X-Ray IAM Policy ===
# =============================================================================

XRAY_POLICY_NAME="${ENV}-${APP_NAME}-xray-policy"
TASK_ROLE_NAME="${TASK_ROLE_ARN##*/}"

log_info "--- X-Ray IAM Policy: ${XRAY_POLICY_NAME} on role ${TASK_ROLE_NAME} ---"

# Check if inline policy already exists
if aws iam get-role-policy \
    --role-name "${TASK_ROLE_NAME}" \
    --policy-name "${XRAY_POLICY_NAME}" > /dev/null 2>&1; then
  log_skip "IAM inline policy ${XRAY_POLICY_NAME}"
else
  # Create inline policy with X-Ray permissions
  XRAY_POLICY_DOC=$(cat <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "xray:PutTraceSegments",
        "xray:PutTelemetryRecords",
        "xray:GetSamplingRules",
        "xray:GetSamplingTargets"
      ],
      "Resource": "*"
    }
  ]
}
EOF
)

  if aws iam put-role-policy \
      --role-name "${TASK_ROLE_NAME}" \
      --policy-name "${XRAY_POLICY_NAME}" \
      --policy-document "${XRAY_POLICY_DOC}"; then
    log_created "IAM inline policy ${XRAY_POLICY_NAME} on role ${TASK_ROLE_NAME}"
  else
    log_error "Failed to create IAM inline policy ${XRAY_POLICY_NAME}"
    exit 1
  fi
fi

log_info "=== Observability: provisioning complete for ${ENV} ==="
