#!/bin/bash
# list-docs.sh - List documentation files with metadata
# Usage: list-docs.sh <directory> [doc_type_filter]

set -euo pipefail

DIR="${1:-docs}"
FILTER_TYPE="${2:-}"

# Find all README.md files
find "$DIR" -name "README.md" -not -path "*/node_modules/*" -not -path "*/.git/*" | while read -r file; do
    # Extract frontmatter
    FRONTMATTER=$(awk '/^---$/,/^---$/{print}' "$file" | grep -v '^---$' || true)

    # Extract fields
    DOC_TYPE=$(echo "$FRONTMATTER" | grep '^fractary_doc_type:' | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "")
    TITLE=$(echo "$FRONTMATTER" | grep '^title:' | sed 's/title: *//' | tr -d '"' || echo "")
    STATUS=$(echo "$FRONTMATTER" | grep '^status:' | sed 's/status: *//' | tr -d '"' || echo "")
    VERSION=$(echo "$FRONTMATTER" | grep '^version:' | sed 's/version: *//' | tr -d '"' || echo "")

    # Apply filter if specified
    if [[ -n "$FILTER_TYPE" && "$DOC_TYPE" != "$FILTER_TYPE" ]]; then
        continue
    fi

    # Output JSON
    echo "{\"path\": \"$file\", \"title\": \"$TITLE\", \"doc_type\": \"$DOC_TYPE\", \"status\": \"$STATUS\", \"version\": \"$VERSION\"}"
done
