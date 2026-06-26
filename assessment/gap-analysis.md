# Gap Analysis: Arquitectura Actual vs Arquitectura Objetivo

## Información General

| Campo | Valor |
|-------|-------|
| **Proyecto** | Multicines - AWS Infrastructure |
| **Cuenta AWS** | 340271092920 |
| **Diagrama de referencia** | `Insumos iniciales/multicines_aws_v1.drawio` |
| **Fecha de assessment** | 2026-06-24 |
| **Región principal** | us-east-1 |
| **Ejecutado por** | gustavo.paredes |

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Recursos existentes a IMPORTAR | 26 |
| Recursos nuevos a CREAR | 15+ |
| Recursos a MODIFICAR | 8 |
| Compliance de tags | 0% (0/23 recursos) |
| Compliance de nomenclatura | 0% full, 9% parcial (3/32) |
| Issues de seguridad | 1 CRITICAL, 9 LOW |

---

## 1. VPC y Networking

### 1.1 VPC Dev (`vpc-0a5ebea8e7bee9ed5`)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| VPC existencia | ✅ `vpc-0a5ebea8e7bee9ed5` CIDR 192.168.103.0/24 + 192.168.104.0/24 | VPC dedicada (diseño propone 10.0.0.0/16) | CIDR diferente al diseño — usar el actual | **IMPORT** |
| Availability Zones | 2 AZs usadas (us-east-1a, us-east-1b) | 1 AZ (us-east-1a) | Hay más AZs de lo necesario | **IMPORT** |
| Subnet pública AZ-A | ✅ `subnet-0c92479c2831f04eb` (192.168.103.0/26) | 1 subnet pública en AZ-A | Coincide | **IMPORT** |
| Subnet pública AZ-B | ✅ `subnet-02193c97ceb6ec25d` (192.168.104.0/26) | No requerida en diseño | Extra — mantener para futuro | **IMPORT** |
| Subnet privada AZ-A | ✅ `subnet-0eeec60453f7f9492` (192.168.103.64/26) | 1 subnet privada en AZ-A | Coincide | **IMPORT** |
| Internet Gateway | ✅ `igw-02cc91ebe8c1c22d3` (dev-igw) | 1 IGW adjunto | Coincide | **IMPORT** |
| NAT Gateway | ✅ `nat-0e87680203ca13848` (dev-nat-az1a) en subnet pública AZ-A | 1 NAT GW en subnet pública | Coincide | **IMPORT** |

### 1.2 VPC Prod (`vpc-0860a0d2cf4df6140`)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| VPC existencia | ✅ `vpc-0860a0d2cf4df6140` CIDR 192.168.119.0/24 + 192.168.109.0/24 | VPC dedicada (diseño propone 10.1.0.0/16) | CIDR diferente al diseño — usar el actual | **IMPORT** |
| Availability Zones | 2 AZs (us-east-1a, us-east-1b) | 2 AZs (us-east-1a, us-east-1b) | ✅ Coincide | **IMPORT** |
| Subnet pública AZ-A | ✅ `subnet-04e4cd18763fd6f84` (192.168.109.0/26) | Subnet pública AZ-A | Coincide | **IMPORT** |
| Subnet pública AZ-B | ✅ `subnet-05c92a4889326c68e` (192.168.119.0/26) | Subnet pública AZ-B | Coincide | **IMPORT** |
| Subnet privada AZ-A | ✅ `subnet-0d55ebfe5adbd4e81` (192.168.109.64/26) | Subnet privada AZ-A | Coincide | **IMPORT** |
| Subnet privada AZ-B | ✅ `subnet-04f8ac3335c426f57` (192.168.119.64/26) | Subnet privada AZ-B | Coincide | **IMPORT** |
| Internet Gateway | ✅ `igw-02629b250edc827d0` (prod-igw-multicines) | 1 IGW adjunto | Coincide | **IMPORT** |
| NAT Gateway AZ-A | ✅ `nat-0bb28ceef6805b2d5` (prod-nat-multicines) | NAT GW por AZ | Coincide | **IMPORT** |
| NAT Gateway AZ-B | ✅ `nat-0bab8e961603584d4` (prod-nat-multicines-1b) | NAT GW por AZ | Coincide | **IMPORT** |

---

## 2. ECS Fargate

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| ECS Cluster | ✅ `multicines-cluster` — ACTIVE, Fargate + Fargate Spot | Clusters separados por env o 1 compartido | 1 cluster con 0 servicios activos | **IMPORT** |
| ECS Services | ❌ 0 servicios activos | Services por ambiente | No existe | **CREATE** |
| Task Definitions | ❌ No existen | TD con api-integration-service + ADOT | No existe | **CREATE** |

---

