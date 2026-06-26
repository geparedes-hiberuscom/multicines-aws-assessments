#!/bin/bash
#
# audit-security-groups.sh - AuditorÃ­a de Security Groups AWS para Multicines
#
# Este script documenta las reglas de ingress y egress de todos los Security
# Groups existentes en la cuenta. Identifica potenciales problemas de seguridad
# como reglas excesivamente permisivas (0.0.0.0/0 en puertos no-HTTPS).
#
# Genera reportes en JSON y Markdown en assessment/output/.
#
# Requisitos:
#   - AWS CLI v2 instalado y configurado
#   - python3 disponible
#   - Permisos: ec2:DescribeSecurityGroups, sts:GetCallerIdentity
#
# Uso:
#   ./assessment/audit-security-groups.sh
#   AWS_REGION=us-west-2 ./assessment/audit-security-groups.sh
#

set -euo pipefail

# ConfiguraciÃ³n
AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUTPUT_DIR}/audit-security-groups_${TIMESTAMP}.json"
REPORT_FILE="${OUTPUT_DIR}/audit-security-groups_${TIMESTAMP}.md"

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

# --- Obtener Security Groups ---

fetch_security_groups() {
    log_info "Obteniendo Security Groups de la regiÃ³n ${AWS_REGION}..."

    local result
    if ! result=$(aws ec2 describe-security-groups --region "${AWS_REGION}" --output json 2>&1); then
        log_error "Error al obtener Security Groups: ${result}"
        echo "[]"
        return 1
    fi

    local count
    count=$(echo "${result}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('SecurityGroups',[])))" 2>/dev/null || echo "0")
    log_success "Security Groups encontrados: ${count}"

    echo "${result}"
}

# --- Analizar Security Groups y detectar problemas ---

