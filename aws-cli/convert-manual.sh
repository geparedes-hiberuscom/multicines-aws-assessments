#!/usr/bin/env bash
# aws-cli/convert-manual.sh Convert DOCX manual to Markdown
#
# Converts "Insumos iniciales/Manual para multicines.docx" to Markdown
# and extracts images to aws-cli/documents/images/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

SOURCE="${PROJECT_ROOT}/Insumos iniciales/Manual para multicines.docx"
OUTPUT_DIR="${SCRIPT_DIR}/documents"
IMAGES_DIR="${OUTPUT_DIR}/images"
OUTPUT_FILE="${OUTPUT_DIR}/manual-original.md"

echo "[INFO] Converting DOCX to Markdown..."

if ! command -v pandoc &>/dev/null; then
 echo "[ERROR] Pandoc not installed."; exit 1
fi

if [ ! -f "$SOURCE" ]; then
 echo "[ERROR] Source not found: $SOURCE"; exit 1
fi

mkdir -p "$OUTPUT_DIR" "$IMAGES_DIR"

cd "$SCRIPT_DIR"
pandoc "$SOURCE" -t markdown --extract-media="documents/images" -o "$OUTPUT_FILE"

echo "[INFO] Done: $OUTPUT_FILE"
echo "[INFO] Images: $IMAGES_DIR"
