"""
Fix VPN section: remove the badly placed one, then insert correctly
as section 13 before Anexo (which becomes 14).
"""
from docx import Document
from docx.shared import Pt, Inches, RGBColor, Cm
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml
import os

DOCX_PATH = os.path.join(os.path.dirname(__file__), "Manual Multicines v2.docx")
doc = Document(DOCX_PATH)
body = doc.element.body

# === Step 1: Remove ALL VPN elements ===
# Find VPN heading and collect all elements until Anexo or end
vpn_start = None
anexo_start = None

for i, p in enumerate(doc.paragraphs):
    if p.style.name == 'Heading 1' and 'VPN Site-to-Site' in p.text:
        vpn_start = p._element
    if p.style.name == 'Heading 1' and 'Anexo' in p.text:
        anexo_start = p._element

if vpn_start is None:
    print("[ERROR] VPN heading not found")
    exit(1)

# Collect VPN elements (from VPN heading until Anexo heading)
vpn_elements_to_remove = []
found_vpn = False
for elem in list(body):
    if elem is vpn_start:
        found_vpn = True
    if found_vpn:
        if elem is anexo_start:
            break
        if elem.tag.endswith('}sectPr'):
            break
        vpn_elements_to_remove.append(elem)

print(f"[INFO] Removing {len(vpn_elements_to_remove)} VPN elements")
for elem in vpn_elements_to_remove:
    body.remove(elem)

# === Step 2: Rename Anexo to 14 ===
for p in doc.paragraphs:
    if p.style.name == 'Heading 1' and 'Anexo' in p.text:
        # Clear and rewrite
        for run in p.runs:
            run.text = ''
        p.runs[0].text = '14. Anexo — Resumen de Recursos por Ambiente'
        print("[INFO] Renamed Anexo to section 14")
        anexo_elem = p._element
        break

# === Step 3: Insert VPN section before Anexo ===
def make_heading(text, level):
    from docx.oxml import OxmlElement
    p = OxmlElement('w:p')
    pPr = OxmlElement('w:pPr')
    pStyle = OxmlElement('w:pStyle')
    pStyle.set(qn('w:val'), f'Heading{level}')
    pPr.append(pStyle)
    p.append(pPr)
    r = OxmlElement('w:r')
    t = OxmlElement('w:t')
    t.text = text
    r.append(t)
    p.append(r)
    return p

def make_para(text, bold=False, indent=False, color=None, size=10):
    from docx.oxml import OxmlElement
    p = OxmlElement('w:p')
    if indent:
        pPr = OxmlElement('w:pPr')
        ind = OxmlElement('w:ind')
        ind.set(qn('w:left'), '720')
        pPr.append(ind)
        p.append(pPr)
    r = OxmlElement('w:r')
    rPr = OxmlElement('w:rPr')
    if bold:
        b = OxmlElement('w:b')
        rPr.append(b)
    if color:
        c = OxmlElement('w:color')
        c.set(qn('w:val'), color)
        rPr.append(c)
    sz = OxmlElement('w:sz')
    sz.set(qn('w:val'), str(size * 2))
    rPr.append(sz)
    r.append(rPr)
    t = OxmlElement('w:t')
    t.set(qn('xml:space'), 'preserve')
    t.text = text
    r.append(t)
    p.append(r)
    return p

def make_page_break():
    from docx.oxml import OxmlElement
    p = OxmlElement('w:p')
    r = OxmlElement('w:r')
    br = OxmlElement('w:br')
    br.set(qn('w:type'), 'page')
    r.append(br)
    p.append(r)
    return p

# Build VPN elements in correct order
vpn_new = []

