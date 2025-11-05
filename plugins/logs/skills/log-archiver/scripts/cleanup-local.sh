#!/bin/bash
# Remove local logs after successful archive
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
INDEX_FILE="$LOG_DIR/.archive-index.json"

# Verify index exists
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "Error: Archive index not found. Cannot safely delete logs." >&2
    exit 1
fi

# Get list of archived logs for this issue from index
ARCHIVED_LOGS=$(jq -r --arg issue "$ISSUE_NUMBER" \
    '.archives[] | select(.issue_number == $issue) | .logs[].local_path' \
    "$INDEX_FILE" 2>/dev/null || true)

if [[ -z "$ARCHIVED_LOGS" ]]; then
    echo "No archived logs found in index for issue #$ISSUE_NUMBER"
    exit 0
fi

# Remove each log file
DELETED_COUNT=0
FREED_BYTES=0
FAILED_FILES=()

while IFS= read -r LOG_FILE; do
    if [[ -f "$LOG_FILE" ]]; then
        # Get file size before deletion
        SIZE=$(stat -c%s "$LOG_FILE" 2>/dev/null || stat -f%z "$LOG_FILE" 2>/dev/null || echo "0")

        # Delete file
        if rm "$LOG_FILE" 2>/dev/null; then
            ((DELETED_COUNT++))
            FREED_BYTES=$((FREED_BYTES + SIZE))
            echo "Deleted: $LOG_FILE"
        else
            FAILED_FILES+=("$LOG_FILE")
            echo "Warning: Failed to delete $LOG_FILE" >&2
        fi

        # Also remove compressed version if exists
        if [[ -f "${LOG_FILE}.gz" ]]; then
            rm "${LOG_FILE}.gz" 2>/dev/null || true
        fi
    fi
done <<< "$ARCHIVED_LOGS"

# Report results
echo "Cleanup complete for issue #$ISSUE_NUMBER"
echo "Deleted: $DELETED_COUNT files"
echo "Freed: $((FREED_BYTES / 1024)) KB"

if [[ ${#FAILED_FILES[@]} -gt 0 ]]; then
    echo "Failed to delete ${#FAILED_FILES[@]} files:" >&2
    printf '%s\n' "${FAILED_FILES[@]}" >&2
    exit 1
fi
