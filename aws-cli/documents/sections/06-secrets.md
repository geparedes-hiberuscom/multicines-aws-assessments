## Secrets Manager

### Descripcion

Se CREAN secretos en AWS Secrets Manager desde el archivo environments/{env}/secrets/secrets.txt.
Cada KEY del archivo se convierte en un secreto independiente cuyo nombre es la key misma.
El valor se almacena como texto plano cifrado. Se usan para credenciales sensibles que
requieren rotacion automatica (BD, APIs externas).

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a Secrets Manager
3. Buscar secretos por prefijo: {env}/integration/
4. Seleccionar un secreto para ver su valor y metadata
5. Revisar pestana "Versions" para historial de cambios

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Prefijo nombre | dev/integration/ | prod/integration/ |
| Origen datos | environments/dev/secrets/secrets.txt | environments/prod/secrets/secrets.txt |
| Nombre del secreto | {KEY} del archivo secrets.txt | {KEY} del archivo secrets.txt |
| Tipo valor | PlainText | PlainText |
| Cifrado | KMS default (aws/secretsmanager) | KMS default (aws/secretsmanager) |
| Formato archivo | KEY=VALUE por linea | KEY=VALUE por linea |

### Verificacion Post-Configuracion

1. En Secrets Manager verificar que existan todos los secretos del archivo
2. Validar con CLI: `aws secretsmanager get-secret-value --secret-id "{env}/integration/{KEY}"`
3. Confirmar que la cantidad de secretos coincida con las lineas del archivo secrets.txt
4. Verificar que el task definition de ECS referencia los secretos correctamente
5. Revisar que el encryption key sea la esperada

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Secreto no encontrado | Nombre incorrecto en task definition | Verificar nombre exacto del secreto (es case-sensitive) |
| AccessDeniedException | ECS task role sin permisos | Agregar politica secretsmanager:GetSecretValue al execution role |
| Valor vacio | Linea mal formateada en secrets.txt | Verificar formato KEY=VALUE sin espacios extras |
| ResourceNotFoundException | Secreto eliminado o region incorrecta | Recrear secreto o verificar region us-east-1 |
