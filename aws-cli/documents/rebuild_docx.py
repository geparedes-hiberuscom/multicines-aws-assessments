"""
Reconstruye Manual Multicines v2.docx desde cero usando el original como
plantilla de estilos, y agrega todo el contenido del manual-multicines.md
con formato correcto (headings, tablas con bordes, imágenes, TODOs en rojo).
"""
import os
import re
import shutil
from docx import Document
from docx.shared import Pt, Inches, RGBColor, Cm
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml.ns import qn, nsdecls
from docx.oxml import parse_xml

BASE_DIR = os.path.dirname(__file__)
ORIGINAL = os.path.join(BASE_DIR, "..", "..","Insumos iniciales", "Manual para multicines.docx")
OUTPUT = os.path.join(BASE_DIR, "Manual Multicines v2.docx")
MD_FILE = os.path.join(BASE_DIR, "manual-multicines.md")
IMAGES_DIR = os.path.join(BASE_DIR, "documents", "images", "media")

# Copy original as base (preserves styles)
shutil.copy2(ORIGINAL, OUTPUT)

# Open the copy and clear all content
doc = Document(OUTPUT)

# Remove all paragraphs and tables from body
body = doc.element.body
for child in list(body):
    if child.tag.endswith('}p') or child.tag.endswith('}tbl') or child.tag.endswith('}sectPr'):
        if child.tag.endswith('}sectPr'):
            continue  # keep section properties
        body.remove(child)

print("[INFO] Cleared document body, keeping styles")

img_count = [0]

# === Parse markdown and rebuild ===
with open(MD_FILE, 'r', encoding='utf-8') as f:
    lines = f.readlines()

def add_shading_to_cell(cell, color="D9E2F3"):
    """Add background color to table cell"""
    tc = cell._tc
    tcPr = tc.get_or_add_tcPr()
    shading = parse_xml(f'<w:shd {nsdecls("w")} w:fill="{color}" w:val="clear"/>')
    tcPr.append(shading)

def create_table(headers, rows):
    """Create a formatted table with borders and header shading"""
    table = doc.add_table(rows=1+len(rows), cols=len(headers))
    table.style = 'Table Grid'
    # Header
    for i, h in enumerate(headers):
        cell = table.rows[0].cells[i]
        cell.text = ''
        p = cell.paragraphs[0]
        run = p.add_run(h)
        run.bold = True
        run.font.size = Pt(9)
        add_shading_to_cell(cell, "D9E2F3")
    # Rows
    for r_idx, row_data in enumerate(rows):
        for c_idx, val in enumerate(row_data):
            cell = table.rows[r_idx+1].cells[c_idx]
            cell.text = ''
            p = cell.paragraphs[0]
            run = p.add_run(str(val))
            run.font.size = Pt(9)
    return table

i = 0
current_table_headers = None
current_table_rows = []
in_table = False

