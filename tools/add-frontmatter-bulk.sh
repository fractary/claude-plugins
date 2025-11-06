#!/bin/bash
# add-frontmatter-bulk.sh
#
# Bulk add codex_sync front matter to documentation files
# Usage: ./tools/add-frontmatter-bulk.sh [docs_dir] [--dry-run]

set -euo pipefail

DOCS_DIR="${1:-./docs}"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    elif [[ -d "$arg" ]]; then
        DOCS_DIR="$arg"
    fi
done

echo "=== Bulk Front Matter Tool ==="
echo "Target: $DOCS_DIR"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Mode: DRY RUN (no changes will be made)"
fi
echo

if [[ ! -d "$DOCS_DIR" ]]; then
    echo "Error: Directory not found: $DOCS_DIR"
    exit 1
fi

UPDATED=0
SKIPPED=0

# Use process substitution to avoid subshell issue
while IFS= read -r DOC; do
    # Check if codex_sync already present
    if grep -q "^codex_sync:" "$DOC" 2>/dev/null; then
        echo "⊘ Skipping $(basename "$DOC") (already has codex_sync)"
        ((SKIPPED++))
        continue
    fi

    # Check if has front matter
    if grep -q "^---$" "$DOC" 2>/dev/null; then
        # Has front matter, add codex_sync field after first ---
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "✓ Would add codex_sync to $(basename "$DOC") (existing front matter)"
        else
            # Create temp file with codex_sync added
            awk '
                BEGIN { added=0 }
                /^---$/ && added==0 { print; print "codex_sync: true"; added=1; next }
                { print }
            ' "$DOC" > "${DOC}.tmp"
            mv "${DOC}.tmp" "$DOC"
            echo "✓ Added codex_sync to $(basename "$DOC") (existing front matter)"
        fi
        ((UPDATED++))
    else
        # No front matter, add minimal front matter
        TITLE=$(head -1 "$DOC" | sed 's/^# //' || echo "Document")
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "✓ Would add front matter to $(basename "$DOC") (new front matter)"
        else
            cat > "${DOC}.tmp" <<EOF
---
title: "$TITLE"
codex_sync: true
---

EOF
            cat "$DOC" >> "${DOC}.tmp"
            mv "${DOC}.tmp" "$DOC"
            echo "✓ Added front matter to $(basename "$DOC") (new front matter)"
        fi
        ((UPDATED++))
    fi
done < <(find "$DOCS_DIR" -type f -name "*.md")

echo
echo "=== Summary ==="
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would update: $UPDATED files"
    echo "Would skip: $SKIPPED files"
    echo
    echo "Run without --dry-run to apply changes"
else
    echo "Updated: $UPDATED files"
    echo "Skipped: $SKIPPED files"
fi
