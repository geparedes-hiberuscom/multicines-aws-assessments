**HIBERUS**

**Manual de Gestión de Infraestructura AWS — Multicines**

Guía operativa para la administración y monitoreo de recursos en AWS

  ------------------------------ ----------------------------------------
  **Versión**                    3.0
  **Plataforma**                 Consola de AWS / AWS CLI
  **Fecha**                      2026
  **Clasificación**              **Confidencial - Uso Interno**
  **Cuenta AWS**                 340271092920
  **Región**                     us-east-1 (Norte de Virginia)
  **Proyecto**                   multicines
  **Servicio**                   multicines-integration
  **Dominio**                    cloudmulticines.com
  ------------------------------ ----------------------------------------

---

**Tabla de Contenido**

1. [Introducción](#1-introducción)
2. [Ingreso a la Consola de AWS](#2-ingreso-a-la-consola-de-aws)
3. [Administración de Acceso (IAM)](#3-administración-de-acceso-iam)
4. [Administración de VPC](#4-administración-de-vpc)
5. [Route 53 — DNS](#5-route-53--dns)
6. [Certificados SSL — ACM](#6-certificados-ssl--acm)
7. [Application Load Balancer](#7-application-load-balancer)
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

Este documento describe la infraestructura cloud implementada en Amazon Web Services (AWS) para el proyecto Multicines. Detalla cada componente configurado, las decisiones técnicas y los pasos para la administración operativa.

## 1.2 Contexto

Multicines requiere exponer su sistema Vista API Connect hacia servicios externos de forma segura. Se implementó una capa de integración en AWS que actúa como intermediaria entre consumidores externos y el sistema on-premise, garantizando disponibilidad, seguridad y trazabilidad.

La solución contempla dos ambientes independientes (desarrollo y producción) con despliegues automatizados mediante GitHub Actions. El acceso público se realiza a través del dominio `cloudmulticines.com` con certificado SSL wildcard.

## 1.3 Inventario de Recursos

| Recurso | Nombre/ID | Ambiente |
|---------|-----------|----------|
| VPC | vpc-0a5ebea8e7bee9ed5 | dev |
| VPC | vpc-0860a0d2cf4df6140 | prod |
| ALB | dev-multicines-integration-alb | dev |
| ALB | prod-multicines-integration-alb | prod |
| ACM Certificate | *.cloudmulticines.com (ISSUED) | shared |
| Route53 Zone | cloudmulticines.com (Z02656981PPWUEVYOEMVL) | shared |
| Route53 Record | api-dev.cloudmulticines.com → ALB dev | dev |
| Route53 Record | api.cloudmulticines.com → ALB prod | prod |
| ECS Cluster | multicines-cluster | shared |
| ECS Service | dev-multicines-integration-svc (1 task) | dev |
| ECS Service | prod-multicines-integration-svc (2 tasks) | prod |
| ECR | multicines/integration-service | shared |
| Secrets | platform/dev/resilience, integrator/dev/app | dev |
| Secrets | platform/prod/resilience, integrator/prod/app | prod |
| SNS Topic | dev-multicines-integration-alarms | dev |
| SNS Topic | prod-multicines-integration-alarms | prod |
| Dashboard | dev-multicines-integration-dashboard | dev |
| Dashboard | prod-multicines-integration-dashboard | prod |
| Rol IAM | ecsTaskExecutionRole | shared |
| Rol IAM | multicines-ecs-task-role | shared |
| Rol IAM | multicines-github-actions-role | shared |

---

# 2. Ingreso a la Consola de AWS

Abrir el navegador e ingresar a: **https://signin.aws.amazon.com**

![](documents/images/media/image.png){width="5.90625in" height="3.8333333333333335in"}

## 2.1 Ingreso con usuario root

1. Seleccionar **Root user** → ingresar email → click **Next**

![](documents/images/media/image2.png){width="5.90625in" height="3.2291666666666665in"}

2. Ingresar contraseña:

![](documents/images/media/image3.png){width="5.90625in" height="3.6875in"}

3. Ingresar código MFA:

![](documents/images/media/image4.png){width="5.90625in" height="3.5416666666666665in"}

4. Dashboard de la consola:

![](documents/images/media/image5.png){width="5.90625in" height="3.1458333333333335in"}

## 2.2 Ingreso con usuario IAM

1. Seleccionar **IAM user** → Account ID: **340271092920** → **Next**

![](documents/images/media/image6.png){width="5.90625in" height="4.0625in"}

2. Ingresar usuario y contraseña → **Sign in**

![](documents/images/media/image7.png){width="5.90625in" height="4.020833333333333in"}

![](documents/images/media/image8.png){width="5.90625in" height="3.1145833333333335in"}

---

# 3. Administración de Acceso (IAM)

## 3.1 Panel de IAM

![](documents/images/media/image9.png){width="5.90625in" height="3.46875in"}

![](documents/images/media/imagea.png){width="5.90625in" height="3.4583333333333335in"}

## 3.2 Grupos IAM

![](documents/images/media/imageb.png){width="5.90625in" height="3.1354166666666665in"}

![](documents/images/media/imagec.png){width="5.90625in" height="3.0729166666666665in"}

![](documents/images/media/imaged.png){width="5.90625in" height="2.71875in"}

![](documents/images/media/imagee.png){width="5.90625in" height="2.2142913385826772in"}

![](documents/images/media/imagef.png){width="5.90625in" height="2.9791666666666665in"}

![](documents/images/media/image10.png){width="5.90625in" height="1.9479166666666667in"}

![](documents/images/media/image11.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image12.png){width="5.90625in" height="2.6770833333333335in"}

## 3.3 Usuarios IAM

![](documents/images/media/image13.png){width="5.90625in" height="3.1458333333333335in"}

![](documents/images/media/image14.png){width="5.90625in" height="3.0104166666666665in"}

![](documents/images/media/image15.png){width="5.90625in" height="2.9895833333333335in"}

![](documents/images/media/image16.png){width="5.90625in" height="2.9583333333333335in"}

![](documents/images/media/image17.png){width="5.90625in" height="2.9479166666666665in"}

![](documents/images/media/image18.png){width="5.90625in" height="2.9479166666666665in"}

![](documents/images/media/image19.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image1a.png){width="5.90625in" height="2.9375in"}

![](documents/images/media/image1b.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image1c.png){width="5.90625in" height="0.4791666666666667in"}

![](documents/images/media/image1d.png){width="5.90625in" height="2.7395833333333335in"}

## 3.4 Políticas IAM

![](documents/images/media/image1e.png){width="5.90625in" height="3.0833333333333335in"}

![](documents/images/media/image1f.png){width="5.90625in" height="3.1041666666666665in"}

## 3.5 Roles del Proyecto

| Rol | ARN | Propósito |
|-----|-----|-----------|
| ecsTaskExecutionRole | arn:aws:iam::340271092920:role/ecsTaskExecutionRole | Rol de ejecución ECS (pull ECR, logs, secrets) |
| multicines-ecs-task-role | arn:aws:iam::340271092920:role/multicines-ecs-task-role | Rol de tarea (X-Ray, SSM) |
| multicines-github-actions-role | arn:aws:iam::340271092920:role/multicines-github-actions-role | CI/CD (OIDC GitHub) |

### AWS CLI — Roles

```
aws iam create-role --role-name ecsTaskExecutionRole \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam attach-role-policy --role-name ecsTaskExecutionRole \
  --policy-arn arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy

aws iam create-role --role-name multicines-ecs-task-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ecs-tasks.amazonaws.com"},"Action":"sts:AssumeRole"}]}'

aws iam put-role-policy --role-name multicines-ecs-task-role \
  --policy-name dev-multicines-integration-xray-policy \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["xray:PutTraceSegments","xray:PutTelemetryRecords","xray:GetSamplingRules","xray:GetSamplingTargets"],"Resource":"*"}]}'
```

> **TODO: Insertar pantalla de IAM Roles mostrando los 3 roles del proyecto**


---

# 4. Administración de VPC

![](documents/images/media/image20.png){width="5.90625in" height="2.96875in"}

![](documents/images/media/image21.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image22.png){width="5.90625in" height="2.9375in"}

![](documents/images/media/image23.png){width="5.90625in" height="2.9166666666666665in"}

![](documents/images/media/image24.png){width="5.90625in" height="2.9479166666666665in"}

![](documents/images/media/image25.png){width="5.90625in" height="2.9895833333333335in"}

## 4.1 VPCs del proyecto

| VPC | ID | Ambiente |
|-----|----|----------|
| vpc-multicines-dev | vpc-0a5ebea8e7bee9ed5 | dev |
| prod-vpc-multicines | vpc-0860a0d2cf4df6140 | prod |

![](documents/images/media/image26.png){width="5.90625in" height="2.6770833333333335in"}

![](documents/images/media/image27.png){width="5.90625in" height="3.0in"}

![](documents/images/media/image28.png){width="5.90625in" height="3.0208333333333335in"}

![](documents/images/media/image29.png){width="5.90625in" height="3.59375in"}

![](documents/images/media/image2a.png){width="5.90625in" height="2.9791666666666665in"}

## 4.2 Internet Gateway

![](documents/images/media/image2b.png){width="5.90625in" height="2.09375in"}

![](documents/images/media/image2c.png){width="5.90625in" height="1.7083333333333333in"}

## 4.3 NAT Gateway

![](documents/images/media/image2d.png){width="5.90625in" height="2.4479166666666665in"}

![](documents/images/media/image2e.png){width="5.90625in" height="3.0416666666666665in"}

![](documents/images/media/image2f.png){width="5.90625in" height="2.8020833333333335in"}

## 4.4 Security Groups

| SG | ID | Ambiente |
|----|-----|----------|
| SG ALB dev | sg-0fdf0c744482646ae | dev |
| SG ECS dev | sg-01c619444bab0b8d3 | dev |
| SG ALB prod | sg-04f21c4c1d065fe60 | prod |
| SG ECS prod | sg-0b78c14cd02b2f6e1 | prod |

![](documents/images/media/image30.png){width="5.90625in" height="1.8614031058617673in"}

![](documents/images/media/image31.png){width="5.90625in" height="2.5in"}

![](documents/images/media/image32.png){width="5.90625in" height="2.7708333333333335in"}

![](documents/images/media/image33.png){width="5.90625in" height="2.84375in"}

![](documents/images/media/image34.png){width="5.90625in" height="2.8333333333333335in"}

## 4.5 Tablas de Enrutamiento

![](documents/images/media/image35.png){width="5.90625in" height="2.1041666666666665in"}

![](documents/images/media/image36.png){width="5.90625in" height="2.8229166666666665in"}

![](documents/images/media/image37.png){width="5.90625in" height="1.84375in"}

![](documents/images/media/image38.png){width="5.90625in" height="2.90625in"}

![](documents/images/media/image39.png){width="5.90625in" height="1.9895833333333333in"}

---

# 5. Route 53 — DNS

## 5.1 Hosted Zone

Dominio: `cloudmulticines.com` | Zone ID: `Z02656981PPWUEVYOEMVL`

La hosted zone fue creada automáticamente al registrar el dominio en Route53.

### Opción A: Registro de dominio en Route53 (recomendado)

1. Route 53 → **Registered domains** → **Register domains**
2. Buscar: `cloudmulticines.com`
3. Si disponible → **Select** → **Proceed to checkout**
4. Llenar datos de contacto → aceptar términos → **Submit**
5. Costo: ~$12/año (.com). AWS auto-crea la hosted zone y configura NS.

### Opción B: Crear hosted zone manualmente (dominio registrado fuera de AWS)

1. Route 53 → **Hosted zones** → **Create hosted zone**
2. Domain name: `cloudmulticines.com`
3. Type: Public hosted zone → **Create**
4. Copiar los 4 nameservers y configurarlos en el registrador externo del dominio

### AWS CLI — Crear hosted zone manual

```
aws route53 create-hosted-zone \
  --name cloudmulticines.com \
  --caller-reference "create-zone-$(date +%s)"
```

> **TODO: Insertar pantalla de la hosted zone con NS y SOA records**

## 5.2 Registros DNS

| Registro | Tipo | Target | Ambiente |
|----------|------|--------|----------|
| api-dev.cloudmulticines.com | A (Alias) | ALB dev | dev |
| api.cloudmulticines.com | A (Alias) | ALB prod | prod |

### Creación del registro (Consola Web)

1. Route 53 → Hosted zones → `cloudmulticines.com` → **Create record**
2. Record name: `api-dev` (o `api` para prod)
3. Record type: **A**
4. Toggle **Alias**: ON
5. Route traffic to: **Alias to Application and Classic Load Balancer**
6. Region: US East (N. Virginia)
7. Seleccionar el ALB del ambiente
8. Evaluate target health: **Yes**
9. Click **Create records**

### AWS CLI — Crear registro A alias

```
aws route53 change-resource-record-sets \
  --hosted-zone-id Z02656981PPWUEVYOEMVL \
  --change-batch '{
    "Changes": [{"Action": "UPSERT", "ResourceRecordSet": {
      "Name": "api-dev.cloudmulticines.com",
      "Type": "A",
      "AliasTarget": {
        "HostedZoneId": "<ALB_HOSTED_ZONE_ID>",
        "DNSName": "dev-multicines-integration-alb-1885310298.us-east-1.elb.amazonaws.com",
        "EvaluateTargetHealth": true
      }
    }}]
  }'
```

### AWS CLI — Listar records

```
aws route53 list-resource-record-sets --hosted-zone-id Z02656981PPWUEVYOEMVL
```

> **TODO: Insertar pantalla de los records dentro de la hosted zone**

---

# 6. Certificados SSL — ACM

## 6.1 Certificado wildcard (DNS validation)

| Parámetro | Valor |
|-----------|-------|
| Dominio | *.cloudmulticines.com |
| Tipo | Solicitado en ACM (DNS validation) |
| Estado | ISSUED |
| ARN | arn:aws:acm:us-east-1:340271092920:certificate/eb5ce963-b419-4672-bb8a-7ed97becfafc |
| Auto-renovación | Sí (mientras CNAME de validación exista) |
| Tags | Name=multicines-integration-acm, Environment=shared |

### Creación (Consola Web)

1. Certificate Manager → **Request certificate** → **Request a public certificate** → **Next**
2. Domain names: `*.cloudmulticines.com`
3. Validation method: **DNS validation**
4. Key algorithm: RSA 2048
5. Tags: Name=`multicines-integration-acm`, Project=`multicines`, Environment=`shared`
6. Click **Request**
7. En el certificado → **Create records in Route 53** (AWS crea el CNAME automáticamente)
8. Esperar 2-5 minutos → estado cambia a **ISSUED**

### AWS CLI — Solicitar certificado

```
aws acm request-certificate \
  --domain-name "*.cloudmulticines.com" \
  --validation-method DNS \
  --tags Key=Name,Value=multicines-integration-acm Key=Project,Value=multicines Key=Environment,Value=shared \
  --region us-east-1
```

### AWS CLI — Ver estado

```
aws acm describe-certificate \
  --certificate-arn arn:aws:acm:us-east-1:340271092920:certificate/eb5ce963-b419-4672-bb8a-7ed97becfafc \
  --region us-east-1 \
  --query "Certificate.{Status:Status,Domain:DomainName,Expiry:NotAfter}"
```

### AWS CLI — Listar certificados

```
aws acm list-certificates --region us-east-1
```

## 6.2 Renovación

El certificado se renueva automáticamente por AWS ~60 días antes de expirar, siempre que:
- El CNAME de validación DNS siga existente en la hosted zone
- El certificado esté asociado a un recurso AWS (ALB listener)

No requiere acción manual.

> **TODO: Insertar pantalla de ACM mostrando certificado ISSUED**

> **TODO: Insertar pantalla del CNAME de validación en Route53**


---

# 7. Application Load Balancer

## 7.1 ALBs existentes

| ALB | DNS | Estado |
|-----|-----|--------|
| dev-multicines-integration-alb | dev-multicines-integration-alb-1885310298.us-east-1.elb.amazonaws.com | active |
| prod-multicines-integration-alb | prod-multicines-integration-alb-43560610.us-east-1.elb.amazonaws.com | active |

### Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Tipo | application, internet-facing | application, internet-facing |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 | ELBSecurityPolicy-TLS13-1-2-2021-06 |
| Certificado | *.cloudmulticines.com | *.cloudmulticines.com |
| Listener HTTPS | 443 → Forward to TG | 443 → Forward to TG |
| Listener HTTP | 80 → Redirect HTTPS (301) | 80 → Redirect HTTPS (301) |
| Target Group | dev-multicines-integration-tg (port 8095) | prod-multicines-integration-tg (port 8095) |
| Health Check | /actuator/health:8095, interval 30s, timeout 10s, healthy 2, unhealthy 5 | (mismo) |

### Creación (Consola Web)

1. EC2 → Load Balancers → **Create Load Balancer** → Application Load Balancer
2. Name: `{env}-multicines-integration-alb`, Scheme: Internet-facing
3. Network mapping: VPC + 2 subnets públicas
4. Security groups: SG ALB del ambiente
5. Listener HTTPS:443 → certificado ACM `*.cloudmulticines.com` → SSL Policy TLS 1.3
6. Crear Target Group: IP type, port 8095, health check /actuator/health
7. Agregar listener HTTP:80 → Redirect HTTPS 301

### AWS CLI — Crear ALB

```
aws elbv2 create-load-balancer \
  --name dev-multicines-integration-alb \
  --type application --scheme internet-facing \
  --subnets subnet-0c92479c2831f04eb subnet-02193c97ceb6ec25d \
  --security-groups sg-0fdf0c744482646ae \
  --tags Key=Name,Value=dev-multicines-integration-alb Key=Project,Value=multicines Key=Environment,Value=dev \
  --region us-east-1
```

### AWS CLI — Crear Target Group

```
aws elbv2 create-target-group \
  --name dev-multicines-integration-tg \
  --protocol HTTP --port 8095 \
  --vpc-id vpc-0a5ebea8e7bee9ed5 --target-type ip \
  --health-check-protocol HTTP --health-check-port 8095 \
  --health-check-path /actuator/health \
  --health-check-interval-seconds 30 --health-check-timeout-seconds 10 \
  --healthy-threshold-count 2 --unhealthy-threshold-count 5 \
  --region us-east-1
```

### AWS CLI — Crear Listener HTTPS:443

```
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTPS --port 443 \
  --ssl-policy ELBSecurityPolicy-TLS13-1-2-2021-06 \
  --certificates CertificateArn=arn:aws:acm:us-east-1:340271092920:certificate/eb5ce963-b419-4672-bb8a-7ed97becfafc \
  --default-actions Type=forward,TargetGroupArn=<TG_ARN> \
  --region us-east-1
```

### AWS CLI — Crear Listener HTTP:80 redirect

```
aws elbv2 create-listener \
  --load-balancer-arn <ALB_ARN> \
  --protocol HTTP --port 80 \
  --default-actions 'Type=redirect,RedirectConfig={Protocol=HTTPS,Port=443,StatusCode=HTTP_301}' \
  --region us-east-1
```

> **TODO: Insertar pantalla del ALB con listeners HTTPS y HTTP**

> **TODO: Insertar pantalla del Target Group con targets healthy**

---

# 8. Secrets Manager

## 8.1 Secretos existentes

| Nombre | Ambiente |
|--------|----------|
| platform/dev/resilience | dev |
| integrator/dev/app | dev |
| platform/prod/resilience | prod |
| integrator/prod/app | prod |

### Creación (Consola Web)

1. Secrets Manager → **Store a new secret**
2. Secret type: **Other type of secret**
3. Key/value: **Plaintext** → pegar JSON compactado
4. Encryption key: aws/secretsmanager (default)
5. Secret name: ej. `platform/dev/resilience`
6. Tags: Name, Project=multicines, Environment={env}
7. Skip rotation → **Store**

### AWS CLI — Crear secreto

```
aws secretsmanager create-secret \
  --name platform/dev/resilience \
  --secret-string '{"key":"value","db_host":"..."}' \
  --tags Key=Name,Value=platform/dev/resilience Key=Project,Value=multicines Key=Environment,Value=dev \
  --region us-east-1
```

### AWS CLI — Obtener valor

```
aws secretsmanager get-secret-value --secret-id platform/dev/resilience --region us-east-1
```

### AWS CLI — Actualizar

```
aws secretsmanager update-secret --secret-id platform/dev/resilience --secret-string '{"key":"new_value"}' --region us-east-1
```

### AWS CLI — Eliminar

```
aws secretsmanager delete-secret --secret-id platform/dev/resilience --force-delete-without-recovery --region us-east-1
```

> **TODO: Insertar pantalla del listado de secretos**


---

# 9. Elastic Container Registry (ECR)

Repositorio: `multicines/integration-service`
URI: `340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service`

![](documents/images/media/image3a.png){width="5.90625in" height="3.3125in"}

![](documents/images/media/image3b.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image3c.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image3d.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image3e.png){width="5.90625in" height="3.2916666666666665in"}

### AWS CLI — ECR

```
# Login
aws ecr get-login-password --region us-east-1 | docker login --username AWS --password-stdin 340271092920.dkr.ecr.us-east-1.amazonaws.com

# Crear repositorio
aws ecr create-repository \
  --repository-name multicines/integration-service \
  --image-tag-mutability IMMUTABLE \
  --encryption-configuration encryptionType=AES256 \
  --region us-east-1

# Push imagen
docker build -t multicines/integration-service:dev-latest .
docker tag multicines/integration-service:dev-latest 340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service:dev-latest
docker push 340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service:dev-latest

# Listar imágenes
aws ecr list-images --repository-name multicines/integration-service --region us-east-1
```

---

# 10. Elastic Container Service (ECS)

## 10.1 Cluster

Cluster: **multicines-cluster** (Fargate, Container Insights activado)

![](documents/images/media/image3f.png){width="5.90625in" height="1.9028073053368328in"}

![](documents/images/media/image40.png){width="5.90625in" height="3.1354166666666665in"}

![](documents/images/media/image41.png){width="5.90625in" height="3.1145833333333335in"}

![](documents/images/media/image42.png){width="5.90625in" height="3.125in"}

![](documents/images/media/image43.png){width="5.90625in" height="1.7534787839020123in"}

### AWS CLI — Crear cluster

```
aws ecs create-cluster --cluster-name multicines-cluster --region us-east-1
```

## 10.2 Servicios ECS

| Servicio | Desired | Running | Estado |
|----------|---------|---------|--------|
| dev-multicines-integration-svc | 1 | 1 | ACTIVE |
| prod-multicines-integration-svc | 2 | 2 | ACTIVE |

## 10.3 Task Definitions

![](documents/images/media/image44.png){width="5.90625in" height="3.09375in"}

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Family | dev-multicines-integration-task | prod-multicines-integration-task |
| CPU | 512 (0.5 vCPU) | 1024 (1 vCPU) |
| Memoria | 1024 MB | 2048 MB |
| Container principal | integration-service:8095 | integration-service:8095 |
| Sidecar ADOT | aws-otel-collector:4317 | aws-otel-collector:4317 |
| Execution Role | ecsTaskExecutionRole | ecsTaskExecutionRole |
| Task Role | multicines-ecs-task-role | multicines-ecs-task-role |
| Log group | /ecs/dev-multicines-integration | /ecs/prod-multicines-integration |

![](documents/images/media/image45.png){width="5.90625in" height="2.8541666666666665in"}

![](documents/images/media/image46.png){width="5.90625in" height="2.7604166666666665in"}

![](documents/images/media/image47.png){width="5.90625in" height="3.0833333333333335in"}

## 10.4 Variables de Entorno

| Variable | Dev | Prod |
|----------|-----|------|
| SPRING_PROFILES_ACTIVE | dev | prod |
| AWS_REGION | us-east-1 | us-east-1 |
| OTEL_TRACES_EXPORTER | otlp | otlp |
| OTEL_SERVICE_NAME | integrator | integrator |
| OTEL_EXPORTER_OTLP_ENDPOINT | http://localhost:4317 | http://localhost:4317 |
| OTEL_EXPORTER_OTLP_PROTOCOL | grpc | grpc |
| OTEL_TRACES_SAMPLER | parentbased_traceidratio | parentbased_traceidratio |
| OTEL_TRACES_SAMPLER_ARG | 1.0 (100%) | 0.10 (10%) |

![](documents/images/media/image48.png){width="5.90625in" height="3.25in"}

![](documents/images/media/image49.png){width="5.90625in" height="2.875in"}

## 10.5 Sidecar ADOT (Trazas X-Ray)

| Parámetro | Valor |
|-----------|-------|
| Container | aws-otel-collector |
| Image | public.ecr.aws/aws-observability/aws-otel-collector:latest |
| Essential | No |
| Memory | 256 MB |
| Puerto | 4317/tcp (gRPC OTLP) |
| Log prefix | otel |

> **TODO: Insertar pantalla de Task Definition con 2 containers (app + otel-collector)**

![](documents/images/media/image4a.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image4b.png){width="5.90625in" height="3.2708333333333335in"}

### AWS CLI — ECS

```
# Registrar Task Definition
aws ecs register-task-definition --cli-input-json file://task-def.json --region us-east-1

# Crear servicio
aws ecs create-service \
  --cluster multicines-cluster \
  --service-name dev-multicines-integration-svc \
  --task-definition dev-multicines-integration-task \
  --launch-type FARGATE --desired-count 1 \
  --enable-execute-command \
  --network-configuration 'awsvpcConfiguration={subnets=["subnet-0eeec60453f7f9492"],securityGroups=["sg-01c619444bab0b8d3"],assignPublicIp=DISABLED}' \
  --load-balancers targetGroupArn=<TG_ARN>,containerName=integration-service,containerPort=8095 \
  --health-check-grace-period-seconds 210 \
  --region us-east-1

# Force new deployment (reiniciar tareas)
aws ecs update-service --cluster multicines-cluster --service dev-multicines-integration-svc --force-new-deployment --region us-east-1

# Esperar estabilidad
aws ecs wait services-stable --cluster multicines-cluster --services dev-multicines-integration-svc --region us-east-1

# Eliminar servicio
aws ecs update-service --cluster multicines-cluster --service dev-multicines-integration-svc --desired-count 0 --region us-east-1
aws ecs delete-service --cluster multicines-cluster --service dev-multicines-integration-svc --region us-east-1
```


---

# 11. Observabilidad — CloudWatch, X-Ray

## 11.1 SNS Topics

| Topic | ARN | Email |
|-------|-----|-------|
| dev-multicines-integration-alarms | arn:aws:sns:us-east-1:340271092920:dev-multicines-integration-alarms | alarms@multicines.com.ec |
| prod-multicines-integration-alarms | arn:aws:sns:us-east-1:340271092920:prod-multicines-integration-alarms | alarms@multicines.com.ec |

### AWS CLI — SNS

```
aws sns create-topic --name dev-multicines-integration-alarms --region us-east-1
aws sns subscribe --topic-arn <TOPIC_ARN> --protocol email --notification-endpoint alarms@multicines.com.ec --region us-east-1
```

> **TODO: Insertar pantalla del SNS Topic con suscripción confirmada**

## 11.2 CloudWatch Alarms

| Alarma | Métrica | Threshold | Período | Estado |
|--------|---------|-----------|---------|--------|
| alarm-cpu-high | AWS/ECS CPUUtilization | ≥ 80% | 300s, 2 eval | OK |
| alarm-memory-high | AWS/ECS MemoryUtilization | ≥ 80% | 300s, 2 eval | OK |
| alarm-5xx | ALB HTTPCode_Target_5XX_Count | ≥ 10 | 60s, 3 eval | INSUFFICIENT_DATA |
| alarm-4xx | ALB HTTPCode_Target_4XX_Count | ≥ 50 | 60s, 3 eval | OK |
| alarm-unhealthy-hosts | ALB UnHealthyHostCount | ≥ 1 | 60s, 2 eval | OK |
| alarm-response-time-high | ALB TargetResponseTime | ≥ 5s (dev) / 3s (prod) | 60s, 3 eval | OK |
| alarm-no-running-tasks | ECS RunningTaskCount | < 1 | 60s, 2 eval | OK |

### AWS CLI — Crear alarma (ejemplo CPU)

```
aws cloudwatch put-metric-alarm \
  --alarm-name dev-multicines-integration-alarm-cpu-high \
  --namespace AWS/ECS --metric-name CPUUtilization \
  --dimensions Name=ServiceName,Value=dev-multicines-integration-svc Name=ClusterName,Value=multicines-cluster \
  --statistic Average --period 300 --evaluation-periods 2 \
  --threshold 80 --comparison-operator GreaterThanOrEqualToThreshold \
  --alarm-actions <SNS_TOPIC_ARN> \
  --region us-east-1
```

### AWS CLI — Listar alarmas

```
aws cloudwatch describe-alarms --alarm-name-prefix dev-multicines-integration --region us-east-1
```

> **TODO: Insertar pantalla del listado de alarmas en CloudWatch**

## 11.3 CloudWatch Dashboards

| Dashboard | Ambiente |
|-----------|----------|
| dev-multicines-integration-dashboard | dev |
| prod-multicines-integration-dashboard | prod |

Widgets: CPU, Memory, Request Count, 5xx, 4xx, Response Time, Healthy/Unhealthy Hosts, Custom Metrics, Running Tasks.

### AWS CLI — Dashboard

```
aws cloudwatch put-dashboard \
  --dashboard-name dev-multicines-integration-dashboard \
  --dashboard-body file://dashboard-body.json \
  --region us-east-1
```

> **TODO: Insertar pantalla del dashboard con widgets activos**

## 11.4 Log Metric Filters

| Filter | Pattern | Metric | Namespace |
|--------|---------|--------|-----------|
| filter-5xx-errors | { $.status >= 500 } | 5xxErrors | Multicines/dev |
| filter-latency | { $.duration_ms = * } | Latency | Multicines/dev |

### AWS CLI — Metric filter

```
aws logs put-metric-filter \
  --log-group-name /ecs/dev-multicines-integration \
  --filter-name dev-multicines-integration-filter-5xx-errors \
  --filter-pattern '{ $.status >= 500 }' \
  --metric-transformations metricName=5xxErrors,metricNamespace=Multicines/dev,metricValue=1 \
  --region us-east-1
```

## 11.5 X-Ray — Trazas

El sidecar ADOT exporta trazas a X-Ray. Para visualizar:

1. X-Ray → **Traces** → filtrar por servicio: `integrator`
2. Click en una traza para ver latencia por segmento

### AWS CLI — IAM Policy X-Ray

```
aws iam put-role-policy \
  --role-name multicines-ecs-task-role \
  --policy-name dev-multicines-integration-xray-policy \
  --policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Action":["xray:PutTraceSegments","xray:PutTelemetryRecords","xray:GetSamplingRules","xray:GetSamplingTargets"],"Resource":"*"}]}'
```

> **TODO: Insertar pantalla de X-Ray Traces**

---

# 12. VPN Site-to-Site

**Estado:** No creada (IP placeholder). Se creará cuando Multicines proporcione la IP pública del router on-premise.

## 12.1 Customer Gateway

1. VPC → Customer Gateways → **Create Customer Gateway**
2. Name: `{env}-multicines-integration-cgw`
3. Routing: Static
4. IP Address: IP del router on-premise
5. BGP ASN: 65000

### AWS CLI

```
aws ec2 create-customer-gateway \
  --type ipsec.1 --public-ip <IP_ROUTER> --bgp-asn 65000 \
  --tag-specifications 'ResourceType=customer-gateway,Tags=[{Key=Name,Value=dev-multicines-integration-cgw}]' \
  --region us-east-1
```

> **TODO: Insertar pantalla de creación de Customer Gateway**

## 12.2 Virtual Private Gateway

1. VPC → Virtual Private Gateways → **Create Virtual Private Gateway**
2. Name: `{env}-multicines-integration-vgw`
3. ASN: Amazon default
4. Crear → **Actions** → **Attach to VPC** → seleccionar VPC del ambiente

### AWS CLI

```
aws ec2 create-vpn-gateway --type ipsec.1 \
  --tag-specifications 'ResourceType=vpn-gateway,Tags=[{Key=Name,Value=dev-multicines-integration-vgw}]' \
  --region us-east-1

aws ec2 attach-vpn-gateway --vpn-gateway-id <VGW_ID> --vpc-id vpc-0a5ebea8e7bee9ed5 --region us-east-1
```

> **TODO: Insertar pantalla del VGW adjunto a la VPC**

## 12.3 VPN Connection

1. VPC → Site-to-Site VPN Connections → **Create VPN Connection**
2. Name: `{env}-multicines-integration-vpn`
3. Target Gateway: VGW creado
4. Customer Gateway: CGW creado
5. Routing: Static
6. Crear → **Download Configuration** para config del router

### AWS CLI

```
aws ec2 create-vpn-connection \
  --type ipsec.1 --customer-gateway-id <CGW_ID> --vpn-gateway-id <VGW_ID> \
  --tag-specifications 'ResourceType=vpn-connection,Tags=[{Key=Name,Value=dev-multicines-integration-vpn}]' \
  --region us-east-1
```

> **TODO: Insertar pantalla de creación de VPN Connection**

## 12.4 Route Propagation

1. VPC → Route Tables → seleccionar tabla privada
2. Route propagation → **Edit** → habilitar para VGW → **Save**

### AWS CLI

```
aws ec2 enable-vgw-route-propagation --gateway-id <VGW_ID> --route-table-id <RTB_PRIVATE_ID> --region us-east-1
```

> **TODO: Insertar pantalla de Route propagation habilitado**


---

# 13. CI/CD — GitHub Actions

## 13.1 Proveedor OIDC

![](documents/images/media/image4c.png){width="5.90625in" height="2.156251093613298in"}

![](documents/images/media/image4d.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image4e.png){width="5.90625in" height="3.09375in"}

### AWS CLI — OIDC Provider

```
aws iam create-open-id-connect-provider \
  --url https://token.actions.githubusercontent.com \
  --client-id-list sts.amazonaws.com \
  --thumbprint-list 6938fd4d98bab03faadb97b34396831e3780aea1
```

## 13.2 Rol IAM para GitHub Actions

Rol: `multicines-github-actions-role` | ARN: `arn:aws:iam::340271092920:role/multicines-github-actions-role`

Políticas: AmazonECS_FullAccess + AmazonEC2ContainerRegistryPowerUser

![](documents/images/media/image4f.png){width="5.90625in" height="3.09375in"}

![](documents/images/media/image50.png){width="5.90625in" height="3.2604166666666665in"}

![](documents/images/media/image51.png){width="5.90625in" height="3.1041666666666665in"}

![](documents/images/media/image52.png){width="5.90625in" height="2.8958333333333335in"}

![](documents/images/media/image53.png){width="5.90625in" height="3.125in"}

![](documents/images/media/image54.png){width="5.90625in" height="1.8333333333333333in"}

### AWS CLI — Crear rol GitHub Actions

```
aws iam create-role --role-name multicines-github-actions-role \
  --assume-role-policy-document '{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"arn:aws:iam::340271092920:oidc-provider/token.actions.githubusercontent.com"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringLike":{"token.actions.githubusercontent.com:sub":"repo:Multicines/Capa-Media:*"}}}]}'

aws iam attach-role-policy --role-name multicines-github-actions-role --policy-arn arn:aws:iam::aws:policy/AmazonECS_FullAccess
aws iam attach-role-policy --role-name multicines-github-actions-role --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
```

## 13.3 Variables y Secrets en GitHub

| Variable | Valor |
|----------|-------|
| AWS_REGION | us-east-1 |
| ECR_REPOSITORY | multicines/integration-service |
| ECS_CLUSTER | multicines-cluster |
| DEV_TASK_DEFINITION | dev-multicines-integration-task |
| PROD_TASK_DEFINITION | prod-multicines-integration-task |
| DEV_ECS_SERVICE | dev-multicines-integration-svc |
| PROD_ECS_SERVICE | prod-multicines-integration-svc |

| Secret | Valor |
|--------|-------|
| AWS_ROLE_ARN | arn:aws:iam::340271092920:role/multicines-github-actions-role |

## 13.4 Pipeline

| Workflow | Trigger | Ambiente |
|----------|---------|----------|
| deploy-dev.yml | Push a `dev` | development |
| deploy-prod.yml | Push a `main` | production |

Flujo: Checkout → OIDC Auth → ECR Login → Build Docker → Push → Update TD → Deploy ECS → Verify → (On failure: Rollback)

## 13.5 Protección de ramas

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
| ACM | Certificado | *.cloudmulticines.com (shared) |
| Route53 | Record | api-dev.cloudmulticines.com |
| ECS | Service | dev-multicines-integration-svc (1 task) |
| Secrets | Secretos | platform/dev/resilience, integrator/dev/app |
| SNS | Topic | dev-multicines-integration-alarms |
| CW | Dashboard | dev-multicines-integration-dashboard |
| CW | Alarms | 7 alarmas activas |

## Prod

| Servicio | Recurso | ID/Nombre |
|----------|---------|-----------|
| VPC | VPC | vpc-0860a0d2cf4df6140 |
| EC2 | SG ALB | sg-04f21c4c1d065fe60 |
| EC2 | SG ECS | sg-0b78c14cd02b2f6e1 |
| ALB | Load Balancer | prod-multicines-integration-alb |
| ALB | Target Group | prod-multicines-integration-tg |
| ACM | Certificado | *.cloudmulticines.com (shared) |
| Route53 | Record | api.cloudmulticines.com |
| ECS | Service | prod-multicines-integration-svc (2 tasks) |
| Secrets | Secretos | platform/prod/resilience, integrator/prod/app |
| SNS | Topic | prod-multicines-integration-alarms |
| CW | Dashboard | prod-multicines-integration-dashboard |

---

*Fin del documento*
