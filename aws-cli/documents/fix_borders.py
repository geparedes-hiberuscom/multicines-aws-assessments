"""
Add 1pt grey border to all images in Manual de Gestión de Recursos en AWS v1.0.docx
"""
from docx import Document
from docx.oxml.ns import qn
from docx.oxml import parse_xml
import os

DOCX_PATH = os.path.join(os.path.dirname(__file__), "Manual de Gestión de Recursos en AWS v1.0.docx")
doc = Document(DOCX_PATH)

count = 0
# Find all pictures in the document
for p in doc.paragraphs:
    for run in p.runs:
        drawings = run._element.findall('.//' + qn('wp:inline'))
        for drawing in drawings:
            # Navigate to pic:spPr
            pics = drawing.findall('.//' + qn('pic:pic'))
            for pic in pics:
                spPr = pic.find(qn('pic:spPr'))
                if spPr is None:
                    continue
                # Remove existing line
                existing = spPr.find(qn('a:ln'))
                if existing is not None:
                    spPr.remove(existing)
                # Add 1pt grey border
                ln = parse_xml(
                    '<a:ln xmlns:a="http://schemas.openxmlformats.org/drawingml/2006/main" w="12700">'
                    '<a:solidFill><a:srgbClr val="808080"/></a:solidFill>'
                    '</a:ln>'
                )
                spPr.append(ln)
                count += 1

doc.save(DOCX_PATH)
print(f"[DONE] Added border to {count} images")
print(f"[DONE] Size: {os.path.getsize(DOCX_PATH) / 1024:.0f} KB")
