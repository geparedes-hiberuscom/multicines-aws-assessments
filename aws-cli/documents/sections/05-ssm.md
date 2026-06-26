## SSM Parameter Store

### Descripcion

Se CREAN parametros en AWS Systems Manager Parameter Store desde el archivo
environments/{env}/secrets/secrets.txt. Cada linea del archivo define un parametro con
formato KEY=VALUE. Los parametros se almacenan como SecureString cifrados con la KMS key
por defecto. Se usan para configuracion de la aplicacion en ECS.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a Systems Manager -> Parameter Store (panel izquierdo)
3. Filtrar por prefijo: /{env}/integration/
4. Seleccionar un parametro para ver su tipo, valor y version
5. Verificar que el tipo sea SecureString

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Prefijo | /dev/integration/ | /prod/integration/ |
| Origen datos | environments/dev/secrets/secrets.txt | environments/prod/secrets/secrets.txt |
| Tipo | SecureString | SecureString |
| KMS Key | aws/ssm (default) | aws/ssm (default) |
| Formato archivo | KEY=VALUE por linea | KEY=VALUE por linea |
| Nombre parametro | /{env}/integration/{KEY} | /{env}/integration/{KEY} |

### Verificacion Post-Configuracion

1. En Parameter Store buscar por prefijo /{env}/integration/
2. Verificar que la cantidad de parametros coincida con lineas en secrets.txt
3. Verificar que el tipo sea SecureString en todos
4. Validar con CLI: `aws ssm get-parameter --name "/{env}/integration/{KEY}" --with-decryption`
5. Confirmar que el task definition de ECS referencia los parametros correctamente

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Parametro no encontrado | Prefijo incorrecto en task definition | Verificar que el path coincida: /{env}/integration/{KEY} |
| AccessDeniedException | ECS task role sin permisos ssm:GetParameters | Agregar politica de acceso a SSM en el task execution role |
| Valor incorrecto | Archivo secrets.txt desactualizado | Actualizar el archivo y ejecutar el script de creacion nuevamente |
| KMS decrypt error | Task role sin permiso kms:Decrypt | Agregar permiso kms:Decrypt para la key aws/ssm |
