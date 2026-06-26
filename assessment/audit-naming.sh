#!/bin/bash
#
# audit-naming.sh - AuditorÃ­a de nomenclatura de recursos AWS para Multicines
#
# Este script evalÃºa la nomenclatura actual de cada recurso AWS contra el
# patrÃ³n estÃ¡ndar: {proyecto}-{servicio}-{ambiente}-{recurso}
# Ejemplo esperado: multicines-integrator-dev-vpc
#
# Utiliza AWS CLI para obtener nombres de recursos (desde Name tags e
# identificadores de recurso) y genera un reporte de cumplimiento.
#
# Requisitos:
#   - AWS CLI v2 instalado y configurado
#   - python3 disponible
#   - Permisos de lectura (describe/list) sobre la cuenta AWS
#
# Uso:
#   ./assessment/audit-naming.sh
#   AWS_REGION=us-west-2 ./assessment/audit-naming.sh
#

set -euo pipefail

# ConfiguraciÃ³n
AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUTPUT_DIR}/audit-naming_${TIMESTAMP}.json"
REPORT_FILE="${OUTPUT_DIR}/audit-naming_${TIMESTAMP}.md"

# PatrÃ³n de nomenclatura esperado
NAMING_PATTERN="{proyecto}-{servicio}-{ambiente}-{recurso}"
PROJECT_NAME="multicines"

# Colores para output en consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# --- Funciones auxiliares ---

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

log_success() {
    echo -e "${GREEN}[OK]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_header() {
    echo -e "${CYAN}${BOLD}$1${NC}" >&2
}


# --- ValidaciÃ³n de prerequisitos ---

check_prerequisites() {
    log_info "Verificando prerequisitos..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no estÃ¡ instalado. InstÃ¡lelo desde https://aws.amazon.com/cli/"
        exit 1
    fi

    if ! command -v python3 &> /dev/null; then
        log_error "python3 no estÃ¡ disponible. Se requiere para procesar JSON."
        exit 1
    fi

    if ! aws sts get-caller-identity --region "${AWS_REGION}" &> /dev/null; then
        log_error "No se puede autenticar con AWS. Verifique sus credenciales."
        exit 1
    fi

    local identity
    identity=$(aws sts get-caller-identity --region "${AWS_REGION}" --output json)
    log_success "Autenticado como: $(echo "${identity}" | python3 -c "import sys,json;print(json.load(sys.stdin).get('Arn','unknown'))" 2>/dev/null || echo 'unknown')"
    log_info "RegiÃ³n configurada: ${AWS_REGION}"
}

# --- Crear directorio de output ---

setup_output_dir() {
    mkdir -p "${OUTPUT_DIR}"
    log_info "Output JSON: ${OUTPUT_FILE}"
    log_info "Reporte MD:  ${REPORT_FILE}"
}

# --- Funciones para obtener nombres de recursos ---

