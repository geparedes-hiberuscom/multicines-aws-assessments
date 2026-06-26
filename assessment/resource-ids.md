# Resource IDs y ARNs para Terraform Import

## Información General

| Campo | Valor |
|-------|-------|
| **Proyecto** | Multicines - AWS Infrastructure |
| **Cuenta AWS** | 340271092920 |
| **Usuario** | gustavo.paredes |
| **Región** | us-east-1 |
| **Fecha de assessment** | 2026-06-24 |
| **Referencia** | [gap-analysis.md](./gap-analysis.md) |

---

## Recursos por Ambiente

### Ambiente: DEV (VPC: `vpc-0a5ebea8e7bee9ed5` — dev-vpc — CIDR 192.168.103.0/24 + 192.168.104.0/24)

#### VPC y Networking (Dev)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 1 | VPC Dev | `module.networking.aws_vpc.main` | `vpc-0a5ebea8e7bee9ed5` |
| 2 | Subnet Pública AZ-A | `module.networking.aws_subnet.public["us-east-1a"]` | `subnet-0c92479c2831f04eb` |
| 3 | Subnet Pública AZ-B | `module.networking.aws_subnet.public["us-east-1b"]` | `subnet-02193c97ceb6ec25d` |
| 4 | Subnet Privada AZ-A | `module.networking.aws_subnet.private["us-east-1a"]` | `subnet-0eeec60453f7f9492` |
| 5 | Internet Gateway | `module.networking.aws_internet_gateway.main` | `igw-02cc91ebe8c1c22d3` |
| 6 | NAT Gateway AZ-A | `module.networking.aws_nat_gateway.main["us-east-1a"]` | `nat-0e87680203ca13848` |

#### Security Groups (Dev)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 7 | ALB Security Group | `module.security.aws_security_group.alb` | `sg-0fdf0c744482646ae` |
| 8 | ECS Security Group | `module.security.aws_security_group.ecs` | `sg-01c619444bab0b8d3` |

#### CloudWatch (Dev)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 9 | Log Group ECS | `module.observability.aws_cloudwatch_log_group.ecs` | `/ecs/dev-multicines-integration` |

---

### Ambiente: PROD (VPC: `vpc-0860a0d2cf4df6140` — prod-vpc-multicines — CIDR 192.168.119.0/24 + 192.168.109.0/24)

#### VPC y Networking (Prod)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 10 | VPC Prod | `module.networking.aws_vpc.main` | `vpc-0860a0d2cf4df6140` |
| 11 | Subnet Pública AZ-A | `module.networking.aws_subnet.public["us-east-1a"]` | `subnet-04e4cd18763fd6f84` |
| 12 | Subnet Pública AZ-B | `module.networking.aws_subnet.public["us-east-1b"]` | `subnet-05c92a4889326c68e` |
| 13 | Subnet Privada AZ-A | `module.networking.aws_subnet.private["us-east-1a"]` | `subnet-0d55ebfe5adbd4e81` |
| 14 | Subnet Privada AZ-B | `module.networking.aws_subnet.private["us-east-1b"]` | `subnet-04f8ac3335c426f57` |
| 15 | Internet Gateway | `module.networking.aws_internet_gateway.main` | `igw-02629b250edc827d0` |
| 16 | NAT Gateway AZ-A | `module.networking.aws_nat_gateway.main["us-east-1a"]` | `nat-0bb28ceef6805b2d5` |
| 17 | NAT Gateway AZ-B | `module.networking.aws_nat_gateway.main["us-east-1b"]` | `nat-0bab8e961603584d4` |

#### Security Groups (Prod)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 18 | ALB Security Group | `module.security.aws_security_group.alb` | `sg-04f21c4c1d065fe60` |
| 19 | ECS Security Group | `module.security.aws_security_group.ecs` | `sg-0b78c14cd02b2f6e1` |

#### CloudWatch (Prod)

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 20 | Log Group ECS | `module.observability.aws_cloudwatch_log_group.ecs` | `/ecs/prod-multicines-integration` |

---

### Recursos Compartidos (Shared)

#### ECS

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 21 | ECS Cluster | `module.ecs.aws_ecs_cluster.main` | `multicines-cluster` |

#### ECR

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 22 | ECR Repository | `aws_ecr_repository.integration_service` | `multicines/integration-service` |

#### IAM y OIDC

| # | Recurso | Terraform Address | ID/ARN |
|---|---------|-------------------|--------|
| 23 | ECS Task Execution Role | `module.ecs.aws_iam_role.execution` | `ecsTaskExecutionRole` |
| 24 | ECS Task Role | `module.ecs.aws_iam_role.task` | `multicines-ecs-task-role` |
| 25 | GitHub Actions Role | `aws_iam_role.github_actions` | `multicines-github-actions-role` |
| 26 | OIDC Provider (GitHub) | `aws_iam_openid_connect_provider.github` | `arn:aws:iam::340271092920:oidc-provider/token.actions.githubusercontent.com` |

---

## Recursos NO Existentes (CREATE — nuevos)

Los siguientes recursos NO existen en la cuenta y deben ser creados por Terraform:

