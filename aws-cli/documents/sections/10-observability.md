## Observabilidad (CloudWatch Alarms, Dashboard, X-Ray)

### Descripción

El módulo de observabilidad provisiona el monitoreo completo del servicio de integración:

- **SNS Topic** para notificaciones de alarmas por email
- **8 CloudWatch Alarms** para métricas críticas (CPU, memoria, 5xx, 4xx, unhealthy hosts, response time, running tasks, VPN tunnel)
- **2 Log Metric Filters** para extraer métricas custom de los logs (errores 5xx y latencia)
- **CloudWatch Dashboard** con 10 widgets para visualización unificada
- **IAM Policy X-Ray** para que el sidecar ADOT exporte trazas distribuidas

### Navegación en Consola AWS

**Dashboard:**

1. Ingresar a la consola AWS → cuenta 340271092920, región us-east-1
2. Buscar **CloudWatch** → panel izquierdo → **Dashboards**
3. Click en: `dev-multicines-integration-dashboard` o `prod-multicines-integration-dashboard`

> **TODO: Incluir pantalla del dashboard completo mostrando todos los widgets**

**Alarmas:**

1. CloudWatch → panel izquierdo → **Alarms** → **All alarms**
2. Filtrar por prefijo: `dev-multicines-integration-alarm` o `prod-multicines-integration-alarm`

> **TODO: Incluir pantalla del listado de alarmas filtradas por prefijo**

**X-Ray Traces:**

1. Buscar **X-Ray** en la barra de búsqueda → **Traces**
2. Filtrar por service: `integrator`
3. Click en una traza para ver el flujo distribuido completo

> **TODO: Incluir pantalla de X-Ray Traces mostrando una traza del servicio integrator**

### SNS Topic para Alarmas

| Parámetro | Dev | Prod |
|-----------|-----|------|
| Nombre topic | dev-multicines-integration-alarms | prod-multicines-integration-alarms |
| Protocolo | email | |
| Email suscriptor | alarms@multicines.com.ec | alarms@multicines.com.ec |

**Nota:** Tras crear la suscripción, se recibe un email de confirmación de AWS SNS. Se debe hacer click en "Confirm subscription" para activar las notificaciones.

> **TODO: Incluir pantalla del SNS Topic con la suscripción email**

### Creación del SNS Topic (Consola Web)

1. Buscar **SNS** → **Topics** → **Create topic**
2. Type: Standard
3. Name: `{env}-multicines-integration-alarms`
4. Tags: Name, Project, Environment, Service
5. Click **Create topic**
6. En el topic → **Create subscription** → Protocol: Email → Endpoint: `alarms@multicines.com.ec`
7. Click **Create subscription** → confirmar via email

> **TODO: Incluir pantalla del formulario de creación del SNS topic**

### CloudWatch Alarms

| Alarma | Métrica | Namespace | Threshold | Período | Evaluaciones |
|--------|---------|-----------|-----------|---------|--------------|
| alarm-cpu-high | CPUUtilization | AWS/ECS | 80% | 300s | 2 |
| alarm-memory-high | MemoryUtilization | AWS/ECS | 80% | 300s | 2 |
| alarm-5xx | HTTPCode_Target_5XX_Count | AWS/ApplicationELB | 10 | 60s | 3 |
| alarm-4xx | HTTPCode_Target_4XX_Count | AWS/ApplicationELB | 50 | 60s | 3 |
| alarm-unhealthy-hosts | UnHealthyHostCount | AWS/ApplicationELB | 1 | 60s | 2 |
| alarm-response-time-high | TargetResponseTime | AWS/ApplicationELB | 5s (dev) / 3s (prod) | 60s | 3 |
| alarm-no-running-tasks | RunningTaskCount | ECS/ContainerInsights | < 1 | 60s | 2 |
| alarm-vpn-tunnel-down | TunnelState | AWS/VPN | < 1 | 60s | 2 |

**Nota:** La alarma VPN solo se crea cuando `VPN_CUSTOMER_IP` no es placeholder (`0.0.0.0`).

### Creación de una Alarma (Consola Web — ejemplo CPU)

1. CloudWatch → Alarms → **Create alarm**
2. **Select metric** → AWS/ECS → ClusterName, ServiceName
3. Seleccionar CPUUtilization para el servicio `{env}-multicines-integration-svc`
4. Statistic: Average, Period: 5 minutes
5. Click **Select metric**
6. Conditions: Greater/Equal than → 80
7. Click **Next**
8. Notification: In alarm → Select SNS topic → `{env}-multicines-integration-alarms`
9. Click **Next**
10. Alarm name: `{env}-multicines-integration-alarm-cpu-high`
11. Click **Create alarm**

> **TODO: Incluir pantalla del wizard de creación de alarma paso "Select metric"**

> **TODO: Incluir pantalla del paso "Conditions" con threshold configurado**

### Log Metric Filters

