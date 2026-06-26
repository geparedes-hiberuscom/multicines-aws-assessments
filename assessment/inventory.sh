#!/bin/bash
#
# inventory.sh - Inventario de recursos AWS existentes en la cuenta de Multicines
#
# Este script ejecuta comandos AWS CLI para listar todos los recursos relevantes
# organizados por categorÃ­a. El output se guarda en assessment/output/.
#
# Requisitos:
#   - AWS CLI v2 instalado y configurado
#   - Permisos de lectura (describe/list) sobre la cuenta AWS
#
# Uso:
#   ./assessment/inventory.sh
#   AWS_REGION=us-west-2 ./assessment/inventory.sh
#

set -euo pipefail

# ConfiguraciÃ³n
AWS_REGION="${AWS_REGION:-us-east-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/output"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
OUTPUT_FILE="${OUTPUT_DIR}/inventory_${TIMESTAMP}.json"

# Colores para output en consola
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Ejecuta un comando AWS CLI y captura el resultado.
# Si falla, registra el error y retorna un JSON vacÃ­o.
run_aws_command() {
    local description="$1"
    shift
    local result

    log_info "Listando: ${description}..."
    if result=$("$@" --output json 2>&1); then
        log_success "${description} - completado"
        echo "${result}"
    else
        log_warning "${description} - fallÃ³: ${result}"
        echo "{\"error\": \"${description} failed\", \"details\": \"$(echo "${result}" | tr '"' "'")\"}"
    fi
}

# --- ValidaciÃ³n de prerequisitos ---

check_prerequisites() {
    log_info "Verificando prerequisitos..."

    if ! command -v aws &> /dev/null; then
        log_error "AWS CLI no estÃ¡ instalado. InstÃ¡lelo desde https://aws.amazon.com/cli/"
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
    log_info "Output se guardarÃ¡ en: ${OUTPUT_FILE}"
}

# --- Funciones de inventario por categorÃ­a ---

inventory_vpcs() {
    run_aws_command "VPCs" \
        aws ec2 describe-vpcs --region "${AWS_REGION}"
}

inventory_subnets() {
    run_aws_command "Subnets" \
        aws ec2 describe-subnets --region "${AWS_REGION}"
}

inventory_ecs_clusters() {
    local clusters
    clusters=$(run_aws_command "ECS Clusters (ARNs)" \
        aws ecs list-clusters --region "${AWS_REGION}")

    # Si hay clusters, obtener detalles
    local cluster_arns
    cluster_arns=$(echo "${clusters}" | python3 -c "import sys,json;arns=json.load(sys.stdin).get('clusterArns',[]);print(' '.join(arns))" 2>/dev/null || echo "")

    if [ -n "${cluster_arns}" ]; then
        run_aws_command "ECS Clusters (detalles)" \
            aws ecs describe-clusters --clusters ${cluster_arns} --region "${AWS_REGION}"
    else
        echo "${clusters}"
    fi
}

inventory_albs() {
    run_aws_command "Application Load Balancers" \
        aws elbv2 describe-load-balancers --region "${AWS_REGION}"
}

inventory_vpn_connections() {
    run_aws_command "VPN Connections" \
        aws ec2 describe-vpn-connections --region "${AWS_REGION}"
}

inventory_security_groups() {
    run_aws_command "Security Groups" \
        aws ec2 describe-security-groups --region "${AWS_REGION}"
}

inventory_iam_roles() {
    # IAM is a global service, region is not required but we pass it for consistency
    run_aws_command "IAM Roles" \
        aws iam list-roles --region "${AWS_REGION}"
}

inventory_ecr_repos() {
    run_aws_command "ECR Repositories" \
        aws ecr describe-repositories --region "${AWS_REGION}"
}

inventory_route53_zones() {
    # Route 53 is a global service
    run_aws_command "Route 53 Hosted Zones" \
        aws route53 list-hosted-zones --region "${AWS_REGION}"
}

inventory_waf_web_acls_regional() {
    run_aws_command "WAF Web ACLs (Regional)" \
        aws wafv2 list-web-acls --scope REGIONAL --region "${AWS_REGION}"
}

inventory_waf_web_acls_cloudfront() {
    # CloudFront WAF must be in us-east-1
    run_aws_command "WAF Web ACLs (CloudFront)" \
        aws wafv2 list-web-acls --scope CLOUDFRONT --region us-east-1
}