| Recurso | Ambiente | Notas |
|---------|----------|-------|
| ALB | Dev | No hay Load Balancers en la cuenta |
| ALB | Prod | No hay Load Balancers en la cuenta |
| Target Groups | Dev/Prod | Dependen de los ALBs |
| ALB Listeners | Dev/Prod | Dependen de los ALBs |
| VPN Connection | Dev | No hay VPN connections |
| VPN Connection | Prod | No hay VPN connections |
| Virtual Private Gateway | Dev/Prod | No existen |
| Customer Gateway | Shared | No existe |
| Route 53 Hosted Zone | Shared | No hay zonas hosted |
| WAF Web ACL | Shared | No hay WAF configurado |
| ACM Certificate | Shared | No hay certificados |
| Secrets Manager | Dev/Prod | No hay secretos |
| SSM Parameters | Dev/Prod | Nuevos recursos |
| CloudWatch Alarms | Dev/Prod | Nuevos recursos |
| ECS Service | Dev/Prod | Cluster existe pero no tiene servicios activos (activeServicesCount=0) |

---

## Comandos de Import

### Dev Environment

```bash
cd environments/dev/
terraform init

# VPC y Networking
terraform import module.networking.aws_vpc.main vpc-0a5ebea8e7bee9ed5
terraform import 'module.networking.aws_subnet.public["us-east-1a"]' subnet-0c92479c2831f04eb
terraform import 'module.networking.aws_subnet.public["us-east-1b"]' subnet-02193c97ceb6ec25d
terraform import 'module.networking.aws_subnet.private["us-east-1a"]' subnet-0eeec60453f7f9492
terraform import module.networking.aws_internet_gateway.main igw-02cc91ebe8c1c22d3
terraform import 'module.networking.aws_nat_gateway.main["us-east-1a"]' nat-0e87680203ca13848

# Security Groups
terraform import module.security.aws_security_group.alb sg-0fdf0c744482646ae
terraform import module.security.aws_security_group.ecs sg-01c619444bab0b8d3

# CloudWatch
terraform import module.observability.aws_cloudwatch_log_group.ecs /ecs/dev-multicines-integration

# ECS (cluster compartido)
terraform import module.ecs.aws_ecs_cluster.main multicines-cluster

# IAM
terraform import module.ecs.aws_iam_role.execution ecsTaskExecutionRole
terraform import module.ecs.aws_iam_role.task multicines-ecs-task-role
```

### Prod Environment

```bash
cd environments/prod/
terraform init

# VPC y Networking
terraform import module.networking.aws_vpc.main vpc-0860a0d2cf4df6140
terraform import 'module.networking.aws_subnet.public["us-east-1a"]' subnet-04e4cd18763fd6f84
terraform import 'module.networking.aws_subnet.public["us-east-1b"]' subnet-05c92a4889326c68e
terraform import 'module.networking.aws_subnet.private["us-east-1a"]' subnet-0d55ebfe5adbd4e81
terraform import 'module.networking.aws_subnet.private["us-east-1b"]' subnet-04f8ac3335c426f57
terraform import module.networking.aws_internet_gateway.main igw-02629b250edc827d0
terraform import 'module.networking.aws_nat_gateway.main["us-east-1a"]' nat-0bb28ceef6805b2d5
terraform import 'module.networking.aws_nat_gateway.main["us-east-1b"]' nat-0bab8e961603584d4

# Security Groups
terraform import module.security.aws_security_group.alb sg-04f21c4c1d065fe60
terraform import module.security.aws_security_group.ecs sg-0b78c14cd02b2f6e1

# CloudWatch
terraform import module.observability.aws_cloudwatch_log_group.ecs /ecs/prod-multicines-integration

# ECS (cluster compartido — importar en el ambiente que lo gestione)
terraform import module.ecs.aws_ecs_cluster.main multicines-cluster

# IAM
terraform import module.ecs.aws_iam_role.execution ecsTaskExecutionRole
terraform import module.ecs.aws_iam_role.task multicines-ecs-task-role
```

### Shared Resources

```bash
# GitHub Actions IAM
terraform import aws_iam_role.github_actions multicines-github-actions-role
terraform import aws_iam_openid_connect_provider.github arn:aws:iam::340271092920:oidc-provider/token.actions.githubusercontent.com

# ECR
terraform import aws_ecr_repository.integration_service multicines/integration-service
```

---

## Notas

1. **ECS Cluster compartido:** Existe un solo cluster `multicines-cluster` con Fargate y Fargate Spot capacity providers pero 0 servicios activos. El diseño objetivo tiene clusters separados por ambiente — decisión pendiente si mantener 1 cluster compartido o crear 2.

2. **VPC CIDRs actuales vs objetivo:** Las VPCs existentes usan CIDRs /24 (192.168.x.0/24), mientras que el diseño objetivo propone /16 (10.0.0.0/16 dev, 10.1.0.0/16 prod). Se recomienda IMPORTAR las VPCs existentes y ajustar el código Terraform a los CIDRs reales.

3. **Subnets dev-subnet-public-az1b:** Existe una subnet pública en AZ-B para dev. El diseño objetivo de dev solo usa 1 AZ — evaluar si mantener o eliminar.

4. **Security Group prod-sg-vpn:** Existe en la VPC default (`vpc-059518f8ed756e6e6`), no en la VPC de prod. Tiene regla CRITICAL que permite ALL traffic desde 0.0.0.0/0. Debe ser reconfigurado.

5. **ECR repository naming:** El repo se llama `multicines/integration-service` (con namespace), no `api-integration-service`. Ajustar el código Terraform al nombre real.
