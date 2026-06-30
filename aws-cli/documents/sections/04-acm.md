## ACM Certificate (Certificado SSL/TLS)

### Descripción

Se importa un certificado SSL/TLS wildcard en AWS Certificate Manager para el dominio `*.test.multicines.com.ec`. Este certificado se asocia al listener HTTPS del ALB para la terminación SSL. Al ser un certificado importado (no solicitado via DNS/email), requiere renovación manual antes de su expiración.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Buscar **Certificate Manager** en la barra de búsqueda
3. En la lista de certificados buscar el dominio: `*.test.multicines.com.ec`
4. Verificar columna **Status**: debe ser "Issued"
5. Click en el certificado → revisar fecha de expiración y recursos asociados

> **TODO: Incluir pantalla del listado de certificados en ACM**

> **TODO: Incluir pantalla del detalle del certificado mostrando dominio y expiración**

### Parámetros de Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Dominio | *.test.multicines.com.ec | *.test.multicines.com.ec |
| Tipo | Imported | Imported |
| Tag Name | dev-multicines-integration-acm | prod-multicines-integration-acm |
| Archivos fuente | environments/dev/certs/ | environments/prod/certs/ |
| certificate | certificate.pem | certificate.pem |
| private-key | private-key.pem | private-key.pem |
| certificate-chain | certificate-chain.pem | certificate-chain.pem |
| Recurso asociado | ALB listener HTTPS:443 | ALB listener HTTPS:443 |
| Región | us-east-1 | us-east-1 |

### Importación paso a paso (Consola Web)

1. Certificate Manager → **Import certificate**
2. En **Certificate body**: pegar contenido de `certificate.pem`
3. En **Certificate private key**: pegar contenido de `private-key.pem`
4. En **Certificate chain**: pegar contenido de `certificate-chain.pem`
5. Click **Next** → agregar tags: Name=`{env}-multicines-integration-acm`, Project=multicines, Environment=`{env}`
6. Click **Import**

> **TODO: Incluir pantalla del formulario de importación de certificado**

### Importación via CLI (script `acm/create.sh`)

```bash
./aws-cli/acm/create.sh dev
```

El script verifica si ya existe un certificado para el dominio antes de importar. Si existe, emite `[SKIP]`.

### Verificación Post-Configuración

1. En ACM verificar que el certificado tenga estado **"Issued"**
2. Verificar que la fecha de expiración sea futura (renovar al menos 30 días antes)
3. En EC2 → Load Balancers → Listener HTTPS:443 → verificar certificado asociado
4. Probar: `openssl s_client -connect {alb-dns}:443 -servername dev-integration.test.multicines.com.ec`

### Renovación del Certificado

Al ser un certificado importado, AWS **no lo renueva automáticamente**. El proceso de renovación es:

1. Obtener nuevo certificado del proveedor SSL
2. Colocar archivos actualizados en `environments/{env}/certs/`
3. Ejecutar: `./aws-cli/acm/update.sh {env}` (re-importa el certificado manteniendo el mismo ARN)
4. No requiere re-asociar al ALB — el ARN no cambia

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Error al importar | Formato PEM incorrecto o chain incompleta | Verificar formato PEM y que la chain incluya certificados intermedios |
| Certificado expirado | No se renovó a tiempo | Importar certificado nuevo con `acm/update.sh` |
| ERR_CERT_AUTHORITY_INVALID | Chain incompleta | Incluir toda la cadena intermedia en certificate-chain.pem |
| No se asocia al ALB | Región incorrecta | El certificado debe estar en us-east-1 (misma región del ALB) |
