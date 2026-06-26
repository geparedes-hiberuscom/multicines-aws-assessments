# Technical Design Document

## Overview

Este documento describe el diseño técnico para la implementación de Infraestructura como Código (IaC) con Terraform HCL para la cuenta AWS de Multicines (ID: 340271092920). Define la estructura de módulos, patrones de configuración, flujos de datos y decisiones arquitectónicas que soportan los 11 requisitos del proyecto.

### Estado Real de la Cuenta AWS (Assessment 2026-06-24)

| Recurso | Estado | Acción |
|---------|--------|--------|
| VPC Dev (192.168.103.0/24 + 192.168.104.0/24) | ✅ Existe | IMPORT |
| VPC Prod (192.168.119.0/24 + 192.168.109.0/24) | ✅ Existe | IMPORT |
| Subnets (públicas y privadas, /26) | ✅ Existen | IMPORT |
| IGWs, NAT Gateways | ✅ Existen | IMPORT |
| ECS Cluster `multicines-cluster` (compartido, 0 servicios) | ✅ Existe | IMPORT |
| ECR `multicines/integration-service` (IMMUTABLE) | ✅ Existe | IMPORT |
| Security Groups (4 SGs, egress permisivo) | ✅ Existen | IMPORT + MODIFY |
| IAM Roles (ecsTaskExecutionRole, multicines-ecs-task-role, multicines-github-actions-role) | ✅ Existen | IMPORT |
| CloudWatch Log Groups (/ecs/dev-multicines-integration, /ecs/prod-multicines-integration) | ✅ Existen | IMPORT + MODIFY |
| OIDC Provider GitHub | ✅ Existe | IMPORT |
| ALBs, Target Groups | ❌ No existen | CREATE |
| VPN connections | ❌ No existen | CREATE |
| WAF Web ACLs | ❌ No existen | CREATE |
| ACM Certificates | ❌ No existen | CREATE |
| Route 53 Hosted Zones | ❌ No existen | CREATE |
| Secrets Manager | ❌ No existen | CREATE |
| SSM Parameters | ❌ No existen | CREATE |
| ECS Services / Task Definitions | ❌ No existen | CREATE |

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                    Repositorio Terraform                          │
├─────────────────────────────────────────────────────────────────┤
│  modules/                    │  environments/                    │
│  ├── networking/             │  ├── dev/                         │
│  ├── vpn/                    │  │   ├── main.tf                  │
│  ├── alb/                    │  │   ├── variables.tf             │
│  ├── ecs/                    │  │   ├── outputs.tf               │
│  ├── ssm/                    │  │   ├── backend.tf               │
│  ├── observability/          │  │   └── terraform.tfvars         │
│  └── security/               │  └── prod/                        │
│                              │      ├── main.tf                  │
│                              │      ├── variables.tf             │
│                              │      ├── outputs.tf               │
│                              │      ├── backend.tf               │
│                              │      └── terraform.tfvars         │
├─────────────────────────────────────────────────────────────────┤
│  .github/workflows/deploy.yml                                    │
│  imports/                                                        │
│  ├── dev-import.sh                                               │
│  ├── prod-import.sh                                              │
│  └── shared-import.sh                                            │
└─────────────────────────────────────────────────────────────────┘
```

### Flujo de tráfico (data path):
```
TRADE (Internet) → Route 53 → WAF → ALB (public subnet) → ECS Fargate (private subnet) → VPN → Vista API Connect (on-premise)
```

### Flujo CI/CD:
```
GitHub Actions → OIDC Auth → ECR (push imagen) → ECS (deploy task definition)
```

## Components and Interfaces

### Component 0: Assessment Scripts (`assessment/`)

**Propósito:** Auditar el estado actual de la cuenta AWS, inventariar recursos existentes, evaluar tags y nomenclatura, y generar el gap analysis entre estado actual y objetivo.

**Archivos:**
- `inventory.sh` - Script AWS CLI que lista todos los recursos existentes por categoría
- `audit-tags.sh` - Script que extrae tags actuales y evalúa cumplimiento del estándar
- `audit-naming.sh` - Script que evalúa nomenclatura actual vs patrón objetivo
- `audit-security-groups.sh` - Script que documenta reglas ingress/egress de todos los SGs
- `gap-analysis.md` - Documento generado comparando estado actual vs arquitectura objetivo
- `resource-ids.md` - Documento con IDs/ARNs de recursos existentes para terraform import

**Outputs del assessment:**
- Inventario completo de recursos AWS
- Reporte de cumplimiento de tags
- Reporte de cumplimiento de nomenclatura
- Gap analysis (existente vs objetivo)
- Listado de resource IDs para import

**Requirement mapping:** Requisito 1 (AC 1-7)

---

### Component 1: Módulo Networking (`modules/networking/`)

**Propósito:** Define la topología de red completa para cada ambiente.

> **Nota Assessment:** Las VPCs existentes usan CIDRs /24 (192.168.x.0/24) con CIDR secundario, NO los /16 (10.x.0.0/16) originalmente propuestos. Las subnets usan bloques /26. Los módulos deben adaptarse a estos CIDRs reales.
> - Dev VPC (`vpc-0a5ebea8e7bee9ed5`): 192.168.103.0/24 + 192.168.104.0/24
> - Prod VPC (`vpc-0860a0d2cf4df6140`): 192.168.119.0/24 + 192.168.109.0/24

**Archivos:**
- `main.tf` - Recursos VPC, subnets, IGW, NAT Gateway, route tables
- `variables.tf` - Inputs parametrizables por ambiente
- `outputs.tf` - VPC ID, subnet IDs, route table IDs

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto (multicines) |
| `environment` | string | Ambiente (dev/prod) |
| `vpc_cidr` | string | CIDR block principal de la VPC (ej: 192.168.103.0/24) |
| `vpc_secondary_cidr` | string | CIDR block secundario de la VPC (ej: 192.168.104.0/24) |
| `availability_zones` | list(string) | AZs a utilizar |
| `public_subnet_cidrs` | list(string) | CIDRs subnets públicas (/26) |
| `private_subnet_cidrs` | list(string) | CIDRs subnets privadas (/26) |
| `enable_nat_gateway` | bool | Habilitar NAT Gateway |

**Outputs:**
- `vpc_id`, `public_subnet_ids`, `private_subnet_ids`, `nat_gateway_ids`, `igw_id`

**Requirement mapping:** Requisito 4 (AC 1-5)

---

### Component 2: Módulo VPN (`modules/vpn/`)

**Propósito:** Configura la conexión VPN Site-to-Site hacia el datacenter on-premise.

> **Nota Assessment:** NO existen VPN connections, Customer Gateways, ni Virtual Private Gateways en la cuenta. Todo debe ser CREADO. Existe un SG `prod-sg-vpn` (sg-0bd705b1fd4514783) en la VPC default con regla CRITICAL (all traffic from 0.0.0.0/0) que NO está asociado a ninguna VPN real.

**Archivos:**
- `main.tf` - Virtual Private Gateway, Customer Gateway, VPN Connection, route propagation
- `variables.tf` - Inputs de configuración VPN
- `outputs.tf` - VPN connection ID, tunnel IPs

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto |
| `environment` | string | Ambiente |
| `vpc_id` | string | VPC ID del ambiente |
| `customer_gateway_ip` | string | IP pública del router on-premise |
| `onpremise_cidr` | string | CIDR del datacenter Multicines |
| `private_route_table_ids` | list(string) | Route tables de subnets privadas |

**Outputs:**
- `vpn_connection_id`, `vgw_id`, `tunnel1_address`, `tunnel2_address`

**Requirement mapping:** Requisito 5 (AC 1-4)

---

### Component 3: Módulo ALB (`modules/alb/`)

**Propósito:** Configura el Application Load Balancer con TLS, WAF y health checks.

> **Nota Assessment:** NO existen ALBs, Target Groups, WAF Web ACLs, ni ACM Certificates en la cuenta. Todo debe ser CREADO. Route 53 hosted zones tampoco existen.

**Archivos:**
- `main.tf` - ALB, listeners, target group, WAF association
- `variables.tf` - Inputs parametrizables
- `outputs.tf` - ALB ARN, DNS name, target group ARN

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto |
| `environment` | string | Ambiente |
| `vpc_id` | string | VPC ID |
| `public_subnet_ids` | list(string) | Subnets públicas para ALB |
| `certificate_arn` | string | ARN del certificado ACM wildcard |
| `waf_acl_arn` | string | ARN del Web ACL de WAF |
| `health_check_port` | number | Puerto health check (8095) |
| `health_check_path` | string | Path del health check |

**Outputs:**
- `alb_arn`, `alb_dns_name`, `target_group_arn`, `alb_security_group_id`

**Requirement mapping:** Requisito 6 (AC 1-5)

---

### Component 4: Módulo ECS (`modules/ecs/`)

**Propósito:** Define el servicio ECS Fargate, task definitions con ADOT sidecar e IAM roles. Usa el cluster compartido existente `multicines-cluster` (Fargate + Fargate Spot) con servicios separados por ambiente mediante naming convention.

> **Nota Assessment:** Solo existe 1 cluster ECS `multicines-cluster` compartido entre ambientes con 0 servicios activos. Los servicios y task definitions deben ser CREADOS. El módulo incluye una variable `create_cluster` que permite usar el cluster existente (false) o crear uno nuevo (true) para flexibilidad futura.

**Archivos:**
- `main.tf` - ECS Cluster (condicional), Task Definition, Service, IAM roles
- `task-definition.tf` - Container definitions con app + ADOT sidecar
- `iam.tf` - Execution role y task role con permisos mínimos
- `variables.tf` - Inputs parametrizables
- `outputs.tf` - Service ARN, task definition ARN

**Interfaz del módulo:**

| Variable                | Tipo         | Descripción                         |
| -------------------------| --------------| -------------------------------------|
| `project_name`          | string       | Nombre del proyecto                 |
| `environment`           | string       | Ambiente                            |
| `create_cluster`        | bool         | Crear cluster nuevo (false = usar existente `multicines-cluster`) |
| `ecs_cluster_name`      | string       | Nombre del cluster (default: `multicines-cluster`) |
| `ecr_repository_url`    | string       | URL del repo ECR (`multicines/integration-service`) |
| `container_image_tag`   | string       | Tag de la imagen (IMMUTABLE)        |
| `cpu`                   | number       | vCPU (256 para dev, 1024 para prod) |
| `memory`                | number       | Memoria MB (1024 dev, 2048 prod)    |
| `desired_count`         | number       | Número de tasks (1 dev, 2 prod)     |
| `container_port`        | number       | Puerto del contenedor (8095)        |
| `target_group_arn`      | string       | ARN del target group del ALB        |
| `private_subnet_ids`    | list(string) | Subnets privadas                    |
| `alb_security_group_id` | string       | SG del ALB (para reglas de ingress) |
| `ssm_parameter_arns`    | list(string) | ARNs de parámetros SSM              |
| `secrets_arns`          | list(string) | ARNs de secretos en Secrets Manager |
| `onpremise_cidr`        | string       | CIDR on-premise para egress rules   |
| `enable_adot_sidecar`   | bool         | Habilitar ADOT collector sidecar    |

**Lógica condicional de cluster:**
```hcl
# Si create_cluster=false, se hace data source al cluster existente
data "aws_ecs_cluster" "existing" {
  count        = var.create_cluster ? 0 : 1
  cluster_name = var.ecs_cluster_name  # "multicines-cluster"
}

