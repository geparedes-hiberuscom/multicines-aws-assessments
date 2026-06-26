# Implementation Plan: AWS Infrastructure Multicines

## Overview

Plan de implementación para la infraestructura AWS de Multicines usando Terraform HCL. Inicia con una fase de assessment de la cuenta existente, seguida INMEDIATAMENTE del pipeline CI/CD + ECR + ECS (prioridad del cliente para tener deploys funcionando), y luego el resto de módulos de infraestructura (networking, security, VPN, ALB, SSM, observabilidad). Finaliza con scripts de importación y documentación ejecutiva.

**Orden de prioridad ajustado:**
1. Assessment (conocer el estado actual)
2. Estructura Terraform base + GitHub Actions Pipeline (CI/CD operativo)
3. SSM + Observability + ECS (servicio desplegable)
4. Environment dev (primer deploy funcional)
5. Networking, Security, VPN, ALB (infraestructura de soporte)
6. Environment prod + Import + Documentación

## Task Dependency Graph

```json
{
  "waves": [
    {"tasks": [1]},
    {"tasks": [2, 13]},
    {"tasks": [7, 8, 9]},
    {"tasks": [10]},
    {"tasks": [3]},
    {"tasks": [4, 5]},
    {"tasks": [6]},
    {"tasks": [11]},
    {"tasks": [12, 14]},
    {"tasks": [15, 16]}
  ]
}
```

## Tasks

- [x] 1. Ejecutar assessment inicial de la cuenta AWS existente y generar reporte de estado actual
  - [x] 1.1. Crear script assessment/inventory.sh que ejecute AWS CLI para listar VPCs, subnets, ECS clusters, ALBs, VPN connections, Security Groups, IAM roles, ECR repos, Route 53 zones, WAF web ACLs, ACM certificates, Secrets Manager secrets y CloudWatch Log Groups
  - [x] 1.2. Crear script assessment/audit-tags.sh que extraiga los tags actuales de cada recurso e identifique cuáles no cumplen con el estándar propuesto Project, Environment, ManagedBy, Service
  - [x] 1.3. Crear script assessment/audit-naming.sh que evalúe la nomenclatura actual de cada recurso contra el patrón multicines-servicio-ambiente-recurso
  - [x] 1.4. Crear script assessment/audit-security-groups.sh que documente las reglas de ingress y egress de todos los Security Groups existentes
  - [x] 1.5. Generar documento assessment/gap-analysis.md comparando la arquitectura actual contra la arquitectura objetivo del diagrama multicines_aws_v1.drawio, identificando recursos existentes a importar vs recursos nuevos a crear
  - [x] 1.6. Generar documento assessment/resource-ids.md con los IDs y ARNs de todos los recursos existentes necesarios para los comandos terraform import
- [x] 2. Crear estructura base del proyecto Terraform dentro de infrastructure/ y configurar backend remoto S3/DynamoDB. Todo el código Terraform (modules/, environments/, versions.tf, imports/) vive dentro de la carpeta infrastructure/ en la raíz del proyecto.
  - [x] 2.1. Crear directorio infrastructure/modules/ en la raíz del proyecto
  - [x] 2.2. Crear directorio infrastructure/environments/dev/ con archivos base main.tf, variables.tf, outputs.tf, backend.tf, terraform.tfvars
  - [x] 2.3. Crear directorio infrastructure/environments/prod/ con archivos base main.tf, variables.tf, outputs.tf, backend.tf, terraform.tfvars
  - [x] 2.4. Configurar backend.tf en dev con S3 bucket multicines-terraform-state, key dev/terraform.tfstate, DynamoDB table multicines-terraform-locks, encrypt true
  - [x] 2.5. Configurar backend.tf en prod con S3 bucket multicines-terraform-state, key prod/terraform.tfstate, DynamoDB table multicines-terraform-locks, encrypt true
  - [x] 2.6. Configurar provider AWS con default_tags en cada main.tf incluyendo tags Project=multicines, Environment=env, ManagedBy=terraform, Service=api-integration-service
  - [x] 2.7. Crear infrastructure/versions.tf con required_providers aws >= 5.0 y terraform required_version >= 1.5
