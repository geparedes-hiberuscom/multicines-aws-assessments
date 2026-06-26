#!/usr/bin/env bash
# aws-cli/security-groups/create.sh - Harden SG egress rules
#
# Usage: ./create.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

# === Dependency validations ===
require_resource "ALB SG $ALB_SG_ID" \
  "aws ec2 describe-security-groups --group-ids $ALB_SG_ID --region $AWS_REGION" \
  "SG must exist in AWS"
require_resource "ECS SG $ECS_SG_ID" \
  "aws ec2 describe-security-groups --group-ids $ECS_SG_ID --region $AWS_REGION" \
  "SG must exist in AWS"

log_info "Hardening Security Groups for $ENV (ALB: $ALB_SG_ID, ECS: $ECS_SG_ID)"

# === Helper functions ===
has_all_traffic_egress() {
  local sg_id="$1"
  local count=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${sg_id}" --region "$AWS_REGION" \
    --query "SecurityGroupRules[?IsEgress==\`true\` && IpProtocol==\`-1\` && CidrIpv4==\`0.0.0.0/0\`] | length(@)" \
    --output text 2>/dev/null || true)
  [ "${count:-0}" -gt 0 ]
}

has_sg_egress_rule() {
  local sg_id="$1" dest_sg="$2" port="$3"
  local count=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${sg_id}" --region "$AWS_REGION" \
    --query "SecurityGroupRules[?IsEgress==\`true\` && IpProtocol==\`tcp\` && FromPort==\`${port}\` && ToPort==\`${port}\` && ReferencedGroupInfo.GroupId==\`${dest_sg}\`] | length(@)" \
    --output text 2>/dev/null || true)
  [ "${count:-0}" -gt 0 ]
}

has_cidr_egress_rule() {
  local sg_id="$1" cidr="$2" port="$3"
  local count=$(aws ec2 describe-security-group-rules \
    --filters "Name=group-id,Values=${sg_id}" --region "$AWS_REGION" \
    --query "SecurityGroupRules[?IsEgress==\`true\` && IpProtocol==\`tcp\` && FromPort==\`${port}\` && ToPort==\`${port}\` && CidrIpv4==\`${cidr}\`] | length(@)" \
    --output text 2>/dev/null || true)
  [ "${count:-0}" -gt 0 ]
}

# === ALB SG: revoke all-traffic, add ALB->ECS:8095 ===
if has_all_traffic_egress "$ALB_SG_ID"; then
  aws ec2 revoke-security-group-egress --group-id "$ALB_SG_ID" \
    --ip-permissions "IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]" --region "$AWS_REGION"
  log_created "Revoked all-traffic egress on ALB SG"
else
  log_skip "All-traffic egress on ALB SG already removed"
fi

if has_sg_egress_rule "$ALB_SG_ID" "$ECS_SG_ID" "$CONTAINER_PORT"; then
  log_skip "ALB->ECS:$CONTAINER_PORT egress"
else
  aws ec2 authorize-security-group-egress --group-id "$ALB_SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=$CONTAINER_PORT,ToPort=$CONTAINER_PORT,UserIdGroupPairs=[{GroupId=${ECS_SG_ID}}]" \
    --region "$AWS_REGION"
  log_created "ALB->ECS:$CONTAINER_PORT egress"
fi

# === ECS SG: revoke all-traffic, add ECS->HTTPS:443 ===
if has_all_traffic_egress "$ECS_SG_ID"; then
  aws ec2 revoke-security-group-egress --group-id "$ECS_SG_ID" \
    --ip-permissions "IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]" --region "$AWS_REGION"
  log_created "Revoked all-traffic egress on ECS SG"
else
  log_skip "All-traffic egress on ECS SG already removed"
fi

if has_cidr_egress_rule "$ECS_SG_ID" "0.0.0.0/0" 443; then
  log_skip "ECS->HTTPS:443 egress"
else
  aws ec2 authorize-security-group-egress --group-id "$ECS_SG_ID" \
    --ip-permissions "IpProtocol=tcp,FromPort=443,ToPort=443,IpRanges=[{CidrIp=0.0.0.0/0,Description=AWS service endpoints}]" \
    --region "$AWS_REGION"
  log_created "ECS->HTTPS:443 egress"
fi

log_info "SG hardening complete for $ENV"
