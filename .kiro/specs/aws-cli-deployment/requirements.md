# Requirements Document

## Introduction

Este documento define los requisitos para la creación de scripts AWS CLI idempotentes que provisionan los recursos faltantes de la infraestructura Multicines en los ambientes dev y prod (cuenta 340271092920, región us-east-1). Incluye también la conversión del manual de operaciones existente a Markdown y su exportación a DOCX con secciones nuevas para cada recurso creado.

## Glossary

- **Script_Orquestador**: Script bash principal (`scripts/create-all.sh`) que invoca secuencialmente los scripts individuales de cada servicio.
- **Script_Servicio**: Script bash individual ubicado en `scripts/` que crea un tipo específico de recurso AWS para un ambiente determinado.
- **Naming_Helper**: Función bash definida al inicio de cada script que genera nombres de recursos siguiendo el patrón `{ambiente}-{recurso}-{tipo}-{zona}`.
- **Idempotencia**: Capacidad de un script de ejecutarse múltiples veces produciendo el mismo resultado final sin recrear recursos ya existentes.
- **ALB**: Application Load Balancer de AWS que distribuye tráfico HTTP/HTTPS a Target Groups.
- **Target_Group**: Grupo de destinos registrado en un ALB que enruta tráfico al puerto 8095 de los contenedores ECS.
- **WAF_WebACL**: Web Access Control List de AWS WAF que protege los ALBs con reglas de rate limiting e IP allowlist.
- **VPN_Site_to_Site**: Conexión VPN entre AWS y la red on-premise del cliente con túneles redundantes.
- **Customer_Gateway**: Recurso AWS que representa el dispositivo VPN on-premise del cliente.
- **ACM_Certificate**: Certificado SSL/TLS gestionado por AWS Certificate Manager para tráfico HTTPS.
- **SSM_Parameter**: Parámetro almacenado en AWS Systems Manager Parameter Store bajo la jerarquía `/multicines/integrator/{env}/`.
- **Secrets_Manager_Secret**: Secreto almacenado en AWS Secrets Manager con valores separados por ambiente.
- **ECS_Service**: Servicio de Amazon ECS Fargate dentro del cluster `multicines-cluster` que ejecuta la task definition del contenedor.
- **Task_Definition**: Definición de tarea ECS que especifica imagen ECR, CPU, memoria, port mappings y log configuration.
- **Security_Group_Hardening**: Proceso de restringir las reglas de egress permisivas actuales (0.0.0.0/0) en los Security Groups existentes.
- **Manual_Operaciones**: Documento Markdown generado a partir de "Insumos iniciales/Manual para multicines.docx" con secciones adicionales para cada recurso nuevo.
- **Pandoc**: Herramienta de conversión de documentos (versión 3.9.0.2) utilizada para convertir DOCX a Markdown y exportar Markdown a DOCX.

## Requirements

### Requirement 1: Estructura de Scripts y Orquestación

**User Story:** As a DevOps engineer, I want a main orchestrator script that invokes individual service scripts, so that I can provision all missing AWS resources in a single execution or run each service script independently.

#### Acceptance Criteria

1. THE Script_Orquestador SHALL reside en la ruta `scripts/create-all.sh` dentro del repositorio aws-assesment.
2. THE Script_Orquestador SHALL invocar cada Script_Servicio en orden de dependencias (Security Groups antes de ALB, ALB antes de ECS Service).
3. WHEN the Script_Orquestador is executed, THE Script_Orquestador SHALL aceptar un parámetro de ambiente (`dev` o `prod`) que se propaga a cada Script_Servicio invocado.
4. THE Script_Servicio SHALL ser ejecutable de forma independiente sin requerir la ejecución previa del Script_Orquestador.
5. THE Script_Servicio SHALL definir la Naming_Helper como función bash al inicio del script para generar nombres con el patrón `{ambiente}-{recurso}-{tipo}-{zona}`.
6. WHEN the zona parameter does not apply to a resource, THE Naming_Helper SHALL omitir el segmento zona del nombre generado.

### Requirement 2: Idempotencia de Scripts

**User Story:** As a DevOps engineer, I want scripts that do not recreate existing resources, so that I can safely re-execute them without side effects.

#### Acceptance Criteria

1. WHEN a Script_Servicio is executed, THE Script_Servicio SHALL ejecutar un comando `aws ... describe` o `aws ... list` para verificar la existencia del recurso antes de intentar crearlo.
2. WHILE a resource already exists in the AWS account, THE Script_Servicio SHALL omitir la creación y emitir un mensaje indicando que el recurso ya existe.
3. WHEN a resource does not exist, THE Script_Servicio SHALL ejecutar el comando `aws ... create` correspondiente y emitir un mensaje confirmando la creación exitosa.
4. IF a command `aws ... create` fails, THEN THE Script_Servicio SHALL emitir un mensaje de error con el código de salida y detener la ejecución del script con exit code distinto de cero.