- [ ] 3. Implementar módulo Networking con VPC, subnets, IGW, NAT Gateway y route tables (adaptado a CIDRs reales /24 con CIDR secundario)
  - [ ] 3.1. Crear modules/networking/main.tf con recursos aws_vpc (CIDR primario), aws_vpc_ipv4_cidr_block_association (CIDR secundario), aws_subnet public y private por AZ (bloques /26), aws_internet_gateway, aws_nat_gateway, aws_eip, aws_route_table, aws_route_table_association
  - [ ] 3.2. Crear modules/networking/variables.tf con variables project_name, environment, vpc_cidr, vpc_secondary_cidr, availability_zones, public_subnet_cidrs, private_subnet_cidrs, enable_nat_gateway
  - [ ] 3.3. Crear modules/networking/outputs.tf exponiendo vpc_id, public_subnet_ids, private_subnet_ids, private_route_table_ids, nat_gateway_ids, igw_id
  - [ ] 3.4. Implementar nomenclatura de recursos con formato project_name-environment-resource usando tags Name
  - [ ] 3.5. Configurar route tables con ruta pública 0.0.0.0/0 hacia IGW y ruta privada 0.0.0.0/0 hacia NAT Gateway
- [ ] 4. Implementar módulo Security con Security Groups y Secrets Manager
  - [ ] 4.1. Crear modules/security/main.tf con Security Groups para ALB y ECS
  - [ ] 4.2. Configurar ALB SG con ingress HTTPS 443 desde 0.0.0.0/0 y egress solo hacia ECS SG en puerto 8095
  - [ ] 4.3. Configurar ECS SG con ingress solo desde ALB SG en puerto 8095
  - [ ] 4.4. Implementar lógica condicional para ECS SG egress: si vpn_available=true permitir tráfico hacia onpremise_cidr, si false solo VPC endpoints
  - [ ] 4.5. Crear modules/security/secrets.tf con aws_secretsmanager_secret para credenciales por ambiente
  - [ ] 4.6. Crear modules/security/variables.tf con project_name, environment, vpc_id, container_port, onpremise_cidr, vpn_available
  - [ ] 4.7. Crear modules/security/outputs.tf exponiendo ecs_security_group_id, alb_security_group_id, secrets_arns
- [ ] 5. Implementar módulo VPN Site-to-Site con Virtual Private Gateway y túneles HA
  - [ ] 5.1. Crear modules/vpn/main.tf con recursos aws_vpn_gateway, aws_customer_gateway, aws_vpn_connection, aws_vpn_gateway_attachment
  - [ ] 5.2. Configurar route propagation en las route tables privadas para propagar rutas del VGW automáticamente
  - [ ] 5.3. Crear modules/vpn/variables.tf con project_name, environment, vpc_id, customer_gateway_ip, customer_gateway_bgp_asn, onpremise_cidr, private_route_table_ids
  - [ ] 5.4. Crear modules/vpn/outputs.tf exponiendo vpn_connection_id, vgw_id, tunnel1_address, tunnel2_address
- [ ] 6. Implementar módulo ALB con listeners HTTPS, WAF association y health checks
  - [ ] 6.1. Crear modules/alb/main.tf con recursos aws_lb, aws_lb_target_group, aws_lb_listener HTTPS 443 con certificado ACM
  - [ ] 6.2. Configurar target group con health check en puerto 8095, protocolo HTTP, path configurable
  - [ ] 6.3. Configurar listener HTTP 80 con redirect a HTTPS
  - [ ] 6.4. Crear asociación WAF con aws_wafv2_web_acl_association
  - [ ] 6.5. Crear modules/alb/variables.tf con project_name, environment, vpc_id, public_subnet_ids, security_group_id, certificate_arn, waf_acl_arn, health_check_port, health_check_path
  - [ ] 6.6. Crear modules/alb/outputs.tf exponiendo alb_arn, alb_dns_name, alb_arn_suffix, target_group_arn
- [ ] 7. Implementar módulo SSM Parameter Store con jerarquía por ambiente
  - [ ] 7.1. Crear modules/ssm/main.tf con recurso aws_ssm_parameter usando for_each sobre mapa de parámetros
  - [ ] 7.2. Configurar jerarquía de nombres /multicines/integrator/environment/parameter_name
  - [ ] 7.3. Incluir parámetro OTEL_TRACES_EXPORTER con valor por defecto otlp tipo String
  - [ ] 7.4. Crear modules/ssm/variables.tf con project_name, environment, parameters como map de objetos con value y type
  - [ ] 7.5. Crear modules/ssm/outputs.tf exponiendo parameter_arns y parameter_names
