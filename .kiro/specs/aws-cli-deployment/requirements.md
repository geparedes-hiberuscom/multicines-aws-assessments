# Requirements Document

## Introduction

Este documento define los requisitos para los scripts AWS CLI idempotentes que provisionan, actualizan y eliminan los recursos de infraestructura Multicines en los ambientes dev y prod (cuenta 340271092920, región us-east-1). El proyecto utiliza una estructura modular con subdirectorios por servicio AWS, configuración externalizada en archivos `env.properties` por ambiente, y una librería compartida de funciones (`lib/common.sh`). Incluye también la conversión del manual de operaciones existente a Markdown, extensión con secciones por recurso, exportación a DOCX, y observabilidad (CloudWatch Alarms, Dashboard, Log Metric Filters, AWS X-Ray con sidecar ADOT).

## Glossary

- **Script_Orquestador**: Scripts bash (`create-all.sh`, `update-all.sh`, `delete-all.sh`) ubicados en la raíz de `aws-cli/` que invocan secuencialmente los módulos de cada servicio.
- **Módulo_Servicio**: Subdirectorio dentro de `aws-cli/` (ej: `alb/`, `ecs/`, `vpn/`) que contiene scripts `create.sh`, `update.sh` y `delete.sh` para gestionar el ciclo de vida completo de un tipo de recurso AWS.
- **common.sh**: Librería compartida en `aws-cli/lib/common.sh` que contiene SOLO funciones (logging, naming, idempotencia, tags, carga de ambiente). NO contiene configuración.
- **env.properties**: Archivo de configuración por ambiente ubicado en `aws-cli/environments/{env}/env.properties` que contiene TODAS las variables de infraestructura (VPC, subnets, SGs, dominios, sizing, etc.).
- **Naming_Convention**: Patrón de nombrado `{env}-{app_name}-{resource_type}` (ej: `dev-multicines-integration-alb`, `prod-multicines-integration-tg`).
- **Idempotencia**: Capacidad de un script de ejecutarse múltiples veces produciendo el mismo resultado final sin recrear recursos ya existentes.
- **ALB**: Application Load Balancer de AWS que distribuye tráfico HTTP/HTTPS a Target Groups.
- **Target_Group**: Grupo de destinos registrado en un ALB con health check configurado (timeout 10s, healthy threshold 2, unhealthy threshold 5).
- **WAF_WebACL**: Web Access Control List de AWS WAF con scope REGIONAL que protege los ALBs con regla de rate limiting.
- **VPN_Site_to_Site**: Conexión VPN entre AWS y la red on-premise del cliente con Customer Gateway, Virtual Private Gateway y route propagation.
- **Customer_Gateway**: Recurso AWS que representa el dispositivo VPN on-premise del cliente (usa valores placeholder: IP 0.0.0.0, ASN 65000).
- **ACM_Certificate**: Certificado SSL/TLS importado en AWS Certificate Manager para tráfico HTTPS en el ALB.
- **SSM_Parameter**: Parámetro almacenado en AWS Systems Manager Parameter Store bajo la jerarquía `/multicines/integrator/{env}/`.
- **Secrets_Manager_Secret**: Secreto almacenado en AWS Secrets Manager con valores separados por ambiente.
- **ECS_Service**: Servicio de Amazon ECS Fargate dentro del cluster `multicines-cluster` con health check grace period de 210 segundos.
- **Task_Definition**: Definición de tarea ECS que especifica imagen ECR, CPU, memoria, port mappings, variables de entorno (incluyendo OTEL) y log configuration.
- **Security_Group_Hardening**: Proceso de restringir las reglas de egress permisivas (0.0.0.0/0) en los Security Groups existentes del ALB y ECS.
- **Route53_Record**: Registro DNS alias tipo A en Route 53 con formato `{env}-integration.{base_domain}` apuntando al ALB.
- **validate-env.sh**: Script que verifica la existencia de todos los recursos pre-existentes referenciados en `env.properties` antes de ejecutar la creación.
- **Manual_Operaciones**: Documento Markdown ensamblado a partir del manual original convertido y secciones por recurso en `documents/sections/`.
- **Pandoc**: Herramienta de conversión de documentos utilizada para convertir DOCX a Markdown y exportar Markdown a DOCX.
- **GitHub_Actions_Workflow**: Workflows de CI/CD (`deploy-dev.yml`, `deploy-prod.yml`) que construyen la imagen Docker, la publican en ECR y despliegan en ECS con rollback automático.

