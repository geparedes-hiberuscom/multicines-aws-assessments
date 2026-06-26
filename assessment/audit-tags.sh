#!/bin/bash
#
# audit-tags.sh - AuditorÃ­a de tags de recursos AWS para Multicines
#
# Este script utiliza la AWS Resource Groups Tagging API para extraer los tags
# actuales de cada recurso e identificar cuÃ¡les no cumplen con el estÃ¡ndar
# propuesto de tags obligatorios: Project, Environment, ManagedBy, Service.
#
# Genera un reporte JSON con el detalle de cumplimiento por recurso y un
# resumen de compliance general.
#
# Requisitos:
#   - AWS CLI v2 instalado y configurado
#   - Permisos: tag:GetResources, sts:GetCallerIdentity
#
# Uso:
#   ./assessment/audit-tags.sh
#   AWS_REGION=us-west-2 ./assessment/audit-tags.sh
#

set -euo pipefail

# ConfiguraciÃ³n
AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUTPUT_DIR}/audit-tags_${TIMESTAMP}.json"
REPORT_FILE="${OUTPUT_DIR}/audit-tags_${TIMESTAMP}.md"

# Tags obligatorios segÃºn el estÃ¡ndar propuesto
REQUIRED_TAGS=("Project" "Environment" "ManagedBy" "Service")

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

# --- Obtener todos los recursos con tags usando Resource Groups Tagging API ---

