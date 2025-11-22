#!/bin/bash
# Find recurring patterns across logs
set -euo pipefail

SINCE_DATE="${1:?Since date required (YYYY-MM-DD)}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")

# Find logs since date
LOGS=$(find "$LOG_DIR" -type f -newermt "$SINCE_DATE" ! -name ".archive-index.json" 2>/dev/null || true)

if [[ -z "$LOGS" ]]; then
    echo "No logs found since $SINCE_DATE"
    exit 0
fi

echo "Pattern Analysis (since $SINCE_DATE)"
echo

# Track patterns in associative array
declare -A PATTERNS

# Common error patterns to detect
PATTERN_REGEXES=(
    "CORS.*error"
    "timeout"
    "connection.*failed"
    "authentication.*failed"
    "permission.*denied"
    "not.*found"
    "undefined.*property"
    "null.*reference"
)

# Search for patterns
for LOG in $LOGS; do
    for REGEX in "${PATTERN_REGEXES[@]}"; do
        COUNT=$(grep -i -c -E "$REGEX" "$LOG" 2>/dev/null || echo "0")

        if [[ $COUNT -gt 0 ]]; then
            CURRENT=${PATTERNS["$REGEX"]:-0}
            PATTERNS["$REGEX"]=$((CURRENT + COUNT))
        fi
    done
done

# Sort and display patterns by frequency
echo "Common Patterns:"
echo

if [[ ${#PATTERNS[@]} -eq 0 ]]; then
    echo "No patterns detected"
else
    # Sort by count (descending)
    for PATTERN in "${!PATTERNS[@]}"; do
        echo "${PATTERNS[$PATTERN]} $PATTERN"
    done | sort -rn | head -10 | nl
fi

echo
echo "Total patterns analyzed: ${#PATTERNS[@]}"
