# Design Document

## Overview

Este documento describe la arquitectura implementada de scripts AWS CLI idempotentes que provisionan, actualizan y eliminan los recursos de infraestructura Multicines en los ambientes dev y prod (cuenta 340271092920, región us-east-1). Incluye también un pipeline de documentación que convierte el manual de operaciones existente a Markdown y lo exporta a DOCX, y workflows de GitHub Actions para CI/CD automatizado con rollback.

## Architecture

La solución se estructura en cuatro capas:

1. **Shared Library** (`aws-cli/lib/common.sh`) — Funciones reutilizables: load_env, logging, naming, idempotencia, tags, validación de dependencias. NO contiene configuración.
2. **Environment Configuration** (`aws-cli/environments/{env}/env.properties`) — Toda la configuración externalizada por ambiente.
3. **Service Modules** (`aws-cli/{service}/create.sh|update.sh|delete.sh`) — Un subdirectorio por servicio AWS con ciclo de vida completo.
4. **Orchestrators** (`aws-cli/create-all.sh`, `update-all.sh`, `delete-all.sh`) — Invocan módulos en orden de dependencias.

```
aws-cli/
├── lib/
│   └── common.sh                  # Shared library (SOLO funciones)
├── environments/
│   ├── dev/
│   │   ├── env.properties         # Configuración del ambiente dev
│   │   ├── certs/                 # Certificados SSL para ACM
│   │   └── secrets/
│   │       └── secrets.txt        # Secretos para SSM/Secrets Manager
│   └── prod/
│       ├── env.properties
│       ├── certs/
│       └── secrets/
│           └── secrets.txt
├── acm/
│   ├── create.sh                  # Importar certificado ACM
│   ├── update.sh                  # Re-importar certificado
│   └── delete.sh                  # Eliminar certificado
├── alb/
│   ├── create.sh                  # ALB + Target Group + Listeners
│   ├── update.sh                  # Actualizar health check TG
│   └── delete.sh                  # Eliminar ALB completo
├── ecs/
│   ├── create.sh                  # Task Definition + Service
│   ├── update.sh                  # Nueva revisión TD + update service
│   └── delete.sh                  # Eliminar servicio ECS
├── route53/
│   ├── create.sh                  # Hosted Zone + Alias Record
│   ├── update.sh                  # UPSERT record (idempotente)
│   └── delete.sh                  # Eliminar record + zone
├── security-groups/
│   ├── create.sh                  # Hardening egress rules
│   ├── update.sh                  # Re-aplicar hardening
│   └── delete.sh                  # Restaurar reglas permisivas
├── secrets/
│   ├── create.sh                  # Crear secretos desde secrets.txt
│   ├── update.sh                  # Actualizar valores
│   └── delete.sh                  # Eliminar secretos
├── ssm/
│   ├── create.sh                  # Crear parámetros desde secrets.txt
│   ├── update.sh                  # Actualizar parámetros
│   └── delete.sh                  # Eliminar parámetros
├── vpn/
│   ├── create.sh                  # CGW + VGW + VPN Connection
│   ├── update.sh                  # Actualizar configuración
│   └── delete.sh                  # Eliminar recursos VPN
├── waf/
│   ├── create.sh                  # WAF Web ACL + rate limiting
│   ├── update.sh                  # Actualizar reglas/asociación
│   └── delete.sh                  # Eliminar WAF
├── documents/
│   ├── sections/                  # Secciones nuevas del manual
│   ├── images/                    # Imágenes extraídas del DOCX
│   ├── manual-original.md         # Manual convertido
│   ├── manual-multicines.md       # Manual ensamblado
│   └── manual-multicines.docx     # Manual exportado
├── create-all.sh                  # Orquestador: crear todo
├── update-all.sh                  # Orquestador: actualizar todo
├── delete-all.sh                  # Orquestador: eliminar todo (con confirmación)
├── validate-env.sh                # Validar existencia de recursos pre-existentes
├── convert-manual.sh              # DOCX → Markdown
└── build-manual.sh                # Ensamblar + exportar MD → DOCX
```

## Design Rules

### Regla: Tripleta create/update/delete obligatoria por módulo

**CADA módulo de servicio AWS** (`aws-cli/{service}/`) DEBE contener siempre los tres scripts de ciclo de vida:

1. `create.sh` — Crear el recurso (idempotente)
2. `update.sh` — Actualizar el recurso existente
3. `delete.sh` — Eliminar el recurso

