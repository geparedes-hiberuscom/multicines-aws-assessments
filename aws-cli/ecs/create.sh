#!/usr/bin/env bash
# aws-cli/ecs/create.sh Register Task Definition and Create ECS Service
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# === Generate resource names ===
# === Names from env.properties ===
TASK_DEF_FAMILY="${ECS_TASK_FAMILY}"
TG_NAME="${ECS_TG_NAME}"

# === Dependency validations ===
require_resource "Target Group $TG_NAME" \
 "aws elbv2 describe-target-groups --names $TG_NAME --region $AWS_REGION" \
 "alb/create.sh $ENV"

require_resource "Execution Role ecsTaskExecutionRole" \
 "aws iam get-role --role-name ecsTaskExecutionRole" \
 "IAM role must exist in AWS"

require_resource "Task Role multicines-ecs-task-role" \
 "aws iam get-role --role-name multicines-ecs-task-role" \
 "IAM role must exist in AWS"

require_resource "ECR Image ${ECR_REPO}:${ECS_IMAGE_TAG}" \
 "aws ecr describe-images --repository-name $ECR_REPO --image-ids imageTag=$ECS_IMAGE_TAG --region $AWS_REGION" \
 "Push an image to ECR first"

require_resource "Log Group $LOG_GROUP" \
 "aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $AWS_REGION" \
 "Log group must exist in AWS"

log_info "Provisioning ECS for $ENV (CPU:$ECS_CPU Mem:$ECS_MEMORY Count:$ECS_DESIRED_COUNT)"

# === 1. Register Task Definition ===

# Build main container environment variables (OTEL extras when tracing enabled)
OTEL_EXTRA_ENV=""
if [ "${OTEL_TRACES_EXPORTER}" == "otlp" ]; then
  OTEL_EXTRA_ENV=",
   {\"name\": \"OTEL_SERVICE_NAME\", \"value\": \"${OTEL_SERVICE_NAME}\"},
   {\"name\": \"OTEL_EXPORTER_OTLP_ENDPOINT\", \"value\": \"http://localhost:4317\"},
   {\"name\": \"OTEL_EXPORTER_OTLP_PROTOCOL\", \"value\": \"grpc\"},
   {\"name\": \"OTEL_TRACES_SAMPLER\", \"value\": \"${OTEL_TRACES_SAMPLER}\"},
   {\"name\": \"OTEL_TRACES_SAMPLER_ARG\", \"value\": \"${OTEL_TRACES_SAMPLER_ARG}\"}"
fi

# Build sidecar container JSON if OTEL tracing is enabled
OTEL_SIDECAR_JSON=""
if [ "${OTEL_TRACES_EXPORTER}" == "otlp" ]; then
  OTEL_SIDECAR_JSON=$(cat <<EOF
,{
 "name": "aws-otel-collector",
 "image": "public.ecr.aws/aws-observability/aws-otel-collector:latest",
 "essential": false,
 "memory": 256,
 "portMappings": [{"containerPort": 4317, "protocol": "tcp"}],
 "logConfiguration": {
 "logDriver": "awslogs",
 "options": {
 "awslogs-group": "${LOG_GROUP}",
 "awslogs-region": "${AWS_REGION}",
 "awslogs-stream-prefix": "otel"
 }
 }
}
EOF
)
fi

TASK_DEF_JSON=$(cat <<EOF
{
 "family": "${TASK_DEF_FAMILY}",
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
 --tags $(get_ecs_tags "$ECS_TASK_FAMILY") \
 --region "$AWS_REGION" \
 --query 'taskDefinition.taskDefinitionArn' --output text)

rm -f "$TASK_DEF_FILE"
if [ -z "$TASK_DEF_ARN" ]; then log_error "Failed to register task def"; exit 1; fi
log_created "Task definition $TASK_DEF_FAMILY (ARN: $TASK_DEF_ARN)"

# === 2. Get Target Group ARN ===
TG_ARN=$(aws elbv2 describe-target-groups --names "$TG_NAME" --region "$AWS_REGION" \
 --query 'TargetGroups[0].TargetGroupArn' --output text)

# === 3. Create ECS Service (idempotent) ===
SERVICE_STATUS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" \
 --services "$ECS_SERVICE_NAME" --region "$AWS_REGION" \
 --query 'services[0].status' --output text 2>/dev/null || true)

if [ "$SERVICE_STATUS" == "ACTIVE" ]; then
 log_skip "ECS service $ECS_SERVICE_NAME (ACTIVE)"
else
 # Wait if service is draining
 if [ "$SERVICE_STATUS" == "DRAINING" ]; then
   log_info "Service is DRAINING. Waiting..."
   while true; do
     sleep 10
     STATUS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" \
       --services "$ECS_SERVICE_NAME" --region "$AWS_REGION" \
       --query 'services[0].status' --output text 2>/dev/null || true)
     if [ "$STATUS" != "DRAINING" ]; then break; fi
     log_info "Still draining..."
   done
 fi
 # Create service
 EXEC_FLAG=""
 if [ "${ECS_ENABLE_EXEC:-true}" == "true" ]; then
   EXEC_FLAG="--enable-execute-command"
 fi
 SUBNETS_JSON=$(echo "$PRIVATE_SUBNETS" | tr ',' '\n' | sed 's/.*/"&"/' | paste -sd ',' -)
 aws ecs create-service --cluster "$ECS_CLUSTER" --service-name "$ECS_SERVICE_NAME" \
 --task-definition "$TASK_DEF_ARN" --launch-type FARGATE \
 --desired-count "$ECS_DESIRED_COUNT" $EXEC_FLAG \
 --network-configuration "awsvpcConfiguration={subnets=[${SUBNETS_JSON}],securityGroups=[\"${ECS_SG_ID}\"],assignPublicIp=DISABLED}" \
 --load-balancers "targetGroupArn=${TG_ARN},containerName=${CONTAINER_NAME},containerPort=${CONTAINER_PORT}" \
 --health-check-grace-period-seconds 210 \
 --region "$AWS_REGION" --tags $(get_ecs_tags "$ECS_SERVICE_NAME") > /dev/null
 if [ $? -ne 0 ]; then log_error "Failed to create ECS service"; exit 1; fi
 log_created "ECS service $ECS_SERVICE_NAME in $ECS_CLUSTER"
fi

log_info "ECS provisioning complete: $ECS_SERVICE_NAME"
