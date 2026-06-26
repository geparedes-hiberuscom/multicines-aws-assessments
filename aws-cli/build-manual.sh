#!/usr/bin/env bash
# aws-cli/build-manual.sh Assemble and export manual to DOCX
#
# Concatenates manual-original.md + sections/*.md manual-multicines.docx

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${SCRIPT_DIR}/documents"
SECTIONS_DIR="${OUTPUT_DIR}/sections"
ORIGINAL_MD="${OUTPUT_DIR}/manual-original.md"
FINAL_MD="${OUTPUT_DIR}/manual-multicines.md"
FINAL_DOCX="${OUTPUT_DIR}/manual-multicines.docx"

echo "[INFO] Building manual..."

if ! command -v pandoc &>/dev/null; then
 echo "[ERROR] Pandoc not installed."; exit 1
fi

if [ ! -f "$ORIGINAL_MD" ]; then
 echo "[ERROR] $ORIGINAL_MD not found. Run convert-manual.sh first."; exit 1
fi

SECTION_FILES=("$SECTIONS_DIR"/*.md)
if [ ! -f "${SECTION_FILES[0]}" ]; then
 echo "[ERROR] No sections in $SECTIONS_DIR"; exit 1
fi

cat "$ORIGINAL_MD" > "$FINAL_MD"
for section in "${SECTION_FILES[@]}"; do
 echo "" >> "$FINAL_MD"
 echo "" >> "$FINAL_MD"
 cat "$section" >> "$FINAL_MD"
done

pandoc "$FINAL_MD" -o "$FINAL_DOCX" --resource-path="${OUTPUT_DIR}"

echo "[INFO] Done: $FINAL_DOCX"
