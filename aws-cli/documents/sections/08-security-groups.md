## Security Groups

### Descripcion

Los Security Groups ya EXISTEN y NO se crean nuevos. El modulo security-groups solo
MODIFICA las reglas de egress para endurecerlos: revoca la regla permisiva por defecto
(0.0.0.0/0 all traffic) y agrega reglas restrictivas que permiten unicamente el trafico
necesario. Hay dos SGs por ambiente: uno para el ALB y otro para las tareas ECS.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a VPC -> Security Groups (panel izquierdo)
3. Buscar por ID del SG: ver tabla de parametros abajo
4. Seleccionar el SG -> pestana "Outbound rules"
5. Verificar que NO exista la regla 0.0.0.0/0 All traffic
6. Verificar que las reglas restrictivas esten presentes

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| SG ALB | sg-0fdf0c744482646ae | sg-04f21c4c1d065fe60 |
| SG ECS | sg-01c619444bab0b8d3 | sg-0b78c14cd02b2f6e1 |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Accion | Revocar egress 0.0.0.0/0 | Revocar egress 0.0.0.0/0 |
| Egress ALB -> ECS | TCP 8095 al SG ECS | TCP 8095 al SG ECS |
| Egress ECS -> HTTPS | TCP 443 a 0.0.0.0/0 | TCP 443 a 0.0.0.0/0 |
| Egress ECS -> DB | TCP 1433 CIDR on-premise | TCP 1433 CIDR on-premise |

### Verificacion Post-Configuracion

1. En el SG del ALB verificar Outbound: solo TCP 8095 hacia SG ECS
2. En el SG de ECS verificar Outbound: TCP 443 (HTTPS) y TCP 1433 (SQL Server)
3. Confirmar que la regla permisiva (All traffic 0.0.0.0/0) fue eliminada de egress
4. Probar conectividad del servicio: health check debe seguir respondiendo
5. Validar con CLI: `aws ec2 describe-security-groups --group-ids {sg-id}`

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Servicio sin conectividad | Regla egress eliminada sin reemplazarla | Agregar regla egress especifica para el destino requerido |
| Target unhealthy | ALB no puede alcanzar ECS por egress | Verificar regla egress ALB -> ECS en puerto 8095 |
| Error conexion BD | Falta regla egress al CIDR de BD | Agregar regla TCP 1433 hacia CIDR on-premise |
| Timeout en APIs externas | Falta regla egress HTTPS 443 | Agregar regla TCP 443 a 0.0.0.0/0 en SG ECS |
