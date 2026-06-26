# Requirements Document

## Introduction

Este documento define los requisitos para la implementación de Infraestructura como Código (IaC) con Terraform HCL para gestionar la infraestructura AWS de Multicines. El proyecto cubre la importación de recursos existentes al state de Terraform, la estandarización de nombres y tags, y la implementación de mejoras en networking, cómputo, configuración, observabilidad, seguridad y CI/CD para el servicio api-integration-service.

## Glossary

- **Plataforma_Terraform**: Conjunto de módulos Terraform HCL que definen y gestionan la infraestructura AWS de Multicines, incluyendo state remoto en S3 con DynamoDB locking
- **VPC_Dev**: Virtual Private Cloud del ambiente de desarrollo con 1 Availability Zone
- **VPC_Prod**: Virtual Private Cloud del ambiente de producción con 2 Availability Zones (AZ-A y AZ-B)
- **ECS_Service**: Servicio AWS ECS Fargate que ejecuta el contenedor api-integration-service
- **ALB**: Application Load Balancer que distribuye tráfico hacia las tasks de ECS Fargate
- **VPN_Connection**: Conexión VPN Site-to-Site entre AWS y el datacenter on-premise de Multicines mediante Virtual Private Gateway con 2 túneles HA
- **SSM_Parameter_Store**: Servicio AWS Systems Manager Parameter Store para almacenar variables de configuración por ambiente
- **Pipeline_CICD**: Pipeline de GitHub Actions que construye, publica y despliega el api-integration-service
- **Vista_API_Connect**: API on-premise (IIS 10 + WCF/.svc) alojada en el datacenter de Multicines
- **ADOT_Collector**: AWS Distro for OpenTelemetry Collector para envío de trazas distribuidas a X-Ray
- **Task_Definition**: Definición de tarea ECS Fargate que especifica imagen, recursos, variables de entorno y configuración del contenedor

## Requirements

### Requirement 1: Assessment Inicial de la Cuenta AWS

**User Story:** Como arquitecto de soluciones, quiero un diagnóstico completo del estado actual de la cuenta AWS de Multicines, para identificar recursos existentes, gaps, y oportunidades de estandarización antes de implementar IaC.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL generar un inventario de todos los recursos AWS existentes en la cuenta, incluyendo VPCs, subnets, ECS clusters, ALBs, VPN connections, Security Groups, IAM roles, ECR repositories, Route 53 zones, WAF rules, ACM certificates, Secrets Manager secrets y CloudWatch Log Groups
2. THE Plataforma_Terraform SHALL documentar los tags actuales de cada recurso existente e identificar cuáles no cumplen con el estándar propuesto (Project, Environment, ManagedBy, Service)
3. THE Plataforma_Terraform SHALL documentar la nomenclatura actual de cada recurso e identificar cuáles no siguen el patrón estándar {proyecto}-{servicio}-{ambiente}-{recurso}
4. THE Plataforma_Terraform SHALL generar un reporte de gaps comparando la arquitectura actual contra la arquitectura objetivo definida en el diagrama multicines_aws_v1.drawio
5. THE Plataforma_Terraform SHALL identificar qué recursos necesitan ser importados al state de Terraform (existentes) y cuáles necesitan ser creados desde cero (nuevos)
6. THE Plataforma_Terraform SHALL documentar la configuración actual de Security Groups incluyendo reglas de ingress y egress para planificar las reglas de seguridad objetivo
7. THE Plataforma_Terraform SHALL documentar los IDs y ARNs de todos los recursos existentes necesarios para los comandos terraform import

### Requirement 2: Estructura del Proyecto Terraform

**User Story:** Como ingeniero DevOps, quiero una estructura de proyecto Terraform modular y organizada, para poder gestionar ambientes de forma independiente con código reutilizable.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL organizar el código en módulos compartidos reutilizables ubicados en un directorio `modules/` en la raíz del proyecto
2. THE Plataforma_Terraform SHALL definir la configuración específica del ambiente de desarrollo en el directorio `environments/dev/`
3. THE Plataforma_Terraform SHALL definir la configuración específica del ambiente de producción en el directorio `environments/prod/`
4. THE Plataforma_Terraform SHALL almacenar el state remoto en un bucket S3 con DynamoDB locking para cada ambiente
5. THE Plataforma_Terraform SHALL utilizar Terraform HCL versión 1.x como lenguaje de definición de infraestructura

