"""
Agrega la sección VPN Site-to-Site al final del Manual Multicines v2.docx
SIN modificar el contenido existente (incluyendo cambios manuales).
Inserta antes de la sección "CI/CD" o al final si no la encuentra.
"""
from docx import Document
from docx.shared import Pt, Inches, RGBColor, Cm
from docx.oxml.ns import nsdecls
from docx.oxml import parse_xml
import os

DOCX_PATH = os.path.join(os.path.dirname(__file__), "Manual Multicines v2.docx")
doc = Document(DOCX_PATH)

# Find insertion point - look for CI/CD heading or append at end
insert_before_idx = None
for i, p in enumerate(doc.paragraphs):
    if "CI/CD" in p.text and p.style.name.startswith("Heading"):
        insert_before_idx = i
        break

# Helper functions
def add_heading(text, level=1):
    return doc.add_heading(text, level=level)

def add_para(text, bold=False):
    p = doc.add_paragraph()
    run = p.add_run(text)
    run.bold = bold
    run.font.size = Pt(10)
    return p

def add_todo(text):
    p = doc.add_paragraph()
    run = p.add_run(f"[TODO: {text}]")
    run.bold = True
    run.font.color.rgb = RGBColor(0xFF, 0x00, 0x00)
    run.font.size = Pt(10)
    return p

def add_step(num, text):
    p = doc.add_paragraph()
    run = p.add_run(f"{num}. {text}")
    run.font.size = Pt(10)
    p.paragraph_format.left_indent = Cm(1)
    return p

def add_table(headers, rows):
    table = doc.add_table(rows=1+len(rows), cols=len(headers))
    table.style = 'Table Grid'
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = ''
        run = cell.paragraphs[0].add_run(h)
        run.bold = True
        run.font.size = Pt(9)
        tc = cell._tc
        tcPr = tc.get_or_add_tcPr()
        shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="D9E2F3" w:val="clear"/>')
        tcPr.append(shading)
    for r_idx, row_data in enumerate(rows):
        for c_idx, val in enumerate(row_data):
            cell = table.rows[r_idx+1].cells[c_idx]
            cell.text = ''
            run = cell.paragraphs[0].add_run(str(val))
            run.font.size = Pt(9)
    doc.add_paragraph()
    return table

# === Add VPN Section ===
doc.add_page_break()

add_heading("VPN Site-to-Site", level=1)

add_para("Se establece una conexión VPN Site-to-Site por ambiente para comunicar la VPC en AWS con la red on-premise de Multicines. Se configura un Customer Gateway (CGW) con la IP pública del router on-premise, un Virtual Private Gateway (VGW) adjunto a la VPC, y una VPN Connection tipo IPSec.")

add_heading("Customer Gateway", level=2)
add_step(1, "VPC → panel izquierdo → Customer Gateways → Create Customer Gateway")
add_step(2, "Name: {env}-multicines-integration-cgw")
add_step(3, "Routing: Static")
add_step(4, "IP Address: IP pública del router on-premise (proporcionada por Multicines)")
add_step(5, "BGP ASN: 65000")
add_step(6, "Click Create Customer Gateway")
add_todo("Insertar pantalla del formulario de creación de Customer Gateway")

add_heading("Virtual Private Gateway", level=2)
add_step(1, "VPC → Virtual Private Gateways → Create Virtual Private Gateway")
add_step(2, "Name: {env}-multicines-integration-vgw")
add_step(3, "ASN: Amazon default ASN")
add_step(4, "Click Create Virtual Private Gateway")
add_step(5, "Seleccionar el VGW recién creado → Actions → Attach to VPC")
add_step(6, "Seleccionar la VPC del ambiente correspondiente")
add_step(7, "Click Attach to VPC")
add_todo("Insertar pantalla del VGW adjunto a la VPC")

add_heading("VPN Connection", level=2)
add_step(1, "VPC → Site-to-Site VPN Connections → Create VPN Connection")
add_step(2, "Name: {env}-multicines-integration-vpn")
add_step(3, "Target Gateway Type: Virtual Private Gateway → seleccionar VGW creado")
add_step(4, "Customer Gateway: Existing → seleccionar CGW creado")
add_step(5, "Routing Options: Static")
add_step(6, "Click Create VPN Connection")
add_step(7, "Seleccionar la conexión → Download Configuration para config del router on-premise")
add_todo("Insertar pantalla del wizard de creación de VPN Connection")
add_todo("Insertar pantalla de Download Configuration")

add_heading("Route Propagation", level=2)
add_step(1, "VPC → Route Tables → seleccionar tabla de rutas privada del ambiente")
add_step(2, "Pestaña Route propagation → Edit route propagation")
add_step(3, "Habilitar propagation para el VGW creado (checkbox)")
add_step(4, "Click Save")
add_step(5, "Verificar en pestaña Routes que aparezcan rutas hacia la red on-premise")
add_todo("Insertar pantalla de Route propagation habilitado")

add_heading("Parámetros de configuración", level=2)
add_table(
    ["Parámetro", "Dev", "Prod"],
    [
        ["Nombre VPN", "dev-multicines-integration-vpn", "prod-multicines-integration-vpn"],
        ["Nombre VGW", "dev-multicines-integration-vgw", "prod-multicines-integration-vgw"],
        ["Nombre CGW", "dev-multicines-integration-cgw", "prod-multicines-integration-cgw"],
        ["VPC", "vpc-0a5ebea8e7bee9ed5", "vpc-0860a0d2cf4df6140"],
        ["Customer IP", "IP del router on-premise", "IP del router on-premise"],
        ["BGP ASN", "65000", "65000"],
        ["Tipo túnel", "ipsec.1", "ipsec.1"],
        ["Route propagation", "Habilitado (route tables privadas)", "Habilitado (route tables privadas)"],
    ]
)

add_heading("Verificación", level=2)
add_step(1, "VPN Connections → Tunnel Details: al menos un túnel con estado UP")
add_step(2, "Route Tables privadas: verificar rutas propagadas hacia CIDR on-premise")
add_step(3, "CloudWatch → Métricas → AWS/VPN → TunnelState (1=UP, 0=DOWN)")

add_heading("Troubleshooting", level=2)
add_table(
    ["Problema", "Causa", "Solución"],
    [
        ["Túnel DOWN", "Config IKE/IPSec incorrecta en router", "Descargar config desde AWS y aplicar en router"],
        ["Sin conectividad", "Route tables sin ruta al CIDR on-premise", "Verificar route propagation habilitado"],
        ["Túnel flapping", "Dead Peer Detection timeout agresivo", "Ajustar DPD timeout en ambos lados"],
    ]
)

# === Save ===
doc.save(DOCX_PATH)
print(f"[OK] VPN section added to: {DOCX_PATH}")
print(f"[OK] Size: {os.path.getsize(DOCX_PATH) / 1024:.0f} KB")