while i < len(lines):
    line = lines[i].rstrip('\n')
    
    # Skip empty lines between content
    if not line.strip() and not in_table:
        i += 1
        continue
    
    # End table if we were in one and hit non-table line
    if in_table and not line.strip().startswith('|'):
        if current_table_headers and current_table_rows:
            create_table(current_table_headers, current_table_rows)
            doc.add_paragraph()
        current_table_headers = None
        current_table_rows = []
        in_table = False
    
    # --- (horizontal rule / page break)
    if line.strip() == '---':
        doc.add_page_break()
        i += 1
        continue
    
    # Headings
    if line.startswith('# ') and not line.startswith('## '):
        text = line[2:].strip()
        doc.add_heading(text, level=1)
        i += 1
        continue
    if line.startswith('## '):
        text = line[3:].strip()
        doc.add_heading(text, level=2)
        i += 1
        continue
    if line.startswith('### '):
        text = line[4:].strip()
        doc.add_heading(text, level=3)
        i += 1
        continue
    
    # TODO markers
    if line.strip().startswith('> **TODO:'):
        text = line.strip().replace('> **TODO:', '').replace('**', '').strip()
        p = doc.add_paragraph()
        run = p.add_run(f"[TODO: {text}]")
        run.bold = True
        run.font.color.rgb = RGBColor(0xFF, 0x00, 0x00)
        run.font.size = Pt(10)
        i += 1
        continue
    
    # Images
    img_match = re.match(r'!\[.*?\]\((.*?)\)', line.strip())
    if img_match:
        img_path = img_match.group(1)
        # Strip any pandoc width/height attributes
        img_path = re.sub(r'\{.*\}', '', img_path).strip()
        # Try multiple path resolutions
        candidates = [
            os.path.join(BASE_DIR, img_path),
            os.path.join(BASE_DIR, "..", img_path) if not img_path.startswith("documents") else None,
            os.path.join(BASE_DIR, img_path.replace("documents/", "")) if "documents/" in img_path else None,
        ]
        # The MD references "documents/images/media/X.png" relative to aws-cli/
        # Script is in aws-cli/documents/, images are in aws-cli/documents/images/media/
        real_path = os.path.join(BASE_DIR, img_path.replace("documents/", ""))
        if not os.path.exists(real_path):
            real_path = os.path.join(BASE_DIR, img_path)
        if not os.path.exists(real_path):
            # Try from aws-cli/ directory
            real_path = os.path.join(BASE_DIR, "..", img_path)
            if not os.path.exists(real_path):
                real_path = os.path.join(os.path.dirname(BASE_DIR), img_path)
        
        if os.path.exists(real_path):
            try:
                doc.add_picture(real_path, width=Inches(5.5))
                img_count[0] += 1
                i += 1
                continue
            except Exception as e:
                pass
        
        # Fallback: placeholder text
        p = doc.add_paragraph()
        run = p.add_run(f"[Imagen no encontrada: {img_path}]")
        run.italic = True
        run.font.color.rgb = RGBColor(0x99, 0x99, 0x99)
        i += 1
        continue
    
    # Tables (markdown pipe format)
    if line.strip().startswith('|') and '|' in line.strip()[1:]:
        cells = [c.strip() for c in line.strip().split('|')[1:-1]]
        if not in_table:
            # First line = headers
            current_table_headers = cells
            in_table = True
            i += 1
            # Skip separator line (|---|---|)
            if i < len(lines) and re.match(r'\|[\s\-:]+\|', lines[i].strip()):
                i += 1
            continue
        else:
            # Data row
            current_table_rows.append(cells)
            i += 1
            continue
    
    # Numbered lists
    num_match = re.match(r'^(\d+)\.\s+(.+)', line.strip())
    if num_match:
        num = num_match.group(1)
        text = num_match.group(2)
        text = text.replace('**', '')
        p = doc.add_paragraph()
        run = p.add_run(f"{num}. {text}")
        run.font.size = Pt(10)
        p.paragraph_format.left_indent = Cm(1)
        i += 1
        continue
    
    # Bullet lists
    if line.strip().startswith('- '):
        text = line.strip()[2:]
        text = text.replace('**', '')
        p = doc.add_paragraph()
        run = p.add_run(f"• {text}")
        run.font.size = Pt(10)
        p.paragraph_format.left_indent = Cm(1)
        i += 1
        continue
    
    # Bold paragraphs (metadata table at top)
    if line.strip().startswith('**') and line.strip().endswith('**'):
        text = line.strip().replace('**', '')
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.bold = True
        i += 1
        continue
    
    # Regular paragraph
    text = line.strip()
    if text:
        # Remove markdown formatting
        text = re.sub(r'\*\*(.+?)\*\*', r'\1', text)
        text = re.sub(r'`(.+?)`', r'\1', text)
        p = doc.add_paragraph()
        run = p.add_run(text)
        run.font.size = Pt(10)
    i += 1

# Flush any remaining table
if in_table and current_table_headers and current_table_rows:
    create_table(current_table_headers, current_table_rows)

doc.save(OUTPUT)
print(f"\n[DONE] {OUTPUT}")
print(f"[DONE] Size: {os.path.getsize(OUTPUT) / 1024:.0f} KB")
print(f"[DONE] Images inserted: {img_count[0]}")