analyze_security_groups() {
    local sg_json="$1"

    log_info "Analizando reglas de ingress y egress..."
    log_info "Identificando potenciales problemas de seguridad..."

    python3 << 'PYTHON_SCRIPT' - "${sg_json}"
import sys
import json

sg_data = json.loads(sys.argv[1])
security_groups = sg_data.get('SecurityGroups', [])

analyzed_sgs = []
security_issues = []
total_ingress_rules = 0
total_egress_rules = 0

for sg in security_groups:
    sg_id = sg.get('GroupId', '')
    sg_name = sg.get('GroupName', '')
    vpc_id = sg.get('VpcId', '')
    description = sg.get('Description', '')

    # Get Name tag
    name_tag = ''
    for tag in sg.get('Tags', []):
        if tag['Key'] == 'Name':
            name_tag = tag['Value']
            break

    # Process ingress rules
    ingress_rules = []
    for rule in sg.get('IpPermissions', []):
        protocol = rule.get('IpProtocol', '-1')
        from_port = rule.get('FromPort', 0)
        to_port = rule.get('ToPort', 0)

        # CIDR ranges (IPv4)
        for cidr in rule.get('IpRanges', []):
            ingress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'source': cidr.get('CidrIp', ''),
                'source_type': 'cidr_ipv4',
                'description': cidr.get('Description', '')
            })

        # CIDR ranges (IPv6)
        for cidr in rule.get('Ipv6Ranges', []):
            ingress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'source': cidr.get('CidrIpv6', ''),
                'source_type': 'cidr_ipv6',
                'description': cidr.get('Description', '')
            })

        # Referenced Security Groups
        for ref_sg in rule.get('UserIdGroupPairs', []):
            source_sg = ref_sg.get('GroupId', '')
            ingress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'source': source_sg,
                'source_type': 'security_group',
                'description': ref_sg.get('Description', '')
            })

        # Prefix Lists
        for pl in rule.get('PrefixListIds', []):
            ingress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'source': pl.get('PrefixListId', ''),
                'source_type': 'prefix_list',
                'description': pl.get('Description', '')
            })

    # Process egress rules
    egress_rules = []
    for rule in sg.get('IpPermissionsEgress', []):
        protocol = rule.get('IpProtocol', '-1')
        from_port = rule.get('FromPort', 0)
        to_port = rule.get('ToPort', 0)

        # CIDR ranges (IPv4)
        for cidr in rule.get('IpRanges', []):
            egress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'destination': cidr.get('CidrIp', ''),
                'destination_type': 'cidr_ipv4',
                'description': cidr.get('Description', '')
            })

        # CIDR ranges (IPv6)
        for cidr in rule.get('Ipv6Ranges', []):
            egress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'destination': cidr.get('CidrIpv6', ''),
                'destination_type': 'cidr_ipv6',
                'description': cidr.get('Description', '')
            })

        # Referenced Security Groups
        for ref_sg in rule.get('UserIdGroupPairs', []):
            dest_sg = ref_sg.get('GroupId', '')
            egress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'destination': dest_sg,
                'destination_type': 'security_group',
                'description': ref_sg.get('Description', '')
            })

        # Prefix Lists
        for pl in rule.get('PrefixListIds', []):
            egress_rules.append({
                'protocol': protocol,
                'from_port': from_port,
                'to_port': to_port,
                'destination': pl.get('PrefixListId', ''),
                'destination_type': 'prefix_list',
                'description': pl.get('Description', '')
            })

    total_ingress_rules += len(ingress_rules)
    total_egress_rules += len(egress_rules)

    # Identify security issues for this SG
    sg_issues = []

    for rule in ingress_rules:
        source = rule.get('source', '')
        protocol = rule.get('protocol', '')
        from_port = rule.get('from_port', 0)
        to_port = rule.get('to_port', 0)

        # Issue: 0.0.0.0/0 on non-HTTPS ports
        if source in ('0.0.0.0/0', '::/0'):
            if protocol == '-1':
                sg_issues.append({
                    'severity': 'CRITICAL',
                    'rule_direction': 'ingress',
                    'issue': 'All traffic allowed from anywhere (0.0.0.0/0)',
                    'detail': f'Protocol: ALL, Ports: ALL, Source: {source}'
                })
            elif to_port != 443 and from_port != 443:
                if from_port == 80 and to_port == 80:
                    sg_issues.append({
                        'severity': 'LOW',
                        'rule_direction': 'ingress',
                        'issue': f'HTTP (port 80) open to the internet - should redirect to HTTPS',
                        'detail': f'Protocol: {protocol}, Port: {from_port}-{to_port}, Source: {source}'
                    })
                elif from_port == 22 and to_port == 22:
                    sg_issues.append({
                        'severity': 'HIGH',
                        'rule_direction': 'ingress',
                        'issue': 'SSH (port 22) open to the internet',
                        'detail': f'Protocol: {protocol}, Port: 22, Source: {source}'
                    })
                elif from_port == 3389 and to_port == 3389:
                    sg_issues.append({
                        'severity': 'HIGH',
                        'rule_direction': 'ingress',
                        'issue': 'RDP (port 3389) open to the internet',
                        'detail': f'Protocol: {protocol}, Port: 3389, Source: {source}'
                    })
                else:
                    sg_issues.append({
                        'severity': 'MEDIUM',
                        'rule_direction': 'ingress',
                        'issue': f'Non-HTTPS port open to the internet (0.0.0.0/0)',
                        'detail': f'Protocol: {protocol}, Port: {from_port}-{to_port}, Source: {source}'
                    })

        # Issue: Wide port range
        if to_port - from_port > 100 and protocol != '-1' and from_port != 0:
            sg_issues.append({
                'severity': 'MEDIUM',
                'rule_direction': 'ingress',
                'issue': f'Wide port range open ({from_port}-{to_port})',
                'detail': f'Protocol: {protocol}, Source: {source}'
            })

    for rule in egress_rules:
        destination = rule.get('destination', '')
        protocol = rule.get('protocol', '')

        # Issue: Unrestricted egress to 0.0.0.0/0 with all protocols
        if destination in ('0.0.0.0/0', '::/0') and protocol == '-1':
            sg_issues.append({
                'severity': 'LOW',
                'rule_direction': 'egress',
                'issue': 'Unrestricted outbound traffic (all protocols to 0.0.0.0/0)',
                'detail': f'Protocol: ALL, Ports: ALL, Destination: {destination}'
            })

    security_issues.extend([{**issue, 'sg_id': sg_id, 'sg_name': name_tag or sg_name} for issue in sg_issues])

    analyzed_sgs.append({
        'sg_id': sg_id,
        'sg_name': sg_name,
        'name_tag': name_tag,
        'vpc_id': vpc_id,
        'description': description,
        'ingress_rules': ingress_rules,
        'egress_rules': egress_rules,
        'ingress_rule_count': len(ingress_rules),
        'egress_rule_count': len(egress_rules),
        'issues': sg_issues,
        'issue_count': len(sg_issues)
    })