resource "aws_ecs_cluster" "main" {
  count = var.create_cluster ? 1 : 0
  name  = var.ecs_cluster_name
  # Capacity providers: FARGATE + FARGATE_SPOT
}

locals {
  cluster_arn = var.create_cluster ? aws_ecs_cluster.main[0].arn : data.aws_ecs_cluster.existing[0].arn
}
```

**Task Definition - Container Definitions:**
```json
[
  {
    "name": "api-integration-service",
    "image": "${ecr_repository_url}:${image_tag}",
    "portMappings": [{"containerPort": 8095}],
    "secrets": [
      {"name": "OTEL_TRACES_EXPORTER", "valueFrom": "/multicines/integrator/{env}/OTEL_TRACES_EXPORTER"}
    ],
    "logConfiguration": {
      "logDriver": "awslogs",
      "options": {
        "awslogs-group": "/ecs/{env}-multicines-integration",
        "awslogs-region": "${region}",
        "awslogs-stream-prefix": "api"
      }
    }
  },
  {
    "name": "adot-collector",
    "image": "public.ecr.aws/aws-observability/aws-otel-collector:latest",
    "essential": false
  }
]
```

> **Nota Assessment:** El repositorio ECR real es `multicines/integration-service` (con namespace, tag mutability IMMUTABLE). Los log groups existentes son `/ecs/dev-multicines-integration` y `/ecs/prod-multicines-integration`.

**Outputs:**
- `ecs_cluster_arn`, `ecs_service_arn`, `task_definition_arn`, `task_role_arn`, `execution_role_arn`

**Requirement mapping:** Requisito 7 (AC 1-5), Requisito 9 (AC 4-5)

---

### Component 5: Módulo SSM (`modules/ssm/`)

**Propósito:** Gestiona los parámetros de configuración de la aplicación en SSM Parameter Store.

> **Nota Assessment:** NO existen parámetros SSM ni secretos en Secrets Manager. Todo debe ser CREADO.

**Archivos:**
- `main.tf` - Parámetros SSM con jerarquía por ambiente
- `variables.tf` - Inputs
- `outputs.tf` - Parameter ARNs

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto |
| `environment` | string | Ambiente |
| `parameters` | map(object) | Mapa de parámetros {name, value, type} |

**Parámetros por defecto:**
```hcl
parameters = {
  OTEL_TRACES_EXPORTER = {
    value = "otlp"
    type  = "String"
  }
}
```

**Outputs:**
- `parameter_arns`, `parameter_names`

**Requirement mapping:** Requisito 8 (AC 1-5)

---

### Component 6: Módulo Observability (`modules/observability/`)

**Propósito:** Configura CloudWatch Log Groups, métricas y dashboards.

> **Nota Assessment:** Los log groups existentes usan el formato `/ecs/{env}-multicines-integration` (NO `/ecs/multicines-integrator-{env}`). No tienen retención configurada — se debe establecer 30 días para dev y 90 días para prod.

**Archivos:**
- `main.tf` - Log groups, metric alarms, dashboard
- `variables.tf` - Inputs
- `outputs.tf` - Log group ARN

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto |
| `environment` | string | Ambiente |
| `log_retention_days` | number | Días de retención (30 dev, 90 prod) |
| `log_group_name` | string | Nombre del log group (ej: `/ecs/dev-multicines-integration`) |
| `ecs_cluster_name` | string | Nombre del cluster ECS (`multicines-cluster`) |
| `ecs_service_name` | string | Nombre del servicio ECS |
| `alb_arn_suffix` | string | Sufijo ARN del ALB para métricas |

**Outputs:**
- `log_group_arn`, `log_group_name`

**Requirement mapping:** Requisito 9 (AC 1-3)

---

### Component 7: Módulo Security (`modules/security/`)

**Propósito:** Configura Security Groups, Secrets Manager y políticas de seguridad transversales.

**Archivos:**
- `main.tf` - Security groups para ECS y ALB
- `secrets.tf` - Secrets Manager secrets
- `variables.tf` - Inputs
- `outputs.tf` - Security group IDs, secret ARNs

**Interfaz del módulo:**

| Variable | Tipo | Descripción |
|----------|------|-------------|
| `project_name` | string | Nombre del proyecto |
| `environment` | string | Ambiente |
| `vpc_id` | string | VPC ID |
| `container_port` | number | Puerto del contenedor (8095) |
| `onpremise_cidr` | string | CIDR on-premise (para egress) |
| `vpn_available` | bool | Si la VPN está configurada |

**Lógica de Security Groups:**
- **ECS SG Ingress:** Solo desde ALB SG en puerto 8095
- **ECS SG Egress (vpn_available=true):** Solo hacia onpremise_cidr + VPC Endpoints de AWS
- **ECS SG Egress (vpn_available=false):** Solo hacia VPC Endpoints de AWS (ECR, SSM, Secrets Manager, CloudWatch, X-Ray)
- **ALB SG Ingress:** HTTPS (443) desde 0.0.0.0/0 (WAF filtra)
- **ALB SG Egress:** Solo hacia ECS SG en puerto 8095

**Outputs:**
- `ecs_security_group_id`, `alb_security_group_id`, `secrets_arns`

**Requirement mapping:** Requisito 10 (AC 1-6)

---

### Component 8: Environment Configuration (`environments/dev/` y `environments/prod/`)

**Propósito:** Instancia los módulos compartidos con valores específicos por ambiente.

**`environments/dev/backend.tf`:**
```hcl
terraform {
  backend "s3" {
    bucket         = "multicines-terraform-state"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "multicines-terraform-locks"
    encrypt        = true
  }
}
```

**`environments/dev/main.tf` (estructura):**
```hcl
provider "aws" {
  region = var.aws_region
  default_tags {
    tags = {
      Project     = "multicines"
      Environment = "dev"
      ManagedBy   = "terraform"
      Service     = "api-integration-service"
    }
  }
}

