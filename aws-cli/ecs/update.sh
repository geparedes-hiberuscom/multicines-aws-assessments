#!/usr/bin/env bash
# aws-cli/ecs/update.sh - Register new task def revision and update service
# Usage: ./update.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Updating ECS for $ENV"

# Register new task definition revision
# Build environment variables for main container
OTEL_EXTRA_ENV=""
if [ "${OTEL_TRACES_EXPORTER}" == "otlp" ]; then
  OTEL_EXTRA_ENV=',
      {"name": "OTEL_SERVICE_NAME", "value": "'"${OTEL_SERVICE_NAME}"'"},
      {"name": "OTEL_EXPORTER_OTLP_ENDPOINT", "value": "http://localhost:4317"},
      {"name": "OTEL_EXPORTER_OTLP_PROTOCOL", "value": "grpc"},
      {"name": "OTEL_TRACES_SAMPLER", "value": "'"${OTEL_TRACES_SAMPLER}"'"},
      {"name": "OTEL_TRACES_SAMPLER_ARG", "value": "'"${OTEL_TRACES_SAMPLER_ARG}"'"}'
fi

# Build sidecar container definition (only when OTEL tracing enabled)
OTEL_SIDECAR_JSON=""
if [ "${OTEL_TRACES_EXPORTER}" == "otlp" ]; then
  OTEL_SIDECAR_JSON=',{
    "name": "aws-otel-collector",
    "image": "public.ecr.aws/aws-observability/aws-otel-collector:latest",
    "essential": false,
    "memory": 256,
    "portMappings": [{"containerPort": 4317, "protocol": "tcp"}],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "'"${LOG_GROUP}"'",
        "awslogs-region": "'"${AWS_REGION}"'",
        "awslogs-stream-prefix": "otel"
      }
    }
  }'
fi

TASK_DEF_JSON=$(cat <<EOF
{
  "family": "${ECS_TASK_FAMILY}",
  "networkMode": "awsvpc",
  "requiresCompatibilities": ["FARGATE"],
  "cpu": "${ECS_CPU}",
  "memory": "${ECS_MEMORY}",
  "executionRoleArn": "${EXECUTION_ROLE_ARN}",
  "taskRoleArn": "${TASK_ROLE_ARN}",
  "containerDefinitions": [{
    "name": "${CONTAINER_NAME}",
    "image": "${ECR_URI}:${ECS_IMAGE_TAG}",
    "essential": true,
    "portMappings": [{"containerPort": ${CONTAINER_PORT}, "protocol": "tcp"}],
    "environment": [
      {"name": "SPRING_PROFILES_ACTIVE", "value": "${SPRING_PROFILES_ACTIVE}"},
      {"name": "AWS_REGION", "value": "${AWS_REGION}"},
      {"name": "OTEL_LOGS_EXPORTER", "value": "${OTEL_LOGS_EXPORTER}"},
      {"name": "OTEL_METRICS_EXPORTER", "value": "${OTEL_METRICS_EXPORTER}"},
      {"name": "OTEL_TRACES_EXPORTER", "value": "${OTEL_TRACES_EXPORTER}"}${OTEL_EXTRA_ENV}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "${LOG_GROUP}",
        "awslogs-region": "${AWS_REGION}",
        "awslogs-stream-prefix": "api"
      }
    }
  }${OTEL_SIDECAR_JSON}]
}
EOF
)

TASK_DEF_FILE=$(mktemp /tmp/task-def-XXXXXX.json)
echo "$TASK_DEF_JSON" > "$TASK_DEF_FILE"

TASK_DEF_ARN=$(aws ecs register-task-definition \
  --cli-input-json "file://${TASK_DEF_FILE}" \
  --region "$AWS_REGION" --query 'taskDefinition.taskDefinitionArn' --output text)
rm -f "$TASK_DEF_FILE"

if [ -z "$TASK_DEF_ARN" ]; then log_error "Failed to register task def"; exit 1; fi
log_created "Task definition revision: $TASK_DEF_ARN"

# Update service to use new task definition
EXEC_FLAG=""
if [ "${ECS_ENABLE_EXEC:-true}" == "true" ]; then
  EXEC_FLAG="--enable-execute-command"
fi
aws ecs update-service --cluster "$ECS_CLUSTER" --service "$ECS_SERVICE_NAME" \
  --task-definition "$TASK_DEF_ARN" --health-check-grace-period-seconds 210 \
  $EXEC_FLAG --region "$AWS_REGION" > /dev/null

log_updated "ECS service $ECS_SERVICE_NAME -> $TASK_DEF_ARN"
log_info "Waiting for service stability..."

aws ecs wait services-stable --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE_NAME" --region "$AWS_REGION"
log_info "Service stable"