Esta regla aplica a **todo nuevo componente o servicio AWS** que se agregue al proyecto. Si se introduce un nuevo módulo (por ejemplo, `observability/`, `cloudfront/`, `rds/`, etc.), se deben crear los tres scripts como parte de la implementación, sin excepción.

**Justificación:** Garantizar que todo recurso provisionado pueda ser gestionado en su ciclo de vida completo (crear, actualizar, eliminar) de forma consistente con el resto del proyecto.

---

## Components and Interfaces

### Component 1: Shared Library (`aws-cli/lib/common.sh`)

**Responsibility:** Proveer funciones compartidas de logging, validación, carga de ambiente, naming, idempotencia, tags y validación de dependencias. NO contiene configuración ni variables de infraestructura.

**Funciones implementadas:**

```bash
# === Validación ===
validate_env()         # Valida que env sea "dev" o "prod", exit 1 si inválido

# === Logging ===
log_info()             # [INFO] timestamp mensaje
log_error()            # [ERROR] timestamp mensaje (stderr)
log_skip()             # [SKIP] timestamp recurso - already exists
log_created()          # [CREATED] timestamp recurso
log_deleted()          # [DELETED] timestamp recurso
log_updated()          # [UPDATED] timestamp recurso

# === Carga de Ambiente ===
load_env()             # Source env.properties + derivar nombres y ECR_URI

# === Naming ===
generate_name()        # {env}-{resource}-{type}[-{zone}]

# === Idempotencia ===
check_exists()         # Evalúa comando describe/list, retorna 0 si existe

# === Validación de Dependencias ===
require_resource()     # Verifica dependencia, exit 1 con hint si falta

# === Tags (3 formatos) ===
get_tags()             # Key=Value format (ALB, ACM, SSM, Secrets, WAF)
get_ecs_tags()         # key=value lowercase (ECS task defs y services)
get_tag_spec()         # {Key=,Value=} format (EC2 tag-specifications: VPN, CGW, VGW)

# === Helpers ===
get_certs_dir()        # Retorna path a environments/{env}/certs/
```

**`load_env` — Comportamiento detallado:**

```bash
load_env() {
  # 1. Valida ambiente (dev|prod)
  # 2. Source environments/{env}/env.properties
  # 3. Deriva variables:
  export ECR_URI="${AWS_ACCOUNT}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPO}"
  export ALB_NAME="${ENV}-${APP_NAME}-alb"
  export ECS_TG_NAME="${ENV}-${APP_NAME}-tg"
  export ECS_SERVICE_NAME="${ENV}-${APP_NAME}-svc"
  export ECS_TASK_FAMILY="${ENV}-${APP_NAME}-task"
  export WAF_NAME="${ENV}-${APP_NAME}-waf"
  export VPN_NAME="${ENV}-${APP_NAME}-vpn"
  export VGW_NAME="${ENV}-${APP_NAME}-vgw"
  export CGW_NAME="${ENV}-${APP_NAME}-cgw"
  export ACM_NAME="${ENV}-${APP_NAME}-acm"
}
```

**Naming Convention:** `{env}-{app_name}-{resource_type}`  
Ejemplos: `dev-multicines-integration-alb`, `dev-multicines-integration-tg`, `dev-multicines-integration-svc`

### Component 2: Environment Configuration (`environments/{env}/env.properties`)

**Responsibility:** Centralizar TODA la configuración de infraestructura por ambiente en un archivo plano key=value.

**Variables definidas:**

| Categoría | Variables |
|-----------|-----------|
| Application | APP_NAME, PROJECT_NAME, AWS_ACCOUNT, AWS_REGION |
| Networking | VPC_ID, PUBLIC_SUBNETS, PRIVATE_SUBNETS, ALB_SG_ID, ECS_SG_ID |
| Domain | DOMAIN (wildcard: `*.test.multicines.com.ec`) |
| ALB | ALB_SSL_POLICY (`ELBSecurityPolicy-TLS13-1-2-2021-06`) |
| ECS | ECS_CLUSTER, ECS_CPU, ECS_MEMORY, ECS_DESIRED_COUNT, ECS_IMAGE_TAG, ECS_ENABLE_EXEC |
| ECR | ECR_REPO |
| Container | CONTAINER_PORT, CONTAINER_NAME, HEALTH_CHECK_PATH, HEALTH_CHECK_PORT |
| Container Env | SPRING_PROFILES_ACTIVE, OTEL_LOGS_EXPORTER, OTEL_METRICS_EXPORTER, OTEL_TRACES_EXPORTER |
| Logs | LOG_GROUP |
| IAM | EXECUTION_ROLE_ARN, TASK_ROLE_ARN |
| WAF | WAF_RATE_LIMIT |
| VPN | VPN_CUSTOMER_IP (placeholder: 0.0.0.0), VPN_BGP_ASN (placeholder: 65000) |