### Requirement 3: Importación de Recursos Existentes

**User Story:** Como ingeniero DevOps, quiero importar los recursos AWS existentes al state de Terraform, para poder gestionar la infraestructura actual sin recrear recursos.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL importar la zona hosted de Route 53 para el dominio apimulticines.com al state de Terraform
2. THE Plataforma_Terraform SHALL importar la configuración de AWS WAF (reglas de rate limit e IP allowlist) al state de Terraform
3. THE Plataforma_Terraform SHALL importar el certificado ACM wildcard al state de Terraform
4. THE Plataforma_Terraform SHALL importar los roles IAM y el OIDC Provider existentes al state de Terraform
5. THE Plataforma_Terraform SHALL importar el repositorio ECR del api-integration-service al state de Terraform
6. THE Plataforma_Terraform SHALL importar las VPCs, subnets, Internet Gateways y NAT Gateways existentes al state de Terraform
7. THE Plataforma_Terraform SHALL importar los servicios ECS Fargate, ALBs y sus target groups existentes al state de Terraform
8. THE Plataforma_Terraform SHALL importar los secretos de Secrets Manager existentes al state de Terraform
9. THE Plataforma_Terraform SHALL importar las conexiones VPN Site-to-Site existentes al state de Terraform

### Requirement 4: Estandarización de Tags y Nombres

**User Story:** Como ingeniero DevOps, quiero que todos los recursos tengan tags y nombres estandarizados según AWS best practices, para facilitar la gestión, facturación y auditoría.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL asignar a cada recurso los tags obligatorios: `Project`, `Environment`, `ManagedBy`, y `Service`
2. THE Plataforma_Terraform SHALL asignar el valor "multicines" al tag `Project` en todos los recursos
3. THE Plataforma_Terraform SHALL asignar el valor "dev" o "prod" al tag `Environment` según el ambiente correspondiente
4. THE Plataforma_Terraform SHALL asignar el valor "terraform" al tag `ManagedBy` en todos los recursos
5. THE Plataforma_Terraform SHALL utilizar un patrón de nomenclatura consistente en formato `{proyecto}-{servicio}-{ambiente}-{recurso}` para los nombres de recursos
6. THE Plataforma_Terraform SHALL aplicar tags mediante un módulo de default_tags para garantizar consistencia en todos los recursos

### Requirement 5: Networking - VPC y Subnets

**User Story:** Como ingeniero DevOps, quiero que la topología de red esté correctamente definida en Terraform, para mantener la separación de ambientes y la alta disponibilidad en producción.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL definir VPC_Dev con 1 Availability Zone conteniendo una subnet pública y una subnet privada
2. THE Plataforma_Terraform SHALL definir VPC_Prod con 2 Availability Zones (AZ-A y AZ-B) conteniendo subnets públicas y privadas en cada AZ
3. THE Plataforma_Terraform SHALL configurar un Internet Gateway en cada VPC para permitir tráfico de entrada desde Internet
4. THE Plataforma_Terraform SHALL configurar un NAT Gateway en la subnet pública de VPC_Dev para permitir tráfico de salida desde la subnet privada
5. THE Plataforma_Terraform SHALL configurar NAT Gateways en las subnets públicas de VPC_Prod para permitir tráfico de salida desde las subnets privadas

### Requirement 6: VPN Site-to-Site

**User Story:** Como ingeniero DevOps, quiero configurar conexiones VPN Site-to-Site entre AWS y el datacenter on-premise, para que las tasks ECS puedan comunicarse con Vista API Connect de forma segura.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL configurar una VPN_Connection en VPC_Dev con un Virtual Private Gateway y 2 túneles HA hacia el datacenter de Multicines
2. THE Plataforma_Terraform SHALL configurar una VPN_Connection en VPC_Prod con un Virtual Private Gateway y 2 túneles HA hacia el datacenter de Multicines
3. THE Plataforma_Terraform SHALL definir las rutas en las tablas de enrutamiento de las subnets privadas para dirigir tráfico hacia el CIDR on-premise a través del Virtual Private Gateway
4. WHEN la VPN_Connection está disponible, THE Plataforma_Terraform SHALL configurar las reglas de Security Group de las tasks ECS para permitir tráfico de salida únicamente hacia el CIDR on-premise por el puerto de Vista_API_Connect