- [ ] 8. Implementar módulo Observability con CloudWatch Log Groups y metric alarms
  - [ ] 8.1. Crear modules/observability/main.tf con aws_cloudwatch_log_group para logs ECS con retención configurable
  - [ ] 8.2. Configurar log group name como /ecs/{environment}-multicines-integration (formato real: /ecs/dev-multicines-integration, /ecs/prod-multicines-integration)
  - [ ] 8.3. Crear CloudWatch metric alarms para ECS CPU mayor a 80%, ECS Memory mayor a 80%, ALB 5xx mayor a threshold, ALB target response time mayor a threshold
  - [ ] 8.4. Crear modules/observability/variables.tf con project_name, environment, log_retention_days, ecs_cluster_name, ecs_service_name, alb_arn_suffix
  - [ ] 8.5. Crear modules/observability/outputs.tf exponiendo log_group_arn y log_group_name
- [ ] 9. Implementar módulo ECS Fargate con task definitions, ADOT sidecar e IAM roles (usando cluster compartido existente `multicines-cluster`)
  - [ ] 9.1. Crear modules/ecs/main.tf con lógica condicional de cluster: variable create_cluster (false para usar cluster existente multicines-cluster via data source, true para crear nuevo), aws_ecs_service con network_configuration y load_balancer, capacity_provider_strategy con FARGATE y FARGATE_SPOT
  - [ ] 9.2. Crear modules/ecs/task-definition.tf con aws_ecs_task_definition conteniendo container definition del api-integration-service con puerto 8095, logConfiguration awslogs con log group /ecs/{env}-multicines-integration, secrets desde SSM con valueFrom
  - [ ] 9.3. Agregar container definition del ADOT sidecar con imagen public.ecr.aws/aws-observability/aws-otel-collector:latest y essential=false
  - [ ] 9.4. Crear modules/ecs/iam.tf con referencia a execution_role existente ecsTaskExecutionRole y task_role existente multicines-ecs-task-role (import, no crear nuevos). Agregar permisos faltantes si necesario (ecr, ssm, secretsmanager, logs, xray)
  - [ ] 9.5. Crear modules/ecs/variables.tf con project_name, environment, create_cluster, ecs_cluster_name (default multicines-cluster), ecr_repository_url (multicines/integration-service), container_image_tag, cpu, memory, desired_count, container_port, target_group_arn, private_subnet_ids, ecs_security_group_id, ssm_parameter_arns, secrets_arns, log_group_name, enable_adot_sidecar
  - [ ] 9.6. Crear modules/ecs/outputs.tf exponiendo ecs_cluster_arn, ecs_cluster_name, ecs_service_arn, ecs_service_name, task_definition_arn, task_role_arn, execution_role_arn
- [ ] 10. Configurar environment dev instanciando todos los módulos con valores de desarrollo
  - [ ] 10.1. Completar environments/dev/main.tf instanciando todos los módulos con parámetros de dev, incluyendo create_cluster=false y ecs_cluster_name=multicines-cluster en módulo ECS
  - [ ] 10.2. Configurar terraform.tfvars con aws_region=us-east-1, vpc_cidr=192.168.103.0/24, vpc_secondary_cidr=192.168.104.0/24, availability_zones=["us-east-1a","us-east-1b"], public_subnet_cidrs=["192.168.103.0/26","192.168.104.0/26"], private_subnet_cidrs=["192.168.103.64/26"], ecs_cpu=256, ecs_memory=1024, ecs_desired_count=1, log_retention_days=30, create_ecs_cluster=false, ecs_cluster_name=multicines-cluster, ecr_repository_name=multicines/integration-service
  - [ ] 10.3. Definir variables en variables.tf correspondientes a todos los inputs necesarios (incluyendo vpc_secondary_cidr, create_ecs_cluster, ecs_cluster_name, ecr_repository_name)
  - [ ] 10.4. Configurar outputs en outputs.tf con valores útiles como VPC ID, ALB DNS, ECS cluster ARN, VPN tunnel IPs
  - [ ] 10.5. Ejecutar terraform fmt y terraform validate para verificar sintaxis