### Component 3: Orchestrators

**`create-all.sh` — Orden de creación (cadena de dependencias):**

```
1. acm/create.sh          → Certificado SSL (requerido por ALB HTTPS listener)
2. waf/create.sh          → WAF Web ACL (se asocia al ALB si existe)
3. security-groups/create.sh → Hardening de egress rules
4. alb/create.sh          → ALB + Target Group + Listeners (requiere ACM)
5. route53/create.sh      → DNS record alias → ALB (requiere ALB)
6. ssm/create.sh          → SSM Parameter Store
7. secrets/create.sh      → Secrets Manager
8. ecs/create.sh          → Task Definition + Service (requiere TG del ALB)
9. vpn/create.sh          → VPN Site-to-Site (independiente)
```

**`update-all.sh` — Módulos actualizables:**

```
1. ssm/update.sh
2. secrets/update.sh
3. security-groups/update.sh
4. waf/update.sh
5. ecs/update.sh
6. acm/update.sh
```

**`delete-all.sh` — Orden inverso con confirmación destructiva:**

```
1. Solicita confirmación explícita ("yes")
2. vpn → ecs → secrets → ssm → route53 → alb → security-groups → waf → acm
```

### Component 4: ALB Module (`aws-cli/alb/`)

**Configuración implementada:**

| Parámetro | Valor |
|-----------|-------|
| Tipo ALB | application, internet-facing |
| Target Group type | ip (Fargate) |
| Health check protocol | HTTP |
| Health check path | /actuator/health |
| Health check port | 8095 |
| Health check interval | 30s |
| Health check timeout | 10s |
| Healthy threshold | 2 |
| Unhealthy threshold | 5 |
| HTTPS listener port | 443 |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 (TLS 1.3) |
| HTTP listener port | 80 (redirect → HTTPS 301) |

**Fail-fast:** Valida existencia del certificado ACM antes de crear cualquier recurso.

### Component 5: ECS Module (`aws-cli/ecs/`)

**Task Definition:**

| Parámetro | Valor |
|-----------|-------|
| Family | `{env}-{app_name}-task` |
| Network mode | awsvpc |
| Compatibilidad | FARGATE |
| CPU/Memory | Desde env.properties (dev: 512/1024) |
| Image | `{ECR_URI}:{ECS_IMAGE_TAG}` |
| Port mapping | CONTAINER_PORT (8095) TCP |
| Log driver | awslogs (stream-prefix: `api`) |
| Environment vars | SPRING_PROFILES_ACTIVE, AWS_REGION, OTEL_LOGS_EXPORTER, OTEL_METRICS_EXPORTER, OTEL_TRACES_EXPORTER |

**ECS Service:**

| Parámetro | Valor |
|-----------|-------|
| Cluster | multicines-cluster |
| Launch type | FARGATE |
| Health check grace period | 210 segundos |
| Execute command | Habilitado cuando ECS_ENABLE_EXEC=true |
| Network | Private subnets, ECS SG, assignPublicIp=DISABLED |
| Load balancer | Target Group del ALB |
| Desired count | Desde env.properties |

**`update.sh`:** Registra nueva revisión de Task Definition, actualiza servicio con `health-check-grace-period-seconds 210`, y espera estabilidad con `aws ecs wait services-stable`.

**`create.sh` — Manejo de DRAINING:** Si el servicio está en estado DRAINING, el script espera en loop hasta que cambie de estado antes de crear uno nuevo.

### Component 6: Route53 Module (`aws-cli/route53/`)

**Patrón DNS implementado:**

```
1. Extrae base domain del wildcard: *.test.multicines.com.ec → test.multicines.com.ec
2. Crea hosted zone para base domain (si no existe)
3. Crea registro alias tipo A:
   Nombre: {env}-integration.{base_domain}
   Ejemplo: dev-integration.test.multicines.com.ec
   Target: DNS del ALB (con EvaluateTargetHealth: true)
4. Usa action UPSERT para idempotencia
5. Emite nameservers de delegación al crear nueva hosted zone
```

### Component 7: VPN Module (`aws-cli/vpn/`)

**Recursos creados:**

1. Customer Gateway (ipsec.1, IP y ASN desde env.properties — placeholders)
2. Virtual Private Gateway (ipsec.1) — attached a VPC
3. VPN Connection (ipsec.1, asocia CGW + VGW)
4. Route Propagation en route tables privadas