module "networking" { source = "../../modules/networking" ... }
module "security"   { source = "../../modules/security" ... }
module "vpn"        { source = "../../modules/vpn" ... }
module "alb"        { source = "../../modules/alb" ... }
module "ssm"        { source = "../../modules/ssm" ... }
module "observability" { source = "../../modules/observability" ... }
module "ecs"        { source = "../../modules/ecs"
  create_cluster   = false
  ecs_cluster_name = "multicines-cluster"
  ...
}
```

**`environments/dev/terraform.tfvars`:**
```hcl
aws_region           = "us-east-1"
environment          = "dev"
vpc_cidr             = "192.168.103.0/24"
vpc_secondary_cidr   = "192.168.104.0/24"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["192.168.103.0/26", "192.168.104.0/26"]
private_subnet_cidrs = ["192.168.103.64/26"]
ecs_cpu              = 256
ecs_memory           = 1024
ecs_desired_count    = 1
log_retention_days   = 30
create_ecs_cluster   = false
ecs_cluster_name     = "multicines-cluster"
ecr_repository_name  = "multicines/integration-service"
```

**`environments/prod/terraform.tfvars`:**
```hcl
aws_region           = "us-east-1"
environment          = "prod"
vpc_cidr             = "192.168.119.0/24"
vpc_secondary_cidr   = "192.168.109.0/24"
availability_zones   = ["us-east-1a", "us-east-1b"]
public_subnet_cidrs  = ["192.168.109.0/26", "192.168.119.0/26"]
private_subnet_cidrs = ["192.168.109.64/26", "192.168.119.64/26"]
ecs_cpu              = 1024
ecs_memory           = 2048
ecs_desired_count    = 2
log_retention_days   = 90
create_ecs_cluster   = false
ecs_cluster_name     = "multicines-cluster"
ecr_repository_name  = "multicines/integration-service"
```

**Requirement mapping:** Requisito 1 (AC 1-5), Requisito 3 (AC 1-6)

---

### Component 9: Import Scripts (`imports/`)

**Propósito:** Scripts para importar recursos existentes al state de Terraform.

> **Nota Assessment:** Los siguientes recursos EXISTEN y deben importarse:
> - VPCs, subnets, IGWs, NAT Gateways (ambos ambientes)
> - ECS Cluster `multicines-cluster` (compartido)
> - ECR Repository `multicines/integration-service`
> - Security Groups (4 SGs funcionales + 1 CRITICAL en VPC default)
> - IAM Roles: `ecsTaskExecutionRole`, `multicines-ecs-task-role`, `multicines-github-actions-role`
> - CloudWatch Log Groups: `/ecs/dev-multicines-integration`, `/ecs/prod-multicines-integration`
> - OIDC Provider para GitHub Actions
>
> Los siguientes NO existen y deben CREARSE (no importar):
> - ALBs, Target Groups, Listeners
> - VPN connections, Customer Gateways
> - WAF Web ACLs
> - ACM Certificates
> - Route 53 Hosted Zones
> - Secrets Manager secrets
> - SSM Parameters
> - ECS Services y Task Definitions

**Archivos:**
- `dev-import.sh` - Comandos terraform import para recursos del ambiente dev
- `prod-import.sh` - Comandos terraform import para recursos del ambiente prod
- `shared-import.sh` - Comandos terraform import para recursos compartidos (ECS cluster, ECR, IAM roles)

**Ejemplo de contenido:**
```bash
#!/bin/bash
# dev-import.sh
cd ../environments/dev

