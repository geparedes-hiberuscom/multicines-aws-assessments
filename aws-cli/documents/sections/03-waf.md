## WAF Web ACL

### Descripcion

Se CREA una Web ACL de AWS WAF asociada al ALB de cada ambiente. Proporciona proteccion
contra ataques comunes como SQL injection, XSS, y rate limiting. Se utilizan reglas
administradas por AWS (AWSManagedRulesCommonRuleSet) y reglas personalizadas de rate limit.

### Navegacion en Consola AWS

1. Ingresar a la consola AWS -> cuenta 340271092920, region us-east-1
2. Ir a WAF & Shield -> Web ACLs
3. Seleccionar scope "Regional" (para ALB)
4. Buscar la Web ACL por nombre: {env}-waf-integration
5. Revisar pestana Rules para ver reglas activas
6. Revisar pestana Associated AWS resources para confirmar asociacion con ALB

### Parametros de Configuracion

| Parametro | Dev | Prod |
|-----------|-----|------|
| Nombre Web ACL | dev-waf-integration | prod-waf-integration |
| Scope | REGIONAL | REGIONAL |
| Recurso asociado | dev-alb-integration | prod-alb-integration |
| Default action | Allow | Allow |
| Regla 1 | AWSManagedRulesCommonRuleSet | AWSManagedRulesCommonRuleSet |
| Regla 2 | AWSManagedRulesSQLiRuleSet | AWSManagedRulesSQLiRuleSet |
| Rate limit | 2000 req/5min | 2000 req/5min |
| Metrica CloudWatch | {env}-waf-metrics | {env}-waf-metrics |

### Verificacion Post-Configuracion

1. En Web ACLs verificar que el estado sea activo
2. Confirmar que el ALB aparece en "Associated AWS resources"
3. Revisar CloudWatch Metrics -> WAF -> verificar que se registran requests
4. Probar con una solicitud maliciosa: `curl "https://{domain}/?id=1 OR 1=1"` - debe ser bloqueada

### Troubleshooting Comun

| Problema | Causa | Solucion |
|----------|-------|----------|
| Requests legitimos bloqueados | Regla demasiado restrictiva | Revisar Sampled requests y ajustar regla a Count mode |
| WAF no bloquea ataques | Web ACL no asociada al ALB | Asociar manualmente en pestana Associated resources |
| Rate limit no funciona | Threshold muy alto | Ajustar el valor de rate limit segun trafico esperado |
| No hay metricas | Metricas deshabilitadas en regla | Habilitar CloudWatch metrics en cada regla |