**Warning:** Emite advertencia cuando VPN_CUSTOMER_IP es 0.0.0.0 (placeholder).

### Component 8: WAF Module (`aws-cli/waf/`)

- Scope: REGIONAL
- Default action: Allow
- Regla: Rate-based, límite WAF_RATE_LIMIT (2000 req/5min por IP), action Block
- Asociación: Al ALB del ambiente (si existe, sino skip informativo)

### Component 9: Security Groups Module (`aws-cli/security-groups/`)

**ALB SG:**
- Revoca egress `0.0.0.0/0` all-traffic (IpProtocol=-1)
- Agrega egress TCP → ECS SG en CONTAINER_PORT

**ECS SG:**
- Revoca egress `0.0.0.0/0` all-traffic
- Agrega egress TCP → 0.0.0.0/0:443 (AWS service endpoints)

**Idempotencia:** Verifica cada regla individual antes de modificar.

### Component 10: ACM Module (`aws-cli/acm/`)

- Importa certificado desde `environments/{env}/certs/` (certificate.pem, private-key.pem, certificate-chain.pem)
- Verifica existencia por dominio antes de importar
- Aplica tags estándar

### Component 11: SSM Module (`aws-cli/ssm/`)

- Lee `environments/{env}/secrets/secrets.txt` parseando bloques key/value con JSON
- Crea parámetros bajo `/multicines/integrator/{env}/`
- Tipo: SecureString para JSONs, String para OTEL_TRACES_EXPORTER (fijo: "otlp")
- Compacta JSON con python3 antes de almacenar

### Component 12: Secrets Manager Module (`aws-cli/secrets/`)

- Lee `environments/{env}/secrets/secrets.txt` (mismo formato que SSM)
- Nombre del secreto = key completa del archivo (ej: `platform/dev/resilience`)
- Aplica tags estándar

### Component 13: Validate Environment (`aws-cli/validate-env.sh`)

Verifica existencia de recursos pre-existentes referenciados en env.properties:
- VPC, Public/Private Subnets, ALB/ECS Security Groups
- Log Group, ECS Cluster, ECR Repository
- IAM Roles (Execution + Task)

Reporta también estado de recursos a crear (ALB, TG, WAF, ACM, ECS Service).

### Component 14: Documentation Pipeline

**`convert-manual.sh`:**
- Verifica Pandoc disponible
- Convierte "Insumos iniciales/Manual para multicines.docx" → `documents/manual-original.md`
- Extrae imágenes a `documents/images/`