## Requirements

### Requirement 1: Estructura Modular y Orquestación

**User Story:** As a DevOps engineer, I want a modular directory structure with orchestrator scripts, so that I can provision, update or delete all AWS resources in a single execution or manage each service independently.

#### Acceptance Criteria

1. THE proyecto SHALL organizar los scripts en subdirectorios por servicio AWS (`acm/`, `alb/`, `ecs/`, `route53/`, `security-groups/`, `secrets/`, `ssm/`, `vpn/`, `waf/`) dentro de `aws-cli/`.
2. EACH Módulo_Servicio SHALL contener tres scripts: `create.sh`, `update.sh` y `delete.sh` para gestionar el ciclo de vida completo del recurso. Esta regla es OBLIGATORIA para todo nuevo módulo de servicio AWS que se agregue al proyecto (presente o futuro), sin excepción.
3. THE Script_Orquestador `create-all.sh` SHALL invocar los módulos en orden de dependencias: acm → waf → security-groups → alb → route53 → ssm → secrets → ecs → vpn.
4. THE Script_Orquestador `update-all.sh` SHALL invocar los módulos actualizables: ssm → secrets → security-groups → waf → ecs → acm.
5. THE Script_Orquestador `delete-all.sh` SHALL invocar los módulos de eliminación en orden inverso a las dependencias.
6. WHEN any Script_Orquestador is executed, THE Script_Orquestador SHALL aceptar un parámetro de ambiente (`dev` o `prod`) que se propaga a cada módulo invocado.
7. EACH script de módulo SHALL ser ejecutable de forma independiente aceptando el parámetro de ambiente sin requerir la ejecución previa del orquestador.
8. THE script `validate-env.sh` SHALL verificar la existencia de todos los recursos pre-existentes (VPC, subnets, SGs, log groups, cluster ECS, repositorio ECR, roles IAM) y reportar cuáles existen y cuáles faltan.

### Requirement 2: Configuración Externalizada y Librería Compartida

**User Story:** As a DevOps engineer, I want all configuration separated from code in environment-specific files, so that I can manage dev and prod independently without modifying scripts.

#### Acceptance Criteria

1. THE archivo `lib/common.sh` SHALL contener SOLO funciones (logging, validación de ambiente, carga de ambiente, naming helper, idempotencia, tags, validación de dependencias) y NO SHALL contener configuración ni variables de infraestructura.
2. THE configuración de cada ambiente SHALL residir en `environments/{env}/env.properties` donde `{env}` es `dev` o `prod`.
3. THE archivo `env.properties` SHALL definir todas las variables necesarias: APP_NAME, PROJECT_NAME, AWS_ACCOUNT, AWS_REGION, VPC_ID, PUBLIC_SUBNETS, PRIVATE_SUBNETS, ALB_SG_ID, ECS_SG_ID, DOMAIN, ECS_CLUSTER, ECS_CPU, ECS_MEMORY, ECS_DESIRED_COUNT, ECS_IMAGE_TAG, ECR_REPO, CONTAINER_PORT, CONTAINER_NAME, HEALTH_CHECK_PATH, HEALTH_CHECK_PORT, LOG_GROUP, EXECUTION_ROLE_ARN, TASK_ROLE_ARN, WAF_RATE_LIMIT, VPN_CUSTOMER_IP, VPN_BGP_ASN.
4. WHEN `load_env` is called, THE función SHALL derivar nombres de recursos usando el patrón `{env}-{app_name}-{tipo}` (ej: `dev-multicines-integration-alb`, `dev-multicines-integration-tg`, `dev-multicines-integration-svc`).
5. THE función `load_env` SHALL exportar la URI de ECR derivada como `{AWS_ACCOUNT}.dkr.ecr.{AWS_REGION}.amazonaws.com/{ECR_REPO}`.
6. EACH script de módulo SHALL comenzar con `source "${SCRIPT_DIR}/../lib/common.sh"` seguido de `load_env "$ENV"` para cargar la configuración del ambiente.

