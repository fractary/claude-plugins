#!/bin/bash
# check-existing-specs.sh - Check if specs already exist for a work_id
#
# Usage: check-existing-specs.sh <work_id> [specs_dir]
#
# Arguments:
#   work_id   - The work/issue ID to check for (e.g., 123, 245)
#   specs_dir - Optional: Path to specs directory (default: ./specs)
#
# Output:
#   JSON object with:
#   - exists: boolean (true if any specs found)
#   - count: number of specs found
#   - specs: array of spec file paths
#
# Exit codes:
#   0 - Success (check completed, specs may or may not exist)
#   1 - Invalid arguments

set -euo pipefail

# Arguments
WORK_ID="${1:-}"
SPECS_DIR="${2:-./specs}"

# Validate work_id
if [[ -z "$WORK_ID" ]]; then
    echo '{"error": "work_id is required", "exit_code": 1}' >&2
    exit 1
fi

# Validate work_id is numeric
if ! [[ "$WORK_ID" =~ ^[0-9]+$ ]]; then
    echo '{"error": "work_id must be numeric", "exit_code": 1}' >&2
    exit 1
fi

# Check if specs directory exists
if [[ ! -d "$SPECS_DIR" ]]; then
    # Directory doesn't exist - no specs can exist
    printf '{"exists": false, "count": 0, "specs": [], "work_id": "%s"}\n' "$WORK_ID"
    exit 0
fi

# Check if specs directory is readable
if [[ ! -r "$SPECS_DIR" ]]; then
    echo '{"error": "specs directory is not readable", "exit_code": 1}' >&2
    exit 1
fi

# Zero-pad work_id to 5 digits for pattern matching
PADDED_ID=$(printf "%05d" "$WORK_ID")

# Pattern: WORK-{padded_id}-*.md
PATTERN="WORK-${PADDED_ID}-*.md"

# Find all matching specs
SPECS=()
while IFS= read -r -d '' file; do
    # Get just the filename
    SPECS+=("$(basename "$file")")
done < <(find "$SPECS_DIR" -maxdepth 1 -name "$PATTERN" -type f -print0 2>/dev/null | sort -z)

# Count specs
COUNT=${#SPECS[@]}

# Helper function to escape JSON strings
json_escape() {
    local str="$1"
    # Escape backslashes first, then quotes
    str="${str//\\/\\\\}"
    str="${str//\"/\\\"}"
    # Escape control characters
    str="${str//$'\n'/\\n}"
    str="${str//$'\r'/\\r}"
    str="${str//$'\t'/\\t}"
    printf '%s' "$str"
}

# Build JSON output
if [[ $COUNT -eq 0 ]]; then
    printf '{"exists": false, "count": 0, "specs": [], "work_id": "%s"}\n' "$WORK_ID"
else
    # Build specs array as JSON with proper escaping
    SPECS_JSON="["
    for i in "${!SPECS[@]}"; do
        if [[ $i -gt 0 ]]; then
            SPECS_JSON+=","
        fi
        ESCAPED_SPEC=$(json_escape "${SPECS[$i]}")
        SPECS_JSON+="\"${ESCAPED_SPEC}\""
    done
    SPECS_JSON+="]"

    # Escape specs_dir as well (could contain special characters in path)
    ESCAPED_DIR=$(json_escape "$SPECS_DIR")
    printf '{"exists": true, "count": %d, "specs": %s, "work_id": "%s", "specs_dir": "%s"}\n' \
        "$COUNT" "$SPECS_JSON" "$WORK_ID" "$ESCAPED_DIR"
fi

exit 0
