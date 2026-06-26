## ECS Service y Task Definition

### Descripcion

Se CREA un servicio ECS y su task definition en el cluster existente multicines-cluster.
El servicio ejecuta la imagen Docker desde ECR (multicines/integration-service) y se registra
en el Target Group del ALB. El contenedor expone el puerto 8095 para trafico y 9000 para
health checks. Se usa Fargate como launch type.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a ECS -> Clusters -> multicines-cluster
3. Pestana Services -> buscar: {env}-integration-service
4. Click en el servicio -> pestana Tasks para ver tareas en ejecucion
5. Ir a Task Definitions -> buscar: {env}-integration-td

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Cluster | multicines-cluster | multicines-cluster |
| Nombre servicio | dev-integration-service | prod-integration-service |
| Task definition | dev-integration-td | prod-integration-td |
| Imagen ECR | multicines/integration-service | multicines/integration-service |
| Puerto aplicacion | 8095 | 8095 |
| Puerto health check | 9000 | 9000 |
| Health check path | /actuator/health | /actuator/health |
| Launch type | FARGATE | FARGATE |
| Desired count | 1 | 2 |
| Security Group ECS | sg-01c619444bab0b8d3 | sg-0b78c14cd02b2f6e1 |
| Target Group | dev-tg-integration | prod-tg-integration |

### Verificacion Post-Configuracion

1. En ECS -> multicines-cluster verificar servicio con estado "ACTIVE"
2. Verificar que las tareas esten en estado "RUNNING"
3. En Target Group verificar targets "healthy"
4. Revisar logs en CloudWatch: /ecs/{env}-integration
5. Probar endpoint: `curl https://integration.test.multicines.com.ec/actuator/health`

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Task STOPPED | Error en contenedor o falta de recursos | Revisar Stopped reason y logs en CloudWatch |
| Target unhealthy | Health check falla | Verificar que puerto 9000 responde en /actuator/health |
| ImagePullError | Permisos ECR insuficientes | Verificar politica ecr:GetDownloadUrlForLayer en execution role |
| Service inestable | Tasks reiniciando constantemente | Revisar limites de CPU/memoria y variables de entorno |