### Requirement 3: Idempotencia y Manejo de Errores

**User Story:** As a DevOps engineer, I want scripts that do not recreate existing resources and fail fast on errors, so that I can safely re-execute them without side effects.

#### Acceptance Criteria

1. WHEN a script de módulo is executed, THE script SHALL verificar la existencia del recurso mediante `aws ... describe` o `aws ... list` antes de intentar crearlo.
2. WHILE a resource already exists in the AWS account, THE script SHALL omitir la creación y emitir un mensaje `[SKIP]` indicando que el recurso ya existe.
3. WHEN a resource is created successfully, THE script SHALL emitir un mensaje `[CREATED]` confirmando la creación exitosa.
4. WHEN a resource is updated successfully, THE script SHALL emitir un mensaje `[UPDATED]` confirmando la actualización.
5. WHEN a resource is deleted successfully, THE script SHALL emitir un mensaje `[DELETED]` confirmando la eliminación.
6. IF a command `aws ... create` fails, THEN THE script SHALL emitir un mensaje `[ERROR]` y detener la ejecución con exit code distinto de cero.
7. EACH script SHALL utilizar `set -euo pipefail` para fallar inmediatamente ante cualquier error no controlado.
8. EACH script SHALL validar dependencias con `require_resource` antes de ejecutar la lógica principal, emitiendo un mensaje de error que indica qué recurso falta y qué script ejecutar primero.

### Requirement 4: Creación de Application Load Balancer

**User Story:** As a DevOps engineer, I want ALBs provisioned with Target Groups, HTTPS listeners and HTTP redirect, so that traffic is securely distributed to ECS services.

#### Acceptance Criteria

1. WHEN the ALB create script is executed, THE script SHALL validar que el certificado ACM existe antes de crear cualquier recurso (fail-fast).
2. THE script SHALL crear un ALB de tipo `application`, scheme `internet-facing`, en las subnets públicas del ambiente con el Security Group del ALB asociado.
3. THE script SHALL crear un Target_Group con target-type `ip`, protocolo HTTP, puerto igual a CONTAINER_PORT, health check en HEALTH_CHECK_PATH con timeout 10 segundos, healthy threshold 2 y unhealthy threshold 5.
4. THE script SHALL crear un Listener HTTPS en el puerto 443 con política TLS `ELBSecurityPolicy-TLS13-1-2-2021-06` que reenvía tráfico al Target_Group.
5. THE script SHALL crear un Listener HTTP en el puerto 80 que redirija a HTTPS con código 301.
6. THE script SHALL nombrar el ALB como `{env}-{app_name}-alb` y el Target Group como `{env}-{app_name}-tg`.
7. WHEN the ALB update script is executed, THE script SHALL actualizar la configuración del health check del Target Group.

### Requirement 5: Creación de ECS Services y Task Definitions

**User Story:** As a DevOps engineer, I want ECS Services and Task Definitions with proper health check grace period, so that Spring Boot services have sufficient time to start without being killed by the load balancer.

#### Acceptance Criteria

1. WHEN the ECS create script is executed, THE script SHALL registrar una Task_Definition con familia `{env}-{app_name}-task`, network mode `awsvpc`, compatibilidad FARGATE, con CPU y memoria definidos en env.properties.
2. THE Task_Definition SHALL incluir variables de entorno: SPRING_PROFILES_ACTIVE, AWS_REGION, OTEL_LOGS_EXPORTER, OTEL_METRICS_EXPORTER, OTEL_TRACES_EXPORTER con valores del env.properties.
3. THE Task_Definition SHALL configurar log configuration con driver `awslogs` apuntando al LOG_GROUP definido en env.properties con stream-prefix `api`.
4. THE script SHALL crear un ECS_Service en el cluster `multicines-cluster` con launch type FARGATE, health check grace period de 210 segundos, y `--enable-execute-command` cuando ECS_ENABLE_EXEC=true.
5. THE ECS_Service SHALL utilizar las subnets privadas y el Security Group ECS del ambiente, con `assignPublicIp=DISABLED`.
6. THE ECS_Service SHALL registrarse en el Target_Group del ALB del ambiente correspondiente.
7. WHEN the ECS update script is executed, THE script SHALL registrar una nueva revisión de Task Definition y actualizar el servicio con `health-check-grace-period-seconds 210`, luego esperar estabilidad con `aws ecs wait services-stable`.
8. IF the ECS service is in state DRAINING, THEN the create script SHALL esperar hasta que el estado cambie antes de crear un nuevo servicio.

