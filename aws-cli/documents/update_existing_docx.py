"""
Actualiza las secciones EXISTENTES del Manual Multicines v2.docx con configuración actual.
Busca tablas y párrafos específicos del documento original y los actualiza in-place.
"""
from docx import Document
from docx.shared import Pt, RGBColor
from docx.oxml.ns import qn
import os

DOCX_PATH = os.path.join(os.path.dirname(__file__), "Manual Multicines v2.docx")

doc = Document(DOCX_PATH)

# === Helper: find paragraph containing text ===
def find_paragraph(text, start_idx=0):
    for i, p in enumerate(doc.paragraphs):
        if i < start_idx:
            continue
        if text.lower() in p.text.lower():
            return i, p
    return -1, None

# === Helper: find table after a paragraph index ===
def find_table_after(para_idx):
    """Find the first table that appears after the given paragraph index in document order."""
    # Get the paragraph element
    para_elem = doc.paragraphs[para_idx]._element
    # Walk siblings after this paragraph looking for a table
    sibling = para_elem.getnext()
    while sibling is not None:
        if sibling.tag.endswith('}tbl'):
            # Found a table element, match it to doc.tables
            for table in doc.tables:
                if table._tbl is sibling:
                    return table
        sibling = sibling.getnext()
    return None

# === Helper: update table cell ===
def set_cell(table, row, col, text):
    cell = table.rows[row].cells[col]
    cell.text = str(text)

# === Helper: add row to table ===
def add_row_to_table(table, values):
    row = table.add_row()
    for i, val in enumerate(values):
        row.cells[i].text = str(val)

# === Helper: insert paragraph after another ===
def insert_para_after(para, text, bold=False, color=None):
    new_p = doc.add_paragraph()
    # Move it after the target paragraph
    para._element.addnext(new_p._element)
    run = new_p.add_run(text)
    run.bold = bold
    if color:
        run.font.color.rgb = color
    return new_p

# =============================================================================
# UPDATE: Task Definition tables — update environment variables
# =============================================================================
print("[INFO] Updating Task Definition environment variables...")

# Find the "Variables de entorno configuradas" section
idx, para = find_paragraph("variables de entorno configuradas")
if idx > 0:
    table = find_table_after(idx)
    if table and len(table.rows) >= 2:
        # Clear existing rows (except header) and rebuild
        # The table should have: Variable | Dev | Prod
        # Current table has old values - let's find and update OTEL_TRACES_EXPORTER
        for row in table.rows[1:]:
            var_name = row.cells[0].text.strip()
            if var_name == "OTEL_TRACES_EXPORTER":
                row.cells[1].text = "otlp"
                row.cells[2].text = "otlp"
                print(f"  [UPDATED] {var_name} → otlp")
        
        # Add new OTEL rows if they don't exist
        existing_vars = [row.cells[0].text.strip() for row in table.rows[1:]]
        new_vars = [
            ("OTEL_SERVICE_NAME", "integrator", "integrator"),
            ("OTEL_EXPORTER_OTLP_ENDPOINT", "http://localhost:4317", "http://localhost:4317"),
            ("OTEL_EXPORTER_OTLP_PROTOCOL", "grpc", "grpc"),
            ("OTEL_TRACES_SAMPLER", "parentbased_traceidratio", "parentbased_traceidratio"),
            ("OTEL_TRACES_SAMPLER_ARG", "1.0 (100%)", "0.10 (10%)"),
        ]
        for var_name, dev_val, prod_val in new_vars:
            if var_name not in existing_vars:
                add_row_to_table(table, [var_name, dev_val, prod_val])
                print(f"  [ADDED] {var_name}")
    print("[OK] Environment variables table updated")
else:
    print("[WARN] Could not find 'Variables de entorno configuradas' section")

# =============================================================================
# UPDATE: Task Definition Dev table — update CPU/Memory values
# =============================================================================
print("[INFO] Updating Task Definition Dev parameters...")

idx, para = find_paragraph("dev --- dev-multicines-integration")
if idx < 0:
    idx, para = find_paragraph("dev-multicines-integration")

