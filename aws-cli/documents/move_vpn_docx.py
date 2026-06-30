"""
Mueve la sección VPN Site-to-Site antes de "Anexo" en Manual Multicines v2.docx.
No modifica ningún otro contenido.
"""
from docx import Document
from docx.oxml.ns import qn
import os
import copy

DOCX_PATH = os.path.join(os.path.dirname(__file__), "Manual Multicines v2.docx")
doc = Document(DOCX_PATH)

body = doc.element.body

# Find all elements
all_elements = list(body)

# Find paragraph indices for key headings
def find_heading_element(text_start):
    for elem in all_elements:
        if elem.tag.endswith('}p'):
            # Check if it's a heading containing the text
            pStyle = elem.find(f'.//{qn("w:pStyle")}')
            if pStyle is not None and 'Heading' in pStyle.get(qn('w:val'), ''):
                full_text = ''.join(t.text or '' for t in elem.findall(f'.//{qn("w:t")}'))
                if text_start.lower() in full_text.lower():
                    return elem
    return None

# Find the "Anexo" heading and "VPN Site-to-Site" heading
anexo_elem = find_heading_element("Anexo")
vpn_elem = find_heading_element("VPN Site-to-Site")

if not anexo_elem or not vpn_elem:
    print(f"[ERROR] Could not find Anexo ({anexo_elem is not None}) or VPN ({vpn_elem is not None})")
    exit(1)

print(f"[INFO] Found Anexo heading")
print(f"[INFO] Found VPN heading")

# Collect all VPN elements (from VPN heading to end of document, before sectPr)
vpn_elements = []
started = False
for elem in list(all_elements):
    if elem is vpn_elem:
        started = True
    if started:
        if elem.tag.endswith('}sectPr'):
            break
        vpn_elements.append(elem)

print(f"[INFO] VPN section has {len(vpn_elements)} elements")

# Remove VPN elements from their current position
for elem in vpn_elements:
    body.remove(elem)

print(f"[INFO] Removed VPN elements from end")

# Insert VPN elements before Anexo
for elem in reversed(vpn_elements):
    anexo_elem.addprevious(elem)

print(f"[INFO] Inserted VPN elements before Anexo")

# Save
doc.save(DOCX_PATH)
print(f"\n[DONE] {DOCX_PATH}")
print(f"[DONE] Size: {os.path.getsize(DOCX_PATH) / 1024:.0f} KB")