### Requirement 6: Creación de Route 53 Records

**User Story:** As a DevOps engineer, I want DNS records created in Route 53 pointing to the ALB, so that the service is accessible via a friendly domain name.

#### Acceptance Criteria

1. WHEN the Route53 create script is executed, THE script SHALL extraer el base domain del wildcard DOMAIN (ej: `*.test.multicines.com.ec` → `test.multicines.com.ec`).
2. THE script SHALL crear una hosted zone para el base domain si no existe.
3. THE script SHALL crear un registro alias tipo A con nombre `{env}-integration.{base_domain}` (ej: `dev-integration.test.multicines.com.ec`) apuntando al DNS del ALB.
4. THE script SHALL utilizar action `UPSERT` para que la operación sea idempotente.
5. WHEN the Route53 update script is executed, THE script SHALL invocar el mismo script de creación (UPSERT es idempotente por naturaleza).
6. WHEN a hosted zone is created, THE script SHALL emitir los nameservers de delegación para configurar en el registrador de dominio.

### Requirement 7: Creación de VPN Site-to-Site

**User Story:** As a network engineer, I want VPN Site-to-Site resources provisioned with placeholders, so that connectivity can be established when the customer provides gateway details.

#### Acceptance Criteria

1. THE env.properties SHALL definir VPN_CUSTOMER_IP=0.0.0.0 y VPN_BGP_ASN=65000 como valores placeholder claramente documentados.
2. WHEN the VPN create script is executed with IP placeholder, THE script SHALL emitir una advertencia indicando que se debe actualizar env.properties antes de uso en producción.
3. THE script SHALL crear un Customer_Gateway tipo `ipsec.1` con la IP y ASN definidos en env.properties.
4. THE script SHALL crear un Virtual Private Gateway tipo `ipsec.1` y adjuntarlo a la VPC del ambiente.
5. THE script SHALL crear una VPN Connection tipo `ipsec.1` asociando el Customer_Gateway y el Virtual Private Gateway.
6. THE script SHALL habilitar route propagation en las route tables privadas asociadas a las PRIVATE_SUBNETS.
7. THE script SHALL nombrar los recursos como `{env}-{app_name}-cgw`, `{env}-{app_name}-vgw`, `{env}-{app_name}-vpn`.

### Requirement 8: Creación de WAF Web ACL

**User Story:** As a security engineer, I want a WAF Web ACL protecting the ALBs with rate limiting, so that the application is shielded from excessive request rates.

#### Acceptance Criteria

1. WHEN the WAF create script is executed, THE script SHALL crear una WAF_WebACL con scope REGIONAL y default action Allow.
2. THE WAF_WebACL SHALL incluir una regla rate-based con límite definido en WAF_RATE_LIMIT de env.properties (default: 2000 requests/5min por IP) y action Block.
3. THE script SHALL asociar la WAF_WebACL al ALB del ambiente si el ALB ya existe.
4. IF the ALB does not exist yet, THEN THE script SHALL omitir la asociación y emitir un mensaje informativo.
5. THE script SHALL nombrar la WAF como `{env}-{app_name}-waf`.

### Requirement 9: Creación de ACM Certificate

**User Story:** As a DevOps engineer, I want an ACM certificate provisioned, so that the ALB listener can terminate HTTPS traffic.

#### Acceptance Criteria

