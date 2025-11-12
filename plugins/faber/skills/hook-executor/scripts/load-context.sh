#!/usr/bin/env bash
# Load context from referenced documentation files
# Used by context hooks to read and format documentation

set -euo pipefail

# Usage: load-context.sh <reference-json> <project-root>
# reference-json: JSON object with {path, description, sections}
# project-root: Project root directory for resolving relative paths

REFERENCE_JSON="${1:-}"
PROJECT_ROOT="${2:-$(pwd)}"

if [[ -z "$REFERENCE_JSON" ]]; then
    echo "Error: Reference JSON required" >&2
    echo "Usage: $0 <reference-json> <project-root>" >&2
    exit 1
fi

# Parse reference JSON
FILE_PATH=$(echo "$REFERENCE_JSON" | jq -r '.path')
DESCRIPTION=$(echo "$REFERENCE_JSON" | jq -r '.description')
SECTIONS=$(echo "$REFERENCE_JSON" | jq -r '.sections // [] | join(",")')

if [[ -z "$FILE_PATH" ]]; then
    echo "Error: 'path' field required in reference JSON" >&2
    exit 1
fi

# Resolve absolute path
ABSOLUTE_PATH="$PROJECT_ROOT/$FILE_PATH"

# Check file exists
if [[ ! -f "$ABSOLUTE_PATH" ]]; then
    echo "Error: Referenced file not found: $FILE_PATH (resolved to: $ABSOLUTE_PATH)" >&2
    exit 1
fi

# Check file is readable
if [[ ! -r "$ABSOLUTE_PATH" ]]; then
    echo "Error: Referenced file not readable: $FILE_PATH" >&2
    exit 1
fi

# Get file size for reporting
FILE_SIZE=$(stat -f%z "$ABSOLUTE_PATH" 2>/dev/null || stat -c%s "$ABSOLUTE_PATH" 2>/dev/null || echo "unknown")

# Output metadata as JSON (to stderr for separation)
echo "{\"path\":\"$FILE_PATH\",\"description\":\"$DESCRIPTION\",\"sizeBytes\":$FILE_SIZE,\"sectionsRequested\":\"$SECTIONS\"}" >&2

# Extract sections if specified
if [[ -n "$SECTIONS" ]]; then
    # Section extraction: look for markdown headers with section names
    IFS=',' read -ra SECTION_ARRAY <<< "$SECTIONS"

    TEMP_OUTPUT=$(mktemp)

    for SECTION in "${SECTION_ARRAY[@]}"; do
        # Look for markdown headers (# Section Name, ## Section Name, etc.)
        # Extract content until next header of same or higher level

        # Escape special regex characters in section name
        ESCAPED_SECTION=$(echo "$SECTION" | sed 's/[.[\*^$]/\\&/g')

        # Extract section using awk
        awk -v section="$SECTION" '
            BEGIN { in_section=0; header_level=0 }

            # Match header with section name
            /^#+/ {
                # Count # characters to determine level
                match($0, /^#+/)
                current_level = RLENGTH

                # Remove # and whitespace to get header text
                header_text = $0
                gsub(/^#+[ \t]*/, "", header_text)
                gsub(/[ \t]*$/, "", header_text)

                if (header_text == section) {
                    in_section = 1
                    header_level = current_level
                    print $0
                    next
                }

                # If we hit a header of same/higher level, exit section
                if (in_section && current_level <= header_level) {
                    in_section = 0
                }
            }

            # Print lines if we are in the target section
            in_section { print }
        ' "$ABSOLUTE_PATH" >> "$TEMP_OUTPUT"
    done

    if [[ -s "$TEMP_OUTPUT" ]]; then
        cat "$TEMP_OUTPUT"
    else
        echo "Warning: Requested sections not found in $FILE_PATH: $SECTIONS" >&2
        echo "Falling back to full file content" >&2
        cat "$ABSOLUTE_PATH"
    fi

    rm -f "$TEMP_OUTPUT"
else
    # Output full file content
    cat "$ABSOLUTE_PATH"
fi
