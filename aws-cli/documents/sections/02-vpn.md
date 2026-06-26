## VPN Site-to-Site

### Descripcion

Se CREA una conexion VPN Site-to-Site por cada ambiente para establecer comunicacion segura
entre la VPC en AWS y la red on-premise de Multicines. Se configura un Customer Gateway (CGW)
con la IP publica del router on-premise y un Virtual Private Gateway (VGW) adjunto a la VPC.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a VPC -> Site-to-Site VPN Connections (panel izquierdo)
3. Buscar la conexion por nombre: {env}-vpn-integration
4. Revisar pestana Tunnel Details para verificar estado de tuneles
5. Ir a Virtual Private Gateways -> verificar adjunto a la VPC
6. Ir a Customer Gateways -> verificar IP del router on-premise

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Nombre VPN | dev-vpn-integration | prod-vpn-integration |
| VPC | vpc-0a5ebea8e7bee9ed5 | vpc-0860a0d2cf4df6140 |
| Nombre VGW | dev-vgw-integration | prod-vgw-integration |
| Nombre CGW | dev-cgw-integration | prod-cgw-integration |
| Tipo routing | static | static |
| Static routes | CIDR red on-premise | CIDR red on-premise |
| Tipo tunel | ipsec.1 | ipsec.1 |

### Verificacion Post-Configuracion

1. En VPN Connections verificar que al menos un tunel tenga estado "UP"
2. Revisar Tunnel Details - ambos tuneles deben mostrar Status: UP
3. Desde una instancia en la VPC, hacer ping a un host on-premise
4. Verificar route tables de la VPC incluyan rutas hacia la red on-premise via VGW

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Tunel DOWN | Configuracion IKE/IPSec incorrecta en router on-premise | Descargar configuracion desde AWS y aplicar en el router |
| No hay conectividad | Route tables sin ruta al CIDR on-premise | Agregar ruta estatica en la route table apuntando al VGW |
| Tunel flapping | Dead Peer Detection agresivo | Ajustar DPD timeout en ambos lados |
| Un solo tunel UP | Configuracion incompleta del segundo tunel | Configurar ambos tuneles en el router on-premise |
