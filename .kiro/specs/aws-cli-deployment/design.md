# Design Document

## Overview

Este documento describe la arquitectura de scripts AWS CLI idempotentes para provisionar la infraestructura faltante de Multicines (ALB, VPN, WAF, ACM, SSM, Secrets Manager, Security Groups hardening, ECS Services) y el pipeline de documentación que convierte y extiende el manual de operaciones.

## Architecture

La solución se estructura en tres capas:

1. **Shared Library** (`scripts/lib/common.sh`) — Funciones reutilizables: naming, logging, idempotency checks
2. **Service Scripts** (`scripts/create-*.sh`, `scripts/harden-*.sh`) — Un script por servicio AWS, ejecutable de forma independiente
3. **Orchestrator** (`scripts/create-all.sh`) — Invoca los service scripts en orden de dependencias

```
scripts/
├── lib/
│   └── common.sh              # Shared library
├── create-all.sh              # Orchestrator
├── create-acm.sh             # ACM Certificate
├── create-waf.sh             # WAF Web ACL
├── harden-security-groups.sh # SG egress hardening
├── create-alb.sh             # ALB + Target Groups + Listeners
├── create-ssm.sh            # SSM Parameter Store
├── create-secrets.sh        # Secrets Manager
├── create-ecs-service.sh    # ECS Task Definition + Service
├── create-vpn.sh            # VPN Site-to-Site
├── convert-manual.sh        # DOCX → MD conversion
└── build-manual.sh          # Assemble + export MD → DOCX

documents/
├── sections/                # Pre-written new sections (ALB, VPN, WAF, etc.)
├── images/                  # Extracted images from DOCX
├── manual-multicines.md     # Assembled Markdown manual
└── manual-multicines.docx   # Exported DOCX
```

## Components and Interfaces

### Component 1: Shared Library (`scripts/lib/common.sh`)

**Responsibility:** Provide naming convention helpers, logging utilities, and idempotency patterns reusable by all service scripts.

**Interfaces:**

```bash
#!/usr/bin/env bash
# scripts/lib/common.sh — Shared library for Multicines AWS CLI scripts

set -euo pipefail

# === Constants ===
AWS_ACCOUNT="340271092920"
AWS_REGION="us-east-1"
ECS_CLUSTER="multicines-cluster"
ECR_REPO="multicines/integration-service"
ECR_URI="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
CONTAINER_PORT=8095

# === Environment-specific lookups ===
declare -A VPC_IDS=(
  [dev]="vpc-0a5ebea8e7bee9ed5"
  [prod]="vpc-0860a0d2cf4df6140"
)

declare -A PUBLIC_SUBNETS=(
  [dev]="subnet-0c92479c2831f04eb,subnet-02193c97ceb6ec25d"
  [prod]="subnet-04e4cd18763fd6f84,subnet-05c92a4889326c68e"
)

declare -A PRIVATE_SUBNETS=(
  [dev]="subnet-0eeec60453f7f9492"
  [prod]="subnet-0d55ebfe5adbd4e81,subnet-04f8ac3335c426f57"
)

declare -A ALB_SG_IDS=(
  [dev]="sg-0fdf0c744482646ae"
  [prod]="sg-04f21c4c1d065fe60"
)

declare -A ECS_SG_IDS=(
  [dev]="sg-01c619444bab0b8d3"
  [prod]="sg-0b78c14cd02b2f6e1"
)

declare -A LOG_GROUPS=(
  [dev]="/ecs/dev-multicines-integration"
  [prod]="/ecs/prod-multicines-integration"
)

# === Naming Helper ===
# Pattern: {env}-{resource}-{type}-{zone}
# Zone is optional — omitted when not applicable
generate_name() {
  local env=$1 resource=$2 type=$3 zone=${4:-""}
  if [ -z "$zone" ]; then
    echo "${env}-${resource}-${type}"
  else
    echo "${env}-${resource}-${type}-${zone}"
  fi
}

# === Logging ===
log_info() {
  echo "[INFO] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

log_error() {
  echo "[ERROR] $(date '+%Y-%m-%d %H:%M:%S') $*" >&2
}

log_skip() {
  echo "[SKIP] $(date '+%Y-%m-%d %H:%M:%S') $* — already exists"
}

log_created() {
  echo "[CREATED] $(date '+%Y-%m-%d %H:%M:%S') $*"
}

# === Idempotency Helper ===
# Usage: check_exists <describe_command> <resource_description>
# Returns 0 if resource exists, 1 if not
check_exists() {
  local describe_cmd="$1"
  if eval "$describe_cmd" > /dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

# === Environment Validation ===
validate_env() {
  local env=$1
  if [[ "$env" != "dev" && "$env" != "prod" ]]; then
    log_error "Invalid environment: $env. Must be 'dev' or 'prod'."
    exit 1
  fi
}
```