# Summary statistics
severity_counts = {'CRITICAL': 0, 'HIGH': 0, 'MEDIUM': 0, 'LOW': 0}
for issue in security_issues:
    severity_counts[issue['severity']] = severity_counts.get(issue['severity'], 0) + 1

sgs_with_issues = len([sg for sg in analyzed_sgs if sg['issue_count'] > 0])
sgs_without_issues = len(analyzed_sgs) - sgs_with_issues

result = {
    "summary": {
        "total_security_groups": len(analyzed_sgs),
        "total_ingress_rules": total_ingress_rules,
        "total_egress_rules": total_egress_rules,
        "total_issues": len(security_issues),
        "sgs_with_issues": sgs_with_issues,
        "sgs_without_issues": sgs_without_issues,
        "severity_counts": severity_counts
    },
    "security_groups": analyzed_sgs,
    "security_issues": security_issues
}

print(json.dumps(result))
PYTHON_SCRIPT
}

# --- Generar reporte Markdown ---

generate_markdown_report() {
    local analysis_json="$1"

    python3 << 'PYTHON_SCRIPT' - "${analysis_json}" "${REPORT_FILE}" "${AWS_REGION}"
import sys
import json
from datetime import datetime, timezone

analysis = json.loads(sys.argv[1])
report_file = sys.argv[2]
region = sys.argv[3]

summary = analysis["summary"]
security_groups = analysis["security_groups"]
issues = analysis["security_issues"]

lines = []
lines.append("# AuditorÃ­a de Security Groups - Multicines AWS")
lines.append("")
lines.append(f"**Fecha:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
lines.append(f"**RegiÃ³n:** {region}")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Resumen Ejecutivo")
lines.append("")
lines.append("| MÃ©trica | Valor |")
lines.append("|---------|-------|")
lines.append(f"| Total Security Groups | {summary['total_security_groups']} |")
lines.append(f"| Total reglas de ingress | {summary['total_ingress_rules']} |")
lines.append(f"| Total reglas de egress | {summary['total_egress_rules']} |")
lines.append(f"| SGs con problemas de seguridad | {summary['sgs_with_issues']} |")
lines.append(f"| SGs sin problemas | {summary['sgs_without_issues']} |")
lines.append(f"| Total problemas identificados | {summary['total_issues']} |")
lines.append("")
# Severity breakdown
lines.append("## Problemas por Severidad")
lines.append("")
lines.append("| Severidad | Cantidad |")
lines.append("|-----------|----------|")
for sev in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
    count = summary['severity_counts'].get(sev, 0)
    emoji = {'CRITICAL': 'ðŸ”´', 'HIGH': 'ðŸŸ ', 'MEDIUM': 'ðŸŸ¡', 'LOW': 'ðŸŸ¢'}.get(sev, '')
    lines.append(f"| {emoji} {sev} | {count} |")
lines.append("")

# Security issues detail
if issues:
    lines.append("## Problemas de Seguridad Identificados")
    lines.append("")

    # Group by severity
    for sev in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
        sev_issues = [i for i in issues if i['severity'] == sev]
        if not sev_issues:
            continue
        emoji = {'CRITICAL': 'ðŸ”´', 'HIGH': 'ðŸŸ ', 'MEDIUM': 'ðŸŸ¡', 'LOW': 'ðŸŸ¢'}.get(sev, '')
        lines.append(f"### {emoji} {sev} ({len(sev_issues)})")
        lines.append("")
        for i, issue in enumerate(sev_issues, 1):
            lines.append(f"{i}. **{issue['sg_name']}** (`{issue['sg_id']}`) - {issue['rule_direction'].upper()}")
            lines.append(f"   - Problema: {issue['issue']}")
            lines.append(f"   - Detalle: `{issue['detail']}`")
            lines.append("")
else:
    lines.append("## Problemas de Seguridad")
    lines.append("")
    lines.append("âœ… No se identificaron problemas de seguridad en los Security Groups.")
    lines.append("")
# Detail per Security Group
lines.append("---")
lines.append("")
lines.append("## Detalle por Security Group")
lines.append("")

for sg in security_groups:
    display_name = sg['name_tag'] if sg['name_tag'] else sg['sg_name']
    issue_badge = f" âš ï¸ ({sg['issue_count']} problemas)" if sg['issue_count'] > 0 else " âœ…"
    lines.append(f"### {display_name} (`{sg['sg_id']}`){issue_badge}")
    lines.append("")
    lines.append(f"- **VPC:** `{sg['vpc_id']}`")
    lines.append(f"- **DescripciÃ³n:** {sg['description']}")
    lines.append(f"- **Reglas ingress:** {sg['ingress_rule_count']}")
    lines.append(f"- **Reglas egress:** {sg['egress_rule_count']}")
    lines.append("")

    # Ingress rules table
    if sg['ingress_rules']:
        lines.append("**Reglas de Ingress:**")
        lines.append("")
        lines.append("| Protocolo | Puerto(s) | Origen | Tipo | DescripciÃ³n |")
        lines.append("|-----------|-----------|--------|------|-------------|")
        for rule in sg['ingress_rules']:
            proto = 'ALL' if rule['protocol'] == '-1' else rule['protocol'].upper()
            ports = 'ALL' if rule['protocol'] == '-1' else f"{rule['from_port']}-{rule['to_port']}" if rule['from_port'] != rule['to_port'] else str(rule['from_port'])
            lines.append(f"| {proto} | {ports} | `{rule['source']}` | {rule['source_type']} | {rule['description']} |")
        lines.append("")
    else:
        lines.append("**Reglas de Ingress:** Ninguna")
        lines.append("")

    # Egress rules table
    if sg['egress_rules']:
        lines.append("**Reglas de Egress:**")
        lines.append("")
        lines.append("| Protocolo | Puerto(s) | Destino | Tipo | DescripciÃ³n |")
        lines.append("|-----------|-----------|---------|------|-------------|")
        for rule in sg['egress_rules']:
            proto = 'ALL' if rule['protocol'] == '-1' else rule['protocol'].upper()
            ports = 'ALL' if rule['protocol'] == '-1' else f"{rule['from_port']}-{rule['to_port']}" if rule['from_port'] != rule['to_port'] else str(rule['from_port'])
            lines.append(f"| {proto} | {ports} | `{rule['destination']}` | {rule['destination_type']} | {rule['description']} |")
        lines.append("")
    else:
        lines.append("**Reglas de Egress:** Ninguna")
        lines.append("")

    lines.append("---")
    lines.append("")
# Recommendations
lines.append("## Recomendaciones")
lines.append("")
lines.append("1. **ALB Security Group:** Permitir ingress solo HTTPS (443) desde 0.0.0.0/0 â€” WAF filtra el trÃ¡fico")
lines.append("2. **ECS Security Group:** Permitir ingress solo desde el ALB SG en puerto 8095")
lines.append("3. **ECS Egress:** Si VPN disponible, permitir solo trÃ¡fico hacia CIDR on-premise; sino, solo VPC Endpoints AWS")
lines.append("4. Eliminar reglas con 0.0.0.0/0 en puertos que no sean 443 (HTTPS)")
lines.append("5. Reemplazar reglas con rangos de puertos amplios por reglas especÃ­ficas")
lines.append("6. Documentar el propÃ³sito de cada regla usando el campo Description")
lines.append("7. Implementar Security Groups con Terraform para control versionado")
lines.append("")

with open(report_file, 'w', encoding='utf-8') as f:
    f.write('\n'.join(lines))
PYTHON_SCRIPT
}

# --- Mostrar resumen en consola ---

print_console_summary() {
    local analysis_json="$1"

    python3 << 'PYTHON_SCRIPT' - "${analysis_json}"
import sys
import json

data = json.loads(sys.argv[1])
summary = data["summary"]
security_groups = data["security_groups"]
issues = data["security_issues"]

# Colores ANSI
RED = '\033[0;31m'
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

print("")
print(f"{BOLD}{'='*60}{NC}")
print(f"{BOLD}  RESUMEN DE AUDITORÃA DE SECURITY GROUPS{NC}")
print(f"{BOLD}{'='*60}{NC}")
print("")
print(f"  Total Security Groups:     {summary['total_security_groups']}")
print(f"  Total reglas ingress:      {summary['total_ingress_rules']}")
print(f"  Total reglas egress:       {summary['total_egress_rules']}")
print("")
print(f"  SGs con problemas:         {RED}{summary['sgs_with_issues']}{NC}")
print(f"  SGs sin problemas:         {GREEN}{summary['sgs_without_issues']}{NC}")
print("")

# Severity breakdown
sev_colors = {'CRITICAL': RED, 'HIGH': RED, 'MEDIUM': YELLOW, 'LOW': GREEN}
print(f"  {CYAN}Problemas por severidad:{NC}")
for sev in ['CRITICAL', 'HIGH', 'MEDIUM', 'LOW']:
    count = summary['severity_counts'].get(sev, 0)
    color = sev_colors.get(sev, NC)
    bar = 'â–ˆ' * min(count, 30)
    print(f"    {sev:<10} : {color}{count:>4}{NC}  {color}{bar}{NC}")
print("")
# Top issues
if issues:
    print(f"  {CYAN}Principales problemas encontrados:{NC}")
    shown = set()
    for issue in sorted(issues, key=lambda x: ['CRITICAL','HIGH','MEDIUM','LOW'].index(x['severity'])):
        key = f"{issue['sg_id']}-{issue['issue']}"
        if key in shown:
            continue
        shown.add(key)
        color = sev_colors.get(issue['severity'], NC)
        print(f"    {color}[{issue['severity']}]{NC} {issue['sg_name']} ({issue['sg_id']})")
        print(f"           {issue['issue']}")
        if len(shown) >= 10:
            remaining = len(issues) - 10
            if remaining > 0:
                print(f"    ... y {remaining} problemas adicionales")
            break
    print("")

# SG summary table
print(f"  {CYAN}Security Groups (resumen):{NC}")
for sg in sorted(security_groups, key=lambda x: -x['issue_count'])[:15]:
    display_name = sg['name_tag'] if sg['name_tag'] else sg['sg_name']
    if sg['issue_count'] > 0:
        color = RED if sg['issue_count'] > 2 else YELLOW
        status = f"{color}{sg['issue_count']} problemas{NC}"
    else:
        status = f"{GREEN}OK{NC}"
    print(f"    {display_name:<30} {sg['sg_id']}  in:{sg['ingress_rule_count']} out:{sg['egress_rule_count']}  {status}")

print("")
print(f"{'='*60}")
PYTHON_SCRIPT
}

# --- EjecuciÃ³n principal ---

main() {
    echo "============================================================" >&2
    echo "  AuditorÃ­a de Security Groups AWS - Multicines" >&2
    echo "  RegiÃ³n: ${AWS_REGION}" >&2
    echo "  Fecha:  $(date)" >&2
    echo "============================================================" >&2
    echo "" >&2

    check_prerequisites
    setup_output_dir

    echo "" >&2

    # Paso 1: Obtener todos los Security Groups
    local sg_json
    sg_json=$(fetch_security_groups)

    local total_sgs
    total_sgs=$(echo "${sg_json}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('SecurityGroups',[])))" 2>/dev/null || echo "0")

    if [ "${total_sgs}" -eq 0 ]; then
        log_warning "No se encontraron Security Groups en la regiÃ³n ${AWS_REGION}."
        exit 0
    fi

    echo "" >&2

    # Paso 2: Analizar reglas y detectar problemas
    local analysis_json
    analysis_json=$(analyze_security_groups "${sg_json}")

    echo "" >&2

    # Paso 3: Guardar reporte JSON
    log_info "Guardando reporte JSON..."
    python3 -c "
import sys, json
from datetime import datetime, timezone
data = json.loads(sys.argv[1])
data['metadata'] = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'region': '${AWS_REGION}',
    'account': '$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")'
}
with open('${OUTPUT_FILE}', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" "${analysis_json}"
    log_success "Reporte JSON guardado: ${OUTPUT_FILE}"

    # Paso 4: Generar reporte Markdown
    log_info "Generando reporte Markdown..."
    generate_markdown_report "${analysis_json}"
    log_success "Reporte Markdown guardado: ${REPORT_FILE}"

    # Paso 5: Mostrar resumen en consola
    print_console_summary "${analysis_json}" >&2

    echo "" >&2
    log_success "AuditorÃ­a de Security Groups completada."
    log_info "Archivos generados:"
    echo "  - JSON:     ${OUTPUT_FILE}" >&2
    echo "  - Markdown: ${REPORT_FILE}" >&2
    echo "" >&2
}

main "$@"