# VPC y Networking
terraform import module.networking.aws_vpc.main vpc-0a5ebea8e7bee9ed5
terraform import module.networking.aws_vpc_ipv4_cidr_block_association.secondary <association-id>
terraform import module.networking.aws_subnet.public["az-a"] subnet-0c92479c2831f04eb
terraform import module.networking.aws_subnet.public["az-b"] subnet-02193c97ceb6ec25d
terraform import module.networking.aws_subnet.private["az-a"] subnet-0eeec60453f7f9492
terraform import module.networking.aws_internet_gateway.main igw-02cc91ebe8c1c22d3
terraform import module.networking.aws_nat_gateway.main nat-0e87680203ca13848

# Security Groups (IMPORT + MODIFY — egress too permissive)
terraform import module.security.aws_security_group.alb sg-0fdf0c744482646ae
terraform import module.security.aws_security_group.ecs sg-01c619444bab0b8d3

# ECS Cluster (compartido — importar en dev, reference en prod)
terraform import module.ecs.aws_ecs_cluster.main multicines-cluster

# CloudWatch Log Group
terraform import module.observability.aws_cloudwatch_log_group.ecs /ecs/dev-multicines-integration

# IAM Roles (compartidos)
terraform import module.ecs.aws_iam_role.execution ecsTaskExecutionRole
terraform import module.ecs.aws_iam_role.task multicines-ecs-task-role
```

```bash
#!/bin/bash
# prod-import.sh
cd ../environments/prod