### Requirement 7: Application Load Balancer

**User Story:** Como ingeniero DevOps, quiero que los ALBs estén configurados correctamente en ambos ambientes, para distribuir tráfico de forma segura hacia las tasks ECS.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL configurar un ALB en VPC_Dev con nodo en la subnet pública de AZ-A y 1 IP pública
2. THE Plataforma_Terraform SHALL configurar un ALB en VPC_Prod con nodos en las subnets públicas de AZ-A y AZ-B con 2 IPs públicas
3. THE Plataforma_Terraform SHALL asociar el certificado ACM wildcard a los listeners HTTPS (puerto 443) de cada ALB
4. THE Plataforma_Terraform SHALL asociar AWS WAF a cada ALB para aplicar reglas de rate limiting e IP allowlist
5. THE Plataforma_Terraform SHALL configurar target groups con health checks apuntando al puerto 8095 de las tasks ECS

### Requirement 8: ECS Fargate

**User Story:** Como ingeniero DevOps, quiero que el servicio ECS Fargate esté dimensionado correctamente por ambiente, para garantizar rendimiento adecuado y eficiencia de costos.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL configurar el ECS_Service en VPC_Dev con 1 task Fargate de 0.5 vCPU y 1 GB de memoria
2. THE Plataforma_Terraform SHALL configurar el ECS_Service en VPC_Prod con un desired_count de 2 tasks Fargate distribuidas entre AZ-A y AZ-B
3. THE Plataforma_Terraform SHALL asignar 1 vCPU y 2 GB de memoria a cada task Fargate en VPC_Prod
4. THE Plataforma_Terraform SHALL configurar las Task_Definitions para exponer el contenedor en el puerto 8095
5. THE Plataforma_Terraform SHALL configurar las Task_Definitions para obtener la imagen del contenedor desde el repositorio ECR del api-integration-service

### Requirement 9: SSM Parameter Store

**User Story:** Como ingeniero DevOps, quiero gestionar las variables de configuración de la aplicación en SSM Parameter Store, para centralizar la configuración y evitar secretos hardcodeados en Task Definitions.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL crear el parámetro SSM `/multicines/integrator/dev/OTEL_TRACES_EXPORTER` para el ambiente de desarrollo
2. THE Plataforma_Terraform SHALL crear el parámetro SSM `/multicines/integrator/prod/OTEL_TRACES_EXPORTER` para el ambiente de producción
3. THE Plataforma_Terraform SHALL organizar los parámetros SSM bajo la jerarquía `/multicines/integrator/{ambiente}/` para cada variable de configuración
4. THE Plataforma_Terraform SHALL actualizar las Task_Definitions de ECS para leer las variables de configuración desde SSM Parameter Store mediante la propiedad `valueFrom`
5. THE Plataforma_Terraform SHALL otorgar permisos IAM (ssm:GetParameters) al execution role de ECS para acceder a los parámetros del path correspondiente

### Requirement 10: Observabilidad

**User Story:** Como ingeniero DevOps, quiero una configuración completa de observabilidad, para monitorear el rendimiento y diagnosticar problemas del api-integration-service.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL configurar CloudWatch Log Groups para almacenar los logs de las tasks ECS en cada ambiente
2. THE Plataforma_Terraform SHALL configurar retención de logs en CloudWatch Logs con una política de retención definida por ambiente
3. THE Plataforma_Terraform SHALL habilitar CloudWatch Metrics para monitorear Fargate (CPU, memoria), ALB (requests, latencia, errores) y VPN (estado de túneles)
4. THE Plataforma_Terraform SHALL configurar el ADOT_Collector como sidecar en las Task_Definitions para enviar trazas distribuidas a AWS X-Ray
5. THE Plataforma_Terraform SHALL otorgar permisos IAM (xray:PutTraceSegments, xray:PutTelemetryRecords) al task role de ECS para el envío de trazas

### Requirement 11: Seguridad

