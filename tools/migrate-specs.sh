#!/bin/bash
# migrate-specs.sh
#
# Migrate existing specs to fractary-spec format with proper front matter
# Usage: ./tools/migrate-specs.sh [source_dir] [--dry-run]

set -euo pipefail

SPEC_DIR="${1:-.}"
TARGET_DIR="/specs"
DRY_RUN=false

# Parse arguments
for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    elif [[ -d "$arg" ]]; then
        SPEC_DIR="$arg"
    fi
done

# Cross-platform stat function for getting file modification date
get_file_date() {
    local file="$1"
    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS
        stat -f %Sm -t "%Y-%m-%d" "$file" 2>/dev/null || date +%Y-%m-%d
    else
        # Linux
        stat -c %y "$file" 2>/dev/null | cut -d' ' -f1 || date +%Y-%m-%d
    fi
}

echo "=== Spec Migration Tool ==="
echo "Source: $SPEC_DIR"
echo "Target: $TARGET_DIR"
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Mode: DRY RUN (no changes will be made)"
fi
echo

# Create target directory (not in dry-run)
if [[ "$DRY_RUN" == "false" ]]; then
    mkdir -p "$TARGET_DIR" || {
        echo "Error: Failed to create target directory: $TARGET_DIR"
        exit 1
    }
fi

MIGRATED=0
SKIPPED=0

# Use null-terminated strings to handle filenames with spaces/special chars
while IFS= read -r -d '' SPEC; do
    BASENAME=$(basename "$SPEC")

    # Skip if already in target directory
    SPEC_DIR_REAL=$(dirname "$(realpath "$SPEC")")
    TARGET_DIR_REAL=$(realpath "$TARGET_DIR" 2>/dev/null || echo "$TARGET_DIR")

    if [[ "$SPEC_DIR_REAL" == "$TARGET_DIR_REAL" ]]; then
        echo "⊘ Skipping $BASENAME (already in target directory)"
        ((SKIPPED++))
        continue
    fi

    # Extract issue number if present
    ISSUE=$(echo "$BASENAME" | grep -oP '\d+' | head -1 || echo "unknown")

    # Add fractary-spec front matter
    if ! grep -q "^---$" "$SPEC" 2>/dev/null; then
        CREATED_DATE=$(get_file_date "$SPEC")

        if [[ "$DRY_RUN" == "true" ]]; then
            echo "✓ Would migrate $BASENAME (issue #${ISSUE})"
        else
            # Create front matter and content with error checking
            if ! cat > "${TARGET_DIR}/${BASENAME}.new" <<EOF
---
spec_id: $(basename "$BASENAME" .md)
issue_number: ${ISSUE}
status: archived
created: ${CREATED_DATE}
migrated: true
migration_date: $(date +%Y-%m-%d)
---

EOF
            then
                echo "✗ Error: Failed to write front matter for $BASENAME"
                continue
            fi

            # Append original content with error checking
            if ! cat "$SPEC" >> "${TARGET_DIR}/${BASENAME}.new"; then
                echo "✗ Error: Failed to append content for $BASENAME"
                rm -f "${TARGET_DIR}/${BASENAME}.new"
                continue
            fi

            # Move to final location with error checking
            if ! mv "${TARGET_DIR}/${BASENAME}.new" "${TARGET_DIR}/${BASENAME}"; then
                echo "✗ Error: Failed to move migrated file for $BASENAME"
                rm -f "${TARGET_DIR}/${BASENAME}.new"
                continue
            fi

            echo "✓ Migrated $BASENAME (issue #${ISSUE})"
        fi
        ((MIGRATED++))
    else
        if [[ "$DRY_RUN" == "true" ]]; then
            echo "✓ Would copy $BASENAME (already has front matter)"
        else
            # Copy with error checking
            if ! cp "$SPEC" "$TARGET_DIR/"; then
                echo "✗ Error: Failed to copy $BASENAME"
                continue
            fi
            echo "✓ Copied $BASENAME (already has front matter)"
        fi
        ((MIGRATED++))
    fi
done < <(find "$SPEC_DIR" -type f \( -name "SPEC-*.md" -o -name "spec-*.md" \) -print0 2>/dev/null)

# Check if any files were found
if ((MIGRATED == 0 && SKIPPED == 0)); then
    echo "No spec files found in $SPEC_DIR"
    exit 0
fi

echo
echo "=== Migration Summary ==="
if [[ "$DRY_RUN" == "true" ]]; then
    echo "Would migrate: $MIGRATED specs"
    echo "Would skip: $SKIPPED specs"
    echo "Target: $TARGET_DIR"
    echo
    echo "Run without --dry-run to apply changes"
else
    echo "Migrated: $MIGRATED specs"
    echo "Skipped: $SKIPPED specs"
    echo "Target: $TARGET_DIR"
fi
