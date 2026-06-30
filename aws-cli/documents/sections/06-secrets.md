## Secrets Manager

### Descripción

Se crean secretos en AWS Secrets Manager para almacenar credenciales sensibles separadas por ambiente. Los valores se leen del archivo `environments/{env}/secrets/secrets.txt` con formato key/value JSON. El nombre de cada secreto corresponde a la key completa del archivo. El JSON se compacta antes de almacenar. Los secretos son consumidos por la Task Definition de ECS para credenciales de bases de datos y APIs externas.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Buscar **Secrets Manager** en la barra de búsqueda
3. En la lista de secretos buscar por nombre del secreto
4. Click en un secreto → pestaña **Secret value** → **Retrieve secret value**
5. Pestaña **Versions** para ver historial de cambios

> **TODO: Incluir pantalla del listado de secretos en Secrets Manager**

> **TODO: Incluir pantalla del detalle de un secreto mostrando "Retrieve secret value"**

### Parámetros de Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Archivo fuente | environments/dev/secrets/secrets.txt | environments/prod/secrets/secrets.txt |
| Nombre del secreto | key completa del archivo | key completa del archivo |
| Tipo valor | JSON compactado | JSON compactado |
| Cifrado | KMS default (aws/secretsmanager) | KMS default (aws/secretsmanager) |
| Tags | Name, Project, Environment, Service | Name, Project, Environment, Service |

### Creación paso a paso (Consola Web)

1. Secrets Manager → **Store a new secret**
2. Secret type: **Other type of secret**
3. Key/value: seleccionar **Plaintext** y pegar el JSON compactado
4. Encryption key: usar default `aws/secretsmanager`
5. Click **Next**
6. Secret name: escribir la key del archivo (ej: `platform/dev/resilience`)
7. Tags: Name={key}, Project=multicines, Environment={env}, Service=multicines-integration
8. Click **Next** → Skip rotation → **Store**

> **TODO: Incluir pantalla del wizard de creación de secreto paso 1 (tipo y valor)**

### Creación via CLI (script `secrets/create.sh`)

```bash
./aws-cli/secrets/create.sh dev
```

El script parsea `secrets.txt`, verifica existencia con `describe-secret` y crea idempotentemente.

### Verificación Post-Configuración

1. Verificar que existan todos los secretos esperados del archivo
2. Click en cada secreto → **Retrieve secret value** → confirmar JSON válido
3. Validar con CLI: `aws secretsmanager get-secret-value --secret-id "{key}"`
4. Confirmar que la task definition referencia los secretos correctamente

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Secreto no encontrado | Nombre incorrecto (es case-sensitive) | Verificar nombre exacto como aparece en secrets.txt |
| AccessDeniedException | Execution role sin permisos | Agregar secretsmanager:GetSecretValue al ecsTaskExecutionRole |
| Valor vacío | Línea mal formateada en secrets.txt | Verificar formato y re-ejecutar script |
| ResourceNotFoundException | Secreto eliminado o región incorrecta | Recrear secreto o verificar región us-east-1 |
