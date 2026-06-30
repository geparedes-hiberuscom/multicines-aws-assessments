## VPN Site-to-Site

### Descripción

Se establece una conexión VPN Site-to-Site por ambiente para comunicar la VPC en AWS con la red on-premise de Multicines. Se crea un Customer Gateway (CGW) con la IP pública del router on-premise, un Virtual Private Gateway (VGW) adjunto a la VPC, y una VPN Connection tipo IPSec que los asocia. Se habilita route propagation en las tablas de enrutamiento privadas.

### Navegación en Consola AWS

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Ir a **VPC** → panel izquierdo → **Site-to-Site VPN Connections**
3. Buscar la conexión: `dev-multicines-integration-vpn` o `prod-multicines-integration-vpn`
4. Pestaña **Tunnel Details**: verificar estado UP/DOWN de cada túnel
5. Panel izquierdo → **Virtual Private Gateways**: verificar adjunto a la VPC
6. Panel izquierdo → **Customer Gateways**: verificar IP del router on-premise

> **TODO: Insertar pantalla del listado de VPN Connections**

> **TODO: Insertar pantalla de Tunnel Details mostrando estado de túneles**

### Parámetros de Configuración

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre VPN | dev-multicines-integration-vpn | prod-multicines-integration-vpn |
| Nombre VGW | dev-multicines-integration-vgw | prod-multicines-integration-vgw |
| Nombre CGW | dev-multicines-integration-cgw | prod-multicines-integration-cgw |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Customer IP | IP pública del router on-premise | IP pública del router on-premise |
| BGP ASN | 65000 | 65000 |
| Tipo túnel | ipsec.1 | ipsec.1 |
| Route propagation | Habilitado en route tables privadas | Habilitado en route tables privadas |

### Creación paso a paso (Consola Web)

**1. Customer Gateway:**

1. VPC → Customer Gateways → **Create Customer Gateway**
2. Name: `{env}-multicines-integration-cgw`
3. Routing: Static
4. IP Address: IP pública del router on-premise (proporcionada por Multicines)
5. BGP ASN: 65000
6. Click **Create Customer Gateway**

> **TODO: Insertar pantalla del formulario de creación de Customer Gateway**

**2. Virtual Private Gateway:**

1. VPC → Virtual Private Gateways → **Create Virtual Private Gateway**
2. Name: `{env}-multicines-integration-vgw`
3. ASN: Amazon default ASN
4. Click **Create Virtual Private Gateway**
5. Seleccionar el VGW recién creado → **Actions** → **Attach to VPC**
6. Seleccionar la VPC del ambiente correspondiente
7. Click **Attach to VPC**

> **TODO: Insertar pantalla del VGW creado y attach a VPC**

**3. VPN Connection:**

1. VPC → Site-to-Site VPN Connections → **Create VPN Connection**
2. Name: `{env}-multicines-integration-vpn`
3. Target Gateway Type: **Virtual Private Gateway** → seleccionar el VGW creado
4. Customer Gateway: **Existing** → seleccionar el CGW creado
5. Routing Options: **Static**
6. Click **Create VPN Connection**
7. Seleccionar la conexión creada → **Download Configuration** para obtener la configuración del router on-premise

> **TODO: Insertar pantalla del wizard de creación de VPN Connection**

> **TODO: Insertar pantalla de Download Configuration**

**4. Route Propagation:**

1. VPC → Route Tables → seleccionar tabla de rutas **privada** del ambiente
2. Pestaña **Route propagation** → **Edit route propagation**
3. Habilitar propagation para el VGW creado (checkbox)
4. Click **Save**
5. Verificar en pestaña **Routes** que aparezcan las rutas hacia la red on-premise

> **TODO: Insertar pantalla de Route propagation habilitado**

### Verificación Post-Configuración

1. VPN Connections → Tunnel Details: al menos un túnel con estado **UP**
2. Route Tables privadas: verificar rutas propagadas hacia CIDR on-premise
3. CloudWatch → Métricas → AWS/VPN → TunnelState (1=UP, 0=DOWN)

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| Túnel DOWN | Config IKE/IPSec incorrecta en router on-premise | Descargar configuración desde AWS y aplicar en el router |
| Sin conectividad | Route tables sin ruta al CIDR on-premise | Verificar route propagation habilitado para el VGW |
| Túnel flapping | Dead Peer Detection timeout agresivo | Ajustar DPD timeout en ambos lados |
