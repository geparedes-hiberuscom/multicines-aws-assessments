# Implementation Plan: Scripts AWS CLI para Despliegue Multicines

## Overview

Implementación de scripts AWS CLI idempotentes para provisionar, actualizar y eliminar la infraestructura Multicines (ALB, VPN, WAF, ACM, SSM, Secrets Manager, SG hardening, ECS Services, Route53, Observabilidad) más un pipeline de documentación y workflows de GitHub Actions para CI/CD automatizado. Los scripts usan Bash con estructura modular por servicio en `aws-cli/`, configuración externalizada en `environments/{env}/env.properties`, y librería compartida en `aws-cli/lib/common.sh`.

## Tasks

- [x] 1. Librería compartida y configuración de ambientes
  - [x] 1.1 Crear `aws-cli/lib/common.sh` con funciones compartidas
    - Implementar `validate_env()` para validar ambiente (dev|prod)
    - Implementar funciones de logging: `log_info`, `log_error`, `log_skip`, `log_created`, `log_deleted`, `log_updated`
    - Implementar `load_env()` que source env.properties y deriva nombres (`ALB_NAME`, `ECS_TG_NAME`, `ECS_SERVICE_NAME`, `ECS_TASK_FAMILY`, `WAF_NAME`, `VPN_NAME`, `VGW_NAME`, `CGW_NAME`, `ACM_NAME`, `ECR_URI`)
    - Implementar `generate_name()` con patrón `{env}-{resource}-{type}[-{zone}]`
    - Implementar `check_exists()` para verificación idempotente de recursos
    - Implementar `require_resource()` para validación fail-fast de dependencias
    - Implementar tres formatos de tags: `get_tags()` (Key=Value), `get_ecs_tags()` (key=value), `get_tag_spec()` (JSON-like para EC2)
    - Implementar `get_certs_dir()` helper para path de certificados
    - _Requisitos: 2.1, 2.4, 2.5, 2.6, 3.7, 3.8, 13.6_

  - [x] 1.2 Crear `aws-cli/environments/dev/env.properties` con configuración dev
    - Definir APP_NAME, PROJECT_NAME, AWS_ACCOUNT, AWS_REGION
    - Definir VPC_ID, PUBLIC_SUBNETS, PRIVATE_SUBNETS, ALB_SG_ID, ECS_SG_ID
    - Definir DOMAIN (wildcard), ALB_SSL_POLICY (TLS 1.3)
    - Definir ECS_CLUSTER, ECS_CPU (512), ECS_MEMORY (1024), ECS_DESIRED_COUNT, ECS_IMAGE_TAG, ECS_ENABLE_EXEC
    - Definir CONTAINER_PORT, CONTAINER_NAME, HEALTH_CHECK_PATH, HEALTH_CHECK_PORT
    - Definir variables OTEL, LOG_GROUP, roles IAM, WAF_RATE_LIMIT, VPN placeholders
    - _Requisitos: 2.2, 2.3_

  - [x] 1.3 Crear `aws-cli/environments/prod/env.properties` con configuración prod
    - Misma estructura que dev con valores de producción
    - _Requisitos: 2.2, 2.3_

- [x] 2. Scripts orquestadores
  - [x] 2.1 Crear `aws-cli/create-all.sh` — orquestador de creación
    - Source common.sh, aceptar parámetro ambiente
    - Invocar módulos en orden: acm → waf → security-groups → alb → route53 → ssm → secrets → ecs → vpn
    - Detener ejecución al primer fallo con exit code non-zero
    - _Requisitos: 1.3, 1.6_

  - [x] 2.2 Crear `aws-cli/update-all.sh` — orquestador de actualización
    - Invocar módulos actualizables: ssm → secrets → security-groups → waf → ecs → acm
    - Continuar ejecución si un módulo falla (log error y seguir)
    - _Requisitos: 1.4, 1.6_

  - [x] 2.3 Crear `aws-cli/delete-all.sh` — orquestador de eliminación
    - Solicitar confirmación destructiva explícita ("yes")
    - Invocar módulos en orden inverso: vpn → ecs → secrets → ssm → route53 → alb → security-groups → waf → acm
    - _Requisitos: 1.5, 1.6_

  - [x] 2.4 Crear `aws-cli/validate-env.sh` — validación de pre-requisitos
    - Verificar existencia de VPC, subnets, SGs, log groups, cluster, ECR, roles IAM
    - Reportar estado de recursos a crear (ALB, TG, WAF, ACM, ECS Service)
    - Emitir resumen OK/MISSING con exit code 1 si hay faltantes
    - _Requisitos: 1.8_