**`build-manual.sh`:**
- Verifica que `manual-original.md` exista (requiere convert-manual.sh previo)
- Concatena: manual-original.md + sections/*.md → manual-multicines.md
- Exporta a DOCX con `--resource-path` para resolver imágenes

### Component 15: GitHub Actions CI/CD

**Arquitectura de workflows (en repositorio Capa-Media):**

| Workflow | Trigger | Ambiente |
|----------|---------|----------|
| `deploy-dev.yml` | push a `dev`, workflow_dispatch | development |
| `deploy-prod.yml` | push a `main`, workflow_dispatch | production |

**Pipeline de cada workflow:**

```
1. Checkout code
2. Configure AWS credentials (OIDC: role-to-assume)
3. Login to Amazon ECR
4. Extract version from pom.xml
5. Build Docker image, tag con {env}-{short_sha} y {version}-{short_sha}
6. Push image to ECR
7. Get current task definition (para rollback)
8. Download task definition actual
9. Render nueva imagen en task definition
10. Deploy to ECS (wait-for-service-stability: true, 10 min timeout)
11. [On failure] Rollback: restore previous TD + force-new-deployment + wait stable
12. Verify deployment: confirmar tareas RUNNING
```

**Permisos:** `id-token: write` (OIDC), `contents: read`  
**Autenticación:** `aws-actions/configure-aws-credentials@v4` con `role-to-assume`  
**Image tags:** `{env}-{GITHUB_SHA::16}` y `{version}-{GITHUB_SHA::16}`

## Data Models

### Environment Properties (env.properties)

```properties
# Formato: key=value (sourced por bash)
APP_NAME=multicines-integration
PROJECT_NAME=multicines
AWS_ACCOUNT=340271092920
AWS_REGION=us-east-1
VPC_ID=vpc-0a5ebea8e7bee9ed5
# ... (todas las variables de infraestructura)
```

### Naming Convention

```
Patrón: {env}-{app_name}-{resource_type}

Ejemplos:
  dev-multicines-integration-alb      (ALB)
  dev-multicines-integration-tg       (Target Group)
  dev-multicines-integration-svc      (ECS Service)
  dev-multicines-integration-task     (Task Definition family)
  dev-multicines-integration-waf      (WAF Web ACL)
  dev-multicines-integration-vpn      (VPN Connection)
  dev-multicines-integration-vgw      (Virtual Private Gateway)
  dev-multicines-integration-cgw      (Customer Gateway)
  dev-multicines-integration-acm      (ACM Certificate)
```

### Tags Structure

```bash
# get_tags (Key=Value) — para ALB, ACM, SSM, Secrets, WAF
Key=Name,Value={name} Key=Project,Value={project} Key=Environment,Value={env} Key=Service,Value={app}

# get_ecs_tags (key=value lowercase) — para ECS
key=Name,value={name} key=Project,value={project} key=Environment,value={env} key=Service,value={app}

# get_tag_spec (JSON-like) — para EC2/VPN tag-specifications
{Key=Name,Value={name}},{Key=Project,Value={project}},{Key=Environment,Value={env}},{Key=Service,Value={app}}
```

### SSM Parameter Hierarchy

```
/multicines/integrator/{env}/{param_name}    → SecureString (JSON compactado)
/multicines/integrator/{env}/OTEL_TRACES_EXPORTER → String "otlp"
```

### Route53 DNS Pattern

```
Wildcard Domain (env.properties):  *.test.multicines.com.ec
Base Domain (derivado):            test.multicines.com.ec
ALB Record:                        {env}-integration.{base_domain}
Ejemplo:                           dev-integration.test.multicines.com.ec
```

## Error Handling

| Patrón | Implementación |
|--------|----------------|
| `set -euo pipefail` | Todos los scripts — falla inmediata ante errores no controlados |
| `require_resource` | Fail-fast: valida dependencias al inicio, exit 1 con hint del script a ejecutar |
| `check_exists` | Idempotencia: evalúa describe/list antes de crear |
| Logging estructurado | [INFO], [ERROR], [SKIP], [CREATED], [UPDATED], [DELETED] con timestamp |
| Exit codes | Non-zero en cualquier falla de creación/actualización |
| DRAINING state | ECS create.sh espera en loop si servicio está en DRAINING |
| Confirmación destructiva | delete-all.sh requiere "yes" explícito |
| Rollback CI/CD | GitHub Actions restaura TD anterior + force-new-deployment en fallo |

## Correctness Properties

### Property 1: load_env produce nombres derivados consistentes

*Para cualquier* ambiente válido (`dev`|`prod`) y *para cualquier* valor de APP_NAME en env.properties, la función `load_env` SHALL derivar todos los nombres de recursos siguiendo el patrón `{env}-{app_name}-{tipo}` donde tipo es uno de: alb, tg, svc, task, waf, vpn, vgw, cgw, acm.

**Valida: Requisitos 2.4, 2.5, 13.2**

### Property 2: Idempotencia — recursos existentes no se recrean

*Para cualquier* módulo de servicio y *para cualquier* recurso que ya existe en la cuenta AWS, ejecutar el script SHALL no invocar un comando `create` para ese recurso, y SHALL emitir un mensaje `[SKIP]`.

**Valida: Requisitos 3.1, 3.2, 3.3**

### Property 3: Orquestador respeta orden de dependencias

*Para cualquier* par de módulos (A, B) donde B depende de un recurso creado por A, el orquestador `create-all.sh` SHALL invocar A antes que B en la secuencia de ejecución.

**Valida: Requisitos 1.3, 1.4, 1.5**

### Property 4: require_resource detiene ejecución ante dependencia faltante

*Para cualquier* script que valida dependencias, si un recurso requerido no existe, `require_resource` SHALL emitir un mensaje de error con el nombre del recurso faltante y SHALL terminar la ejecución con exit code 1.

**Valida: Requisito 3.8**

### Property 5: Tags aplicados consistentemente en 3 formatos

*Para cualquier* recurso creado, los tags SHALL incluir Name, Project, Environment y Service, formateados con `get_tags` (Key=Value), `get_ecs_tags` (key=value) o `get_tag_spec` (JSON-like) según el servicio AWS.

**Valida: Requisitos 13.1, 13.2, 13.3, 13.4, 13.5, 13.6**

### Property 6: CI/CD rollback preserva estabilidad

*Para cualquier* despliegue fallido en GitHub Actions, el workflow SHALL restaurar la task definition anterior mediante `update-service` con `--force-new-deployment` y SHALL esperar estabilidad del servicio con `aws ecs wait services-stable`.

**Valida: Requisito 15.6**
