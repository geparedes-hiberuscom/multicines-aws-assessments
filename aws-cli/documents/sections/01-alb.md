## Application Load Balancer (ALB)

### Descripción

El Application Load Balancer distribuye el tráfico HTTPS entrante hacia las tareas ECS del servicio de integración. Se provisiona un ALB por ambiente (dev/prod) con terminación SSL mediante certificado ACM, listener HTTPS en puerto 443 con política TLS 1.3, y un listener HTTP en puerto 80 que redirige automáticamente a HTTPS (código 301). El Target Group registra las tareas Fargate por IP con health check en el endpoint Spring Boot Actuator.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Ir a **EC2** → **Load Balancers** (panel izquierdo)
3. Buscar el ALB por nombre: `dev-multicines-integration-alb` o `prod-multicines-integration-alb`
4. Pestaña **Listeners**: verificar listener HTTPS:443 con política `ELBSecurityPolicy-TLS13-1-2-2021-06`
5. Pestaña **Listeners**: verificar listener HTTP:80 con acción redirect → HTTPS 301
6. Click en el Target Group asociado: `dev-multicines-integration-tg` o `prod-multicines-integration-tg`

> **TODO: Incluir pantalla del listado de Load Balancers con el ALB seleccionado**

> **TODO: Incluir pantalla de la pestaña Listeners mostrando HTTPS:443 y HTTP:80**

### Parámetros de Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre ALB | dev-multicines-integration-alb | prod-multicines-integration-alb |
| Tipo | application | application |
| Esquema | internet-facing | internet-facing |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Subnets públicas | subnet-0c92479c2831f04eb, subnet-02193c97ceb6ec25d | subnet-04e4cd18763fd6f84, subnet-05c92a4889326c68e |
| Security Group ALB | sg-0fdf0c744482646ae | sg-04f21c4c1d065fe60 |
| SSL Policy | ELBSecurityPolicy-TLS13-1-2-2021-06 | ELBSecurityPolicy-TLS13-1-2-2021-06 |
| Certificado | ACM *.test.multicines.com.ec | ACM *.test.multicines.com.ec |

### Target Group

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre TG | dev-multicines-integration-tg | prod-multicines-integration-tg |
| Target type | ip (Fargate) | ip (Fargate) |
| Protocolo | HTTP | HTTP |
| Puerto destino | 8095 | 8095 |
| Health Check Path | /actuator/health | /actuator/health |
| Health Check Port | 8095 | 8095 |
| Health Check Interval | 30s | 30s |
| Health Check Timeout | 10s | 10s |
| Healthy Threshold | 2 | 2 |
| Unhealthy Threshold | 5 | 5 |

> **TODO: Incluir pantalla del Target Group mostrando health check configuration**

### Creación paso a paso (Consola Web)

1. EC2 → Load Balancers → **Create Load Balancer** → seleccionar "Application Load Balancer"
2. Nombre: `{env}-multicines-integration-alb`, Scheme: Internet-facing, IP address type: IPv4
3. Network mapping: seleccionar VPC y las 2 subnets públicas del ambiente
4. Security groups: seleccionar el SG del ALB (`sg-0fdf0c744482646ae` para dev)
5. Listeners: agregar HTTPS:443, seleccionar certificado ACM y política TLS 1.3
6. Target Group: **Create target group** → type: IP, port 8095, health check como tabla anterior
7. Agregar segundo listener HTTP:80 con acción **Redirect to HTTPS** (status 301)
8. Revisar y hacer click en **Create load balancer**

> **TODO: Incluir pantalla del wizard de creación del ALB paso 2 (network mapping)**

### Verificación Post-Configuración

1. En Load Balancers verificar estado **"active"**
2. En Target Groups verificar targets con estado **"healthy"**
3. Probar acceso HTTPS: `curl -k https://{alb-dns}/actuator/health`
4. Verificar redirección HTTP→HTTPS: `curl -I http://{alb-dns}` → debe retornar 301

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Target unhealthy | Health check falla en /actuator/health:8095 | Verificar que el contenedor responde en ese puerto y path |
| 502 Bad Gateway | No hay targets registrados | Verificar que el servicio ECS está corriendo y registrado en el TG |
| 503 Service Unavailable | Targets en draining | Esperar despliegue o verificar task definition |
| ERR_SSL_VERSION_OR_CIPHER_MISMATCH | Cliente no soporta TLS 1.3 | Verificar que el cliente soporte TLS 1.3 (política restrictiva) |