- [ ] 11. Configurar environment prod instanciando todos los módulos con valores de producción
  - [ ] 11.1. Completar environments/prod/main.tf instanciando todos los módulos con parámetros de prod, incluyendo create_cluster=false y ecs_cluster_name=multicines-cluster en módulo ECS
  - [ ] 11.2. Configurar terraform.tfvars con aws_region=us-east-1, vpc_cidr=192.168.119.0/24, vpc_secondary_cidr=192.168.109.0/24, availability_zones=["us-east-1a","us-east-1b"], public_subnet_cidrs=["192.168.109.0/26","192.168.119.0/26"], private_subnet_cidrs=["192.168.109.64/26","192.168.119.64/26"], ecs_cpu=1024, ecs_memory=2048, ecs_desired_count=2, log_retention_days=90, create_ecs_cluster=false, ecs_cluster_name=multicines-cluster, ecr_repository_name=multicines/integration-service
  - [ ] 11.3. Definir variables en variables.tf correspondientes a todos los inputs necesarios (incluyendo vpc_secondary_cidr, create_ecs_cluster, ecs_cluster_name, ecr_repository_name)
  - [ ] 11.4. Configurar outputs en outputs.tf con valores útiles como VPC ID, ALB DNS, ECS cluster ARN, VPN tunnel IPs
  - [ ] 11.5. Ejecutar terraform fmt y terraform validate para verificar sintaxis
- [ ] 12. Crear scripts de importación de recursos existentes al state de Terraform basados en el assessment
  - [ ] 12.1. Crear imports/dev-import.sh con comandos terraform import para recursos existentes en dev: VPC vpc-0a5ebea8e7bee9ed5, subnets (subnet-0c92479c2831f04eb, subnet-02193c97ceb6ec25d, subnet-0eeec60453f7f9492), IGW igw-02cc91ebe8c1c22d3, NAT nat-0e87680203ca13848, SGs (sg-0fdf0c744482646ae, sg-01c619444bab0b8d3), Log Group /ecs/dev-multicines-integration
  - [ ] 12.2. Crear imports/prod-import.sh con comandos terraform import para recursos existentes en prod: VPC vpc-0860a0d2cf4df6140, subnets (subnet-04e4cd18763fd6f84, subnet-05c92a4889326c68e, subnet-0d55ebfe5adbd4e81, subnet-04f8ac3335c426f57), IGW igw-02629b250edc827d0, NATs (nat-0bb28ceef6805b2d5, nat-0bab8e961603584d4), SGs (sg-04f21c4c1d065fe60, sg-0b78c14cd02b2f6e1), Log Group /ecs/prod-multicines-integration
  - [ ] 12.3. Crear imports/shared-import.sh con comandos terraform import para recursos compartidos: ECS cluster multicines-cluster, ECR multicines/integration-service, IAM roles (ecsTaskExecutionRole, multicines-ecs-task-role, multicines-github-actions-role), OIDC Provider
  - [ ] 12.4. Documentar en comentarios el formato de IDs requeridos para cada tipo de recurso y notas sobre recursos que NO existen (ALB, VPN, WAF, ACM, Route53, Secrets, SSM — estos se CREAN, no se importan)
  - [ ] 12.5. Agregar imports/README.md explicando el proceso de importación paso a paso, diferenciando entre IMPORT y CREATE
- [x] 13. Implementar pipeline GitHub Actions con build, deploy y rollback automático
  - [x] 13.1. Crear .github/workflows/deploy.yml con job build-and-push que hace checkout, configure-aws-credentials con OIDC (role: multicines-github-actions-role), login ECR, build Docker image y push a ECR repo multicines/integration-service (tags IMMUTABLE)
  - [x] 13.2. Agregar job deploy-dev que actualiza task definition, update ECS service en cluster multicines-cluster y wait services-stable con timeout
  - [x] 13.3. Agregar job deploy-prod que requiere approval via environment protection y despliega a cluster multicines-cluster con service de prod
  - [x] 13.4. Implementar rollback: si aws ecs wait services-stable falla, revertir a task definition anterior
  - [x] 13.5. Configurar trigger con push a rama main para deploy a dev y aprobación manual para prod
  - [x] 13.6. Agregar step de verificación post-deploy con curl al health check endpoint
- [ ] 14. Crear workflows de validación y documentación del proyecto
  - [ ] 14.1. Crear .github/workflows/terraform-validate.yml que ejecute terraform fmt -check, terraform validate y tflint en cada PR
  - [ ] 14.2. Agregar checkov scan al workflow de validación para detectar issues de seguridad en IaC
  - [ ] 14.3. Crear README.md en la raíz documentando estructura del proyecto, prerequisitos y cómo ejecutar terraform plan/apply por ambiente
  - [ ] 14.4. Crear docs/standards.md documentando convención de tags y nomenclatura