1. WHEN the ACM create script is executed, THE script SHALL importar o solicitar un certificado en ACM para el dominio definido en DOMAIN de env.properties.
2. THE script SHALL verificar si ya existe un certificado para el mismo dominio antes de crear uno nuevo.
3. THE script SHALL nombrar el certificado con tag Name `{env}-{app_name}-acm`.

### Requirement 10: Creación de SSM Parameter Store

**User Story:** As a DevOps engineer, I want application secrets stored in SSM Parameter Store, so that ECS tasks can retrieve configuration at runtime.

#### Acceptance Criteria

1. WHEN the SSM create script is executed, THE script SHALL crear parámetros bajo la jerarquía `/multicines/integrator/{env}/`.
2. THE script SHALL leer los valores desde el archivo `environments/{env}/secrets/secrets.txt` parseando bloques key/value con contenido JSON.
3. THE script SHALL crear los parámetros del archivo secrets.txt como tipo `SecureString` con el JSON compactado.
4. THE script SHALL crear el parámetro fijo `OTEL_TRACES_EXPORTER` con valor `otlp` y tipo `String`.
5. WHILE a parameter with the same path already exists, THE script SHALL omitir la creación de ese parámetro.

### Requirement 11: Creación de Secrets Manager

**User Story:** As a DevOps engineer, I want application secrets stored in Secrets Manager, so that sensitive credentials are managed securely.

#### Acceptance Criteria

1. WHEN the Secrets Manager create script is executed, THE script SHALL crear secretos separados por ambiente.
2. WHILE a secret with the same name already exists, THE script SHALL omitir la creación de ese secreto.
3. THE script SHALL aplicar tags estándar (Name, Project, Environment, Service) a cada secreto creado.

### Requirement 12: Hardening de Security Groups

**User Story:** As a security engineer, I want restrictive egress rules on existing Security Groups, so that outbound traffic is limited to only necessary destinations.

#### Acceptance Criteria

1. WHEN the Security Groups create script is executed, THE script SHALL revocar la regla de egress `0.0.0.0/0` all-traffic (`IpProtocol=-1`) del Security Group ALB si existe.
2. THE script SHALL agregar una regla de egress en el SG ALB que permita tráfico TCP solo al CONTAINER_PORT hacia el Security Group ECS.
3. THE script SHALL revocar la regla de egress `0.0.0.0/0` all-traffic del Security Group ECS si existe.
4. THE script SHALL agregar una regla de egress en el SG ECS que permita tráfico TCP al puerto 443 hacia `0.0.0.0/0` (endpoints de servicios AWS: ECR, CloudWatch, SSM, Secrets Manager).
5. EACH operación de regla SHALL verificar si ya fue aplicada antes de ejecutar (idempotencia a nivel de regla individual).

### Requirement 13: Tags Estandarizados

**User Story:** As a DevOps engineer, I want all resources tagged consistently, so that cost allocation and resource identification are standardized.

#### Acceptance Criteria

1. EACH recurso creado SHALL recibir los tags: Name, Project, Environment, Service.
2. THE tag `Name` SHALL seguir el Naming_Convention `{env}-{app_name}-{tipo}`.
3. THE tag `Project` SHALL tener valor fijo `multicines`.
4. THE tag `Environment` SHALL tener el valor del ambiente (`dev` o `prod`).
5. THE tag `Service` SHALL tener el valor de APP_NAME del env.properties.
6. THE common.sh SHALL proveer funciones de tags en tres formatos: `get_tags` (Key=Value para ALB/ACM/SSM), `get_ecs_tags` (key=value lowercase para ECS), `get_tag_spec` (formato tag-specifications para EC2/VPN).

### Requirement 14: Conversión y Extensión del Manual de Operaciones

**User Story:** As a documentation maintainer, I want the existing operations manual converted to Markdown and extended with new resource sections, so that it is version-controlled and complete.

#### Acceptance Criteria