fetch_all_tagged_resources() {
    log_info "Obteniendo recursos vÃ­a Resource Groups Tagging API..."

    local all_resources="[]"
    local pagination_token=""
    local page=1

    while true; do
        local cmd_args=(aws resourcegroupstaggingapi get-resources --region "${AWS_REGION}" --output json)

        if [ -n "${pagination_token}" ]; then
            cmd_args+=(--pagination-token "${pagination_token}")
        fi

        local response
        if ! response=$("${cmd_args[@]}" 2>&1); then
            log_error "Error al obtener recursos: ${response}"
            echo "[]"
            return 1
        fi

        # Extraer recursos de esta pÃ¡gina y concatenar
        local page_resources
        page_resources=$(echo "${response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
resources = data.get('ResourceTagMappingList', [])
print(json.dumps(resources))
" 2>/dev/null || echo "[]")

        all_resources=$(python3 -c "
import sys, json
existing = json.loads(sys.argv[1])
new_page = json.loads(sys.argv[2])
existing.extend(new_page)
print(json.dumps(existing))
" "${all_resources}" "${page_resources}" 2>/dev/null || echo "${all_resources}")

        # Verificar si hay mÃ¡s pÃ¡ginas
        pagination_token=$(echo "${response}" | python3 -c "
import sys, json
data = json.load(sys.stdin)
token = data.get('PaginationToken', '')
print(token)
" 2>/dev/null || echo "")

        local page_count
        page_count=$(echo "${page_resources}" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
        log_info "  PÃ¡gina ${page}: ${page_count} recursos obtenidos"

        page=$((page + 1))

        if [ -z "${pagination_token}" ]; then
            break
        fi
    done

    local total
    total=$(echo "${all_resources}" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")
    log_success "Total de recursos obtenidos: ${total}"

    echo "${all_resources}"
}

# --- Evaluar cumplimiento de tags ---

evaluate_tag_compliance() {
    local resources_json="$1"

    log_info "Evaluando cumplimiento de tags obligatorios..."
    log_info "Tags requeridos: ${REQUIRED_TAGS[*]}"

    python3 << 'PYTHON_SCRIPT' - "${resources_json}" "${REQUIRED_TAGS[*]}"
import sys
import json

resources_json = sys.argv[1]
required_tags_str = sys.argv[2]
required_tags = required_tags_str.split()

resources = json.loads(resources_json)

compliant = []
non_compliant = []

for resource in resources:
    arn = resource.get('ResourceARN', 'unknown')
    tags = resource.get('Tags', [])

    # Construir mapa de tags del recurso
    tag_map = {tag['Key']: tag['Value'] for tag in tags}

    # Verificar tags faltantes
    missing_tags = [t for t in required_tags if t not in tag_map]
    present_tags = [t for t in required_tags if t in tag_map]

    resource_report = {
        "arn": arn,
        "resource_type": arn.split(":")[2] if len(arn.split(":")) > 2 else "unknown",
        "existing_tags": tag_map,
        "required_tags_present": present_tags,
        "required_tags_missing": missing_tags,
        "is_compliant": len(missing_tags) == 0,
        "compliance_percentage": round((len(present_tags) / len(required_tags)) * 100, 1)
    }

    if len(missing_tags) == 0:
        compliant.append(resource_report)
    else:
        non_compliant.append(resource_report)

# EstadÃ­sticas por tipo de recurso
resource_types = {}
for r in compliant + non_compliant:
    rtype = r["resource_type"]
    if rtype not in resource_types:
        resource_types[rtype] = {"total": 0, "compliant": 0, "non_compliant": 0}
    resource_types[rtype]["total"] += 1
    if r["is_compliant"]:
        resource_types[rtype]["compliant"] += 1
    else:
        resource_types[rtype]["non_compliant"] += 1

# EstadÃ­sticas por tag faltante
missing_tag_stats = {tag: 0 for tag in required_tags}
for r in non_compliant:
    for tag in r["required_tags_missing"]:
        missing_tag_stats[tag] += 1

total_resources = len(compliant) + len(non_compliant)
compliance_rate = round((len(compliant) / total_resources * 100), 1) if total_resources > 0 else 0

result = {
    "summary": {
        "total_resources": total_resources,
        "compliant_resources": len(compliant),
        "non_compliant_resources": len(non_compliant),
        "compliance_rate_percent": compliance_rate,
        "required_tags": required_tags,
        "missing_tag_frequency": missing_tag_stats,
        "compliance_by_resource_type": resource_types
    },
    "compliant_resources": compliant,
    "non_compliant_resources": non_compliant
}

print(json.dumps(result))
PYTHON_SCRIPT
}

# --- Generar reporte Markdown ---

generate_markdown_report() {
    local compliance_json="$1"

    python3 << 'PYTHON_SCRIPT' - "${compliance_json}" "${REPORT_FILE}" "${AWS_REGION}"
import sys
import json
from datetime import datetime, timezone

compliance_data = json.loads(sys.argv[1])
report_file = sys.argv[2]
region = sys.argv[3]

summary = compliance_data["summary"]
non_compliant = compliance_data["non_compliant_resources"]
compliant = compliance_data["compliant_resources"]

lines = []
lines.append("# AuditorÃ­a de Tags - Multicines AWS")
lines.append("")
lines.append(f"**Fecha:** {datetime.now(timezone.utc).strftime('%Y-%m-%d %H:%M:%S UTC')}")
lines.append(f"**RegiÃ³n:** {region}")
lines.append(f"**Tags obligatorios:** {', '.join(summary['required_tags'])}")
lines.append("")
lines.append("---")
lines.append("")
lines.append("## Resumen Ejecutivo")
lines.append("")
lines.append(f"| MÃ©trica | Valor |")
lines.append(f"|---------|-------|")
lines.append(f"| Total de recursos evaluados | {summary['total_resources']} |")
lines.append(f"| Recursos conformes | {summary['compliant_resources']} |")
lines.append(f"| Recursos NO conformes | {summary['non_compliant_resources']} |")
lines.append(f"| Tasa de cumplimiento | {summary['compliance_rate_percent']}% |")
lines.append("")

# Frecuencia de tags faltantes
lines.append("## Tags Faltantes (Frecuencia)")
lines.append("")
lines.append("| Tag | Recursos sin este tag |")
lines.append("|-----|----------------------|")
for tag, count in sorted(summary["missing_tag_frequency"].items(), key=lambda x: -x[1]):
    lines.append(f"| {tag} | {count} |")
lines.append("")

# Compliance por tipo de recurso
lines.append("## Cumplimiento por Tipo de Recurso")
lines.append("")
lines.append("| Tipo de Recurso | Total | Conformes | No Conformes | % Cumplimiento |")
lines.append("|-----------------|-------|-----------|--------------|----------------|")
for rtype, stats in sorted(summary["compliance_by_resource_type"].items()):
    pct = round((stats["compliant"] / stats["total"]) * 100, 1) if stats["total"] > 0 else 0
    lines.append(f"| {rtype} | {stats['total']} | {stats['compliant']} | {stats['non_compliant']} | {pct}% |")
lines.append("")

# Recursos NO conformes (detalle)
lines.append("## Recursos No Conformes (Detalle)")
lines.append("")
if non_compliant:
    for i, resource in enumerate(non_compliant[:50], 1):  # Limitar a 50 para legibilidad
        lines.append(f"### {i}. `{resource['arn']}`")
        lines.append("")
        lines.append(f"- **Tipo:** {resource['resource_type']}")
        lines.append(f"- **Cumplimiento:** {resource['compliance_percentage']}%")
        lines.append(f"- **Tags faltantes:** {', '.join(resource['required_tags_missing'])}")
        lines.append(f"- **Tags presentes:** {', '.join(resource['required_tags_present']) if resource['required_tags_present'] else 'Ninguno'}")
        lines.append("")
    if len(non_compliant) > 50:
        lines.append(f"*... y {len(non_compliant) - 50} recursos adicionales no conformes (ver JSON para detalle completo)*")
        lines.append("")
else:
    lines.append("âœ… Todos los recursos cumplen con el estÃ¡ndar de tags.")
    lines.append("")

# Recursos conformes (resumen)
lines.append("## Recursos Conformes")
lines.append("")
if compliant:
    lines.append(f"Total: {len(compliant)} recursos cumplen con todos los tags obligatorios.")
    lines.append("")
    lines.append("<details>")
    lines.append("<summary>Ver lista completa de recursos conformes</summary>")
    lines.append("")
    for resource in compliant[:100]:
        lines.append(f"- `{resource['arn']}`")
    if len(compliant) > 100:
        lines.append(f"- *... y {len(compliant) - 100} recursos adicionales*")
    lines.append("")
    lines.append("</details>")
    lines.append("")
else:
    lines.append("âš ï¸ No se encontraron recursos que cumplan con todos los tags obligatorios.")
    lines.append("")

# Recomendaciones
lines.append("---")
lines.append("")
lines.append("## Recomendaciones")
lines.append("")
lines.append("1. Aplicar los tags faltantes de forma inmediata a todos los recursos no conformes")
lines.append("2. Implementar `default_tags` en el provider de Terraform para garantizar tags automÃ¡ticos")
lines.append("3. Configurar AWS Config Rule `required-tags` para detectar recursos sin tags obligatorios")
lines.append("4. Usar AWS Tag Editor para aplicaciÃ³n masiva de tags pendientes")
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
print(f"{BOLD}  RESUMEN DE AUDITORÃA DE TAGS{NC}")
print(f"{BOLD}{'='*60}{NC}")
print("")
print(f"  Tags obligatorios: {', '.join(summary['required_tags'])}")
print("")
print(f"  Total recursos evaluados:  {summary['total_resources']}")

if summary['compliance_rate_percent'] >= 80:
    color = GREEN
elif summary['compliance_rate_percent'] >= 50:
    color = YELLOW
else:
    color = RED

print(f"  Recursos conformes:        {GREEN}{summary['compliant_resources']}{NC}")
print(f"  Recursos NO conformes:     {RED}{summary['non_compliant_resources']}{NC}")
print(f"  Tasa de cumplimiento:      {color}{summary['compliance_rate_percent']}%{NC}")
print("")

# Tags faltantes
print(f"  {CYAN}Frecuencia de tags faltantes:{NC}")
for tag, count in sorted(summary['missing_tag_frequency'].items(), key=lambda x: -x[1]):
    bar = 'â–ˆ' * min(count, 30)
    print(f"    {tag:<12} : {count:>4} recursos  {YELLOW}{bar}{NC}")
print("")

# Top 5 tipos de recurso con peor cumplimiento
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
    echo "  AuditorÃ­a de Tags AWS - Multicines" >&2
    echo "  RegiÃ³n: ${AWS_REGION}" >&2
    echo "  Fecha:  $(date)" >&2
    echo "============================================================" >&2
    echo "" >&2

    check_prerequisites
    setup_output_dir

    echo "" >&2

    # Paso 1: Obtener todos los recursos con sus tags
    local resources_json
    resources_json=$(fetch_all_tagged_resources)

    local total_resources
    total_resources=$(echo "${resources_json}" | python3 -c "import sys,json;print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

    if [ "${total_resources}" -eq 0 ]; then
        log_warning "No se encontraron recursos con tags en la regiÃ³n ${AWS_REGION}."
        log_info "Esto puede significar que los recursos no tienen tags asignados."
        log_info "Considere usar 'aws resourcegroupstaggingapi get-resources' manualmente para verificar."
        exit 0
    fi

    echo "" >&2

    # Paso 2: Evaluar cumplimiento de tags
    local compliance_json
    compliance_json=$(evaluate_tag_compliance "${resources_json}")

    echo "" >&2

    # Paso 3: Guardar reporte JSON
    log_info "Guardando reporte JSON..."
    python3 -c "
import sys, json
data = json.loads(sys.argv[1])
# Agregar metadata
from datetime import datetime, timezone
data['metadata'] = {
    'timestamp': datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ'),
    'region': '${AWS_REGION}',
    'account': '$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "unknown")',
    'required_tags': '${REQUIRED_TAGS[*]}'.split()
}
with open('${OUTPUT_FILE}', 'w', encoding='utf-8') as f:
    json.dump(data, f, indent=2, ensure_ascii=False)
" "${compliance_json}"
    log_success "Reporte JSON guardado: ${OUTPUT_FILE}"

    # Paso 4: Generar reporte Markdown
    log_info "Generando reporte Markdown..."
    generate_markdown_report "${compliance_json}"
    log_success "Reporte Markdown guardado: ${REPORT_FILE}"

    # Paso 5: Mostrar resumen en consola
    print_console_summary "${compliance_json}" >&2

    echo "" >&2
    log_success "AuditorÃ­a de tags completada."
    log_info "Archivos generados:"
    echo "  - JSON: ${OUTPUT_FILE}" >&2
    echo "  - Markdown: ${REPORT_FILE}" >&2
    echo "" >&2
}

main "$@"