- [x] 3. Módulo ACM (certificados SSL)
  - [x] 3.1 Crear `aws-cli/acm/create.sh`
    - Validar existencia de archivos de certificado en `environments/{env}/certs/`
    - Verificar si certificado ya existe por dominio via `aws acm list-certificates`
    - Importar certificado con `aws acm import-certificate` (certificate.pem, private-key.pem, certificate-chain.pem)
    - Aplicar tags con `get_tags()`
    - _Requisitos: 9.1, 9.2, 9.3_

  - [x] 3.2 Crear `aws-cli/acm/update.sh` y `aws-cli/acm/delete.sh`
    - Update: re-importar certificado
    - Delete: eliminar certificado por ARN
    - _Requisitos: 1.2_

- [x] 4. Módulo WAF (Web Application Firewall)
  - [x] 4.1 Crear `aws-cli/waf/create.sh`
    - Crear WAF Web ACL scope REGIONAL con default action Allow
    - Agregar regla rate-based (WAF_RATE_LIMIT req/5min por IP, action Block)
    - Asociar WAF al ALB si existe (skip informativo si no)
    - Aplicar tags con `get_tags()`
    - _Requisitos: 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 4.2 Crear `aws-cli/waf/update.sh` y `aws-cli/waf/delete.sh`
    - Update: actualizar reglas y re-asociar
    - Delete: desasociar de ALB y eliminar Web ACL
    - _Requisitos: 1.2_

- [x] 5. Módulo Security Groups (hardening)
  - [x] 5.1 Crear `aws-cli/security-groups/create.sh`
    - Validar dependencias con `require_resource` (ALB SG, ECS SG)
    - ALB SG: revocar egress 0.0.0.0/0 all-traffic, agregar egress TCP → ECS SG:CONTAINER_PORT
    - ECS SG: revocar egress 0.0.0.0/0 all-traffic, agregar egress TCP → 0.0.0.0/0:443
    - Idempotencia: verificar cada regla individual antes de modificar
    - _Requisitos: 12.1, 12.2, 12.3, 12.4, 12.5_

  - [x] 5.2 Crear `aws-cli/security-groups/update.sh` y `aws-cli/security-groups/delete.sh`
    - Update: re-aplicar hardening
    - Delete: restaurar regla permisiva all-traffic
    - _Requisitos: 1.2_

- [x] 6. Módulo ALB (Application Load Balancer)
  - [x] 6.1 Crear `aws-cli/alb/create.sh`
    - Fail-fast: validar certificado ACM existe antes de crear cualquier recurso
    - Validar dependencia ALB SG con `require_resource`
    - Crear ALB tipo application, internet-facing, en PUBLIC_SUBNETS con ALB_SG_ID
    - Crear Target Group tipo ip, puerto CONTAINER_PORT, health check (timeout:10s, healthy:2, unhealthy:5, interval:30s)
    - Crear Listener HTTPS:443 con SSL policy `ELBSecurityPolicy-TLS13-1-2-2021-06`, forward a TG
    - Crear Listener HTTP:80 redirect → HTTPS (301)
    - Aplicar tags con `get_tags()`
    - _Requisitos: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [x] 6.2 Crear `aws-cli/alb/update.sh` y `aws-cli/alb/delete.sh`
    - Update: actualizar health check del Target Group
    - Delete: eliminar listeners, TG y ALB
    - _Requisitos: 4.7, 1.2_

