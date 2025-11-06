#!/bin/bash
# migrate-specs.sh
#
# Migrate existing specs to fractary-spec format with proper front matter
# Usage: ./tools/migrate-specs.sh [source_dir]

set -euo pipefail

SPEC_DIR="${1:-.}"
TARGET_DIR="/specs"

echo "=== Spec Migration Tool ==="
echo "Source: $SPEC_DIR"
echo "Target: $TARGET_DIR"
echo

# Create target directory
mkdir -p "$TARGET_DIR"

# Find spec files
SPECS=$(find "$SPEC_DIR" -type f \( -name "SPEC-*.md" -o -name "spec-*.md" \) 2>/dev/null || true)

if [[ -z "$SPECS" ]]; then
    echo "No spec files found in $SPEC_DIR"
    exit 0
fi

MIGRATED=0
SKIPPED=0

for SPEC in $SPECS; do
    BASENAME=$(basename "$SPEC")

    # Skip if already in target directory
    if [[ "$(dirname "$(realpath "$SPEC")")" == "$(realpath "$TARGET_DIR")" ]]; then
        echo "⊘ Skipping $BASENAME (already in target directory)"
        ((SKIPPED++))
        continue
    fi

    # Extract issue number if present
    ISSUE=$(echo "$BASENAME" | grep -oP '\d+' | head -1 || echo "unknown")

    # Add fractary-spec front matter
    if ! grep -q "^---$" "$SPEC"; then
        CREATED_DATE=$(stat -c %y "$SPEC" 2>/dev/null | cut -d' ' -f1 || date +%Y-%m-%d)

        cat > "${TARGET_DIR}/${BASENAME}.new" <<EOF
---
spec_id: $(basename "$BASENAME" .md)
issue_number: ${ISSUE}
status: archived
created: ${CREATED_DATE}
migrated: true
migration_date: $(date +%Y-%m-%d)
---

EOF
        cat "$SPEC" >> "${TARGET_DIR}/${BASENAME}.new"
        mv "${TARGET_DIR}/${BASENAME}.new" "${TARGET_DIR}/${BASENAME}"

        echo "✓ Migrated $BASENAME (issue #${ISSUE})"
        ((MIGRATED++))
    else
        cp "$SPEC" "$TARGET_DIR/"
        echo "✓ Copied $BASENAME (already has front matter)"
        ((MIGRATED++))
    fi
done

echo
echo "=== Migration Summary ==="
echo "Migrated: $MIGRATED"
echo "Skipped: $SKIPPED"
echo "Target: $TARGET_DIR"
