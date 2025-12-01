#!/bin/bash
# pattern-expand.sh - Expand file patterns and wildcards
# Usage: pattern-expand.sh <pattern> [doc_type_filter]

set -euo pipefail

# Parse arguments
PATTERN="$1"
DOC_TYPE_FILTER="${2:-}"

# Expand glob pattern
if [[ "$PATTERN" == *"*"* ]]; then
    # Contains wildcard - use find with pattern
    # Convert glob to find pattern
    # Example: docs/api/**/*.md → find docs/api -name "*.md"

    BASE_DIR=$(echo "$PATTERN" | sed 's/\*\*.*//' | sed 's/\/$//')
    FILENAME_PATTERN=$(basename "$PATTERN")

    if [[ ! -d "$BASE_DIR" ]]; then
        echo "ERROR: Base directory not found: $BASE_DIR" >&2
        exit 1
    fi

    # Find matching files
    FILES=()
    while IFS= read -r file; do
        [[ -z "$file" ]] && continue

        # Filter by doc_type if specified
        if [[ -n "$DOC_TYPE_FILTER" ]]; then
            DOC_TYPE=$(grep "^fractary_doc_type:" "$file" 2>/dev/null | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "_untyped")

            if [[ "$DOC_TYPE" != "$DOC_TYPE_FILTER" ]]; then
                continue
            fi
        fi

        FILES+=("$file")
    done < <(find "$BASE_DIR" -name "$FILENAME_PATTERN" -type f 2>/dev/null | sort)

    # Output as JSON array
    printf '%s\n' "${FILES[@]}" | jq -R . | jq -s .

    exit 0

else
    # No wildcard - check if single file or directory
    if [[ -f "$PATTERN" ]]; then
        # Single file
        echo "[\"$PATTERN\"]" | jq .
        exit 0

    elif [[ -d "$PATTERN" ]]; then
        # Directory - find all .md files
        FILES=()
        while IFS= read -r file; do
            [[ -z "$file" ]] && continue

            # Skip README.md indices
            if [[ "$(basename "$file")" == "README.md" ]] && grep -q "automatically generated" "$file" 2>/dev/null; then
                continue
            fi

            # Filter by doc_type if specified
            if [[ -n "$DOC_TYPE_FILTER" ]]; then
                DOC_TYPE=$(grep "^fractary_doc_type:" "$file" 2>/dev/null | sed 's/fractary_doc_type: *//' | tr -d '"' || echo "_untyped")

                if [[ "$DOC_TYPE" != "$DOC_TYPE_FILTER" ]]; then
                    continue
                fi
            fi

            FILES+=("$file")
        done < <(find "$PATTERN" -name "*.md" -type f 2>/dev/null | sort)

        # Output as JSON array
        printf '%s\n' "${FILES[@]}" | jq -R . | jq -s .
        exit 0

    else
        echo "ERROR: Path not found: $PATTERN" >&2
        exit 1
    fi
fi