- [x] 7. Módulo Route53 (DNS)
  - [x] 7.1 Crear `aws-cli/route53/create.sh`
    - Extraer base domain de wildcard DOMAIN (`*.test.multicines.com.ec` → `test.multicines.com.ec`)
    - Validar dependencia ALB con `require_resource`
    - Crear hosted zone si no existe
    - Crear registro alias tipo A: `{env}-integration.{base_domain}` → ALB DNS (UPSERT)
    - Emitir nameservers de delegación al crear nueva zona
    - _Requisitos: 6.1, 6.2, 6.3, 6.4, 6.5, 6.6_

  - [x] 7.2 Crear `aws-cli/route53/update.sh` y `aws-cli/route53/delete.sh`
    - Update: invocar create (UPSERT es idempotente)
    - Delete: eliminar registro y hosted zone
    - _Requisitos: 1.2_

- [x] 8. Módulo SSM Parameter Store
  - [x] 8.1 Crear `aws-cli/ssm/create.sh`
    - Leer `environments/{env}/secrets/secrets.txt` parseando bloques key/value JSON
    - Crear parámetros bajo `/multicines/integrator/{env}/` como SecureString (JSON compactado con python3)
    - Crear parámetro fijo `OTEL_TRACES_EXPORTER` como String con valor "otlp"
    - Verificar existencia antes de crear cada parámetro
    - Aplicar tags con `get_tags()`
    - _Requisitos: 10.1, 10.2, 10.3, 10.4, 10.5_

  - [x] 8.2 Crear `aws-cli/ssm/update.sh` y `aws-cli/ssm/delete.sh`
    - Update: actualizar valores de parámetros existentes
    - Delete: eliminar parámetros por path
    - _Requisitos: 1.2_

- [x] 9. Módulo Secrets Manager
  - [x] 9.1 Crear `aws-cli/secrets/create.sh`
    - Leer `environments/{env}/secrets/secrets.txt` (mismo formato que SSM)
    - Nombre del secreto = key completa del archivo
    - Verificar existencia con `aws secretsmanager describe-secret`
    - Compactar JSON con python3 antes de almacenar
    - Aplicar tags con `get_tags()`
    - _Requisitos: 11.1, 11.2, 11.3_

  - [x] 9.2 Crear `aws-cli/secrets/update.sh` y `aws-cli/secrets/delete.sh`
    - Update: actualizar valor del secreto
    - Delete: eliminar secreto (force-delete-without-recovery)
    - _Requisitos: 1.2_

- [x] 10. Módulo ECS (Elastic Container Service)
  - [x] 10.1 Crear `aws-cli/ecs/create.sh`
    - Validar dependencias: TG, Execution Role, Task Role, ECR Image, Log Group
    - Registrar Task Definition (awsvpc, FARGATE, CPU/Memory de env.properties, OTEL vars, awslogs)
    - Aplicar tags ECS con `get_ecs_tags()`
    - Manejar estado DRAINING (esperar en loop)
    - Crear Service en cluster multicines-cluster, FARGATE, private subnets, ECS SG
    - Health check grace period: 210 segundos
    - Enable execute command cuando ECS_ENABLE_EXEC=true
    - Registrar en Target Group del ALB
    - _Requisitos: 5.1, 5.2, 5.3, 5.4, 5.5, 5.6, 5.8_

  - [x] 10.2 Crear `aws-cli/ecs/update.sh`
    - Registrar nueva revisión de Task Definition
    - Update service con nueva TD + health-check-grace-period-seconds 210
    - Habilitar execute-command si ECS_ENABLE_EXEC=true
    - Esperar estabilidad con `aws ecs wait services-stable`
    - _Requisitos: 5.7_

  - [x] 10.3 Crear `aws-cli/ecs/delete.sh`
    - Actualizar desired-count a 0, eliminar servicio, deregister task definitions
    - _Requisitos: 1.2_