if idx > 0:
    table = find_table_after(idx)
    if table:
        for row in table.rows[1:]:
            param = row.cells[0].text.strip()
            if "CPU" in param.upper() and "vCPU" not in row.cells[1].text:
                pass  # Already correct format
            if param == "Nombre del contenedor" or "contenedor" in param.lower():
                row.cells[1].text = "integration-service"
                print(f"  [UPDATED] Container name → integration-service")
        print("[OK] Dev Task Definition table checked")
else:
    print("[WARN] Could not find Dev task definition section")

# =============================================================================
# UPDATE: Prod table 
# =============================================================================
print("[INFO] Updating Task Definition Prod parameters...")

idx, para = find_paragraph("prod --- prod-multicines-integration")
if idx < 0:
    idx, para = find_paragraph("prod-multicines-integration", start_idx=400)

if idx > 0:
    table = find_table_after(idx)
    if table:
        for row in table.rows[1:]:
            param = row.cells[0].text.strip()
            if param == "Nombre del contenedor" or "contenedor" in param.lower():
                row.cells[1].text = "integration-service"
                print(f"  [UPDATED] Prod container name → integration-service")
            if "Memoria" in param:
                row.cells[1].text = "2GB"
                print(f"  [UPDATED] Prod memory → 2GB")
            if "CPU" in param and "vCPU" not in row.cells[1].text:
                row.cells[1].text = "1 vCPU"
                print(f"  [UPDATED] Prod CPU → 1 vCPU")
        print("[OK] Prod Task Definition table checked")
else:
    print("[WARN] Could not find Prod task definition section")

# =============================================================================
# ADD: Note about ADOT sidecar after Task Definition section
# =============================================================================
print("[INFO] Adding ADOT sidecar note...")

idx, para = find_paragraph("para crear cada task definition")
if idx < 0:
    idx, para = find_paragraph("task definition")

# Find last paragraph before ECS service creation that mentions task def
idx2, para2 = find_paragraph("proveedor de identid")
if idx2 > 0:
    # Insert sidecar info before the OIDC section
    note_text = ("[ACTUALIZACIÓN] La Task Definition incluye un segundo contenedor sidecar "
                 "'aws-otel-collector' (ADOT) para trazabilidad distribuida con AWS X-Ray. "
                 "Image: public.ecr.aws/aws-observability/aws-otel-collector:latest, "
                 "Puerto 4317/tcp (gRPC OTLP), Essential: No, Memory: 256 MB. "
                 "Solo se agrega cuando OTEL_TRACES_EXPORTER=otlp en las variables de entorno.")
    new_p = insert_para_after(doc.paragraphs[idx2 - 1], note_text, bold=True, color=RGBColor(0x00, 0x70, 0xC0))
    print("[OK] ADOT sidecar note added before OIDC section")
else:
    print("[WARN] Could not find insertion point for ADOT note")

# =============================================================================
# UPDATE: GitHub Actions variables table
# =============================================================================
print("[INFO] Updating GitHub Actions variables...")

idx, para = find_paragraph("repository variables")
if idx > 0:
    table = find_table_after(idx)
    if table:
        for row in table.rows[1:]:
            var_name = row.cells[0].text.strip()
            if var_name == "DEV_TASK_DEFINITION":
                row.cells[1].text = "dev-multicines-integration-task"
                print(f"  [UPDATED] DEV_TASK_DEFINITION")
            elif var_name == "PROD_TASK_DEFINITION":
                row.cells[1].text = "prod-multicines-integration-task"
                print(f"  [UPDATED] PROD_TASK_DEFINITION")
            elif var_name == "DEV_ECS_SERVICE":
                row.cells[1].text = "dev-multicines-integration-svc"
                print(f"  [UPDATED] DEV_ECS_SERVICE")
            elif var_name == "PROD_ECS_SERVICE":
                row.cells[1].text = "prod-multicines-integration-svc"
                print(f"  [UPDATED] PROD_ECS_SERVICE")
        print("[OK] GitHub Actions variables updated")
else:
    print("[WARN] Could not find Repository variables section")

# =============================================================================
# SAVE
# =============================================================================
doc.save(DOCX_PATH)
print(f"\n[DONE] Documento guardado: {DOCX_PATH}")
print(f"[DONE] Tamaño: {os.path.getsize(DOCX_PATH) / 1024:.0f} KB")