### Component 2: Orchestrator (`scripts/create-all.sh`)

**Responsibility:** Accept an environment parameter and invoke service scripts in dependency order.

**Execution Order (Dependency Chain):**

```
1. create-acm.sh        → ACM certificate (needs DNS validation before ALB can use it)
2. create-waf.sh        → WAF Web ACL (must exist before ALB association)
3. harden-security-groups.sh → Restrict egress rules
4. create-alb.sh        → ALB + Target Groups + Listeners (needs ACM ARN, WAF ARN, SGs)
5. create-ssm.sh       → SSM Parameters
6. create-secrets.sh   → Secrets Manager
7. create-ecs-service.sh → ECS Task Definition + Service (needs ALB TG, SSM, Secrets)
8. create-vpn.sh       → VPN (independent, placeholders)
```

**Interface:**

```bash
#!/usr/bin/env bash
# scripts/create-all.sh — Orchestrator

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
validate_env "$ENV"

log_info "=== Starting infrastructure provisioning for environment: $ENV ==="

SCRIPTS=(
  "create-acm.sh"
  "create-waf.sh"
  "harden-security-groups.sh"
  "create-alb.sh"
  "create-ssm.sh"
  "create-secrets.sh"
  "create-ecs-service.sh"
  "create-vpn.sh"
)

for script in "${SCRIPTS[@]}"; do
  log_info "--- Executing: $script ---"
  "${SCRIPT_DIR}/${script}" "$ENV"
  if [ $? -ne 0 ]; then
    log_error "Script $script failed. Stopping."
    exit 1
  fi
done

log_info "=== All scripts completed successfully for $ENV ==="
```

### Component 3: Service Scripts — Idempotency Pattern

Each service script follows a consistent pattern:

```bash
#!/usr/bin/env bash
# scripts/create-<service>.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

ENV="${1:?Usage: $0 <dev|prod>}"
validate_env "$ENV"

# 1. Generate resource name
RESOURCE_NAME=$(generate_name "$ENV" "<resource>" "<type>")

# 2. Check if resource exists (idempotency)
if check_exists "aws <service> describe-<resource> --name $RESOURCE_NAME --region $AWS_REGION"; then
  log_skip "$RESOURCE_NAME"
else
  # 3. Create resource
  aws <service> create-<resource> ... --region "$AWS_REGION"
  if [ $? -ne 0 ]; then
    log_error "Failed to create $RESOURCE_NAME"
    exit 1
  fi
  log_created "$RESOURCE_NAME"
fi
```

### Component 4: ALB Script (`scripts/create-alb.sh`)

**Responsibility:** Create ALB, Target Group, and HTTPS Listener for the specified environment.

**Key Operations:**
- Creates ALB of type `application` in public subnets with the existing ALB security group
- Creates Target Group with health check on port 8095, protocol HTTP
- Creates HTTPS:443 listener forwarding to the target group (requires ACM cert ARN)

**Data Flow:**
```
Input: ENV (dev|prod)
  → Lookup subnets: PUBLIC_SUBNETS[$ENV]
  → Lookup SG: ALB_SG_IDS[$ENV]
  → Generate names: generate_name($ENV, "alb", "application")
  → Check existence via: aws elbv2 describe-load-balancers --names <name>
  → Create ALB → ARN
  → Create Target Group → TG ARN
  → Create Listener (ALB ARN + TG ARN + ACM cert ARN)
Output: ALB ARN, Target Group ARN (stored for ECS script)
```

### Component 5: WAF Script (`scripts/create-waf.sh`)

**Responsibility:** Create a REGIONAL WAF Web ACL with rate limiting rule and associate it with the ALB.

**Key Operations:**
- Creates WAF Web ACL with scope REGIONAL
- Adds rate-based rule (configurable threshold)
- Associates Web ACL with the ALB ARN after ALB creation

