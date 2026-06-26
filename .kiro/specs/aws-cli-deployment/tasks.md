# Implementation Plan: AWS CLI Deployment Scripts

## Overview

Implementación de scripts AWS CLI idempotentes para provisionar la infraestructura faltante de Multicines (ALB, VPN, WAF, ACM, SSM, Secrets Manager, SG hardening, ECS Services) más un pipeline de documentación que convierte y extiende el manual de operaciones. Los scripts usan Bash y residen en `aws-cli/` con una shared library en `aws-cli/lib/common.sh`.

## Tasks

- [ ] 1. Create shared library and orchestrator
  - [ ] 1.1 Create `aws-cli/lib/common.sh` with constants, environment lookup maps, naming helper, logging functions, and idempotency utilities
    - Define `AWS_ACCOUNT`, `AWS_REGION`, `ECS_CLUSTER`, `ECR_REPO`, `ECR_URI`, `CONTAINER_PORT` constants
    - Implement associative arrays: `VPC_IDS`, `PUBLIC_SUBNETS`, `PRIVATE_SUBNETS`, `ALB_SG_IDS`, `ECS_SG_IDS`, `LOG_GROUPS`
    - Implement `generate_name()` following pattern `{env}-{resource}-{type}-{zone}`
    - Implement `log_info`, `log_error`, `log_skip`, `log_created` functions
    - Implement `check_exists()` and `validate_env()` helper functions
    - _Requirements: 1.5, 1.6, 2.1, 2.2_

  - [ ] 1.2 Create `aws-cli/create-all.sh` orchestrator
    - Source `aws-cli/lib/common.sh`
    - Accept environment parameter (`dev`|`prod`) and validate it
    - Invoke service scripts in dependency order: create-acm → create-waf → harden-security-groups → create-alb → create-ssm → create-secrets → create-ecs-service → create-vpn
    - Stop execution on first failure with non-zero exit code
    - _Requirements: 1.1, 1.2, 1.3, 1.4_

  - [ ]* 1.3 Write property test for `generate_name` function (bats-core)
    - **Property 1: Naming function produces correct pattern**
    - **Validates: Requirements 1.5, 1.6**
    - Test with arbitrary env/resource/type/zone combinations
    - Verify hyphen-separated segment count is correct (3 without zone, 4 with zone)

- [ ] 2. Checkpoint - Ensure shared library and orchestrator are correct
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 3. Implement ACM and WAF scripts
  - [ ] 3.1 Create `aws-cli/create-acm.sh`
    - Source common library and validate environment parameter
    - Generate certificate name using `generate_name`
    - Check existence via `aws acm list-certificates` filtering by domain
    - Request certificate via `aws acm request-certificate` for the required domain
    - Output DNS validation CNAME records to stdout
    - Tag certificate following naming convention
    - _Requirements: 6.1, 6.2, 6.3, 2.1, 2.2, 2.3, 2.4_

  - [ ] 3.2 Create `aws-cli/create-waf.sh`
    - Source common library and validate environment parameter
    - Generate Web ACL name using `generate_name` (e.g., `dev-waf-webacl`)
    - Check existence via `aws wafv2 get-web-acl` or `list-web-acls`
    - Create REGIONAL WAF Web ACL with rate-based rule
    - Associate Web ACL to the ALB ARN (retrieved via describe)
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 2.1, 2.2, 2.3, 2.4_

- [ ] 4. Implement Security Groups hardening and ALB scripts
  - [ ] 4.1 Create `aws-cli/harden-security-groups.sh`
    - Source common library and validate environment parameter
    - Revoke `0.0.0.0/0` all-traffic egress on ALB SGs (dev: sg-0fdf0c744482646ae, prod: sg-04f21c4c1d065fe60)
    - Add egress rule ALB→ECS on port 8095 only (referencing ECS SG as destination)
    - Revoke `0.0.0.0/0` all-traffic egress on ECS SGs (dev: sg-01c619444bab0b8d3, prod: sg-0b78c14cd02b2f6e1)
    - Add egress rules ECS→HTTPS(443) for AWS service endpoints (ECR, CloudWatch, SSM, Secrets Manager)
    - Implement idempotency: check current rules before modifying
    - _Requirements: 9.1, 9.2, 9.3, 9.4, 2.1, 2.2, 2.4_

  - [ ] 4.2 Create `aws-cli/create-alb.sh`
    - Source common library and validate environment parameter
    - Generate ALB name using `generate_name` (e.g., `dev-alb-application`)
    - Check ALB existence via `aws elbv2 describe-load-balancers --names`
    - Create ALB type `application` in public subnets with existing ALB SG
    - Create Target Group with health check on port 8095 (HTTP protocol)
    - Create HTTPS:443 listener forwarding to the target group (using ACM cert ARN)
    - _Requirements: 3.1, 3.2, 3.3, 3.4, 3.5, 2.1, 2.2, 2.3, 2.4_

  - [ ]* 4.3 Write unit tests for idempotency pattern (bats-core)
    - **Property 2: Script idempotency — existing resources are not recreated**
    - **Validates: Requirements 2.1, 2.2, 2.3**
    - Mock AWS CLI responses to verify check-before-create pattern
    - Verify skip messages emitted for existing resources