1. THE script `convert-manual.sh` SHALL usar Pandoc para convertir "Insumos iniciales/Manual para multicines.docx" a Markdown en `documents/manual-original.md`.
2. THE script `convert-manual.sh` SHALL extraer las imágenes del DOCX y almacenarlas en `documents/images/`.
3. THE directorio `documents/sections/` SHALL contener archivos Markdown individuales con documentación de cada recurso provisionado.
4. THE script `build-manual.sh` SHALL concatenar `manual-original.md` + todos los archivos de `sections/*.md` en un archivo `manual-multicines.md`.
5. THE script `build-manual.sh` SHALL exportar el Markdown ensamblado a `documents/manual-multicines.docx` usando Pandoc con `--resource-path` para resolver imágenes.
6. THE script `build-manual.sh` SHALL requerir que `convert-manual.sh` haya sido ejecutado previamente (verifica existencia de `manual-original.md`).

### Requirement 15: GitHub Actions CI/CD

**User Story:** As a DevOps engineer, I want GitHub Actions workflows that build, push and deploy automatically, so that code changes reach ECS without manual intervention.

#### Acceptance Criteria

1. THE workflow `deploy-dev.yml` SHALL ejecutarse en push a la rama `dev` y mediante `workflow_dispatch`.
2. THE workflow `deploy-prod.yml` SHALL ejecutarse en push a la rama `main` y mediante `workflow_dispatch`.
3. EACH workflow SHALL autenticarse con AWS usando OIDC (`aws-actions/configure-aws-credentials@v4` con `role-to-assume`).
4. EACH workflow SHALL construir la imagen Docker, tagear con `{env}-{short_sha}` y `{version}-{short_sha}`, y publicar en ECR.
5. EACH workflow SHALL descargar la task definition actual, actualizar la imagen del contenedor, y desplegar en ECS usando `aws-actions/amazon-ecs-deploy-task-definition@v2` con `wait-for-service-stability: true`.
6. WHEN a deployment fails, THE workflow SHALL ejecutar rollback automático restaurando la task definition anterior y esperando estabilidad del servicio.
7. AFTER successful deployment, THE workflow SHALL verificar que existen tareas RUNNING en el servicio ECS.

### Requirement 16: Módulo de Observabilidad (estructura de scripts)

**User Story:** As a DevOps engineer, I want an observability module following the existing project patterns, so that I can create, update and delete observability resources consistently.

#### Acceptance Criteria

1. THE módulo SHALL residir en `aws-cli/observability/` con tres scripts: `create.sh`, `update.sh` y `delete.sh`.
2. EACH script SHALL seguir el patrón existente: `source lib/common.sh`, `load_env "$ENV"`, validación de dependencias con `require_resource`, idempotencia con `check_exists`.
3. THE script `create.sh` SHALL crear los recursos en orden: SNS Topic → CloudWatch Alarms → Log Metric Filters → Dashboard → IAM X-Ray Policy.
4. THE archivo `env.properties` SHALL ser extendido con variables: `SNS_ALARM_EMAIL`, `ALARM_CPU_THRESHOLD`, `ALARM_MEMORY_THRESHOLD`, `ALARM_5XX_THRESHOLD`, `OTEL_SERVICE_NAME`, `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG`.
5. THE orquestador `create-all.sh` SHALL incluir `observability/create.sh` después de `ecs/create.sh` en la cadena de ejecución.

### Requirement 17: SNS Topic para Alarmas

**User Story:** As a DevOps engineer, I want an SNS topic for alarm notifications, so that the team is alerted when infrastructure issues occur.

#### Acceptance Criteria

1. WHEN the observability create script is executed, THE script SHALL crear un SNS Topic con nombre `{env}-{app_name}-alarms`.
2. THE script SHALL crear una suscripción email al topic usando la dirección definida en `SNS_ALARM_EMAIL` de env.properties.
3. WHILE the SNS Topic already exists, THE script SHALL omitir la creación y emitir un mensaje `[SKIP]`.

### Requirement 18: CloudWatch Alarms

**User Story:** As a DevOps engineer, I want CloudWatch alarms for critical metrics, so that I am notified when the service degrades.

#### Acceptance Criteria

