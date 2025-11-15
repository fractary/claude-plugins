#!/usr/bin/env bash
#
# collect-specs.sh - Collect all specs for an issue
#
# Usage: collect-specs.sh <issue_number> <specs_dir>
#
# Outputs JSON array of spec file paths

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
SPECS_DIR="${2:-/specs}"

# Format issue number with leading zeros (5 digits) to match WORK-XXXXX naming
PADDED_ISSUE=$(printf "%05d" "$ISSUE_NUMBER")

# Find all specs for issue using WORK-XXXXX naming pattern
SPECS=$(find "$SPECS_DIR" -type f -name "WORK-${PADDED_ISSUE}*.md" 2>/dev/null || true)

if [[ -z "$SPECS" ]]; then
    echo '{"error": "No specs found for issue #'"$ISSUE_NUMBER"'"}' >&2
    exit 1
fi

# Build JSON array
echo "$SPECS" | jq -R -s -c 'split("\n") | map(select(length > 0))'