# VPC y Networking
terraform import module.networking.aws_vpc.main vpc-0860a0d2cf4df6140
terraform import module.networking.aws_vpc_ipv4_cidr_block_association.secondary <association-id>
terraform import module.networking.aws_subnet.public["az-a"] subnet-04e4cd18763fd6f84
terraform import module.networking.aws_subnet.public["az-b"] subnet-05c92a4889326c68e
terraform import module.networking.aws_subnet.private["az-a"] subnet-0d55ebfe5adbd4e81
terraform import module.networking.aws_subnet.private["az-b"] subnet-04f8ac3335c426f57
terraform import module.networking.aws_internet_gateway.main igw-02629b250edc827d0
terraform import module.networking.aws_nat_gateway.main["az-a"] nat-0bb28ceef6805b2d5
terraform import module.networking.aws_nat_gateway.main["az-b"] nat-0bab8e961603584d4

# Security Groups (IMPORT + MODIFY — egress too permissive, HTTP 80 on ALB)
terraform import module.security.aws_security_group.alb sg-04f21c4c1d065fe60
terraform import module.security.aws_security_group.ecs sg-0b78c14cd02b2f6e1

# CloudWatch Log Group
terraform import module.observability.aws_cloudwatch_log_group.ecs /ecs/prod-multicines-integration

