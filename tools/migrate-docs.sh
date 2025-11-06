#!/bin/bash
# migrate-docs.sh
#
# Migrate existing documentation to fractary-docs format by adding front matter
# Usage: ./tools/migrate-docs.sh <doc_file>

set -euo pipefail

DOC_FILE="$1"

if [[ ! -f "$DOC_FILE" ]]; then
    echo "Error: File not found: $DOC_FILE"
    exit 1
fi

# Add front matter if missing
if ! grep -q "^---$" "$DOC_FILE"; then
    TITLE=$(head -1 "$DOC_FILE" | sed 's/^# //')
    DATE=$(date +%Y-%m-%d)

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
else
    echo "⊘ $DOC_FILE already has front matter, skipping"
fi