**User Story:** Como ingeniero DevOps, quiero que la infraestructura cumpla con las mejores prácticas de seguridad de AWS, para proteger el servicio y los datos en tránsito.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL configurar Security Groups de las tasks ECS permitiendo tráfico de entrada únicamente desde el ALB por el puerto 8095
2. THE Plataforma_Terraform SHALL configurar AWS Shield Standard en los recursos expuestos a Internet para protección DDoS
3. THE Plataforma_Terraform SHALL gestionar los secretos sensibles (credenciales, API keys) en Secrets Manager con acceso restringido por ambiente
4. THE Plataforma_Terraform SHALL configurar VPC_Prod con recursos distribuidos en 2 Availability Zones para alta disponibilidad
5. THE Plataforma_Terraform SHALL definir políticas IAM con privilegio mínimo para cada rol de ejecución y tarea de ECS
6. IF un Security Group no tiene reglas de salida explícitas hacia el CIDR on-premise, THEN THE Plataforma_Terraform SHALL restringir el tráfico de salida a los endpoints de servicios AWS necesarios (ECR, SSM, Secrets Manager, CloudWatch, X-Ray)

### Requirement 12: CI/CD con GitHub Actions

**User Story:** Como ingeniero DevOps, quiero un pipeline CI/CD robusto en GitHub Actions, para automatizar el despliegue seguro del api-integration-service en ambos ambientes.

#### Acceptance Criteria

1. THE Pipeline_CICD SHALL autenticarse con AWS mediante OIDC (sin credenciales long-lived) utilizando el IAM OIDC Provider configurado
2. THE Pipeline_CICD SHALL construir la imagen Docker y publicarla en el repositorio ECR del api-integration-service
3. THE Pipeline_CICD SHALL desplegar la nueva Task_Definition en el ECS_Service del ambiente correspondiente
4. WHEN se realiza un push a la rama principal, THE Pipeline_CICD SHALL ejecutar el despliegue en el ambiente de desarrollo
5. THE Pipeline_CICD SHALL verificar que el primer despliegue en el ambiente de desarrollo es exitoso antes de permitir despliegue a producción
6. THE Pipeline_CICD SHALL activar protección de ramas en el repositorio para requerir aprobación antes de merge a la rama principal
7. IF el despliegue en ECS falla (servicio no alcanza estado RUNNING), THEN THE Pipeline_CICD SHALL reportar el error y revertir a la Task_Definition anterior

### Requirement 13: Documentación Profesional y Manual de Operaciones

**User Story:** Como arquitecto de soluciones, quiero entregar un paquete de documentación ejecutiva profesional que incluya manuales de operación con pasos en la consola AWS, diagramas de arquitectura actualizados, y documentos de estándares, para que el equipo de Multicines pueda gestionar y mantener la infraestructura de forma autónoma.

#### Acceptance Criteria

1. THE Plataforma_Terraform SHALL generar un manual de operaciones actualizado (basado en Insumos iniciales/Manual para multicines.docx) con pasos detallados usando la consola AWS para crear, configurar y gestionar cada componente de la infraestructura final (VPC, subnets, ALB, ECS, VPN, SSM, Security Groups, Secrets Manager, CloudWatch, IAM)
2. THE Plataforma_Terraform SHALL incluir en el manual capturas de pantalla de referencia o descripciones precisas de la navegación en la consola AWS para cada operación
3. THE Plataforma_Terraform SHALL generar un diagrama de arquitectura final actualizado en formato draw.io que refleje la infraestructura objetivo completa con todos los componentes, flujos de datos y conexiones
4. THE Plataforma_Terraform SHALL generar un documento de estándares de infraestructura que defina la convención de tags, nomenclatura, políticas de seguridad y mejores prácticas adoptadas
5. THE Plataforma_Terraform SHALL generar un documento de runbook operativo con procedimientos para escenarios comunes: deploy manual, rollback, troubleshooting de VPN, escalamiento de ECS, rotación de secretos y revisión de logs
6. THE Plataforma_Terraform SHALL generar un documento de arquitectura ejecutivo (resumen de 2-3 páginas) para stakeholders no técnicos que describa la solución, beneficios, costos estimados y roadmap
7. THE Plataforma_Terraform SHALL organizar toda la documentación entregable en un directorio docs/ con estructura clara y un índice principal