- [ ] 5. Checkpoint - Ensure ACM, WAF, SG hardening, and ALB scripts work
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 6. Implement SSM, Secrets Manager, and ECS Service scripts
  - [ ] 6.1 Create `aws-cli/create-ssm.sh`
    - Source common library and validate environment parameter
    - Create parameters under `/multicines/integrator/{env}/app` (String type)
    - Create parameters under `/multicines/integrator/{env}/resilience` (SecureString type)
    - Check existence via `aws ssm get-parameter` before creating each parameter
    - _Requirements: 7.1, 7.2, 7.3, 2.1, 2.2, 2.3, 2.4_

  - [ ] 6.2 Create `aws-cli/create-secrets.sh`
    - Source common library and validate environment parameter
    - Generate secret name using `generate_name` (e.g., `dev-multicines-integration-secrets`)
    - Check existence via `aws secretsmanager describe-secret`
    - Create secret with placeholder JSON value per environment
    - _Requirements: 8.1, 8.2, 8.3, 2.1, 2.2, 2.3, 2.4_

  - [ ] 6.3 Create `aws-cli/create-ecs-service.sh`
    - Source common library and validate environment parameter
    - Register Task Definition: image from ECR (`multicines/integration-service:latest`), CPU 256, Memory 512, containerPort 8095, awslogs driver, execution role `ecsTaskExecutionRole`, task role `multicines-ecs-task-role`
    - Create ECS Service in cluster `multicines-cluster`, launch type FARGATE, private subnets, ECS SG, load balancer target group from ALB
    - Desired count: 1
    - Idempotent: check existing service via `aws ecs describe-services`
    - _Requirements: 10.1, 10.2, 10.3, 10.4, 10.5, 2.1, 2.2, 2.3, 2.4_

- [ ] 7. Implement VPN script
  - [ ] 7.1 Create `aws-cli/create-vpn.sh`
    - Source common library and validate environment parameter
    - Create Customer Gateway with placeholder IP (`0.0.0.0`) and BGP ASN (`65000`) — clearly marked with comments
    - Create Virtual Private Gateway and attach to VPC
    - Create VPN Connection type `ipsec.1` associating CGW and VGW
    - Enable route propagation on private route tables
    - Name resources following naming convention (e.g., `dev-vpn-connection`, `dev-cgw-customer`, `dev-vgw-gateway`)
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 2.1, 2.2, 2.3, 2.4_

- [ ] 8. Checkpoint - Ensure all infrastructure scripts are complete and consistent
  - Ensure all tests pass, ask the user if questions arise.

- [ ] 9. Implement documentation pipeline
  - [ ] 9.1 Create `aws-cli/convert-manual.sh`
    - Check Pandoc availability and version (3.9.0.2)
    - Convert "Insumos iniciales/Manual para multicines.docx" → `documents/manual-original.md`
    - Extract images to `documents/images/`
    - Preserve image references in generated Markdown pointing to `documents/images/`
    - Do NOT modify anything in "Insumos iniciales/" directory
    - _Requirements: 11.1, 11.2, 11.3, 11.4_

  - [ ] 9.2 Create `documents/sections/` directory with new documentation sections (one `.md` per resource type)
    - Write sections for: ALB, VPN, WAF, ACM, SSM, Secrets Manager, ECS Service, Security Groups
    - Each section documents AWS console steps to verify and operate the resource
    - _Requirements: 12.1, 12.2, 12.3_

  - [ ] 9.3 Create `aws-cli/build-manual.sh`
    - Concatenate `documents/manual-original.md` + all files in `documents/sections/*.md` → `documents/manual-multicines.md`
    - Export assembled Markdown to `documents/manual-multicines.docx` via Pandoc
    - Use `--resource-path` for image resolution
    - _Requirements: 13.1, 13.2, 13.3_

  - [ ]* 9.4 Write tests for documentation pipeline
    - **Property 5: Manual section completeness for provisioned resources**
    - **Validates: Requirements 12.1**
    - Verify each resource type in `aws-cli/create-*.sh` has a corresponding section in `documents/sections/`
    - Verify image references in assembled Markdown resolve to existing files

- [ ] 10. Final checkpoint - Ensure all scripts and documentation are complete
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Checkpoints ensure incremental validation
- All scripts use Bash and follow the idempotency pattern (check → skip or create)
- Property tests use bats-core for shell testing
- All file paths are relative to the `aws-assesment` workspace root
- The "Insumos iniciales/" directory is read-only — never modified
- Pandoc 3.9.0.2 is assumed available in the environment
- ALL scripts reside in the `aws-cli/` directory (including documentation pipeline scripts)

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1"] },
    { "id": 1, "tasks": ["1.2", "1.3"] },
    { "id": 2, "tasks": ["3.1", "3.2"] },
    { "id": 3, "tasks": ["4.1", "4.2", "4.3"] },
    { "id": 4, "tasks": ["6.1", "6.2", "7.1", "9.1"] },
    { "id": 5, "tasks": ["6.3", "9.2"] },
    { "id": 6, "tasks": ["9.3", "9.4"] }
  ]
}
```