| Filter | Pattern | Metric Name | Namespace | Log Group |
|--------|---------|-------------|-----------|-----------|
| filter-5xx-errors | `{ $.status >= 500 }` | 5xxErrors | Multicines/{env} | /ecs/{env}-multicines-integration |
| filter-latency | `{ $.duration_ms = * }` | Latency | Multicines/{env} | /ecs/{env}-multicines-integration |

### Creación de Metric Filter (Consola Web — ejemplo 5xx)

1. CloudWatch → Logs → Log groups → `/ecs/{env}-multicines-integration`
2. Pestaña **Metric filters** → **Create metric filter**
3. Filter pattern: `{ $.status >= 500 }`
4. Click **Test pattern** para validar contra logs existentes
5. Click **Next**
6. Filter name: `{env}-multicines-integration-filter-5xx-errors`
7. Metric namespace: `Multicines/{env}`
8. Metric name: `5xxErrors`
9. Metric value: `1`
10. Click **Create metric filter**

> **TODO: Incluir pantalla del formulario de creación de metric filter**

### CloudWatch Dashboard — Widgets

El dashboard `{env}-multicines-integration-dashboard` contiene:

| Widget | Métrica | Tipo |
|--------|---------|------|
| ECS CPU Utilization | AWS/ECS CPUUtilization | Line |
| ECS Memory Utilization | AWS/ECS MemoryUtilization | Line |
| ALB Request Count | ApplicationELB RequestCount | Line |
| ALB 5xx Error Rate | ApplicationELB HTTPCode_Target_5XX_Count | Line |
| ALB Target Response Time | ApplicationELB TargetResponseTime | Line |
| Healthy / Unhealthy Hosts | ApplicationELB HealthyHostCount + UnHealthyHostCount | Line |
| Custom Metrics | Multicines/{env} 5xxErrors + Latency | Line |
| ECS Running Task Count | ECS/ContainerInsights RunningTaskCount | Line |
| ALB 4xx Error Count | ApplicationELB HTTPCode_Target_4XX_Count | Line |
| VPN Tunnel State | AWS/VPN TunnelState | Line |

Todos los widgets usan período de 5 minutos y región us-east-1.

### IAM Policy X-Ray

Se agrega una inline policy al task role para que el sidecar ADOT pueda exportar trazas:

| Parámetro | Valor |
|-----------|-------|
| Policy name | {env}-multicines-integration-xray-policy |
| Role | multicines-ecs-task-role |
| Actions | xray:PutTraceSegments, xray:PutTelemetryRecords, xray:GetSamplingRules, xray:GetSamplingTargets |
| Resource | * |

### Creación de la IAM Policy (Consola Web)

1. IAM → Roles → buscar `multicines-ecs-task-role`
2. Pestaña **Permissions** → **Add permissions** → **Create inline policy**
3. Service: X-Ray
4. Actions: PutTraceSegments, PutTelemetryRecords, GetSamplingRules, GetSamplingTargets
5. Resources: All resources
6. Click **Next** → Policy name: `{env}-multicines-integration-xray-policy`
7. Click **Create policy**

> **TODO: Incluir pantalla de la inline policy X-Ray en el rol multicines-ecs-task-role**

### Creación via CLI

```bash
./aws-cli/observability/create.sh dev    # Crea todo: SNS + Alarms + Filters + Dashboard + IAM
./aws-cli/observability/update.sh dev    # Re-aplica (todos los APIs son idempotentes)
./aws-cli/observability/delete.sh dev    # Elimina todo en orden inverso
```

### Verificación Post-Configuración

1. **Dashboard:** CloudWatch → Dashboards → verificar que muestre datos
2. **Alarmas:** CloudWatch → Alarms → todas deben estar en estado OK (verde)
3. **SNS:** Confirmar suscripción email (revisar inbox/spam de alarms@multicines.com.ec)
4. **Metric Filters:** CloudWatch → Logs → Log group → pestaña Metric filters
5. **X-Ray:** X-Ray → Traces → verificar trazas del servicio `integrator`
6. **IAM:** IAM → Roles → multicines-ecs-task-role → verificar inline policy xray

### Troubleshooting

| Problema | Causa | Solución |
|----------|-------|----------|
| No llegan emails de alarma | Suscripción SNS no confirmada | Buscar email de confirmación de AWS en inbox/spam |
| Alarma en INSUFFICIENT_DATA | Servicio no emite métrica aún | Esperar a que haya tráfico; verificar servicio está running |
| Dashboard sin datos | Período sin actividad o servicio apagado | Generar tráfico de prueba con curl al endpoint |
| No hay trazas en X-Ray | OTEL_TRACES_EXPORTER=none o sidecar no corre | Verificar env.properties y que container otel-collector esté RUNNING |
| Metric filters sin datos | Logs no están en formato JSON esperado | Verificar que la app emite logs con campos `status` y `duration_ms` |
| Alarma VPN no creada | IP placeholder 0.0.0.0 | Se crea automáticamente al configurar IP real en env.properties |