- [x] 11. Módulo VPN (Site-to-Site)
  - [x] 11.1 Crear `aws-cli/vpn/create.sh`
    - Validar dependencia VPC con `require_resource`
    - Emitir advertencia si VPN_CUSTOMER_IP=0.0.0.0 (placeholder)
    - Crear Customer Gateway tipo ipsec.1 con IP y ASN de env.properties
    - Crear Virtual Private Gateway tipo ipsec.1 y attach a VPC
    - Crear VPN Connection tipo ipsec.1 asociando CGW + VGW
    - Habilitar route propagation en route tables privadas
    - Aplicar tags con `get_tag_spec()` (formato EC2 tag-specifications)
    - Nombrar: `{env}-{app_name}-cgw`, `{env}-{app_name}-vgw`, `{env}-{app_name}-vpn`
    - _Requisitos: 7.1, 7.2, 7.3, 7.4, 7.5, 7.6, 7.7_

  - [x] 11.2 Crear `aws-cli/vpn/update.sh` y `aws-cli/vpn/delete.sh`
    - Update: actualizar configuración VPN
    - Delete: eliminar VPN connection, detach + delete VGW, delete CGW
    - _Requisitos: 1.2_

- [x] 12. Pipeline de documentación
  - [x] 12.1 Crear `aws-cli/convert-manual.sh`
    - Verificar disponibilidad de Pandoc
    - Convertir "Insumos iniciales/Manual para multicines.docx" → `documents/manual-original.md`
    - Extraer imágenes a `documents/images/`
    - _Requisitos: 14.1, 14.2_

  - [x] 12.2 Crear `aws-cli/documents/sections/` con secciones de documentación por recurso
    - Secciones para: ALB, VPN, WAF, ACM, SSM, Secrets Manager, ECS, Security Groups
    - _Requisitos: 14.3_

  - [x] 12.3 Crear `aws-cli/build-manual.sh`
    - Verificar Pandoc y existencia de manual-original.md
    - Concatenar manual-original.md + sections/*.md → manual-multicines.md
    - Exportar a DOCX con `--resource-path` para resolución de imágenes
    - _Requisitos: 14.4, 14.5, 14.6_

- [x] 13. GitHub Actions CI/CD
  - [x] 13.1 Crear workflow `deploy-dev.yml`
    - Trigger: push a rama `dev` + workflow_dispatch
    - Permisos: id-token write (OIDC), contents read
    - Autenticación: aws-actions/configure-aws-credentials@v4 con role-to-assume
    - Build: Docker build + tag `{env}-{short_sha}` y `{version}-{short_sha}`
    - Push: imagen a ECR
    - Deploy: download TD → render image → aws-actions/amazon-ecs-deploy-task-definition@v2 (wait-for-service-stability: true, 10 min)
    - Rollback: on failure, restore previous TD + force-new-deployment + wait stable
    - Verify: confirmar tareas RUNNING
    - _Requisitos: 15.1, 15.3, 15.4, 15.5, 15.6, 15.7_

  - [x] 13.2 Crear workflow `deploy-prod.yml`
    - Trigger: push a rama `main` + workflow_dispatch
    - Misma estructura que dev con environment production
    - Verificación: confirmar ≥2 tareas running
    - _Requisitos: 15.2, 15.3, 15.4, 15.5, 15.6, 15.7_

## Notes

- Todos los scripts usan `set -euo pipefail` para fallo inmediato
- Cada módulo sigue el patrón: source common.sh → load_env → require_resource → check_exists → create/skip
- Los scripts son ejecutables de forma independiente o via orquestador
- Configuración 100% externalizada en env.properties (cero hardcoding en scripts)
- Los workflows de GitHub Actions residen en el repositorio del servicio (Capa-Media), no en este repositorio
- Pandoc es requerido para el pipeline de documentación
- Los archivos de certificados y secrets NO se versionan en git

## Task Dependency Graph

```json
{
  "waves": [
    { "id": 0, "tasks": ["1.1", "1.2", "1.3"] },
    { "id": 1, "tasks": ["2.1", "2.2", "2.3", "2.4"] },
    { "id": 2, "tasks": ["3.1", "3.2"] },
    { "id": 3, "tasks": ["4.1", "4.2", "5.1", "5.2"] },
    { "id": 4, "tasks": ["6.1", "6.2"] },
    { "id": 5, "tasks": ["7.1", "7.2"] },
    { "id": 6, "tasks": ["8.1", "8.2", "9.1", "9.2"] },
    { "id": 7, "tasks": ["10.1", "10.2", "10.3"] },
    { "id": 8, "tasks": ["11.1", "11.2"] },
    { "id": 9, "tasks": ["12.1", "12.2", "12.3"] },
    { "id": 10, "tasks": ["13.1", "13.2"] },
    { "id": 11, "tasks": ["14.1", "14.2"] },
    { "id": 12, "tasks": ["14.3", "18.1"] },
    { "id": 13, "tasks": ["15.1", "15.2", "15.3", "15.4"] },
    { "id": 14, "tasks": ["16.1", "16.2"] },
    { "id": 15, "tasks": ["17.1"] },
    { "id": 16, "tasks": ["19.1", "19.2"] },
    { "id": 17, "tasks": ["20.1", "20.2", "20.3"] }
  ]
}
```

- [x] 14. Módulo Observabilidad — Configuración y SNS
  - [x] 14.1 Actualizar `environments/dev/env.properties` con variables de observabilidad
    - Agregar: SNS_ALARM_EMAIL, ALARM_CPU_THRESHOLD=80, ALARM_MEMORY_THRESHOLD=80, ALARM_5XX_THRESHOLD=10
    - Cambiar: OTEL_TRACES_EXPORTER de "none" a "otlp"
    - Agregar: OTEL_SERVICE_NAME=integrator, OTEL_TRACES_SAMPLER=parentbased_traceidratio, OTEL_TRACES_SAMPLER_ARG=1.0
    - _Requisitos: 16.4, 21.5_

  - [x] 14.2 Actualizar `environments/prod/env.properties` con variables de observabilidad
    - Mismas variables que dev pero OTEL_TRACES_SAMPLER_ARG=0.10 (10% muestreo)
    - _Requisitos: 16.4, 21.5_

  - [x] 14.3 Crear `aws-cli/observability/create.sh` — sección SNS Topic
    - Source common.sh, load_env, validar ambiente
    - Verificar si topic `{env}-{app_name}-alarms` existe con `aws sns list-topics`
    - Crear topic y suscripción email con SNS_ALARM_EMAIL
    - _Requisitos: 16.1, 16.2, 17.1, 17.2, 17.3_

- [x] 15. Módulo Observabilidad — CloudWatch Alarms
  - [x] 15.1 Agregar alarma CPU alta en `observability/create.sh`
    - Métrica: AWS/ECS CPUUtilization, dimensions: ServiceName + ClusterName
    - Threshold: ALARM_CPU_THRESHOLD, period 300s, eval 2 datapoints
    - Acción: SNS_ARN del topic creado
    - Nombre: `{env}-{app_name}-alarm-cpu-high`
    - _Requisitos: 18.1, 18.5_

  - [x] 15.2 Agregar alarma Memory alta en `observability/create.sh`
    - Métrica: AWS/ECS MemoryUtilization, dimensions: ServiceName + ClusterName
    - Threshold: ALARM_MEMORY_THRESHOLD, period 300s, eval 2 datapoints
    - Nombre: `{env}-{app_name}-alarm-memory-high`
    - _Requisitos: 18.2, 18.5_

  - [x] 15.3 Agregar alarma 5xx del ALB en `observability/create.sh`
    - Métrica: AWS/ApplicationELB HTTPCode_Target_5XX_Count, dimensions: LoadBalancer
    - Threshold: ALARM_5XX_THRESHOLD, period 60s, eval 3 datapoints
    - Nombre: `{env}-{app_name}-alarm-5xx`
    - _Requisitos: 18.3, 18.5_

  - [x] 15.4 Agregar alarma Unhealthy Hosts en `observability/create.sh`
    - Métrica: AWS/ApplicationELB UnHealthyHostCount, dimensions: TargetGroup + LoadBalancer
    - Threshold: 1, period 60s, eval 2 datapoints
    - Nombre: `{env}-{app_name}-alarm-unhealthy-hosts`
    - _Requisitos: 18.4, 18.5_

- [x] 16. Módulo Observabilidad — Log Metric Filters
  - [x] 16.1 Crear metric filter para errores 5xx en `observability/create.sh`
    - Filter pattern: `{ $.status >= 500 }`
    - Metric namespace: Multicines/{env}, metric name: 5xxErrors
    - Log group: LOG_GROUP de env.properties
    - Nombre: `{env}-{app_name}-filter-5xx-errors`
    - _Requisitos: 19.1, 19.3, 19.4, 19.5_

  - [x] 16.2 Crear metric filter para latencia en `observability/create.sh`
    - Filter pattern: `{ $.duration_ms = * }`
    - Metric namespace: Multicines/{env}, metric name: Latency, metric value: $.duration_ms
    - Nombre: `{env}-{app_name}-filter-latency`
    - _Requisitos: 19.2, 19.3, 19.4, 19.5_

- [x] 17. Módulo Observabilidad — Dashboard
  - [x] 17.1 Crear CloudWatch Dashboard en `observability/create.sh`
    - Nombre: `{env}-{app_name}-dashboard`
    - Widgets JSON: CPU, Memory, Request Count, 5xx Rate, Response Time, Healthy/Unhealthy, custom metrics
    - Usar `aws cloudwatch put-dashboard` (idempotente por diseño)
    - _Requisitos: 20.1, 20.2, 20.3, 20.4_

- [x] 18. Módulo Observabilidad — X-Ray IAM Policy
  - [x] 18.1 Agregar inline policy X-Ray al task role en `observability/create.sh`
    - Policy name: `{env}-{app_name}-xray-policy`
    - Acciones: xray:PutTraceSegments, xray:PutTelemetryRecords, xray:GetSamplingRules, xray:GetSamplingTargets
    - Verificar existencia antes de crear con `aws iam get-role-policy`
    - _Requisitos: 22.1, 22.2, 22.3_

- [x] 19. Actualizar ECS con sidecar ADOT
  - [x] 19.1 Modificar `ecs/create.sh` — agregar lógica condicional de sidecar
    - IF OTEL_TRACES_EXPORTER=otlp THEN agregar container `aws-otel-collector` al JSON
    - Sidecar: image public.ecr.aws/aws-observability/aws-otel-collector:latest, essential=false, memory 256, port 4317, logs con prefix "otel"
    - Agregar variables OTEL completas al contenedor principal: OTEL_SERVICE_NAME, OTEL_EXPORTER_OTLP_ENDPOINT, OTEL_EXPORTER_OTLP_PROTOCOL, OTEL_TRACES_SAMPLER, OTEL_TRACES_SAMPLER_ARG
    - _Requisitos: 21.1, 21.2, 21.3, 21.4, 21.5_

  - [x] 19.2 Modificar `ecs/update.sh` — misma lógica condicional de sidecar
    - Replicar lógica de create.sh para la generación del JSON de task definition
    - _Requisitos: 21.5_

- [x] 20. Completar módulo observabilidad
  - [x] 20.1 Crear `aws-cli/observability/update.sh`
    - Actualizar alarmas (put-metric-alarm es idempotente — se puede re-ejecutar)
    - Actualizar dashboard y metric filters
    - _Requisitos: 16.1_

  - [x] 20.2 Crear `aws-cli/observability/delete.sh`
    - Eliminar dashboard, alarmas, metric filters, inline policy, SNS topic + suscripción
    - _Requisitos: 16.1_

  - [x] 20.3 Actualizar `create-all.sh` para incluir `observability/create.sh` después de ecs
    - _Requisitos: 16.5_
