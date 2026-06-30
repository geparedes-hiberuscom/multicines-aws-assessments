## ECS Service y Task Definition

### Descripción

Se registra una Task Definition y se crea un servicio ECS Fargate en el cluster `multicines-cluster`. El servicio ejecuta la imagen Docker del repositorio ECR `multicines/integration-service` y se registra en el Target Group del ALB. Utiliza subnets privadas con assignPublicIp=DISABLED, health check grace period de 210 segundos para dar tiempo de arranque a Spring Boot, y Execute Command habilitado para troubleshooting.

Cuando la variable `OTEL_TRACES_EXPORTER=otlp` está configurada, la Task Definition incluye un sidecar **AWS Distro for OpenTelemetry (ADOT)** que recolecta trazas distribuidas y las exporta a AWS X-Ray.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Buscar **ECS** → click en **Clusters** → `multicines-cluster`
3. Pestaña **Services** → buscar: `dev-multicines-integration-svc` o `prod-multicines-integration-svc`
4. Click en el servicio → pestaña **Tasks** para ver tareas en ejecución
5. Click en una tarea → pestaña **Containers** para ver contenedor principal + sidecar OTEL
6. Para Task Definitions: panel izquierdo → **Task definitions** → buscar: `dev-multicines-integration-task`

> **TODO: Incluir pantalla del cluster multicines-cluster con servicios listados**

> **TODO: Incluir pantalla del detalle del servicio mostrando tareas RUNNING**

> **TODO: Incluir pantalla de la Task Definition mostrando 2 containers (app + otel-collector)**

### Parámetros del Servicio ECS

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Cluster | multicines-cluster | multicines-cluster |
| Nombre servicio | dev-multicines-integration-svc | prod-multicines-integration-svc |
| Launch type | FARGATE | FARGATE |
| Desired count | 1 | 2 |
| Health check grace period | 210s | 210s |
| Execute command | Habilitado | Habilitado |
| Subnets | subnet-0eeec60453f7f9492 (privada) | subnet-0d55ebfe5adbd4e81, subnet-04f8ac3335c426f57 (privadas) |
| Security Group | sg-01c619444bab0b8d3 | sg-0b78c14cd02b2f6e1 |
| assignPublicIp | DISABLED | DISABLED |
| Target Group | dev-multicines-integration-tg | prod-multicines-integration-tg |

### Parámetros de la Task Definition

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Family | dev-multicines-integration-task | prod-multicines-integration-task |
| Network mode | awsvpc | awsvpc |
| Compatibilidad | FARGATE | FARGATE |
| CPU | 512 (0.5 vCPU) | 1024 (1 vCPU) |
| Memoria | 1024 MB | 2048 MB |
| Execution Role | arn:aws:iam::340271092920:role/ecsTaskExecutionRole | (mismo) |
| Task Role | arn:aws:iam::340271092920:role/multicines-ecs-task-role | (mismo) |

### Contenedor Principal

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre | integration-service | integration-service |
| Imagen | 340271092920.dkr.ecr.us-east-1.amazonaws.com/multicines/integration-service:{tag} | (mismo repo) |
| Puerto | 8095/tcp | 8095/tcp |
| Log group | /ecs/dev-multicines-integration | /ecs/prod-multicines-integration |
| Log stream prefix | api | api |

### Variables de Entorno del Contenedor Principal

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
| OTEL_TRACES_SAMPLER_ARG | 1.0 (100% muestreo) | 0.10 (10% muestreo) |

### Sidecar ADOT Collector (condicional: solo si OTEL_TRACES_EXPORTER=otlp)

| Parámetro | Valor |
|-----------|-------|
| Nombre | aws-otel-collector |
| Imagen | public.ecr.aws/aws-observability/aws-otel-collector:latest |
| Essential | false |
| Memoria | 256 MB |
| Puerto | 4317/tcp (gRPC OTLP) |
| Log group | Mismo que contenedor principal |
| Log stream prefix | otel |

El sidecar recibe trazas del contenedor principal via localhost:4317 y las exporta a AWS X-Ray. Si `OTEL_TRACES_EXPORTER=none`, el sidecar NO se incluye en la Task Definition.

> **TODO: Incluir pantalla del JSON de la Task Definition mostrando containerDefinitions con 2 containers**

### Creación paso a paso (Consola Web)

**Task Definition:**

1. ECS → Task definitions → **Create new task definition**
2. Family: `{env}-multicines-integration-task`
3. Launch type: AWS Fargate
4. Task role: `multicines-ecs-task-role`, Execution role: `ecsTaskExecutionRole`
5. CPU: 512 (dev) / 1024 (prod), Memory: 1024 (dev) / 2048 (prod)
6. Container 1 (principal): nombre=`integration-service`, imagen=ECR URI, port=8095
7. Agregar variables de entorno como tabla anterior
8. Log configuration: awslogs, group=`/ecs/{env}-multicines-integration`, prefix=`api`
9. **Add container** → Container 2 (sidecar): nombre=`aws-otel-collector`, imagen=ADOT pública, essential=false, memory=256, port=4317
10. Click **Create**

> **TODO: Incluir pantalla del formulario de Task Definition con container principal configurado**

**Service:**

1. ECS → Clusters → `multicines-cluster` → **Create service**
2. Launch type: FARGATE
3. Task definition: seleccionar la family recién creada
4. Service name: `{env}-multicines-integration-svc`
5. Desired tasks: 1 (dev) / 2 (prod)
6. Networking: seleccionar subnets privadas, SG ECS, Public IP=OFF
7. Load balancing: seleccionar ALB existente y Target Group
8. Health check grace period: 210
9. Habilitar **Enable Execute Command**
10. Click **Create service**

> **TODO: Incluir pantalla del wizard de creación de servicio paso networking**

### Creación via CLI

```bash
./aws-cli/ecs/create.sh dev    # Crea TD + Service
./aws-cli/ecs/update.sh dev    # Nueva revisión TD + update service + wait stable
```

### Verificación Post-Configuración

1. En ECS → cluster → servicio: verificar **Running count** = Desired count
2. Pestaña Tasks: todas las tareas deben estar en estado **RUNNING**
3. Click en una tarea → Containers: verificar `integration-service` (RUNNING) y `aws-otel-collector` (RUNNING)
4. Target Group: targets en estado **healthy**
5. CloudWatch Logs: verificar logs en `/ecs/{env}-multicines-integration` con prefijos `api` y `otel`
6. X-Ray: ir a AWS X-Ray → Traces para ver trazas distribuidas

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Task STOPPED | Error en contenedor o OOM | Revisar Stopped reason en ECS y logs en CloudWatch |
| Target unhealthy | Health check timeout (210s insuficiente) | Verificar que Spring Boot inicia en menos de 210s |
| ImagePullError | Permisos ECR insuficientes | Verificar política ecr:GetDownloadUrlForLayer en execution role |
| Sidecar OTEL crash | Permisos X-Ray insuficientes | Verificar inline policy xray en task role (observability module) |
| No hay trazas en X-Ray | OTEL_TRACES_EXPORTER=none | Verificar env.properties tiene `otlp` y re-deploy con update.sh |
| Service inestable | Tasks reiniciando | Verificar logs, aumentar CPU/memoria si OOM |