### Component 6: ACM Script (`scripts/create-acm.sh`)

**Responsibility:** Request an ACM certificate and output DNS validation instructions.

**Key Operations:**
- Requests certificate via `aws acm request-certificate`
- Outputs CNAME records needed for DNS validation
- Tags certificate following naming convention

### Component 7: Security Groups Hardening (`scripts/harden-security-groups.sh`)

**Responsibility:** Replace permissive egress rules with restrictive ones on existing SGs.

**Key Operations:**
- Revokes `0.0.0.0/0` all-traffic egress on ALB SGs
- Adds egress rule ALB→ECS on port 8095 only
- Revokes `0.0.0.0/0` all-traffic egress on ECS SGs
- Adds egress rules ECS→HTTPS(443) for AWS service endpoints (ECR, CloudWatch, SSM, Secrets Manager)

### Component 8: VPN Script (`scripts/create-vpn.sh`)

**Responsibility:** Create VPN Site-to-Site resources with placeholder values for customer gateway.

**Key Operations:**
- Creates Customer Gateway with placeholder IP (`0.0.0.0`) and BGP ASN (`65000`)
- Creates Virtual Private Gateway and attaches to VPC
- Creates VPN Connection type `ipsec.1`
- Enables route propagation on private route tables

### Component 9: SSM Script (`scripts/create-ssm.sh`)

**Responsibility:** Create SSM parameters under `/multicines/integrator/{env}/` hierarchy.

**Parameters to create:**
- `/multicines/integrator/{env}/app` — Application config (vista.base-url)
- `/multicines/integrator/{env}/resilience` — Resilience4j configuration (SecureString due to sensitive thresholds)

### Component 10: Secrets Script (`scripts/create-secrets.sh`)

**Responsibility:** Create Secrets Manager secrets with placeholder values per environment.

**Key Operations:**
- Creates `{env}-multicines-integration-secrets` with placeholder JSON
- Idempotent: checks existence via `aws secretsmanager describe-secret`

### Component 11: ECS Service Script (`scripts/create-ecs-service.sh`)

**Responsibility:** Register Task Definition and create ECS Service in the existing cluster.

**Task Definition Configuration:**
- Image: `340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service:latest`
- CPU: 256, Memory: 512 (Fargate)
- Port mapping: containerPort 8095
- Execution role: `ecsTaskExecutionRole`
- Task role: `multicines-ecs-task-role`
- Log configuration: awslogs driver → log group `/ecs/{env}-multicines-integration`
- Secrets/environment from SSM and Secrets Manager

**ECS Service Configuration:**
- Cluster: `multicines-cluster`
- Launch type: FARGATE
- Network: private subnets + ECS security group
- Load balancer: target group from ALB script
- Desired count: 1

### Component 12: Documentation Pipeline

**`scripts/convert-manual.sh`:**
```bash
#!/usr/bin/env bash
# Convert DOCX → MD, extract images

PANDOC_VERSION="3.9.0.2"
SOURCE="Insumos iniciales/Manual para multicines.docx"
OUTPUT_DIR="documents"
IMAGES_DIR="${OUTPUT_DIR}/images"

mkdir -p "$IMAGES_DIR"

pandoc "$SOURCE" \
  -t markdown \
  --extract-media="$IMAGES_DIR" \
  -o "${OUTPUT_DIR}/manual-original.md"
```

**`scripts/build-manual.sh`:**
```bash
#!/usr/bin/env bash
# Assemble final manual (original + new sections) and export to DOCX

OUTPUT_DIR="documents"
SECTIONS_DIR="${OUTPUT_DIR}/sections"
FINAL_MD="${OUTPUT_DIR}/manual-multicines.md"
FINAL_DOCX="${OUTPUT_DIR}/manual-multicines.docx"

# Concatenate original + new sections
cat "${OUTPUT_DIR}/manual-original.md" > "$FINAL_MD"
for section in "$SECTIONS_DIR"/*.md; do
  echo "" >> "$FINAL_MD"
  cat "$section" >> "$FINAL_MD"
done

# Export to DOCX
pandoc "$FINAL_MD" \
  -o "$FINAL_DOCX" \
  --resource-path="${OUTPUT_DIR}"
```

## Data Models

### Environment Configuration Map