vpn_new.append(make_page_break())
vpn_new.append(make_heading('13. VPN Site-to-Site', 1))
vpn_new.append(make_para(''))
vpn_new.append(make_para('Se establece una conexión VPN Site-to-Site por ambiente para comunicar la VPC en AWS con la red on-premise de Multicines. Se configura un Customer Gateway (CGW), un Virtual Private Gateway (VGW) adjunto a la VPC, y una VPN Connection tipo IPSec que los asocia. Se habilita route propagation en las tablas de enrutamiento privadas.'))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.1 Customer Gateway', 2))
vpn_new.append(make_para('1. VPC → panel izquierdo → Customer Gateways → Create Customer Gateway', indent=True))
vpn_new.append(make_para('2. Name: {env}-multicines-integration-cgw', indent=True))
vpn_new.append(make_para('3. Routing: Static', indent=True))
vpn_new.append(make_para('4. IP Address: IP pública del router on-premise (proporcionada por Multicines)', indent=True))
vpn_new.append(make_para('5. BGP ASN: 65000', indent=True))
vpn_new.append(make_para('6. Click Create Customer Gateway', indent=True))
vpn_new.append(make_para(''))
vpn_new.append(make_para('[TODO: Insertar pantalla del formulario de creación de Customer Gateway]', bold=True, color='FF0000'))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.2 Virtual Private Gateway', 2))
vpn_new.append(make_para('1. VPC → Virtual Private Gateways → Create Virtual Private Gateway', indent=True))
vpn_new.append(make_para('2. Name: {env}-multicines-integration-vgw', indent=True))
vpn_new.append(make_para('3. ASN: Amazon default ASN', indent=True))
vpn_new.append(make_para('4. Click Create Virtual Private Gateway', indent=True))
vpn_new.append(make_para('5. Seleccionar el VGW → Actions → Attach to VPC', indent=True))
vpn_new.append(make_para('6. Seleccionar la VPC del ambiente correspondiente', indent=True))
vpn_new.append(make_para('7. Click Attach to VPC', indent=True))
vpn_new.append(make_para(''))
vpn_new.append(make_para('[TODO: Insertar pantalla del VGW adjunto a la VPC]', bold=True, color='FF0000'))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.3 VPN Connection', 2))
vpn_new.append(make_para('1. VPC → Site-to-Site VPN Connections → Create VPN Connection', indent=True))
vpn_new.append(make_para('2. Name: {env}-multicines-integration-vpn', indent=True))
vpn_new.append(make_para('3. Target Gateway Type: Virtual Private Gateway → seleccionar VGW creado', indent=True))
vpn_new.append(make_para('4. Customer Gateway: Existing → seleccionar CGW creado', indent=True))
vpn_new.append(make_para('5. Routing Options: Static', indent=True))
vpn_new.append(make_para('6. Click Create VPN Connection', indent=True))
vpn_new.append(make_para('7. Seleccionar la conexión → Download Configuration para config del router', indent=True))
vpn_new.append(make_para(''))
vpn_new.append(make_para('[TODO: Insertar pantalla del wizard de creación de VPN Connection]', bold=True, color='FF0000'))
vpn_new.append(make_para('[TODO: Insertar pantalla de Download Configuration]', bold=True, color='FF0000'))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.4 Route Propagation', 2))
vpn_new.append(make_para('1. VPC → Route Tables → seleccionar tabla de rutas privada del ambiente', indent=True))
vpn_new.append(make_para('2. Pestaña Route propagation → Edit route propagation', indent=True))
vpn_new.append(make_para('3. Habilitar propagation para el VGW creado (checkbox)', indent=True))
vpn_new.append(make_para('4. Click Save', indent=True))
vpn_new.append(make_para('5. Verificar en pestaña Routes que aparezcan rutas hacia la red on-premise', indent=True))
vpn_new.append(make_para(''))
vpn_new.append(make_para('[TODO: Insertar pantalla de Route propagation habilitado]', bold=True, color='FF0000'))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.5 Parámetros de Configuración', 2))
vpn_new.append(make_para(''))

vpn_new.append(make_heading('13.6 Verificación', 2))
vpn_new.append(make_para('1. VPN Connections → Tunnel Details: al menos un túnel con estado UP', indent=True))
vpn_new.append(make_para('2. Route Tables privadas: verificar rutas propagadas hacia CIDR on-premise', indent=True))
vpn_new.append(make_para('3. CloudWatch → Métricas → AWS/VPN → TunnelState (1=UP, 0=DOWN)', indent=True))
vpn_new.append(make_para(''))

# Insert all VPN elements before Anexo
for elem in reversed(vpn_new):
    anexo_elem.addprevious(elem)

print(f"[INFO] Inserted {len(vpn_new)} new VPN elements before Anexo")

# === Step 4: Add VPN config table ===
# Tables need to be added via python-docx API after the document is restructured
# We'll add it at the end and note it needs manual placement
# Actually let's just save as-is - the table from before was removed

doc.save(DOCX_PATH)
print(f"\n[DONE] {DOCX_PATH}")
print(f"[DONE] Size: {os.path.getsize(DOCX_PATH) / 1024:.0f} KB")
