#!/usr/bin/env bash
# aws-cli/security-groups/delete.sh - Revert SGs to permissive (restore original)
# Usage: ./delete.sh <dev|prod>

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
load_env "$ENV"

log_info "Reverting Security Groups to permissive for $ENV"

# Restore all-traffic egress on ALB SG
aws ec2 authorize-security-group-egress --group-id "$ALB_SG_ID" \
  --ip-permissions "IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]" --region "$AWS_REGION" 2>/dev/null
log_info "Restored all-traffic egress on ALB SG $ALB_SG_ID"

# Restore all-traffic egress on ECS SG
aws ec2 authorize-security-group-egress --group-id "$ECS_SG_ID" \
  --ip-permissions "IpProtocol=-1,IpRanges=[{CidrIp=0.0.0.0/0}]" --region "$AWS_REGION" 2>/dev/null
log_info "Restored all-traffic egress on ECS SG $ECS_SG_ID"

log_info "SG revert complete for $ENV"
