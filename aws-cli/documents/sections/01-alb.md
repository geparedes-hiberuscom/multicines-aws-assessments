## Application Load Balancer (ALB)

### Descripcion

Se CREA un Application Load Balancer por cada ambiente (dev/prod) dentro de la VPC correspondiente.
El ALB recibe trafico HTTPS en el puerto 443 y lo envia al Target Group que apunta a las tareas ECS
en el puerto 8095. Se asocia el certificado ACM para terminacion SSL.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a EC2 -> Load Balancers (panel izquierdo)
3. Buscar el ALB por nombre: {env}-alb-integration
4. Revisar pestana Listeners (puerto 443 HTTPS)
5. Revisar pestana Target Groups -> {env}-tg-integration

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Nombre ALB | dev-alb-integration | prod-alb-integration |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Security Group | sg-0fdf0c744482646ae | sg-04f21c4c1d065fe60 |
| Listener | HTTPS:443 | HTTPS:443 |
| Target Group | dev-tg-integration | prod-tg-integration |
| Puerto destino | 8095 | 8095 |
| Health Check Path | /actuator/health | /actuator/health |
| Health Check Port | 9000 | 9000 |
| Tipo | application | application |
| Esquema | internet-facing | internet-facing |

### Verificacion Post-Configuracion

1. En Load Balancers verificar estado "active"
2. En Target Groups verificar targets con estado "healthy"
3. Probar acceso HTTPS al DNS del ALB: `curl -k https://{alb-dns}/actuator/health`
4. Verificar que el listener 443 tenga el certificado ACM asociado

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Target unhealthy | Health check falla en puerto 9000 | Verificar que el contenedor expone puerto 9000 y responde en /actuator/health |
| 502 Bad Gateway | No hay targets registrados | Verificar que el servicio ECS esta corriendo y registrado en el TG |
| 503 Service Unavailable | Todos los targets estan draining | Esperar despliegue o verificar task definition |
| Timeout en conexion | Security Group no permite trafico | Verificar reglas ingress del SG del ALB (443) y del ECS (8095) |
