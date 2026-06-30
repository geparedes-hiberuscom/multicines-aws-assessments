## Route 53 (DNS)

### Descripción

Se crea una hosted zone en Route 53 para el dominio base `test.multicines.com.ec` y un registro DNS alias tipo A que apunta al ALB. El registro tiene formato `{env}-integration.{base_domain}` (ejemplo: `dev-integration.test.multicines.com.ec`). Se utiliza action UPSERT para que la operación sea idempotente. Al crear la hosted zone se emiten los nameservers de delegación que deben configurarse en el registrador de dominio.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Buscar **Route 53** en la barra de búsqueda
3. Panel izquierdo → **Hosted zones**
4. Buscar: `test.multicines.com.ec`
5. Click en la hosted zone → verificar registros tipo A (alias al ALB)

> **TODO: Incluir pantalla del listado de hosted zones**

> **TODO: Incluir pantalla de los records dentro de la hosted zone mostrando el alias A**

### Parámetros de Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Wildcard Domain (env.properties) | *.test.multicines.com.ec | *.test.multicines.com.ec |
| Base Domain (derivado) | test.multicines.com.ec | test.multicines.com.ec |
| Hosted Zone | test.multicines.com.ec | test.multicines.com.ec |
| Registro DNS | dev-integration.test.multicines.com.ec | prod-integration.test.multicines.com.ec |
| Tipo registro | A (Alias) | A (Alias) |
| Target | DNS del ALB dev | DNS del ALB prod |
| Evaluate Target Health | true | true |

### Creación paso a paso (Consola Web)

**1. Hosted Zone (si no existe):**

1. Route 53 → Hosted zones → **Create hosted zone**
2. Domain name: `test.multicines.com.ec`
3. Type: **Public hosted zone**
4. Click **Create hosted zone**
5. **IMPORTANTE:** Copiar los 4 nameservers (NS records) y configurarlos en el registrador de dominio

> **TODO: Incluir pantalla de la hosted zone recién creada mostrando NS records**

**2. Registro Alias:**

1. Dentro de la hosted zone → **Create record**
2. Record name: `dev-integration` (o `prod-integration`)
3. Record type: **A**
4. Toggle **Alias**: ON
5. Route traffic to: **Alias to Application and Classic Load Balancer**
6. Region: US East (N. Virginia)
7. Seleccionar el ALB correspondiente
8. Evaluate target health: **Yes**
9. Click **Create records**

> **TODO: Incluir pantalla del formulario de creación de record alias tipo A**

### Creación via CLI

```bash
./aws-cli/route53/create.sh dev
```

El script usa UPSERT, por lo que puede ejecutarse múltiples veces sin efecto secundario. Si la hosted zone no existe, la crea y emite los nameservers.

### Delegación de Nameservers

Al crear la hosted zone, Route 53 asigna 4 nameservers. Estos deben configurarse en el registrador del dominio `multicines.com.ec` como delegación para la subzona `test.multicines.com.ec`:

```
ns-XXXX.awsdns-XX.org
ns-XXXX.awsdns-XX.co.uk
ns-XXXX.awsdns-XX.com
ns-XXXX.awsdns-XX.net
```

Sin esta delegación, las consultas DNS no llegarán a Route 53.

### Verificación Post-Configuración

1. Hosted zone → verificar registro A alias para `{env}-integration.test.multicines.com.ec`
2. Probar resolución DNS: `nslookup dev-integration.test.multicines.com.ec`
3. Debe resolver al DNS del ALB
4. Probar acceso: `curl https://dev-integration.test.multicines.com.ec/actuator/health`

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| DNS no resuelve | Nameservers no delegados en registrador | Configurar NS records en el registrador del dominio |
| Resuelve pero timeout | ALB no accesible o SG sin ingress 443 | Verificar ALB activo y SG permite HTTPS |
| NXDOMAIN | Registro no creado | Ejecutar route53/create.sh o crear manualmente |
| Propagación lenta | TTL alto o cache DNS | Esperar TTL o flush DNS local: `ipconfig /flushdns` |
