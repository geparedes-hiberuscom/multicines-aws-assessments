**HIBERUS**

**Manual de Gestión de Infraestructura AWS — Multicines**

Guía operativa para la administración y monitoreo de recursos en AWS

  ------------------------------ ----------------------------------------
  **Versión**                    2.0
  **Plataforma**                 Consola de AWS
  **Fecha**                      2026
  **Clasificación**              **Confidencial - Uso Interno**
  **Cuenta AWS**                 340271092920
  **Región**                     us-east-1 (Norte de Virginia)
  **Proyecto**                   multicines
  **Servicio**                   multicines-integration
  ------------------------------ ----------------------------------------

---

**Tabla de Contenido**

1. [Introducción](#1-introducción)
2. [Ingreso a la Consola de AWS](#2-ingreso-a-la-consola-de-aws)
3. [Administración de Acceso (IAM)](#3-administración-de-acceso-iam)
4. [Administración de VPC](#4-administración-de-vpc)
5. [Certificados SSL — ACM](#5-certificados-ssl--acm)
6. [Application Load Balancer](#6-application-load-balancer)
7. [Route 53 — DNS](#7-route-53--dns)
8. [Secrets Manager](#8-secrets-manager)
9. [Elastic Container Registry (ECR)](#9-elastic-container-registry-ecr)
10. [Elastic Container Service (ECS)](#10-elastic-container-service-ecs)
11. [Observabilidad — CloudWatch, X-Ray](#11-observabilidad--cloudwatch-x-ray)
12. [VPN Site-to-Site](#12-vpn-site-to-site)
13. [CI/CD — GitHub Actions](#13-cicd--github-actions)
14. [Anexo — Resumen de Recursos por Ambiente](#14-anexo)


---

# 1. Introducción

## 1.1 Propósito del documento

Este documento describe la infraestructura cloud implementada en Amazon Web Services (AWS) para el proyecto Multicines. Detalla cada componente configurado, las decisiones técnicas tomadas y los pasos para la administración operativa de los recursos.

## 1.2 Contexto

Multicines requiere exponer su sistema Vista API Connect hacia servicios externos de forma segura. Se implementó una capa de integración en AWS que actúa como intermediaria entre consumidores externos y el sistema on-premise, garantizando disponibilidad, seguridad y trazabilidad.

La solución contempla dos ambientes independientes (desarrollo y producción) con despliegues automatizados mediante GitHub Actions.

## 1.3 Inventario de Recursos Existentes

| Recurso | Nombre | Ambiente |
|---------|--------|----------|
| VPC | vpc-0a5ebea8e7bee9ed5 | dev |
| VPC | vpc-0860a0d2cf4df6140 | prod |
| ALB | dev-multicines-integration-alb | dev |
| ALB | prod-multicines-integration-alb | prod |
| Target Group | dev-multicines-integration-tg | dev |
| Target Group | prod-multicines-integration-tg | prod |
| ACM Certificate | *.test.multicines.com.ec (ISSUED) | ambos |
| Route53 Zone | test.multicines.com.ec | ambos |
| Route53 Record | dev-integration.test.multicines.com.ec | dev |
| ECS Cluster | multicines-cluster | ambos |
| ECS Service | dev-multicines-integration-svc (1 task) | dev |
| ECS Service | prod-multicines-integration-svc (2 tasks) | prod |
| ECR | multicines/integration-service | ambos |
| Secrets Manager | platform/dev/resilience, integrator/dev/app | dev |
| SNS Topic | dev-multicines-integration-alarms | dev |
| SNS Topic | prod-multicines-integration-alarms | prod |
| Dashboard | dev-multicines-integration-dashboard | dev |
| Dashboard | prod-multicines-integration-dashboard | prod |
| CloudWatch Alarms | 7 alarmas activas (dev) | dev |
| Rol IAM | ecsTaskExecutionRole | ambos |
| Rol IAM | multicines-ecs-task-role | ambos |
| Rol IAM | multicines-github-actions-role | ambos |

---

# 2. Ingreso a la Consola de AWS

Abrir el navegador e ingresar a: **https://signin.aws.amazon.com**

![](documents/images/media/image.png){width="5.90625in" height="3.8333333333333335in"}

## 2.1 Ingreso con usuario root

Seleccionar **Root user**, ingresar email, click **Next**:

![](documents/images/media/image2.png){width="5.90625in" height="3.2291666666666665in"}

Ingresar contraseña:

![](documents/images/media/image3.png){width="5.90625in" height="3.6875in"}

Ingresar código MFA:

![](documents/images/media/image4.png){width="5.90625in" height="3.5416666666666665in"}

Dashboard de la consola tras autenticación exitosa:

![](documents/images/media/image5.png){width="5.90625in" height="3.1458333333333335in"}

## 2.2 Ingreso con usuario IAM

1. Seleccionar **IAM user** → Account ID: **340271092920** → Click **Next**

![](documents/images/media/image6.png){width="5.90625in" height="4.0625in"}

2. Ingresar usuario y contraseña IAM → Click **Sign in**

![](documents/images/media/image7.png){width="5.90625in" height="4.020833333333333in"}

Consola principal tras login exitoso:

![](documents/images/media/image8.png){width="5.90625in" height="3.1145833333333335in"}


---

# 3. Administración de Acceso (IAM)

## 3.1 Panel de IAM

Buscar **IAM** en la barra de búsqueda:

![](documents/images/media/image9.png){width="5.90625in" height="3.46875in"}

![](documents/images/media/imagea.png){width="5.90625in" height="3.4583333333333335in"}

## 3.2 Grupos IAM

![](documents/images/media/imageb.png){width="5.90625in" height="3.1354166666666665in"}

### Creación de grupo

User groups → **Create group** → asignar nombre y políticas:

![](documents/images/media/imagec.png){width="5.90625in" height="3.0729166666666665in"}

![](documents/images/media/imaged.png){width="5.90625in" height="2.71875in"}

![](documents/images/media/imagee.png){width="5.90625in" height="2.2142913385826772in"}

![](documents/images/media/imagef.png){width="5.90625in" height="2.9791666666666665in"}

![](documents/images/media/image10.png){width="5.90625in" height="1.9479166666666667in"}

### Editar grupo

![](documents/images/media/image11.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image12.png){width="5.90625in" height="2.6770833333333335in"}

## 3.3 Usuarios IAM

Users → **Create user**:

![](documents/images/media/image13.png){width="5.90625in" height="3.1458333333333335in"}

![](documents/images/media/image14.png){width="5.90625in" height="3.0104166666666665in"}

![](documents/images/media/image15.png){width="5.90625in" height="2.9895833333333335in"}

Asignación a grupo:

![](documents/images/media/image16.png){width="5.90625in" height="2.9583333333333335in"}

![](documents/images/media/image17.png){width="5.90625in" height="2.9479166666666665in"}

![](documents/images/media/image18.png){width="5.90625in" height="2.9479166666666665in"}

Resumen y creación:

![](documents/images/media/image19.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image1a.png){width="5.90625in" height="2.9375in"}

Descargar credenciales CSV:

![](documents/images/media/image1b.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image1c.png){width="5.90625in" height="0.4791666666666667in"}

![](documents/images/media/image1d.png){width="5.90625in" height="2.7395833333333335in"}

## 3.4 Políticas IAM

![](documents/images/media/image1e.png){width="5.90625in" height="3.0833333333333335in"}

![](documents/images/media/image1f.png){width="5.90625in" height="3.1041666666666665in"}


---

# 4. Administración de VPC

## 4.1 Creación de una VPC

Buscar **VPC** en la consola:

![](documents/images/media/image20.png){width="5.90625in" height="2.96875in"}

![](documents/images/media/image21.png){width="5.90625in" height="3.1145833333333335in"}

Seleccionar **VPC and more** y configurar parámetros de red:

![](documents/images/media/image22.png){width="5.90625in" height="2.9375in"}

![](documents/images/media/image23.png){width="5.90625in" height="2.9166666666666665in"}

![](documents/images/media/image24.png){width="5.90625in" height="2.9479166666666665in"}

![](documents/images/media/image25.png){width="5.90625in" height="2.9895833333333335in"}

## 4.2 VPCs del proyecto

![](documents/images/media/image26.png){width="5.90625in" height="2.6770833333333335in"}

![](documents/images/media/image27.png){width="5.90625in" height="3.0in"}

![](documents/images/media/image28.png){width="5.90625in" height="3.0208333333333335in"}

![](documents/images/media/image29.png){width="5.90625in" height="3.59375in"}

![](documents/images/media/image2a.png){width="5.90625in" height="2.9791666666666665in"}

## 4.3 Internet Gateway

![](documents/images/media/image2b.png){width="5.90625in" height="2.09375in"}

![](documents/images/media/image2c.png){width="5.90625in" height="1.7083333333333333in"}

## 4.4 NAT Gateway

![](documents/images/media/image2d.png){width="5.90625in" height="2.4479166666666665in"}

![](documents/images/media/image2e.png){width="5.90625in" height="3.0416666666666665in"}

![](documents/images/media/image2f.png){width="5.90625in" height="2.8020833333333335in"}

## 4.5 Security Groups

![](documents/images/media/image30.png){width="5.90625in" height="1.8614031058617673in"}

**SG ALB** (dev: sg-0fdf0c744482646ae / prod: sg-04f21c4c1d065fe60):

![](documents/images/media/image31.png){width="5.90625in" height="2.5in"}

![](documents/images/media/image32.png){width="5.90625in" height="2.7708333333333335in"}

**SG ECS** (dev: sg-01c619444bab0b8d3 / prod: sg-0b78c14cd02b2f6e1):

![](documents/images/media/image33.png){width="5.90625in" height="2.84375in"}

![](documents/images/media/image34.png){width="5.90625in" height="2.8333333333333335in"}

## 4.6 Tablas de Enrutamiento

![](documents/images/media/image35.png){width="5.90625in" height="2.1041666666666665in"}

![](documents/images/media/image36.png){width="5.90625in" height="2.8229166666666665in"}

![](documents/images/media/image37.png){width="5.90625in" height="1.84375in"}

![](documents/images/media/image38.png){width="5.90625in" height="2.90625in"}

![](documents/images/media/image39.png){width="5.90625in" height="1.9895833333333333in"}


---

# 5. Certificados SSL — ACM

## 5.1 Certificado importado

Se importó el certificado wildcard `*.test.multicines.com.ec` en ACM. Estado actual: **ISSUED**.

### Paso a paso

1. Buscar **Certificate Manager** en la consola
2. Click **Import certificate**
3. Certificate body: pegar contenido de `certificate.pem`
4. Certificate private key: pegar `private-key.pem`
5. Certificate chain: pegar `certificate-chain.pem`
6. Click **Next** → Tags → Click **Import**

> **TODO: Insertar pantalla de ACM mostrando el certificado con estado ISSUED**

## 5.2 Renovación

Al ser importado, AWS **no** lo renueva automáticamente. Para renovar: ACM → seleccionar certificado → **Reimport** → pegar nuevos archivos PEM.

---

# 6. Application Load Balancer

## 6.1 ALBs existentes

| ALB | DNS | Estado |
|-----|-----|--------|
| dev-multicines-integration-alb | dev-multicines-integration-alb-545782741.us-east-1.elb.amazonaws.com | active |
| prod-multicines-integration-alb | prod-multicines-integration-alb-163067168.us-east-1.elb.amazonaws.com | active |

### Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Tipo | application, internet-facing | application, internet-facing |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 | ELBSecurityPolicy-TLS13-1-2-2021-06 |
| Listener HTTPS | 443 → Forward to TG | 443 → Forward to TG |
| Listener HTTP | 80 → Redirect HTTPS (301) | 80 → Redirect HTTPS (301) |
| Target Group | dev-multicines-integration-tg | prod-multicines-integration-tg |
| Health Check | /actuator/health:8095 | /actuator/health:8095 |
| Healthy/Unhealthy | 2 / 5 | 2 / 5 |

### Creación (paso a paso)

1. EC2 → Load Balancers → **Create Load Balancer** → Application Load Balancer
2. Name: `{env}-multicines-integration-alb`, Scheme: Internet-facing
3. Network mapping: VPC + 2 subnets públicas
4. Security groups: SG ALB del ambiente
5. Listener HTTPS:443 → certificado ACM → SSL Policy TLS 1.3
6. Target Group: IP type, port 8095, health check /actuator/health
7. Agregar listener HTTP:80 → Redirect HTTPS 301

> **TODO: Insertar pantalla del ALB mostrando listeners HTTPS y HTTP**

> **TODO: Insertar pantalla del Target Group con targets healthy**

---

# 7. Route 53 — DNS

## 7.1 Hosted Zone

Hosted zone: `test.multicines.com.ec` (ID: Z0314211307ID7A02PYNF)

## 7.2 Registro DNS existente

| Registro | Tipo | Target |
|----------|------|--------|
| dev-integration.test.multicines.com.ec | A (Alias) | ALB dev |

### Creación de registro

1. Route 53 → Hosted zones → `test.multicines.com.ec` → **Create record**
2. Record name: `dev-integration`
3. Type: A, Alias: ON
4. Route to: Application Load Balancer → us-east-1 → seleccionar ALB
5. Evaluate target health: Yes
6. Click **Create records**

> **TODO: Insertar pantalla de la hosted zone con el record A alias**

---

# 8. Secrets Manager

## 8.1 Secretos existentes

| Nombre del secreto | Ambiente |
|-------------------|----------|
| platform/dev/resilience | dev |
| integrator/dev/app | dev |

### Creación de un secreto

1. Buscar **Secrets Manager** → **Store a new secret**
2. Secret type: **Other type of secret**
3. Key/value: seleccionar **Plaintext** → pegar JSON
4. Encryption key: aws/secretsmanager (default)
5. Click **Next** → Secret name → Tags → **Store**

> **TODO: Insertar pantalla del listado de secretos en Secrets Manager**


---

# 9. Elastic Container Registry (ECR)

Repositorio privado: `multicines/integration-service`
URI: `340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service`

![](documents/images/media/image3a.png){width="5.90625in" height="3.3125in"}

![](documents/images/media/image3b.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image3c.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image3d.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image3e.png){width="5.90625in" height="3.2916666666666665in"}

---

# 10. Elastic Container Service (ECS)

## 10.1 Cluster

Cluster: **multicines-cluster** (Fargate, Container Insights activado)

![](documents/images/media/image3f.png){width="5.90625in" height="1.9028073053368328in"}

![](documents/images/media/image40.png){width="5.90625in" height="3.1354166666666665in"}

![](documents/images/media/image41.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image42.png){width="5.90625in" height="3.125in"}

![](documents/images/media/image43.png){width="5.90625in" height="1.7534787839020123in"}

## 10.2 Servicios ECS activos

| Servicio | Desired | Running | Estado |
|----------|---------|---------|--------|
| dev-multicines-integration-svc | 1 | 1 | ACTIVE |
| prod-multicines-integration-svc | 2 | 2 | ACTIVE |

## 10.3 Task Definitions

![](documents/images/media/image44.png){width="5.90625in" height="3.09375in"}

**Dev — dev-multicines-integration-task:**

| Parámetro | Valor |
|-----------|-------|
| Launch type | AWS Fargate |
| CPU | 0.5 vCPU (512) |
| Memoria | 1 GB (1024) |
| Container principal | integration-service |
| Puerto | 8095 |
| Task role | multicines-ecs-task-role |
| Execution role | ecsTaskExecutionRole |
| Log group | /ecs/dev-multicines-integration |

![](documents/images/media/image45.png){width="5.90625in" height="2.8541666666666665in"}

![](documents/images/media/image46.png){width="5.90625in" height="2.7604166666666665in"}

**Prod — prod-multicines-integration-task:**

| Parámetro | Valor |
|-----------|-------|
| Launch type | AWS Fargate |
| CPU | 1 vCPU (1024) |
| Memoria | 2 GB (2048) |
| Container principal | integration-service |
| Puerto | 8095 |
| Desired count | 2 |

![](documents/images/media/image47.png){width="5.90625in" height="3.0833333333333335in"}

## 10.4 Variables de entorno

| Variable | Dev | Prod |
|----------|-----|------|
| SPRING_PROFILES_ACTIVE | dev | prod |
| AWS_REGION | us-east-1 | us-east-1 |
| OTEL_LOGS_EXPORTER | none | none |
| OTEL_METRICS_EXPORTER | none | none |
| OTEL_TRACES_EXPORTER | otlp | otlp |
| OTEL_SERVICE_NAME | integrator | integrator |
| OTEL_EXPORTER_OTLP_ENDPOINT | http://localhost:4317 | http://localhost:4317 |
| OTEL_EXPORTER_OTLP_PROTOCOL | grpc | grpc |
| OTEL_TRACES_SAMPLER | parentbased_traceidratio | parentbased_traceidratio |
| OTEL_TRACES_SAMPLER_ARG | 1.0 (100%) | 0.10 (10%) |

![](documents/images/media/image48.png){width="5.90625in" height="3.25in"}

![](documents/images/media/image49.png){width="5.90625in" height="2.875in"}

## 10.5 Sidecar ADOT Collector (Trazas X-Ray)

La Task Definition incluye un segundo contenedor sidecar para trazabilidad distribuida:

| Parámetro | Valor |
|-----------|-------|
| Container name | aws-otel-collector |
| Image | public.ecr.aws/aws-observability/aws-otel-collector:latest |
| Essential | No |
| Memory | 256 MB |
| Puerto | 4317/tcp (gRPC OTLP) |
| Log stream prefix | otel |

El sidecar recibe trazas del contenedor principal via localhost:4317 y las exporta a AWS X-Ray.

> **TODO: Insertar pantalla de la Task Definition mostrando 2 containers**

![](documents/images/media/image4a.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image4b.png){width="5.90625in" height="3.2708333333333335in"}


---

# 11. Observabilidad — CloudWatch, X-Ray

## 11.1 SNS Topics para alarmas

| Topic | ARN |
|-------|-----|
| dev-multicines-integration-alarms | arn:aws:sns:us-east-1:340271092920:dev-multicines-integration-alarms |
| prod-multicines-integration-alarms | arn:aws:sns:us-east-1:340271092920:prod-multicines-integration-alarms |

Suscripción email: `alarms@multicines.com.ec`

### Creación

1. SNS → Topics → **Create topic** → Standard → Name: `{env}-multicines-integration-alarms`
2. **Create subscription** → Protocol: Email → Endpoint: alarms@multicines.com.ec
3. Confirmar suscripción desde email recibido

> **TODO: Insertar pantalla del SNS Topic con suscripción email confirmada**

## 11.2 CloudWatch Alarms (dev)

| Alarma | Estado |
|--------|--------|
| dev-multicines-integration-alarm-cpu-high | OK |
| dev-multicines-integration-alarm-memory-high | OK |
| dev-multicines-integration-alarm-5xx | INSUFFICIENT_DATA |
| dev-multicines-integration-alarm-4xx | OK |
| dev-multicines-integration-alarm-unhealthy-hosts | OK |
| dev-multicines-integration-alarm-no-running-tasks | OK |
| dev-multicines-integration-alarm-response-time-high | OK |

### Configuración de alarmas

| Alarma | Métrica | Threshold | Período |
|--------|---------|-----------|---------|
| alarm-cpu-high | AWS/ECS CPUUtilization | ≥ 80% | 300s, 2 eval |
| alarm-memory-high | AWS/ECS MemoryUtilization | ≥ 80% | 300s, 2 eval |
| alarm-5xx | ALB HTTPCode_Target_5XX_Count | ≥ 10 | 60s, 3 eval |
| alarm-4xx | ALB HTTPCode_Target_4XX_Count | ≥ 50 | 60s, 3 eval |
| alarm-unhealthy-hosts | ALB UnHealthyHostCount | ≥ 1 | 60s, 2 eval |
| alarm-response-time-high | ALB TargetResponseTime | ≥ 5s (dev) / 3s (prod) | 60s, 3 eval |
| alarm-no-running-tasks | ECS RunningTaskCount | < 1 | 60s, 2 eval |

### Creación de alarma (ejemplo CPU)

1. CloudWatch → Alarms → **Create alarm**
2. Select metric → AWS/ECS → ClusterName, ServiceName → CPUUtilization
3. Statistic: Average, Period: 5 min
4. Condition: ≥ 80
5. Notification → SNS topic `{env}-multicines-integration-alarms`
6. Alarm name: `{env}-multicines-integration-alarm-cpu-high`
7. Click **Create alarm**

> **TODO: Insertar pantalla del listado de alarmas mostrando estados OK**

## 11.3 CloudWatch Dashboards

| Dashboard | Ambiente |
|-----------|----------|
| dev-multicines-integration-dashboard | dev |
| prod-multicines-integration-dashboard | prod |

Widgets: CPU, Memory, Request Count, 5xx, 4xx, Response Time, Healthy/Unhealthy Hosts, Custom Metrics, Running Tasks.

### Acceso

1. CloudWatch → Dashboards → click en `{env}-multicines-integration-dashboard`

> **TODO: Insertar pantalla del dashboard con los widgets activos**

## 11.4 Log Metric Filters

| Filter | Pattern | Metric | Namespace |
|--------|---------|--------|-----------|
| filter-5xx-errors | { $.status >= 500 } | 5xxErrors | Multicines/{env} |
| filter-latency | { $.duration_ms = * } | Latency | Multicines/{env} |

## 11.5 X-Ray — Trazas distribuidas

El sidecar ADOT exporta trazas a X-Ray. Para verlas:

1. Buscar **X-Ray** → **Traces**
2. Filtrar por servicio: `integrator`
3. Click en una traza para ver latencia por segmento

> **TODO: Insertar pantalla de X-Ray Traces del servicio integrator**

## 11.6 IAM Policy X-Ray

Inline policy `{env}-multicines-integration-xray-policy` en rol `multicines-ecs-task-role`:

- xray:PutTraceSegments
- xray:PutTelemetryRecords
- xray:GetSamplingRules
- xray:GetSamplingTargets


---

# 12. VPN Site-to-Site

## 12.1 Customer Gateway

1. VPC → Customer Gateways → **Create Customer Gateway**
2. Name: `{env}-multicines-integration-cgw`
3. Routing: Static
4. IP Address: IP pública del router on-premise (proporcionada por Multicines)
5. BGP ASN: 65000
6. Click **Create Customer Gateway**

> **TODO: Insertar pantalla del formulario de creación de Customer Gateway**

## 12.2 Virtual Private Gateway

1. VPC → Virtual Private Gateways → **Create Virtual Private Gateway**
2. Name: `{env}-multicines-integration-vgw`
3. ASN: Amazon default
4. Click **Create Virtual Private Gateway**
5. Seleccionar el VGW → **Actions** → **Attach to VPC** → seleccionar VPC del ambiente
6. Click **Attach to VPC**

> **TODO: Insertar pantalla del VGW adjunto a la VPC**

## 12.3 VPN Connection

1. VPC → Site-to-Site VPN Connections → **Create VPN Connection**
2. Name: `{env}-multicines-integration-vpn`
3. Target Gateway: Virtual Private Gateway → seleccionar VGW creado
4. Customer Gateway: Existing → seleccionar CGW creado
5. Routing Options: Static
6. Click **Create VPN Connection**
7. Seleccionar la conexión → **Download Configuration** para obtener config del router on-premise

> **TODO: Insertar pantalla del wizard de creación de VPN**

> **TODO: Insertar pantalla de Download Configuration**

## 12.4 Route Propagation

1. VPC → Route Tables → seleccionar tabla de rutas **privada**
2. Pestaña **Route propagation** → **Edit route propagation**
3. Habilitar propagation para el VGW (checkbox)
4. Click **Save**
5. Verificar en pestaña Routes que aparezcan rutas hacia la red on-premise

> **TODO: Insertar pantalla de Route propagation habilitado**

## 12.5 Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre VPN | dev-multicines-integration-vpn | prod-multicines-integration-vpn |
| Nombre VGW | dev-multicines-integration-vgw | prod-multicines-integration-vgw |
| Nombre CGW | dev-multicines-integration-cgw | prod-multicines-integration-cgw |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Customer IP | IP del router on-premise | IP del router on-premise |
| BGP ASN | 65000 | 65000 |
| Tipo túnel | ipsec.1 | ipsec.1 |

## 12.6 Verificación

1. VPN Connections → Tunnel Details: al menos un túnel **UP**
2. Route Tables privadas: rutas propagadas hacia CIDR on-premise
3. CloudWatch → AWS/VPN → TunnelState (1=UP, 0=DOWN)

---

# 13. CI/CD — GitHub Actions

## 12.1 Proveedor OIDC

![](documents/images/media/image4c.png){width="5.90625in" height="2.156251093613298in"}

![](documents/images/media/image4d.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image4e.png){width="5.90625in" height="3.09375in"}

## 12.2 Rol IAM para GitHub Actions

Rol: `multicines-github-actions-role`
ARN: `arn:aws:iam::340271092920:role/multicines-github-actions-role`

Políticas asignadas:
- AmazonECS_FullAccess
- AmazonEC2ContainerRegistryPowerUser

![](documents/images/media/image4f.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image50.png){width="5.90625in" height="3.2604166666666665in"}

![](documents/images/media/image51.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image52.png){width="5.90625in" height="2.8958333333333335in"}

![](documents/images/media/image53.png){width="5.90625in" height="3.125in"}

![](documents/images/media/image54.png){width="5.90625in" height="1.8333333333333333in"}

## 12.3 Variables y Secrets en GitHub

**Repository variables:**

| Variable | Valor |
|----------|-------|
| AWS_REGION | us-east-1 |
| ECR_REPOSITORY | multicines/integration-service |
| ECS_CLUSTER | multicines-cluster |
| DEV_TASK_DEFINITION | dev-multicines-integration-task |
| PROD_TASK_DEFINITION | prod-multicines-integration-task |
| DEV_ECS_SERVICE | dev-multicines-integration-svc |
| PROD_ECS_SERVICE | prod-multicines-integration-svc |

**Secrets:**

| Secret | Valor |
|--------|-------|
| AWS_ROLE_ARN | arn:aws:iam::340271092920:role/multicines-github-actions-role |

## 12.4 Pipeline de despliegue

| Workflow | Trigger | Ambiente |
|----------|---------|----------|
| deploy-dev.yml | Push a rama `dev` | development |
| deploy-prod.yml | Push a rama `main` | production |

Flujo: Checkout → OIDC Auth → ECR Login → Build Docker → Push → Update TD → Deploy ECS → Verify → (On failure: Rollback)

## 12.5 Protección de ramas

![](documents/images/media/image55.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image56.png){width="5.90625in" height="3.28125in"}

![](documents/images/media/image57.png){width="5.90625in" height="3.0416666666666665in"}

![](documents/images/media/image58.png){width="5.90625in" height="3.1458333333333335in"}

![](documents/images/media/image59.png){width="5.90625in" height="3.1354166666666665in"}

![](documents/images/media/image5a.png){width="5.90625in" height="3.125in"}

![](documents/images/media/image5b.png){width="5.90625in" height="3.1770833333333335in"}

---

# 14. Anexo — Resumen de Recursos por Ambiente

## Dev

| Servicio | Recurso | ID/Nombre |
|----------|---------|-----------|
| VPC | VPC | vpc-0a5ebea8e7bee9ed5 |
| EC2 | SG ALB | sg-0fdf0c744482646ae |
| EC2 | SG ECS | sg-01c619444bab0b8d3 |
| ALB | Load Balancer | dev-multicines-integration-alb |
| ALB | Target Group | dev-multicines-integration-tg |
| ACM | Certificado | *.test.multicines.com.ec |
| Route53 | Record A | dev-integration.test.multicines.com.ec |
| ECS | Service | dev-multicines-integration-svc (1 task) |
| Secrets | Secretos | platform/dev/resilience, integrator/dev/app |
| SNS | Topic | dev-multicines-integration-alarms |
| CW | Dashboard | dev-multicines-integration-dashboard |
| CW | Alarms | 7 alarmas (ver sección 11) |

## Prod

| Servicio | Recurso | ID/Nombre |
|----------|---------|-----------|
| VPC | VPC | vpc-0860a0d2cf4df6140 |
| EC2 | SG ALB | sg-04f21c4c1d065fe60 |
| EC2 | SG ECS | sg-0b78c14cd02b2f6e1 |
| ALB | Load Balancer | prod-multicines-integration-alb |
| ALB | Target Group | prod-multicines-integration-tg |
| ACM | Certificado | *.test.multicines.com.ec |
| ECS | Service | prod-multicines-integration-svc (2 tasks) |
| SNS | Topic | prod-multicines-integration-alarms |
| CW | Dashboard | prod-multicines-integration-dashboard |

---

*Fin del documento*
