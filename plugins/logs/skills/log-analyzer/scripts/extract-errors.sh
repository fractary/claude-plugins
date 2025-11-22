#!/bin/bash
# Extract all errors from logs
set -euo pipefail

ISSUE_NUMBER="${1:-}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")

# Determine which logs to analyze
if [[ -n "$ISSUE_NUMBER" ]]; then
    # Specific issue
    LOGS=$(find "$LOG_DIR" -type f \( -name "*${ISSUE_NUMBER}*" -o -name "${ISSUE_NUMBER}-*" \) 2>/dev/null || true)
else
    # All logs
    LOGS=$(find "$LOG_DIR" -type f ! -name ".archive-index.json" 2>/dev/null || true)
fi

if [[ -z "$LOGS" ]]; then
    echo "No logs found"
    exit 0
fi

# Error patterns to match (case insensitive)
ERROR_PATTERNS=(
    "error:"
    "ERROR:"
    "exception:"
    "EXCEPTION:"
    "failed:"
    "FAILED:"
    "timeout:"
    "TIMEOUT:"
    "fatal:"
    "FATAL:"
)

# Extract errors with context
echo "Error Analysis${ISSUE_NUMBER:+ for Issue #$ISSUE_NUMBER}"
echo
echo "Found errors:"
echo

ERROR_COUNT=0
for LOG in $LOGS; do
    for PATTERN in "${ERROR_PATTERNS[@]}"; do
        # Search for pattern with context
        MATCHES=$(grep -i -n -B 2 -A 2 "$PATTERN" "$LOG" 2>/dev/null || true)

        if [[ -n "$MATCHES" ]]; then
            LOG_NAME=$(basename "$LOG")
            ((ERROR_COUNT++))

            echo "$ERROR_COUNT. [$LOG_NAME]"
            echo "$MATCHES" | head -20  # Limit context output
            echo
        fi
    done
done

if [[ $ERROR_COUNT -eq 0 ]]; then
    echo "No errors found"
fi

echo
echo "Total errors found: $ERROR_COUNT"