## 3. Application Load Balancer (ALB)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| ALB Dev | ❌ No existe | ALB en subnet pública con HTTPS 443 | Gap total | **CREATE** |
| ALB Prod | ❌ No existe | ALB en subnets públicas AZ-A y AZ-B | Gap total | **CREATE** |
| Target Groups | ❌ No existen | TG con health check puerto 8095 | Gap total | **CREATE** |
| WAF asociado | ❌ No existe WAF | WAF Web ACL asociado a cada ALB | Gap total | **CREATE** |
| ACM Certificate | ❌ No existe | Certificado wildcard para HTTPS | Gap total | **CREATE** |

---

## 4. VPN Site-to-Site

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| VPN Connection Dev | ❌ No existe | VPN S2S con VGW y 2 túneles HA | Gap total | **CREATE** |
| VPN Connection Prod | ❌ No existe | VPN S2S con VGW y 2 túneles HA | Gap total | **CREATE** |
| Customer Gateway | ❌ No existe | CGW apuntando a IP on-premise | Gap total | **CREATE** |
| Route propagation | ❌ No configurado | VGW propagando rutas a route tables privadas | Gap total | **CREATE** |

> ⚠️ **Nota:** Existe un Security Group `prod-sg-vpn` (sg-0bd705b1fd4514783) en la VPC default, pero NO hay VPN connections reales. Este SG tiene una regla CRITICAL (all traffic from 0.0.0.0/0).

---

## 5. Security Groups

### 5.1 Estado Actual

| SG ID | Nombre | VPC | Ingress | Egress | Issues |
|-------|--------|-----|---------|--------|--------|
| sg-0fdf0c744482646ae | dev-sg-alb | vpc-dev | 1 regla | 1 regla | 1 LOW (egress unrestricted) |
| sg-01c619444bab0b8d3 | dev-sg-ecs | vpc-dev | 1 regla | 1 regla | 1 LOW (egress unrestricted) |
| sg-04f21c4c1d065fe60 | prod-sg-alb | vpc-prod | 2 reglas | 1 regla | 2 LOW (HTTP 80, egress unrestricted) |
| sg-0b78c14cd02b2f6e1 | prod-sg-ecs | vpc-prod | 1 regla | 2 reglas | 1 LOW (egress unrestricted) |
| sg-0bd705b1fd4514783 | prod-sg-vpn | vpc-default | 1 regla | 1 regla | 🔴 1 CRITICAL (all from 0.0.0.0/0) |

### 5.2 Gap vs Objetivo

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| ALB SG Dev | ✅ Existe (sg-0fdf0c744482646ae) | Ingress HTTPS 443, Egress solo a ECS:8095 | Egress too permissive | **IMPORT + MODIFY** |
| ECS SG Dev | ✅ Existe (sg-01c619444bab0b8d3) | Ingress solo desde ALB:8095, Egress restrictivo | Egress too permissive | **IMPORT + MODIFY** |
| ALB SG Prod | ✅ Existe (sg-04f21c4c1d065fe60) | Ingress HTTPS 443, Egress solo a ECS:8095 | HTTP 80 no debería estar, Egress too permissive | **IMPORT + MODIFY** |
| ECS SG Prod | ✅ Existe (sg-0b78c14cd02b2f6e1) | Ingress solo desde ALB:8095, Egress restrictivo | Egress too permissive | **IMPORT + MODIFY** |

---

## 6. IAM Roles y Políticas

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| ECS Execution Role | ✅ `ecsTaskExecutionRole` | `multicines-ecs-execution-{env}` con permisos ECR, SSM, SecretsManager, Logs | Nombre no sigue convención, evaluar permisos | **IMPORT + MODIFY** |
| ECS Task Role | ✅ `multicines-ecs-task-role` | `multicines-ecs-task-{env}` con permisos X-Ray | Nombre parcialmente correcto, verificar permisos | **IMPORT + MODIFY** |
| GitHub Actions Role | ✅ `multicines-github-actions-role` | Con OIDC trust y permisos ECR + ECS | Existe y es funcional | **IMPORT** |
| OIDC Provider | ✅ `arn:aws:iam::340271092920:oidc-provider/token.actions.githubusercontent.com` | GitHub OIDC Provider | Existe | **IMPORT** |

---

## 7. ECR (Elastic Container Registry)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Repositorio | ✅ `multicines/integration-service` (IMMUTABLE tags) | Repo para api-integration-service | Existe (nombre con namespace) | **IMPORT** |
| Image scanning | ❌ scanOnPush=false | Scan on push habilitado | Debe habilitarse | **IMPORT + MODIFY** |

---

