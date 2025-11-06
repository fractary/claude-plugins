#!/bin/bash
# migrate-docs.sh
#
# Migrate existing documentation to fractary-docs format by adding front matter
# Usage: ./tools/migrate-docs.sh <doc_file> [--dry-run]

set -euo pipefail

DOC_FILE=""
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    elif [[ -f "$arg" ]]; then
        DOC_FILE="$arg"
    fi
done

if [[ -z "$DOC_FILE" ]]; then
    echo "Usage: $0 <doc_file> [--dry-run]"
    exit 1
fi

if [[ ! -f "$DOC_FILE" ]]; then
    echo "Error: File not found: $DOC_FILE"
    exit 1
fi

# Add front matter if missing
if ! grep -q "^---$" "$DOC_FILE"; then
    TITLE=$(head -1 "$DOC_FILE" | sed 's/^# //')
    DATE=$(date +%Y-%m-%d)

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "Would add front matter to $DOC_FILE:"
        echo "---"
        echo "title: \"$TITLE\""
        echo "type: design"
        echo "created: \"$DATE\""
        echo "updated: \"$DATE\""
        echo "codex_sync: true"
        echo "---"
        echo
        echo "(original content would follow)"
    else
        cat > "${DOC_FILE}.new" <<EOF
---
title: "$TITLE"
type: design
created: "$DATE"
updated: "$DATE"
codex_sync: true
---

EOF
        cat "$DOC_FILE" >> "${DOC_FILE}.new"
        mv "${DOC_FILE}.new" "$DOC_FILE"

        echo "✓ Added front matter to $DOC_FILE"
    fi
else
    echo "⊘ $DOC_FILE already has front matter, skipping"
fi