inventory_acm_certificates() {
    run_aws_command "ACM Certificates" \
        aws acm list-certificates --region "${AWS_REGION}"
}

inventory_secrets_manager() {
    run_aws_command "Secrets Manager Secrets" \
        aws secretsmanager list-secrets --region "${AWS_REGION}"
}

inventory_cloudwatch_log_groups() {
    run_aws_command "CloudWatch Log Groups" \
        aws logs describe-log-groups --region "${AWS_REGION}"
}

# --- EjecuciÃ³n principal ---

main() {
    echo "============================================================" >&2
    echo "  Inventario de Recursos AWS - Multicines" >&2
    echo "  RegiÃ³n: ${AWS_REGION}" >&2
    echo "  Fecha:  $(date)" >&2
    echo "============================================================" >&2
    echo "" >&2

    check_prerequisites
    setup_output_dir

    echo "" >&2
    log_info "Iniciando inventario de recursos AWS..."
    echo "" >&2

    # Recopilar inventario de cada categorÃ­a
    local vpcs subnets ecs albs vpn sgs iam_roles ecr route53 waf_regional waf_cloudfront acm secrets log_groups

    vpcs=$(inventory_vpcs)
    subnets=$(inventory_subnets)
    ecs=$(inventory_ecs_clusters)
    albs=$(inventory_albs)
    vpn=$(inventory_vpn_connections)
    sgs=$(inventory_security_groups)
    iam_roles=$(inventory_iam_roles)
    ecr=$(inventory_ecr_repos)
    route53=$(inventory_route53_zones)
    waf_regional=$(inventory_waf_web_acls_regional)
    waf_cloudfront=$(inventory_waf_web_acls_cloudfront)
    acm=$(inventory_acm_certificates)
    secrets=$(inventory_secrets_manager)
    log_groups=$(inventory_cloudwatch_log_groups)

    # Construir JSON consolidado
    cat > "${OUTPUT_FILE}" << EOF
{
  "metadata": {
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "region": "${AWS_REGION}",
    "account": "$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo 'unknown')"
  },
  "vpcs": ${vpcs},
  "subnets": ${subnets},
  "ecs_clusters": ${ecs},
  "load_balancers": ${albs},
  "vpn_connections": ${vpn},
  "security_groups": ${sgs},
  "iam_roles": ${iam_roles},
  "ecr_repositories": ${ecr},
  "route53_hosted_zones": ${route53},
  "waf_web_acls": {
    "regional": ${waf_regional},
    "cloudfront": ${waf_cloudfront}
  },
  "acm_certificates": ${acm},
  "secrets_manager": ${secrets},
  "cloudwatch_log_groups": ${log_groups}
}
EOF

    echo "" >&2
    echo "============================================================" >&2
    log_success "Inventario completado exitosamente."
    log_info "Archivo generado: ${OUTPUT_FILE}"
    echo "============================================================" >&2

    # Resumen rÃ¡pido de recursos encontrados
    echo "" >&2
    log_info "Resumen de recursos encontrados:"
    echo "  - VPCs:              $(echo "${vpcs}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('Vpcs',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Subnets:           $(echo "${subnets}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('Subnets',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - ECS Clusters:      $(echo "${ecs}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('clusters',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Load Balancers:    $(echo "${albs}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('LoadBalancers',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - VPN Connections:   $(echo "${vpn}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('VpnConnections',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Security Groups:   $(echo "${sgs}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('SecurityGroups',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - IAM Roles:         $(echo "${iam_roles}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('Roles',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - ECR Repos:         $(echo "${ecr}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('repositories',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Route 53 Zones:    $(echo "${route53}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('HostedZones',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - WAF Web ACLs:      $(echo "${waf_regional}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('WebACLs',[])))" 2>/dev/null || echo 'N/A') (regional)" >&2
    echo "  - ACM Certificates:  $(echo "${acm}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('CertificateSummaryList',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Secrets:           $(echo "${secrets}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('SecretList',[])))" 2>/dev/null || echo 'N/A')" >&2
    echo "  - Log Groups:        $(echo "${log_groups}" | python3 -c "import sys,json;print(len(json.load(sys.stdin).get('logGroups',[])))" 2>/dev/null || echo 'N/A')" >&2
}

main "$@"