- [ ] 15. Generar manual de operaciones AWS con pasos detallados de consola y documentación ejecutiva
  - [ ] 15.1. Crear docs/manual-operaciones-aws.md con secciones por componente: VPC y subnets, Internet Gateway, NAT Gateway, Security Groups, ALB, ECS Cluster y Service, Task Definitions, VPN Site-to-Site, SSM Parameter Store, Secrets Manager, CloudWatch, IAM roles
  - [ ] 15.2. Para cada componente documentar: navegación en consola AWS, pasos de creación, configuración de parámetros, verificación post-configuración y troubleshooting común
  - [ ] 15.3. Crear docs/runbook-operativo.md con procedimientos para: deploy manual sin CI/CD, rollback de task definition, troubleshooting VPN caída, escalamiento manual de ECS tasks, rotación de secretos en Secrets Manager, y revisión de logs en CloudWatch
  - [ ] 15.4. Crear docs/arquitectura-ejecutiva.md con resumen ejecutivo de 2-3 páginas para stakeholders no técnicos incluyendo descripción de la solución, beneficios, estimación de costos mensuales AWS y roadmap de evolución
  - [ ] 15.5. Crear docs/estandares-infraestructura.md con convenciones de tags obligatorios, patrón de nomenclatura, políticas de Security Groups, políticas IAM least privilege y mejores prácticas adoptadas del Well-Architected Framework
  - [ ] 15.6. Crear docs/index.md como índice general que vincule todos los documentos del paquete de entrega
- [ ] 16. Generar diagramas de arquitectura actualizados en formato draw.io
  - [ ] 16.1. Crear docs/diagramas/multicines-aws-final.drawio con el diagrama de arquitectura completo final reflejando todos los componentes implementados, flujos de datos y conexiones entre servicios
  - [ ] 16.2. Crear docs/diagramas/flujo-deploy.drawio con el diagrama del pipeline CI/CD mostrando cada stage desde push a main hasta deploy en prod con rollback
  - [ ] 16.3. Crear docs/diagramas/flujo-red.drawio con el diagrama detallado de networking mostrando subnets, route tables, NAT, IGW, VPN tunnels y Security Groups
  - [ ] 16.4. Actualizar el diagrama base multicines_aws_v1.drawio con las correcciones y mejoras identificadas durante el assessment

## Notes

- **Estructura del proyecto:** Todo el código Terraform (modules/, environments/, versions.tf, imports/) vive dentro de la carpeta `infrastructure/` en la raíz del proyecto. Los módulos se referencian con `source = "../../modules/..."` desde los environments.
- La Task 1 (Assessment) genera los insumos necesarios para la Task 12 (Import Scripts) — los IDs y ARNs de recursos existentes
- Los valores de CIDR del on-premise y la IP del Customer Gateway deben ser proporcionados por el equipo de redes de Multicines antes de ejecutar los módulos VPN
- El bucket S3 y la tabla DynamoDB para el state remoto deben crearse manualmente o con un script bootstrap previo a la ejecución de Terraform
- Los scripts de assessment requieren AWS CLI configurado con permisos de lectura sobre la cuenta de Multicines
- Las Tasks 15 y 16 (documentación) se ejecutan al final cuando toda la infraestructura está definida, para reflejar el estado final completo
- El manual de operaciones (Task 15) se basa en el documento existente "Insumos iniciales/Manual para multicines.docx" que debe ser actualizado con la arquitectura final
- **Assessment completado (2026-06-24):** Los CIDRs reales son 192.168.x.0/24 (NO 10.x.0.0/16). El cluster ECS `multicines-cluster` es compartido (1 solo cluster, 0 servicios). El ECR repo es `multicines/integration-service` (IMMUTABLE). No existen ALB, VPN, WAF, ACM, Route 53, Secrets, SSM — estos deben CREARSE. Los IAM roles existentes usan nombres genéricos (ecsTaskExecutionRole, multicines-ecs-task-role). Los log groups existentes son `/ecs/dev-multicines-integration` y `/ecs/prod-multicines-integration`.
- **Security Group CRITICAL:** `prod-sg-vpn` (sg-0bd705b1fd4514783) en VPC default tiene ALL traffic from 0.0.0.0/0 — debe eliminarse o restringirse inmediatamente (no está asociado a ninguna VPN real)
