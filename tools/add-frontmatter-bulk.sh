#!/bin/bash
# add-frontmatter-bulk.sh
#
# Bulk add codex_sync front matter to documentation files
# Usage: ./tools/add-frontmatter-bulk.sh [docs_dir]

set -euo pipefail

DOCS_DIR="${1:-./docs}"

echo "=== Bulk Front Matter Tool ==="
echo "Target: $DOCS_DIR"
echo

if [[ ! -d "$DOCS_DIR" ]]; then
    echo "Error: Directory not found: $DOCS_DIR"
    exit 1
fi

UPDATED=0
SKIPPED=0

find "$DOCS_DIR" -type f -name "*.md" | while read DOC; do
    # Check if codex_sync already present
    if grep -q "^codex_sync:" "$DOC" 2>/dev/null; then
        echo "⊘ Skipping $(basename "$DOC") (already has codex_sync)"
        ((SKIPPED++)) 2>/dev/null || true
        continue
    fi

    # Check if has front matter
    if grep -q "^---$" "$DOC" 2>/dev/null; then
        # Has front matter, add codex_sync field after first ---
        # Create temp file with codex_sync added
        awk '
            BEGIN { added=0 }
            /^---$/ && added==0 { print; print "codex_sync: true"; added=1; next }
            { print }
        ' "$DOC" > "${DOC}.tmp"
        mv "${DOC}.tmp" "$DOC"
        echo "✓ Added codex_sync to $(basename "$DOC") (existing front matter)"
        ((UPDATED++)) 2>/dev/null || true
    else
        # No front matter, add minimal front matter
        TITLE=$(head -1 "$DOC" | sed 's/^# //' || echo "Document")
        cat > "${DOC}.tmp" <<EOF
---
title: "$TITLE"
codex_sync: true
---

EOF
        cat "$DOC" >> "${DOC}.tmp"
        mv "${DOC}.tmp" "$DOC"
        echo "✓ Added front matter to $(basename "$DOC") (new front matter)"
        ((UPDATED++)) 2>/dev/null || true
    fi
done

echo
echo "=== Summary ==="
echo "Updated: $UPDATED files"
echo "Skipped: $SKIPPED files"
