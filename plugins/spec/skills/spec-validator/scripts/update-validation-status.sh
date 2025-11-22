#!/usr/bin/env bash
#
# update-validation-status.sh - Update spec validation status
#
# Usage: update-validation-status.sh <spec_path> <validated> [notes]
#
# Updates spec frontmatter with validation results

set -euo pipefail

SPEC_PATH="${1:?Spec path required}"
VALIDATED="${2:?Validated status required}"  # true|false|partial
NOTES="${3:-}"

# Validate spec exists
if [[ ! -f "$SPEC_PATH" ]]; then
    echo "Error: Spec file not found: $SPEC_PATH" >&2
    exit 1
fi

CURRENT_DATE=$(date -u +%Y-%m-%d)

# Create temp file
TEMP_FILE=$(mktemp)

# Update frontmatter
awk -v validated="$VALIDATED" -v date="$CURRENT_DATE" -v notes="$NOTES" '
BEGIN { in_frontmatter=0; frontmatter_done=0 }

/^---$/ {
    if (!in_frontmatter) {
        in_frontmatter=1
        print
        next
    } else {
        # End of frontmatter
        if (frontmatter_done == 0) {
            # Add/update validation fields before closing
            print "validated: " validated
            print "validation_date: \"" date "\""
            if (notes != "") {
                print "validation_notes: \"" notes "\""
            }
            frontmatter_done=1
        }
        print
        next
    }
}

in_frontmatter && /^validated:/ { next }
in_frontmatter && /^validation_date:/ { next }
in_frontmatter && /^validation_notes:/ { next }
in_frontmatter && /^status:/ {
    # Update status based on validation
    if (validated == "true") {
        print "status: validated"
    } else if (validated == "partial") {
        print "status: in_progress"
    } else {
        print "status: draft"
    }
    next
}

{ print }
' "$SPEC_PATH" > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$SPEC_PATH"

echo "Validation status updated in $SPEC_PATH"
echo "  validated: $VALIDATED"
echo "  validation_date: $CURRENT_DATE"
if [[ -n "$NOTES" ]]; then
    echo "  validation_notes: $NOTES"
fi
