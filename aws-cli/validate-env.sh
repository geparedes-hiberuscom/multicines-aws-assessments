#!/usr/bin/env bash
# aws-cli/validate-env.sh - Validate that existing resources in env.properties exist in AWS
#
# Checks VPC, subnets, security groups, log groups, ECS cluster, ECR repo, IAM roles
# Reports what EXISTS (ready to use) and what's MISSING (needs attention)
#
# Usage: ./validate-env.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

PASS=0
FAIL=0

check() {
  local name="$1" cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "[OK] $name"
    PASS=$((PASS + 1))
  else
    echo "[MISSING] $name"
    FAIL=$((FAIL + 1))
  fi
}

echo "============================================"
echo " Validating environment: $ENV"
echo "============================================"
echo ""

echo "--- Existing resources (should exist) ---"
check "VPC $VPC_ID" "aws ec2 describe-vpcs --vpc-ids $VPC_ID --region $AWS_REGION"

IFS=',' read -ra PUB_SUBS <<< "$PUBLIC_SUBNETS"
for s in "${PUB_SUBS[@]}"; do
  check "Public Subnet $s" "aws ec2 describe-subnets --subnet-ids $s --region $AWS_REGION"
done

IFS=',' read -ra PRIV_SUBS <<< "$PRIVATE_SUBNETS"
for s in "${PRIV_SUBS[@]}"; do
  check "Private Subnet $s" "aws ec2 describe-subnets --subnet-ids $s --region $AWS_REGION"
done

check "ALB SG $ALB_SG_ID" "aws ec2 describe-security-groups --group-ids $ALB_SG_ID --region $AWS_REGION"
check "ECS SG $ECS_SG_ID" "aws ec2 describe-security-groups --group-ids $ECS_SG_ID --region $AWS_REGION"
check "Log Group $LOG_GROUP" "aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP --region $AWS_REGION --query 'logGroups[0].logGroupName' --output text"
check "ECS Cluster $ECS_CLUSTER" "aws ecs describe-clusters --clusters $ECS_CLUSTER --region $AWS_REGION --query 'clusters[?status==\`ACTIVE\`].clusterName | [0]' --output text"
check "ECR Repo $ECR_REPO" "aws ecr describe-repositories --repository-names $ECR_REPO --region $AWS_REGION"

EXEC_ROLE=$(echo "$EXECUTION_ROLE_ARN" | awk -F'/' '{print $NF}')
TASK_ROLE_NAME=$(echo "$TASK_ROLE_ARN" | awk -F'/' '{print $NF}')
check "IAM Execution Role $EXEC_ROLE" "aws iam get-role --role-name $EXEC_ROLE"
check "IAM Task Role $TASK_ROLE_NAME" "aws iam get-role --role-name $TASK_ROLE_NAME"

echo ""
echo "--- Resources to CREATE (should NOT exist yet) ---"

# ALB_NAME from env.properties
if aws elbv2 describe-load-balancers --names "$ALB_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
  echo "[EXISTS] ALB $ALB_NAME (already created)"
else
  echo "[TO CREATE] ALB $ALB_NAME"
fi

if aws elbv2 describe-target-groups --names "$ECS_TG_NAME" --region "$AWS_REGION" > /dev/null 2>&1; then
  echo "[EXISTS] Target Group $ECS_TG_NAME (already created)"
else
  echo "[TO CREATE] Target Group $ECS_TG_NAME"
fi

WEB_ACL_NAME="$WAF_NAME"
WAF_EXISTS=$(aws wafv2 list-web-acls --scope REGIONAL --region "$AWS_REGION" --query "WebACLs[?Name=='${WEB_ACL_NAME}'].Name | [0]" --output text 2>/dev/null || true)
if [ -n "$WAF_EXISTS" ] && [ "$WAF_EXISTS" != "None" ]; then
  echo "[EXISTS] WAF $WEB_ACL_NAME (already created)"
else
  echo "[TO CREATE] WAF $WEB_ACL_NAME"
fi

CERT_EXISTS=$(aws acm list-certificates --region "$AWS_REGION" --query "CertificateSummaryList[?DomainName=='${DOMAIN}'].DomainName | [0]" --output text 2>/dev/null || true)
if [ -n "$CERT_EXISTS" ] && [ "$CERT_EXISTS" != "None" ]; then
  echo "[EXISTS] ACM Certificate $DOMAIN (already imported)"
else
  echo "[TO CREATE] ACM Certificate $DOMAIN"
fi

SVC_STATUS=$(aws ecs describe-services --cluster "$ECS_CLUSTER" --services "$ECS_SERVICE_NAME" --region "$AWS_REGION" --query 'services[0].status' --output text 2>/dev/null || true)
if [ "$SVC_STATUS" == "ACTIVE" ]; then
  echo "[EXISTS] ECS Service $ECS_SERVICE_NAME (already running)"
else
  echo "[TO CREATE] ECS Service $ECS_SERVICE_NAME"
fi

echo ""
echo "============================================"
echo " Results: $PASS OK, $FAIL MISSING"
echo "============================================"

if [ $FAIL -gt 0 ]; then
  echo ""
  echo "WARNING: Some existing resources are MISSING."
  echo "Fix env.properties or create the missing resources before running create-all.sh"
  exit 1
fi