1. THE script SHALL crear una alarma de CPU alta del servicio ECS con threshold de `ALARM_CPU_THRESHOLD` (default: 80%), período 300s, evaluación 2 datapoints, acción → SNS Topic.
2. THE script SHALL crear una alarma de memoria alta del servicio ECS con threshold de `ALARM_MEMORY_THRESHOLD` (default: 80%), período 300s, evaluación 2 datapoints, acción → SNS Topic.
3. THE script SHALL crear una alarma de errores 5xx del ALB (métrica `HTTPCode_Target_5XX_Count`) con threshold de `ALARM_5XX_THRESHOLD` (default: 10), período 60s, evaluación 3 datapoints, acción → SNS Topic.
4. THE script SHALL crear una alarma de unhealthy hosts en el Target Group (métrica `UnHealthyHostCount`) con threshold 1, período 60s, evaluación 2 datapoints, acción → SNS Topic.
5. EACH alarma SHALL ser nombrada con el patrón `{env}-{app_name}-alarm-{metric_name}`.

### Requirement 19: Log Metric Filters

**User Story:** As a DevOps engineer, I want custom metrics extracted from application logs, so that I can alarm on application-level signals.

#### Acceptance Criteria

1. THE script SHALL crear un metric filter para contar errores HTTP 5xx en los logs (filtro sobre campo `status` >= 500 en JSON).
2. THE script SHALL crear un metric filter para extraer la latencia de requests (campo `duration_ms` del JSON).
3. EACH metric filter SHALL publicar métricas en el namespace `Multicines/{env}`.
4. EACH metric filter SHALL aplicarse al log group definido en `LOG_GROUP` de env.properties.
5. EACH metric filter SHALL ser nombrado con el patrón `{env}-{app_name}-filter-{name}`.

### Requirement 20: CloudWatch Dashboard

**User Story:** As a DevOps engineer, I want a unified dashboard showing key service metrics, so that I can monitor the health of the system at a glance.

#### Acceptance Criteria

1. THE script SHALL crear un dashboard con nombre `{env}-{app_name}-dashboard`.
2. THE dashboard SHALL incluir widgets para: CPU, Memory, Request count, 5xx error rate, Target response time, Healthy/Unhealthy hosts, custom log metrics.
3. EACH widget SHALL usar período de 5 minutos y región `us-east-1`.
4. WHEN the dashboard already exists, THE script SHALL actualizarlo (put-dashboard es idempotente).

### Requirement 21: AWS X-Ray (Sidecar ADOT Collector)

**User Story:** As a DevOps engineer, I want distributed tracing enabled via X-Ray, so that I can visualize request flows and identify latency bottlenecks.

#### Acceptance Criteria

1. WHEN `OTEL_TRACES_EXPORTER=otlp` en env.properties, THE task definition de ECS SHALL incluir un sidecar `aws-otel-collector` con imagen `public.ecr.aws/aws-observability/aws-otel-collector:latest`.
2. THE sidecar SHALL exponer puerto 4317 (gRPC OTLP) accesible por localhost desde el contenedor principal.
3. THE sidecar SHALL tener essential=false, memory 256MB, logs al mismo LOG_GROUP con stream-prefix `otel`.
4. THE contenedor principal SHALL recibir variables: `OTEL_SERVICE_NAME`, `OTEL_TRACES_EXPORTER=otlp`, `OTEL_EXPORTER_OTLP_ENDPOINT=http://localhost:4317`, `OTEL_EXPORTER_OTLP_PROTOCOL=grpc`, `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG`.
5. WHEN `OTEL_TRACES_EXPORTER=none`, THE scripts `ecs/create.sh` y `ecs/update.sh` SHALL omitir el sidecar (comportamiento actual).

### Requirement 22: Permisos IAM para X-Ray

**User Story:** As a DevOps engineer, I want the ECS task role to have X-Ray permissions, so that the ADOT collector can export traces.

#### Acceptance Criteria

1. THE task role SHALL tener permisos: `xray:PutTraceSegments`, `xray:PutTelemetryRecords`, `xray:GetSamplingRules`, `xray:GetSamplingTargets`.
2. THE módulo de observabilidad SHALL agregar una inline policy `{env}-{app_name}-xray-policy` al task role.
3. IF the policy already exists, THE script SHALL omitir la creación.