```bash
# Lookup tables in common.sh provide environment-specific resource IDs
# Key: environment name (dev|prod)
# Value: AWS resource ID

VPC_IDS[dev]="vpc-0a5ebea8e7bee9ed5"
VPC_IDS[prod]="vpc-0860a0d2cf4df6140"

PUBLIC_SUBNETS[dev]="subnet-0c92479c2831f04eb,subnet-02193c97ceb6ec25d"
PUBLIC_SUBNETS[prod]="subnet-04e4cd18763fd6f84,subnet-05c92a4889326c68e"

PRIVATE_SUBNETS[dev]="subnet-0eeec60453f7f9492"
PRIVATE_SUBNETS[prod]="subnet-0d55ebfe5adbd4e81,subnet-04f8ac3335c426f57"
```

### Naming Convention Pattern

```
Pattern: {env}-{resource}-{type}-{zone}
Examples:
  dev-alb-application        (no zone)
  prod-alb-application       (no zone)
  dev-tg-integration-8095    (with port as zone)
  dev-waf-webacl             (no zone)
  prod-vpn-connection        (no zone)
  dev-cgw-customer           (no zone)
  dev-vgw-gateway            (no zone)
```

### SSM Parameter Hierarchy

```
/multicines/integrator/{env}/app          → {"vista.base-url": "https://..."}
/multicines/integrator/{env}/resilience   → {resilience4j config JSON}
```

### Secrets Manager Structure

```
Secret Name: {env}-multicines-integration-secrets
Secret Value: JSON with application secrets (placeholder values)
```

## Error Handling

| Scenario | Behavior |
|----------|----------|
| Invalid environment parameter | `validate_env` prints error and exits with code 1 |
| AWS CLI command fails | Script captures exit code, logs error, exits with non-zero code |
| Resource already exists | Script logs skip message and continues to next resource |
| Network/API timeout | AWS CLI retries (default behavior), eventual failure triggers error path |
| Missing dependency (e.g., ALB ARN for ECS) | Orchestrator stops at failing script; user must run dependencies first |
| Pandoc not installed | Script checks for pandoc availability, exits with descriptive error |

## Testing Strategy

**Unit/Property Tests (Shell — using bats-core):**
- `generate_name` function: property-based testing with arbitrary (env, resource, type, zone) inputs
- Idempotency logic: mock AWS CLI responses to verify check-before-create pattern
- Orchestrator ordering: parse script to verify dependency chain

**Integration Tests (against real AWS):**
- Each service script run against a sandbox/dev account
- Verify resources exist with correct configuration post-execution
- Run scripts twice to confirm idempotency (no errors on re-run)

**Smoke Tests:**
- File structure validation (scripts exist at expected paths)
- Pandoc availability and version check
- Manual output file generation

**Documentation Tests:**
- Verify all resource types have corresponding sections in assembled manual
- Verify image references resolve to existing files in `documents/images/`

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system — essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Naming function produces correct pattern

*For any* valid combination of environment (`dev`|`prod`), resource name, type, and optional zone, the `generate_name` function SHALL produce a string matching the pattern `{env}-{resource}-{type}` when zone is empty, or `{env}-{resource}-{type}-{zone}` when zone is provided, with exactly the correct number of hyphen-separated segments.

**Validates: Requirements 1.5, 1.6**

### Property 2: Script idempotency — existing resources are not recreated

*For any* service script and *for any* resource that already exists in the AWS account, executing the script SHALL not invoke a `create` command for that resource, and SHALL emit a skip/already-exists log message.

**Validates: Requirements 2.1, 2.2, 2.3, 7.3, 8.3**

### Property 3: Orchestrator respects dependency ordering

*For any* pair of scripts (A, B) where B depends on a resource created by A, the orchestrator SHALL invoke A before B in the execution sequence.

**Validates: Requirements 1.2**

### Property 4: Document image reference preservation

*For any* image embedded in the source DOCX, the converted Markdown SHALL contain a reference to that image pointing to the `documents/images/` path, and the exported DOCX SHALL embed or reference the same image.

**Validates: Requirements 11.3, 13.3**

### Property 5: Manual section completeness for provisioned resources

*For any* resource type that has a creation script in the `scripts/` directory, the assembled manual SHALL contain a corresponding documentation section describing that resource type.

**Validates: Requirements 12.1**
