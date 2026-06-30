# Pendientes de Infraestructura

## DNS / Route 53

- [ ] Identificar quién administra el dominio `multicines.com.ec` (registrador externo)
- [ ] Solicitar la creación de registros NS para delegar `test.multicines.com.ec` a Route 53:
  - `ns-1155.awsdns-16.org`
  - `ns-368.awsdns-46.com`
  - `ns-770.awsdns-32.net`
  - `ns-1738.awsdns-25.co.uk`
- [ ] Validar resolución DNS: `nslookup dev-integration.test.multicines.com.ec`

## Observabilidad (CloudWatch + X-Ray)

- [ ] Habilitar X-Ray: cambiar `OTEL_TRACES_EXPORTER` de `none` a `otlp` en env.properties
- [ ] Agregar sidecar `aws-otel-collector` en la task definition de ECS
- [ ] Agregar variables OTEL faltantes: `OTEL_EXPORTER_OTLP_ENDPOINT`, `OTEL_TRACES_SAMPLER`, `OTEL_TRACES_SAMPLER_ARG`
- [ ] Verificar permisos IAM del task role: `xray:PutTraceSegments`, `xray:PutTelemetryRecords`
- [ ] Crear CloudWatch Alarms (CPU, memoria, errores 5xx)
- [ ] Crear CloudWatch Dashboard
- [ ] Crear Log Metric Filters para métricas custom

## Optimización de Costos

- [ ] Evaluar eliminar NAT Gateway en dev (usar `assignPublicIp: ENABLED` o VPC Endpoints)
- [ ] Evaluar reducir NAT Gateways en prod de 2 a 1 (trade-off: disponibilidad vs costo)
- [ ] Bajar ECS desired count a 0 cuando no se use dev (`aws ecs update-service --desired-count 0`)

## VPN Site-to-Site

- [ ] Obtener la IP pública del router/firewall de Multicines (donde está Vista)
- [ ] Obtener el BGP ASN del router (o definir si se usará static routing)
- [ ] Actualizar `VPN_CUSTOMER_IP` y `VPN_BGP_ASN` en `aws-cli/environments/{env}/env.properties`
- [ ] Ejecutar `aws-cli/vpn/create.sh dev` (y luego prod)
- [ ] Descargar configuración del túnel IPsec desde AWS y aplicarla en el router on-premises
- [ ] Validar conectividad: desde ECS hacer ping/curl al servidor Vista por IP privada
- [ ] Costo estimado: ~$36/mes por conexión VPN activa