### Requirement 3: Creación de Application Load Balancer

**User Story:** As a DevOps engineer, I want ALBs provisioned in dev and prod, so that HTTP/HTTPS traffic is distributed to ECS services.

#### Acceptance Criteria

1. WHEN the ALB script is executed for an environment, THE Script_Servicio SHALL crear un ALB de tipo `application` en las subnets públicas de la VPC correspondiente (dev: subnet-0c92479c2831f04eb, subnet-02193c97ceb6ec25d; prod: subnet-04e4cd18763fd6f84, subnet-05c92a4889326c68e).
2. THE Script_Servicio SHALL crear un Target_Group con health check en el puerto 8095 y protocolo HTTP para cada ambiente.
3. THE Script_Servicio SHALL crear un Listener HTTPS en el puerto 443 que reenvía tráfico al Target_Group correspondiente.
4. THE Script_Servicio SHALL asociar el Security Group del ALB existente (dev: sg-0fdf0c744482646ae, prod: sg-04f21c4c1d065fe60) al ALB creado.
5. THE Script_Servicio SHALL nombrar el ALB siguiendo el patrón de Naming_Helper (ejemplo: `dev-alb-application`, `prod-alb-application`).

### Requirement 4: Creación de VPN Site-to-Site

**User Story:** As a network engineer, I want VPN Site-to-Site connections provisioned with placeholders for on-premise parameters, so that I can establish connectivity when the customer provides the gateway details.

#### Acceptance Criteria

1. WHEN the VPN script is executed, THE Script_Servicio SHALL crear un Customer_Gateway con valores placeholder para IP address y BGP ASN claramente marcados con comentarios en el script.
2. THE Script_Servicio SHALL crear un Virtual Private Gateway y adjuntarlo a la VPC del ambiente correspondiente (dev: vpc-0a5ebea8e7bee9ed5, prod: vpc-0860a0d2cf4df6140).
3. THE Script_Servicio SHALL crear una VPN Connection de tipo `ipsec.1` asociando el Customer_Gateway y el Virtual Private Gateway creados.
4. THE Script_Servicio SHALL habilitar route propagation en las route tables privadas de la VPC correspondiente.
5. THE Script_Servicio SHALL nombrar los recursos VPN siguiendo el patrón de Naming_Helper (ejemplo: `dev-vpn-connection`, `prod-cgw-customer`).

### Requirement 5: Creación de WAF Web ACL

**User Story:** As a security engineer, I want a WAF Web ACL protecting the ALBs, so that the application is shielded from common web attacks and excessive request rates.

#### Acceptance Criteria

1. WHEN the WAF script is executed, THE Script_Servicio SHALL crear una WAF_WebACL con scope REGIONAL.
2. THE Script_Servicio SHALL configurar una regla de rate limiting en la WAF_WebACL.
3. THE Script_Servicio SHALL asociar la WAF_WebACL a los ALBs creados en dev y prod.
4. THE Script_Servicio SHALL nombrar la WAF_WebACL siguiendo el patrón de Naming_Helper (ejemplo: `dev-waf-webacl`, `prod-waf-webacl`).

### Requirement 6: Creación de ACM Certificate

**User Story:** As a DevOps engineer, I want an ACM certificate provisioned, so that the ALB listeners can terminate HTTPS traffic.

#### Acceptance Criteria

1. WHEN the ACM script is executed, THE Script_Servicio SHALL solicitar un certificado en ACM para el dominio requerido.
2. THE Script_Servicio SHALL emitir las instrucciones de validación DNS del certificado como salida del script.
3. THE Script_Servicio SHALL nombrar el certificado usando tags siguiendo el patrón de Naming_Helper.

### Requirement 7: Creación de SSM Parameter Store

**User Story:** As a DevOps engineer, I want application configuration stored in SSM Parameter Store, so that ECS tasks can retrieve configuration at runtime without hardcoded values.

#### Acceptance Criteria

1. WHEN the SSM script is executed, THE Script_Servicio SHALL crear parámetros bajo la jerarquía `/multicines/integrator/{env}/` donde `{env}` es el ambiente (dev o prod).
2. THE Script_Servicio SHALL crear los parámetros como tipo `String` o `SecureString` según la sensibilidad del valor.
3. WHILE a parameter with the same name already exists, THE Script_Servicio SHALL omitir la creación de ese parámetro específico.

### Requirement 8: Creación de Secrets Manager

**User Story:** As a DevOps engineer, I want application secrets stored in Secrets Manager, so that sensitive credentials are managed securely and rotatable.

#### Acceptance Criteria

