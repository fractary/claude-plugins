#!/bin/bash
# classify-by-content.sh - Classify doc_type by reading frontmatter
# Usage: classify-by-content.sh <file_path>

set -euo pipefail

FILE_PATH="$1"

# Extract frontmatter (between --- markers)
FRONTMATTER=$(awk '/^---$/,/^---$/{print}' "$FILE_PATH" | grep -v '^---$' || true)

# Extract fractary_doc_type field
DOC_TYPE=$(echo "$FRONTMATTER" | grep '^fractary_doc_type:' | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "_untyped")

if [[ "$DOC_TYPE" != "_untyped" ]]; then
    echo "{\"doc_type\": \"$DOC_TYPE\", \"confidence\": 90, \"method\": \"frontmatter\"}"
else
    echo "{\"doc_type\": \"_untyped\", \"confidence\": 50, \"method\": \"fallback\"}"
fi