# ECR Repository (compartido)
terraform import module.ecs.aws_ecr_repository.main multicines/integration-service
```

**Requirement mapping:** Requisito 2 (AC 1-9)

---

### Component 10: GitHub Actions Workflow (`.github/workflows/deploy.yml`)

**Propósito:** Pipeline CI/CD para build, push y deploy del api-integration-service.

**Flujo del workflow:**
```
push to main → build → push ECR → deploy dev → wait stable → (manual approval) → deploy prod
```

**Jobs principales:**
1. `build-and-push`: Build imagen Docker, push a ECR
2. `deploy-dev`: Deploy task definition en ECS dev, wait for service stability
3. `deploy-prod`: (manual trigger/approval) Deploy task definition en ECS prod

**Configuración OIDC:**
```yaml
permissions:
  id-token: write
  contents: read

steps:
  - uses: aws-actions/configure-aws-credentials@v4
    with:
      role-to-assume: arn:aws:iam::340271092920:role/multicines-github-actions-role
      aws-region: us-east-1
```

**Rollback strategy:**
```yaml
- name: Deploy to ECS
  run: |
    CLUSTER="multicines-cluster"
    aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $NEW_TD
    aws ecs wait services-stable --cluster $CLUSTER --services $SERVICE || {
      echo "Deploy failed, rolling back..."
      aws ecs update-service --cluster $CLUSTER --service $SERVICE --task-definition $OLD_TD
      exit 1
    }