get_vpc_names() {
    log_info "Obteniendo nombres de VPCs..."
    aws ec2 describe-vpcs --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for vpc in data.get('Vpcs', []):
    name = ''
    for tag in vpc.get('Tags', []):
        if tag['Key'] == 'Name':
            name = tag['Value']
            break
    results.append({
        'resource_type': 'vpc',
        'resource_id': vpc['VpcId'],
        'current_name': name,
        'identifier': vpc['VpcId']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_subnet_names() {
    log_info "Obteniendo nombres de Subnets..."
    aws ec2 describe-subnets --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for subnet in data.get('Subnets', []):
    name = ''
    for tag in subnet.get('Tags', []):
        if tag['Key'] == 'Name':
            name = tag['Value']
            break
    results.append({
        'resource_type': 'subnet',
        'resource_id': subnet['SubnetId'],
        'current_name': name,
        'identifier': subnet['SubnetId']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_ecs_cluster_names() {
    log_info "Obteniendo nombres de ECS Clusters..."
    local cluster_arns
    cluster_arns=$(aws ecs list-clusters --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
arns = data.get('clusterArns', [])
print(' '.join(arns))
" 2>/dev/null || echo "")

    if [ -z "${cluster_arns}" ]; then
        echo "[]"
        return
    fi

    aws ecs describe-clusters --clusters ${cluster_arns} --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for cluster in data.get('clusters', []):
    results.append({
        'resource_type': 'ecs-cluster',
        'resource_id': cluster['clusterArn'],
        'current_name': cluster['clusterName'],
        'identifier': cluster['clusterArn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_alb_names() {
    log_info "Obteniendo nombres de ALBs..."
    aws elbv2 describe-load-balancers --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for lb in data.get('LoadBalancers', []):
    results.append({
        'resource_type': 'alb',
        'resource_id': lb['LoadBalancerArn'],
        'current_name': lb['LoadBalancerName'],
        'identifier': lb['LoadBalancerArn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_security_group_names() {
    log_info "Obteniendo nombres de Security Groups..."
    aws ec2 describe-security-groups --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for sg in data.get('SecurityGroups', []):
    name_tag = ''
    for tag in sg.get('Tags', []):
        if tag['Key'] == 'Name':
            name_tag = tag['Value']
            break
    # Use Name tag if available, otherwise GroupName
    display_name = name_tag if name_tag else sg['GroupName']
    results.append({
        'resource_type': 'security-group',
        'resource_id': sg['GroupId'],
        'current_name': display_name,
        'identifier': sg['GroupId']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_iam_role_names() {
    log_info "Obteniendo nombres de IAM Roles..."
    aws iam list-roles --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for role in data.get('Roles', []):
    # Skip AWS service-linked roles
    if role['Path'].startswith('/aws-service-role/'):
        continue
    results.append({
        'resource_type': 'iam-role',
        'resource_id': role['Arn'],
        'current_name': role['RoleName'],
        'identifier': role['Arn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_ecr_repo_names() {
    log_info "Obteniendo nombres de ECR Repositories..."
    aws ecr describe-repositories --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for repo in data.get('repositories', []):
    results.append({
        'resource_type': 'ecr-repository',
        'resource_id': repo['repositoryArn'],
        'current_name': repo['repositoryName'],
        'identifier': repo['repositoryArn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_route53_zone_names() {
    log_info "Obteniendo nombres de Route 53 Hosted Zones..."
    aws route53 list-hosted-zones --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for zone in data.get('HostedZones', []):
    results.append({
        'resource_type': 'route53-zone',
        'resource_id': zone['Id'],
        'current_name': zone['Name'].rstrip('.'),
        'identifier': zone['Id']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_waf_acl_names() {
    log_info "Obteniendo nombres de WAF Web ACLs..."
    aws wafv2 list-web-acls --scope REGIONAL --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for acl in data.get('WebACLs', []):
    results.append({
        'resource_type': 'waf-acl',
        'resource_id': acl.get('ARN', acl.get('Id', '')),
        'current_name': acl['Name'],
        'identifier': acl.get('ARN', acl.get('Id', ''))
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_acm_certificate_names() {
    log_info "Obteniendo nombres de ACM Certificates..."
    aws acm list-certificates --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for cert in data.get('CertificateSummaryList', []):
    results.append({
        'resource_type': 'acm-certificate',
        'resource_id': cert['CertificateArn'],
        'current_name': cert.get('DomainName', ''),
        'identifier': cert['CertificateArn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_secrets_manager_names() {
    log_info "Obteniendo nombres de Secrets Manager secrets..."
    aws secretsmanager list-secrets --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for secret in data.get('SecretList', []):
    results.append({
        'resource_type': 'secret',
        'resource_id': secret['ARN'],
        'current_name': secret['Name'],
        'identifier': secret['ARN']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_cloudwatch_log_group_names() {
    log_info "Obteniendo nombres de CloudWatch Log Groups..."
    aws logs describe-log-groups --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for lg in data.get('logGroups', []):
    results.append({
        'resource_type': 'log-group',
        'resource_id': lg['arn'],
        'current_name': lg['logGroupName'],
        'identifier': lg['arn']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}

get_vpn_connection_names() {
    log_info "Obteniendo nombres de VPN Connections..."
    aws ec2 describe-vpn-connections --region "${AWS_REGION}" --output json 2>/dev/null | python3 -c "
import sys, json
data = json.load(sys.stdin)
results = []
for vpn in data.get('VpnConnections', []):
    name = ''
    for tag in vpn.get('Tags', []):
        if tag['Key'] == 'Name':
            name = tag['Value']
            break
    results.append({
        'resource_type': 'vpn-connection',
        'resource_id': vpn['VpnConnectionId'],
        'current_name': name if name else vpn['VpnConnectionId'],
        'identifier': vpn['VpnConnectionId']
    })
print(json.dumps(results))
" 2>/dev/null || echo "[]"
}


# --- Evaluar nomenclatura ---

evaluate_naming_compliance() {
    local all_resources_json="$1"

    log_info "Evaluando nomenclatura contra patrÃ³n: ${NAMING_PATTERN}..."

    python3 << 'PYTHON_SCRIPT' - "${all_resources_json}" "${PROJECT_NAME}"
import sys
import json
import re

all_resources = json.loads(sys.argv[1])
project_name = sys.argv[2]

# PatrÃ³n esperado: {proyecto}-{servicio}-{ambiente}-{recurso}
# Ejemplo: multicines-integrator-dev-vpc
# El patrÃ³n permite variaciones:
#   - proyecto debe ser el nombre del proyecto (multicines)
#   - servicio es un identificador alfanumÃ©rico con guiones
#   - ambiente es dev o prod
#   - recurso es un identificador alfanumÃ©rico con guiones
NAMING_REGEX = re.compile(
    r'^' + re.escape(project_name) + r'-[a-z0-9]+(?:-[a-z0-9]+)*-(dev|prod|staging|test)-[a-z0-9]+(?:-[a-z0-9]+)*$',
    re.IGNORECASE
)

# Also accept simpler pattern: multicines-{ambiente}-{recurso} (without servicio)
NAMING_REGEX_SIMPLE = re.compile(
    r'^' + re.escape(project_name) + r'-(dev|prod|staging|test)-[a-z0-9]+(?:-[a-z0-9]+)*$',
    re.IGNORECASE
)

# Accept pattern that starts with project name (partial compliance)
STARTS_WITH_PROJECT = re.compile(
    r'^' + re.escape(project_name) + r'-',
    re.IGNORECASE
)

compliant = []
non_compliant = []
partial_compliant = []

for resource in all_resources:
    name = resource.get('current_name', '')
    resource_type = resource.get('resource_type', 'unknown')

    # Skip resources without a meaningful name
    if not name or name == resource.get('resource_id', ''):
        evaluation = {
            **resource,
            'compliance_status': 'no_name',
            'expected_pattern': f'{project_name}-<servicio>-<ambiente>-<recurso>',
            'issue': 'Recurso sin nombre (Name tag vacÃ­o o no definido)',
            'suggestion': f'{project_name}-integrator-dev-{resource_type}'
        }
        non_compliant.append(evaluation)
        continue

    # Check full pattern compliance
    if NAMING_REGEX.match(name):
        evaluation = {
            **resource,
            'compliance_status': 'compliant',
            'expected_pattern': f'{project_name}-<servicio>-<ambiente>-<recurso>',
            'issue': None,
            'suggestion': None
        }
        compliant.append(evaluation)
    elif NAMING_REGEX_SIMPLE.match(name):
        # Simplified pattern (missing service component)
        evaluation = {
            **resource,
            'compliance_status': 'partial',
            'expected_pattern': f'{project_name}-<servicio>-<ambiente>-<recurso>',
            'issue': 'Falta componente de servicio en el nombre',
            'suggestion': name.replace(f'{project_name}-', f'{project_name}-integrator-', 1)
        }
        partial_compliant.append(evaluation)
    elif STARTS_WITH_PROJECT.match(name):
        # Starts with project name but doesn't follow full pattern
        evaluation = {
            **resource,
            'compliance_status': 'partial',
            'expected_pattern': f'{project_name}-<servicio>-<ambiente>-<recurso>',
            'issue': 'Comienza con nombre de proyecto pero no sigue patrÃ³n completo',
            'suggestion': f'{project_name}-integrator-dev-{resource_type}'
        }
        partial_compliant.append(evaluation)
    else:
        # Doesn't follow naming convention at all
        evaluation = {
            **resource,
            'compliance_status': 'non_compliant',
            'expected_pattern': f'{project_name}-<servicio>-<ambiente>-<recurso>',
            'issue': 'No sigue el patrÃ³n de nomenclatura estÃ¡ndar',
            'suggestion': f'{project_name}-integrator-dev-{resource_type}'
        }
        non_compliant.append(evaluation)

total = len(compliant) + len(non_compliant) + len(partial_compliant)
compliance_rate = round((len(compliant) / total) * 100, 1) if total > 0 else 0
partial_rate = round((len(partial_compliant) / total) * 100, 1) if total > 0 else 0

# Stats by resource type
by_type = {}
for r in compliant + non_compliant + partial_compliant:
    rtype = r['resource_type']
    if rtype not in by_type:
        by_type[rtype] = {'total': 0, 'compliant': 0, 'partial': 0, 'non_compliant': 0}
    by_type[rtype]['total'] += 1
    if r['compliance_status'] == 'compliant':
        by_type[rtype]['compliant'] += 1
    elif r['compliance_status'] == 'partial':
        by_type[rtype]['partial'] += 1
    else:
        by_type[rtype]['non_compliant'] += 1

# Stats by issue type
issues = {}
for r in non_compliant + partial_compliant:
    issue = r.get('issue', 'unknown')
    issues[issue] = issues.get(issue, 0) + 1

result = {
    "summary": {
        "total_resources": total,
        "compliant_resources": len(compliant),
        "partial_compliant_resources": len(partial_compliant),
        "non_compliant_resources": len(non_compliant),
        "compliance_rate_percent": compliance_rate,
        "partial_compliance_rate_percent": partial_rate,
        "naming_pattern": f"{project_name}-<servicio>-<ambiente>-<recurso>",
        "project_name": project_name,
        "compliance_by_resource_type": by_type,
        "issues_frequency": issues
    },
    "compliant_resources": compliant,
    "partial_compliant_resources": partial_compliant,
    "non_compliant_resources": non_compliant
}

print(json.dumps(result))
PYTHON_SCRIPT
}

# --- Generar reporte Markdown ---

generate_markdown_report() {
    local compliance_json="$1"

    python3 << 'PYTHON_SCRIPT' - "${compliance_json}" "${REPORT_FILE}" "${AWS_REGION}" "${NAMING_PATTERN}" "${PROJECT_NAME}"
import sys
import json
from datetime import datetime, timezone

compliance_data = json.loads(sys.argv[1])
report_file = sys.argv[2]
region = sys.argv[3]
naming_pattern = sys.argv[4]
project_name = sys.argv[5]

summary = compliance_data["summary"]
non_compliant = compliance_data["non_compliant_resources"]
partial = compliance_data["partial_compliant_resources"]
compliant = compliance_data["compliant_resources"]

lines = []
lines.append("# AuditorÃ­a de Nomenclatura - Multicines AWS")
lines.append("")
lines.append(f"**Fecha:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
lines.append(f"**RegiÃ³n:** {region}")
lines.append(f"**PatrÃ³n esperado:** `{naming_pattern}`")
lines.append(f"**Ejemplo:** `{project_name}-integrator-dev-vpc`")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Resumen Ejecutivo")
lines.append("")
lines.append("| MÃ©trica | Valor |")
lines.append("|---------|-------|")
lines.append(f"| Total de recursos evaluados | {summary['total_resources']} |")
lines.append(f"| Recursos conformes (patrÃ³n completo) | {summary['compliant_resources']} |")
lines.append(f"| Recursos parcialmente conformes | {summary['partial_compliant_resources']} |")
lines.append(f"| Recursos NO conformes | {summary['non_compliant_resources']} |")
lines.append(f"| Tasa de cumplimiento total | {summary['compliance_rate_percent']}% |")
lines.append(f"| Tasa de cumplimiento parcial | {summary['partial_compliance_rate_percent']}% |")
lines.append("")

# Issues frequency
lines.append("## Problemas Identificados (Frecuencia)")
lines.append("")
lines.append("| Problema | Cantidad de recursos |")
lines.append("|----------|---------------------|")
for issue, count in sorted(summary["issues_frequency"].items(), key=lambda x: -x[1]):
    lines.append(f"| {issue} | {count} |")
lines.append("")

# Compliance by resource type
lines.append("## Cumplimiento por Tipo de Recurso")
lines.append("")
lines.append("| Tipo de Recurso | Total | Conformes | Parcial | No Conformes | % Cumplimiento |")
lines.append("|-----------------|-------|-----------|---------|--------------|----------------|")
for rtype, stats in sorted(summary["compliance_by_resource_type"].items()):
    pct = round((stats["compliant"] / stats["total"]) * 100, 1) if stats["total"] > 0 else 0
    lines.append(f"| {rtype} | {stats['total']} | {stats['compliant']} | {stats['partial']} | {stats['non_compliant']} | {pct}% |")
lines.append("")

# Non-compliant resources detail
lines.append("## Recursos No Conformes (Detalle)")
lines.append("")
if non_compliant:
    for i, resource in enumerate(non_compliant[:50], 1):
        lines.append(f"### {i}. `{resource['current_name'] or '(sin nombre)'}`")
        lines.append("")
        lines.append(f"- **Tipo:** {resource['resource_type']}")
        lines.append(f"- **ID:** `{resource['resource_id']}`")
        lines.append(f"- **Problema:** {resource['issue']}")
        lines.append(f"- **Nombre sugerido:** `{resource['suggestion']}`")
        lines.append("")
    if len(non_compliant) > 50:
        lines.append(f"*... y {len(non_compliant) - 50} recursos adicionales no conformes (ver JSON para detalle completo)*")
        lines.append("")
else:
    lines.append("âœ… No se encontraron recursos completamente fuera del estÃ¡ndar de nomenclatura.")
    lines.append("")

# Partial compliant resources
lines.append("## Recursos Parcialmente Conformes")
lines.append("")
if partial:
    for i, resource in enumerate(partial[:30], 1):
        lines.append(f"### {i}. `{resource['current_name']}`")
        lines.append("")
        lines.append(f"- **Tipo:** {resource['resource_type']}")
        lines.append(f"- **ID:** `{resource['resource_id']}`")
        lines.append(f"- **Problema:** {resource['issue']}")
        lines.append(f"- **Nombre sugerido:** `{resource['suggestion']}`")
        lines.append("")
    if len(partial) > 30:
        lines.append(f"*... y {len(partial) - 30} recursos adicionales parcialmente conformes*")
        lines.append("")
else:
    lines.append("No se encontraron recursos parcialmente conformes.")
    lines.append("")

# Compliant resources summary
lines.append("## Recursos Conformes")
lines.append("")
if compliant:
    lines.append(f"Total: {len(compliant)} recursos siguen el patrÃ³n de nomenclatura correctamente.")
    lines.append("")
    lines.append("<details>")
    lines.append("<summary>Ver lista completa de recursos conformes</summary>")
    lines.append("")
    for resource in compliant[:100]:
        lines.append(f"- `{resource['current_name']}` ({resource['resource_type']})")
    if len(compliant) > 100:
        lines.append(f"- *... y {len(compliant) - 100} recursos adicionales*")
    lines.append("")
    lines.append("</details>")
    lines.append("")
else:
    lines.append("âš ï¸ No se encontraron recursos que cumplan con el patrÃ³n de nomenclatura completo.")
    lines.append("")

# Recommendations
lines.append("---")
lines.append("")
lines.append("## Recomendaciones")
lines.append("")
lines.append(f"1. Adoptar el patrÃ³n `{naming_pattern}` para todos los recursos nuevos creados con Terraform")
lines.append(f"2. Renombrar recursos existentes usando el tag `Name` con formato `{project_name}-<servicio>-<ambiente>-<recurso>`")
lines.append("3. Implementar validaciÃ³n de nombres en el pipeline CI/CD (terraform validate + custom rules)")
lines.append("4. Documentar excepciones legÃ­timas (ej: dominios Route 53, certificados ACM por dominio)")
lines.append("5. Usar `default_tags` y convenciÃ³n de `Name` tag en todos los mÃ³dulos Terraform")
lines.append("")

with open(report_file, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
PYTHON_SCRIPT
}

# --- Mostrar resumen en consola ---

print_console_summary() {
    local compliance_json="$1"

    python3 << 'PYTHON_SCRIPT' - "${compliance_json}"
import sys
import json

data = json.loads(sys.argv[1])
summary = data["summary"]

# Colores ANSI
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

print("")
print(f"{BOLD}{'='*60}{NC}")
print(f"{BOLD}  RESUMEN DE AUDITORÃA DE NOMENCLATURA{NC}")
print(f"{BOLD}{'='*60}{NC}")
print("")
print(f"  PatrÃ³n esperado: {summary['naming_pattern']}")
print(f"  Proyecto:        {summary['project_name']}")
print("")
print(f"  Total recursos evaluados:       {summary['total_resources']}")

if summary['compliance_rate_percent'] >= 80:
    color = GREEN
elif summary['compliance_rate_percent'] >= 50:
    color = YELLOW
else:
    color = RED

print(f"  Recursos conformes:             {GREEN}{summary['compliant_resources']}{NC}")
print(f"  Recursos parcialmente conformes: {YELLOW}{summary['partial_compliant_resources']}{NC}")
print(f"  Recursos NO conformes:          {RED}{summary['non_compliant_resources']}{NC}")
print(f"  Tasa de cumplimiento:           {color}{summary['compliance_rate_percent']}%{NC}")
print("")

# Issues frequency
if summary['issues_frequency']:
    print(f"  {CYAN}Problemas identificados:{NC}")
    for issue, count in sorted(summary['issues_frequency'].items(), key=lambda x: -x[1]):
        bar = 'â–ˆ' * min(count, 30)
        print(f"    {issue[:40]:<40} : {count:>4}  {YELLOW}{bar}{NC}")
    print("")

# Compliance by resource type
print(f"  {CYAN}Cumplimiento por tipo de recurso:{NC}")
sorted_types = sorted(
    summary['compliance_by_resource_type'].items(),
    key=lambda x: (x[1]['compliant'] / x[1]['total'] if x[1]['total'] > 0 else 1)
)
for rtype, stats in sorted_types[:10]:
    pct = round((stats['compliant'] / stats['total']) * 100, 1) if stats['total'] > 0 else 0
    if pct >= 80:
        color = GREEN
    elif pct >= 50:
        color = YELLOW
    else:
        color = RED
    print(f"    {rtype:<20} : {color}{pct:>5.1f}%{NC}  ({stats['compliant']}/{stats['total']})")

print("")
print(f"{'='*60}")
PYTHON_SCRIPT
}

# --- EjecuciÃ³n principal ---

main() {
    echo "============================================================" >&2
    echo "  AuditorÃ­a de Nomenclatura AWS - Multicines" >&2
    echo "  RegiÃ³n: ${AWS_REGION}" >&2
    echo "  PatrÃ³n: ${NAMING_PATTERN}" >&2
    echo "  Fecha:  $(date)" >&2
    echo "============================================================" >&2
    echo "" >&2

    check_prerequisites
    setup_output_dir

    echo "" >&2
    log_info "Recopilando nombres de recursos AWS..."
    echo "" >&2

    # Paso 1: Obtener nombres de todos los tipos de recursos
    local vpcs subnets ecs_clusters albs sgs iam_roles ecr_repos
    local route53_zones waf_acls acm_certs secrets log_groups vpn_connections

    vpcs=$(get_vpc_names)
    subnets=$(get_subnet_names)
    ecs_clusters=$(get_ecs_cluster_names)
    albs=$(get_alb_names)
    sgs=$(get_security_group_names)
    iam_roles=$(get_iam_role_names)
    ecr_repos=$(get_ecr_repo_names)
    route53_zones=$(get_route53_zone_names)
    waf_acls=$(get_waf_acl_names)
    acm_certs=$(get_acm_certificate_names)
    secrets=$(get_secrets_manager_names)
    log_groups=$(get_cloudwatch_log_group_names)
    vpn_connections=$(get_vpn_connection_names)

    echo "" >&2

    # Paso 2: Consolidar todos los recursos en un array
    log_info "Consolidando recursos para evaluaciÃ³n..."
    local all_resources
    all_resources=$(python3 -c "
import sys, json
arrays = [
    json.loads(sys.argv[1]),
    json.loads(sys.argv[2]),
    json.loads(sys.argv[3]),
    json.loads(sys.argv[4]),
    json.loads(sys.argv[5]),
    json.loads(sys.argv[6]),
    json.loads(sys.argv[7]),
    json.loads(sys.argv[8]),
    json.loads(sys.argv[9]),
    json.loads(sys.argv[10]),
    json.loads(sys.argv[11]),
    json.loads(sys.argv[12]),
    json.loads(sys.argv[13])
]
result = []
for arr in arrays:
    if isinstance(arr, list):
        result.extend(arr)
print(json.dumps(result))
" "${vpcs}" "${subnets}" "${ecs_clusters}" "${albs}" "${sgs}" "${iam_roles}" "${ecr_repos}" "${route53_zones}" "${waf_acls}" "${acm_certs}" "${secrets}" "${log_groups}" "${vpn_connections}" 2>/dev/null || echo "[]")

    local total_resources
    total_resources=$(echo "${all_resources}" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    log_success "Total de recursos recopilados: ${total_resources}"

    if [ "${total_resources}" -eq 0 ]; then
        log_warning "No se encontraron recursos para evaluar en la regiÃ³n ${AWS_REGION}."
        exit 0
    fi

    echo "" >&2

    # Paso 3: Evaluar nomenclatura
    local compliance_json
    compliance_json=$(evaluate_naming_compliance "${all_resources}")

    echo "" >&2

    # Paso 4: Guardar reporte JSON
    log_info "Guardando reporte JSON..."
    python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.loads(sys.argv[1])
data['metadata'] = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'region': '${AWS_REGION}',
    'account': '$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")',
    'naming_pattern': '${NAMING_PATTERN}',
    'project_name': '${PROJECT_NAME}'
}
with open('${OUTPUT_FILE}', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" "${compliance_json}"
    log_success "Reporte JSON guardado: ${OUTPUT_FILE}"

    # Paso 5: Generar reporte Markdown
    log_info "Generando reporte Markdown..."
    generate_markdown_report "${compliance_json}"
    log_success "Reporte Markdown guardado: ${REPORT_FILE}"

    # Paso 6: Mostrar resumen en consola
    print_console_summary "${compliance_json}" >&2

    echo "" >&2
    log_success "AuditorÃ­a de nomenclatura completada."
    log_info "Archivos generados:"
    echo "  - JSON:     ${OUTPUT_FILE}" >&2
    echo "  - Markdown: ${REPORT_FILE}" >&2
    echo "" >&2
}

main "$@"