## 8. Route 53

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Hosted Zone | ❌ No existe | Zona `apimulticines.com` | Gap total | **CREATE** |
| DNS Records | ❌ No existen | A/ALIAS records a ALBs | Gap total | **CREATE** |

---

## 9. WAF (Web Application Firewall)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Web ACL | ❌ No existe | Web ACL con rate limit + IP allowlist | Gap total | **CREATE** |
| Asociación ALB | ❌ No existe | WAF asociado a cada ALB | Gap total | **CREATE** |

---

## 10. ACM (Certificate Manager)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Certificado wildcard | ❌ No existe | `*.apimulticines.com` validado | Gap total | **CREATE** |

---

## 11. SSM Parameter Store

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Jerarquía | ❌ No existen parámetros | `/multicines/integrator/{env}/` | Gap total | **CREATE** |
| OTEL_TRACES_EXPORTER | ❌ No existe | Parámetro con valor "otlp" | Gap total | **CREATE** |

---

## 12. Secrets Manager

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Secretos por ambiente | ❌ No existen | Secretos separados dev/prod | Gap total | **CREATE** |

---

## 13. CloudWatch (Observabilidad)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| Log Group Dev | ✅ `/ecs/dev-multicines-integration` (sin retención definida) | Retención 30 días | Falta política de retención | **IMPORT + MODIFY** |
| Log Group Prod | ✅ `/ecs/prod-multicines-integration` (sin retención definida) | Retención 90 días | Falta política de retención | **IMPORT + MODIFY** |
| Metric Alarms | ❌ No existen | Alarmas CPU, Memoria, 5xx, latencia | Gap total | **CREATE** |
| ADOT / X-Ray | ❌ No configurado | Trazas distribuidas via ADOT Collector | Gap total | **CREATE** |

---

## 14. CI/CD (GitHub Actions)

| Aspecto | Estado Actual | Estado Objetivo | Gap | Acción |
|---------|--------------|-----------------|-----|--------|
| OIDC Provider | ✅ Existe | GitHub OIDC configurado | Coincide | **IMPORT** |
| IAM Role | ✅ `multicines-github-actions-role` | Role con permisos ECR + ECS | Existe | **IMPORT** |
| Workflow deploy.yml | ❌ No existe en repo | Pipeline completo con rollback | Gap total | **CREATE** |
| Workflow validate.yml | ❌ No existe | Validación terraform en PRs | Gap total | **CREATE** |

---

## Resumen de Acciones

### Clasificación Final

| Acción | Cantidad | Recursos |
|--------|----------|----------|
| **IMPORT** (sin cambios) | 18 | VPCs, Subnets, IGWs, NAT GWs, ECS Cluster, ECR, IAM Roles, OIDC, GitHub Actions Role |
| **IMPORT + MODIFY** | 8 | Security Groups (4), Log Groups (2), ECS Execution Role, ECR scan policy |
| **CREATE** | 15+ | ALBs, Target Groups, Listeners, VPN, Customer GW, Route 53, WAF, ACM, SSM, Secrets, Alarms, ADOT, ECS Services, Task Definitions, Workflows |

### Prioridad de Implementación

1. **IMPORT primero** — Traer recursos existentes al state sin disrupción
2. **CREATE infraestructura base** — ALB, ACM, Route 53 (prerequisitos para servicio)
3. **CREATE ECS Services** — Deployar el api-integration-service
4. **MODIFY Security Groups** — Restringir egress según diseño objetivo
5. **CREATE VPN** — Conectividad con on-premise (requiere datos del equipo de redes)
6. **CREATE Observabilidad** — Alarms, ADOT, dashboards

---

## Hallazgos Críticos

1. 🔴 **Security Group `prod-sg-vpn` permite ALL traffic desde 0.0.0.0/0** — Debe eliminarse o restringirse inmediatamente.
2. ⚠️ **0% compliance de tags** — Ningún recurso tiene los tags obligatorios (Project, Environment, ManagedBy, Service). Terraform `default_tags` resolverá esto.
3. ⚠️ **0% compliance de nomenclatura** — Ningún recurso sigue el patrón completo `multicines-{servicio}-{ambiente}-{recurso}`. Los nombres parciales (dev-vpc, prod-vpc-multicines) son legibles pero inconsistentes.
4. ⚠️ **CIDRs diferentes al diseño** — Las VPCs usan /24 (192.168.x.0/24) en lugar de /16 (10.x.0.0/16). El código Terraform debe adaptarse a los CIDRs reales existentes.
5. ⚠️ **ECS Cluster compartido** — Solo existe 1 cluster para ambos ambientes. Decisión: mantener compartido o crear separados.
6. ℹ️ **No hay ALB, VPN, WAF, ACM, Route 53, Secrets** — Gran parte de la arquitectura objetivo es nueva y no requiere import.