```

**Requirement mapping:** Requisito 11 (AC 1-7)

### Component 11: Documentación Profesional Ejecutiva (`docs/`)

**Propósito:** Paquete de entregables documentales para que Multicines pueda gestionar la infraestructura de forma autónoma.

**Estructura de entregables:**
```
docs/
├── index.md                          # Índice general de documentación
├── manual-operaciones-aws.md         # Manual paso a paso con consola AWS
├── arquitectura-ejecutiva.md         # Resumen ejecutivo para stakeholders
├── estandares-infraestructura.md     # Convenciones de tags, nombres, seguridad
├── runbook-operativo.md              # Procedimientos operacionales
├── diagramas/
│   ├── multicines-aws-final.drawio   # Diagrama arquitectura final
│   ├── flujo-deploy.drawio           # Diagrama pipeline CI/CD
│   └── flujo-red.drawio              # Diagrama de networking y VPN
└── README.md                         # Cómo usar esta documentación
```

**Manual de Operaciones (basado en Manual para multicines.docx):**
- Sección por componente AWS con pasos de consola
- Navegación exacta en la consola para cada operación CRUD
- Screenshots de referencia o descripciones de cada pantalla
- Procedimientos de verificación post-configuración

**Documento Ejecutivo:**
- Resumen de la solución (2-3 páginas)
- Diagrama de alto nivel
- Beneficios y justificación
- Estimación de costos mensuales
- Roadmap de evolución

**Requirement mapping:** Requisito 13 (AC 1-7)

---

## Data Models

### Terraform State Structure

Cada ambiente mantiene su propio state file en S3:
- `s3://multicines-terraform-state/dev/terraform.tfstate`
- `s3://multicines-terraform-state/prod/terraform.tfstate`

DynamoDB table `multicines-terraform-locks` para state locking.

### SSM Parameter Store Hierarchy

```
/multicines/integrator/
├── dev/
│   ├── OTEL_TRACES_EXPORTER
│   ├── APP_CONFIG_VAR_1
│   └── APP_CONFIG_VAR_N
└── prod/
    ├── OTEL_TRACES_EXPORTER
    ├── APP_CONFIG_VAR_1
    └── APP_CONFIG_VAR_N
```

