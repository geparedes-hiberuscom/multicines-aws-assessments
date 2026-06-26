## ACM Certificate

### Descripcion

Se IMPORTA un certificado SSL/TLS en AWS Certificate Manager desde archivos PEM ubicados en
environments/{env}/certs/. El certificado cubre el dominio *.test.multicines.com.ec y se
asocia al listener HTTPS del ALB. No se solicita un certificado nuevo, se importa uno existente.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a Certificate Manager (ACM)
3. Buscar el certificado por dominio: *.test.multicines.com.ec
4. Verificar estado "Issued" y fecha de expiracion
5. Revisar pestana "Associated resources" para confirmar asociacion con ALB

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Dominio | *.test.multicines.com.ec | *.test.multicines.com.ec |
| Tipo | Imported | Imported |
| Origen certificado | environments/dev/certs/ | environments/prod/certs/ |
| Archivo certificate | certificate.pem | certificate.pem |
| Archivo private key | private-key.pem | private-key.pem |
| Archivo chain | chain.pem | chain.pem |
| Recurso asociado | dev-alb-integration | prod-alb-integration |

### Verificacion Post-Configuracion

1. En ACM verificar que el certificado tenga estado "Issued"
2. Verificar que la fecha de expiracion sea futura
3. Confirmar el dominio del certificado: *.test.multicines.com.ec
4. Verificar en el ALB listener 443 que el certificado este asociado
5. Probar: `openssl s_client -connect {alb-dns}:443 -servername integration.test.multicines.com.ec`

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Error al importar | Formato PEM incorrecto o chain incompleta | Verificar que los archivos esten en formato PEM valido |
| Certificado expirado | No se renovo a tiempo | Importar un certificado nuevo con fecha vigente |
| ERR_CERT_AUTHORITY_INVALID | Chain de certificados incompleta | Incluir toda la cadena intermedia en chain.pem |
| No se asocia al ALB | Region incorrecta | Importar en us-east-1 (misma region del ALB) |