1. WHEN the Secrets Manager script is executed, THE Script_Servicio SHALL crear secretos separados por ambiente con valores placeholder.
2. THE Script_Servicio SHALL nombrar los secretos siguiendo el patrón de Naming_Helper.
3. WHILE a secret with the same name already exists, THE Script_Servicio SHALL omitir la creación de ese secreto específico.

### Requirement 9: Hardening de Security Groups

**User Story:** As a security engineer, I want restrictive egress rules on existing Security Groups, so that outbound traffic from ALBs and ECS tasks is limited to only necessary destinations.

#### Acceptance Criteria

1. WHEN the Security Groups hardening script is executed, THE Script_Servicio SHALL revocar la regla de egress `0.0.0.0/0` all-traffic de los Security Groups ALB (dev: sg-0fdf0c744482646ae, prod: sg-04f21c4c1d065fe60).
2. THE Script_Servicio SHALL agregar una regla de egress en los Security Groups ALB que permita tráfico solo al puerto 8095 hacia los Security Groups ECS correspondientes.
3. THE Script_Servicio SHALL revocar la regla de egress `0.0.0.0/0` all-traffic de los Security Groups ECS (dev: sg-01c619444bab0b8d3, prod: sg-0b78c14cd02b2f6e1).
4. THE Script_Servicio SHALL agregar reglas de egress en los Security Groups ECS que permitan tráfico HTTPS (443) hacia los endpoints necesarios (ECR, CloudWatch Logs, SSM, Secrets Manager).

### Requirement 10: Creación de ECS Services y Task Definitions

**User Story:** As a DevOps engineer, I want ECS Services and Task Definitions created in the existing cluster, so that the integration-service container runs in Fargate for each environment.

#### Acceptance Criteria

1. WHEN the ECS script is executed, THE Script_Servicio SHALL registrar una Task_Definition con la imagen del repositorio ECR `multicines/integration-service`, puerto 8095, y log configuration apuntando al log group existente (`/ecs/{env}-multicines-integration`).
2. THE Script_Servicio SHALL configurar la Task_Definition con el rol de ejecución `ecsTaskExecutionRole` y el rol de tarea `multicines-ecs-task-role`.
3. THE Script_Servicio SHALL crear un ECS_Service en el cluster `multicines-cluster` con launch type FARGATE, asignando las subnets privadas y el Security Group ECS del ambiente correspondiente.
4. THE Script_Servicio SHALL registrar el ECS_Service en el Target_Group del ALB del ambiente correspondiente.
5. THE Script_Servicio SHALL nombrar el servicio y la task definition siguiendo el patrón de Naming_Helper.

### Requirement 11: Conversión del Manual de Operaciones a Markdown

**User Story:** As a documentation maintainer, I want the existing operations manual converted to Markdown, so that it is version-controlled and easy to extend with new resource documentation.

#### Acceptance Criteria

1. THE Script_Servicio SHALL usar Pandoc versión 3.9.0.2 para convertir "Insumos iniciales/Manual para multicines.docx" a formato Markdown.
2. THE Script_Servicio SHALL extraer las imágenes del DOCX original y almacenarlas en `documents/images/`.
3. THE Script_Servicio SHALL preservar las referencias a imágenes en el Markdown generado apuntando a la ruta `documents/images/`.
4. THE Script_Servicio SHALL tratar el archivo "Insumos iniciales/Manual para multicines.docx" como solo lectura sin modificar el directorio "Insumos iniciales/".

### Requirement 12: Extensión del Manual con Secciones de Recursos Nuevos

**User Story:** As a documentation maintainer, I want new sections added to the operations manual for each provisioned resource, so that operations teams have step-by-step console instructions for all infrastructure.

#### Acceptance Criteria

1. WHEN new resources are provisioned, THE Manual_Operaciones SHALL incluir una sección nueva por cada tipo de recurso creado (ALB, VPN, WAF, ACM, SSM, Secrets Manager, ECS Service).
2. THE Manual_Operaciones SHALL documentar pasos de consola web AWS para verificar y operar cada recurso.
3. THE Manual_Operaciones SHALL residir en la ruta `documents/` dentro del repositorio aws-assesment.

### Requirement 13: Exportación del Manual a DOCX

**User Story:** As a documentation maintainer, I want the final Markdown manual exported to DOCX format, so that stakeholders who prefer Word documents can access the documentation.

#### Acceptance Criteria

1. THE Script_Servicio SHALL usar Pandoc versión 3.9.0.2 para exportar el Manual_Operaciones en Markdown a formato DOCX.
2. THE Script_Servicio SHALL almacenar el DOCX exportado en la ruta `documents/` dentro del repositorio aws-assesment.
3. THE Script_Servicio SHALL preservar las imágenes referenciadas en el Markdown dentro del DOCX exportado.
