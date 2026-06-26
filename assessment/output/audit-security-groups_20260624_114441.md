# Auditoría de Security Groups - Multicines AWS

**Fecha:** 2026-06-24 16:44:46 UTC
**Región:** us-east-1

---

## Resumen Ejecutivo

| Métrica | Valor |
|---------|-------|
| Total Security Groups | 8 |
| Total reglas de ingress | 9 |
| Total reglas de egress | 9 |
| SGs con problemas de seguridad | 8 |
| SGs sin problemas | 0 |
| Total problemas identificados | 10 |

## Problemas por Severidad

| Severidad | Cantidad |
|-----------|----------|
| 🔴 CRITICAL | 1 |
| 🟠 HIGH | 0 |
| 🟡 MEDIUM | 0 |
| 🟢 LOW | 9 |

## Problemas de Seguridad Identificados

### 🔴 CRITICAL (1)

1. **prod-sg-vpn** (`sg-0bd705b1fd4514783`) - INGRESS
   - Problema: All traffic allowed from anywhere (0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Source: 0.0.0.0/0`

### 🟢 LOW (9)

1. **prod-sg-alb** (`sg-04f21c4c1d065fe60`) - INGRESS
   - Problema: HTTP (port 80) open to the internet - should redirect to HTTPS
   - Detalle: `Protocol: tcp, Port: 80-80, Source: 0.0.0.0/0`

2. **prod-sg-alb** (`sg-04f21c4c1d065fe60`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

3. **prod-sg-vpn** (`sg-0bd705b1fd4514783`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

4. **default** (`sg-0b19eae99c365c720`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

5. **dev-sg-ecs** (`sg-01c619444bab0b8d3`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

6. **prod-sg-ecs** (`sg-0b78c14cd02b2f6e1`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

7. **dev-sg-alb** (`sg-0fdf0c744482646ae`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

8. **default** (`sg-0af4ff8abd9aec744`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

9. **default** (`sg-0adf5805a777a592c`) - EGRESS
   - Problema: Unrestricted outbound traffic (all protocols to 0.0.0.0/0)
   - Detalle: `Protocol: ALL, Ports: ALL, Destination: 0.0.0.0/0`

---

## Detalle por Security Group

### prod-sg-alb (`sg-04f21c4c1d065fe60`) ⚠️ (2 problemas)

- **VPC:** `vpc-0860a0d2cf4df6140`
- **Descripción:** Grupo de seguridad para ALB
- **Reglas ingress:** 2
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| TCP | 80 | `0.0.0.0/0` | cidr_ipv4 |  |
| TCP | 443 | `0.0.0.0/0` | cidr_ipv4 |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### prod-sg-vpn (`sg-0bd705b1fd4514783`) ⚠️ (2 problemas)

- **VPC:** `vpc-059518f8ed756e6e6`
- **Descripción:** Grupo de seguridad para la VPN
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### default (`sg-0b19eae99c365c720`) ⚠️ (1 problemas)

- **VPC:** `vpc-059518f8ed756e6e6`
- **Descripción:** default VPC security group
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| ALL | ALL | `sg-0b19eae99c365c720` | security_group |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### dev-sg-ecs (`sg-01c619444bab0b8d3`) ⚠️ (1 problemas)

- **VPC:** `vpc-0a5ebea8e7bee9ed5`
- **Descripción:** Tasks Fargate DEV - entrada solo desde el ALB
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| TCP | 8095 | `sg-0fdf0c744482646ae` | security_group | entrada solo desde el ALB |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### prod-sg-ecs (`sg-0b78c14cd02b2f6e1`) ⚠️ (1 problemas)

- **VPC:** `vpc-0860a0d2cf4df6140`
- **Descripción:** Grupo de seguridad para ECS Fargate
- **Reglas ingress:** 1
- **Reglas egress:** 2

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| TCP | 8095 | `sg-04f21c4c1d065fe60` | security_group |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |
| TCP | 443 | `0.0.0.0/0` | cidr_ipv4 |  |

---

### dev-sg-alb (`sg-0fdf0c744482646ae`) ⚠️ (1 problemas)

- **VPC:** `vpc-0a5ebea8e7bee9ed5`
- **Descripción:** ALB DEV - entrada HTTPs desde Trade
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| TCP | 443 | `0.0.0.0/0` | cidr_ipv4 | IP Trade |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### default (`sg-0af4ff8abd9aec744`) ⚠️ (1 problemas)

- **VPC:** `vpc-0a5ebea8e7bee9ed5`
- **Descripción:** default VPC security group
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| ALL | ALL | `sg-0af4ff8abd9aec744` | security_group |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

### default (`sg-0adf5805a777a592c`) ⚠️ (1 problemas)

- **VPC:** `vpc-0860a0d2cf4df6140`
- **Descripción:** default VPC security group
- **Reglas ingress:** 1
- **Reglas egress:** 1

**Reglas de Ingress:**

| Protocolo | Puerto(s) | Origen | Tipo | Descripción |
|-----------|-----------|--------|------|-------------|
| ALL | ALL | `sg-0adf5805a777a592c` | security_group |  |

**Reglas de Egress:**

| Protocolo | Puerto(s) | Destino | Tipo | Descripción |
|-----------|-----------|---------|------|-------------|
| ALL | ALL | `0.0.0.0/0` | cidr_ipv4 |  |

---

## Recomendaciones

1. **ALB Security Group:** Permitir ingress solo HTTPS (443) desde 0.0.0.0/0 — WAF filtra el tráfico
2. **ECS Security Group:** Permitir ingress solo desde el ALB SG en puerto 8095
3. **ECS Egress:** Si VPN disponible, permitir solo tráfico hacia CIDR on-premise; sino, solo VPC Endpoints AWS
4. Eliminar reglas con 0.0.0.0/0 en puertos que no sean 443 (HTTPS)
5. Reemplazar reglas con rangos de puertos amplios por reglas específicas
6. Documentar el propósito de cada regla usando el campo Description
7. Implementar Security Groups con Terraform para control versionado