### IAM Role Structure

> **Nota Assessment:** Los roles IAM existentes usan nombres genéricos (no por ambiente): `ecsTaskExecutionRole`, `multicines-ecs-task-role`, `multicines-github-actions-role`. OIDC Provider existe en `arn:aws:iam::340271092920:oidc-provider/token.actions.githubusercontent.com`.

| Rol                              | Propósito           | Permisos clave                                                                                                       |
| ----------------------------------| ---------------------| ----------------------------------------------------------------------------------------------------------------------|
| `ecsTaskExecutionRole` (existente) | ECS execution role  | ecr:GetAuthorizationToken, ecr:BatchGetImage, ssm:GetParameters, secretsmanager:GetSecretValue, logs:CreateLogStream |
| `multicines-ecs-task-role` (existente) | ECS task role       | xray:PutTraceSegments, xray:PutTelemetryRecords                                                                      |
| `multicines-github-actions-role` (existente) | GitHub Actions OIDC | ecr:PutImage, ecs:UpdateService, ecs:RegisterTaskDefinition                                                          |

## Error Handling

| Escenario              | Estrategia                                           |
| ------------------------| ------------------------------------------------------|
| Terraform apply falla  | State lock previene corrupción; fix y re-apply       |
| VPN túnel down         | 2 túneles HA; CloudWatch alarm notifica              |
| ECS deploy falla       | Rollback automático a task definition anterior       |
| SSM parameter missing  | Task falla al iniciar; CloudWatch Logs captura error |
| ALB health check falla | ECS drains task, reemplaza con nueva instancia       |

## Testing Strategy

| Tipo | Herramienta | Alcance |
|------|-------------|---------|
| Terraform validate | `terraform validate` | Sintaxis y tipos |
| Terraform plan | `terraform plan` | Preview de cambios |
| Terraform fmt | `terraform fmt -check` | Formato consistente |
| tflint | tflint | Best practices Terraform |
| checkov | checkov | Security scanning IaC |
| Integration | Deploy en dev primero | Validación end-to-end |

## Correctness Properties

### Property 1: Aislamiento de ambientes

VPC dev y prod no comparten recursos de red. Cada ambiente tiene su propio state file en S3. Se valida con `terraform plan` mostrando recursos separados.

**Validates: Requirements 4.1, 4.2**

### Property 2: Least privilege IAM

Cada rol IAM tiene solo los permisos necesarios para su función. Execution role accede a ECR, SSM, Secrets Manager y CloudWatch. Task role accede solo a X-Ray. Se valida con checkov.

**Validates: Requirements 10.5**

### Property 3: Conectividad VPN HA

Cada conexión VPN tiene 2 túneles activos para alta disponibilidad. CloudWatch alarm monitorea el estado de los túneles.

**Validates: Requirements 5.1, 5.2**

### Property 4: Tags consistentes

Todos los recursos tienen los 4 tags obligatorios (Project, Environment, ManagedBy, Service) aplicados mediante default_tags del provider. Se valida con tflint y AWS Config.

**Validates: Requirements 3.1, 3.2, 3.3, 3.4**

### Property 5: ECS dimensionamiento correcto

Dev tiene 1 task con 0.5 vCPU y 1 GB. Prod tiene 2 tasks con 1 vCPU y 2 GB cada una. Los valores se definen en terraform.tfvars y terraform plan los confirma.

**Validates: Requirements 7.1, 7.2, 7.3**

### Property 6: SSM sin hardcode

Ninguna variable sensible aparece en plain text en Task Definitions. Todas las variables de configuración se leen desde SSM Parameter Store via valueFrom. Se valida con checkov y grep en container definitions.

**Validates: Requirements 8.4**

### Property 7: Rollback CI/CD

Un deploy fallido que no alcanza estado services-stable revierte automáticamente a la task definition anterior. Se valida con integration test en dev.

**Validates: Requirements 11.7**
