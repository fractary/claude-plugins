#!/bin/bash
# Find logs older than threshold for auto-backup
set -euo pipefail

LOGS_DIR="${1:-/logs}"
THRESHOLD_DAYS="${2:-7}"
INDEX_FILE="${3:-/logs/.archive-index.json}"

# Convert threshold to seconds
THRESHOLD_SECONDS=$((THRESHOLD_DAYS * 24 * 60 * 60))
CURRENT_TIME=$(date +%s)
CUTOFF_TIME=$((CURRENT_TIME - THRESHOLD_SECONDS))

# Find all session log files
SESSION_LOGS=$(find "$LOGS_DIR/sessions" -type f -name "*.md" 2>/dev/null || echo "")

if [[ -z "$SESSION_LOGS" ]]; then
    echo "[]"
    exit 0
fi

# Build JSON array of old logs
OLD_LOGS="["
FIRST=true

while IFS= read -r log_file; do
    # Get file modification time
    FILE_TIME=$(stat -c %Y "$log_file" 2>/dev/null || stat -f %m "$log_file" 2>/dev/null || echo "0")

    # Check if older than threshold
    if [[ $FILE_TIME -lt $CUTOFF_TIME ]]; then
        # Extract issue number from file
        ISSUE_NUM=$(grep "^issue_number:" "$log_file" 2>/dev/null | cut -d: -f2- | xargs || echo "unknown")

        # Check if already archived
        ALREADY_ARCHIVED=false
        if [[ -f "$INDEX_FILE" ]]; then
            if jq -e --arg issue "$ISSUE_NUM" '.archives[] | select(.issue_number == $issue)' "$INDEX_FILE" >/dev/null 2>&1; then
                ALREADY_ARCHIVED=true
            fi
        fi

        # Skip if already archived
        if [[ "$ALREADY_ARCHIVED" == "true" ]]; then
            continue
        fi

        # Calculate age in days
        AGE_SECONDS=$((CURRENT_TIME - FILE_TIME))
        AGE_DAYS=$((AGE_SECONDS / 86400))

        # Add to array
        if [[ "$FIRST" == "true" ]]; then
            FIRST=false
        else
            OLD_LOGS+=","
        fi

        OLD_LOGS+=$(cat <<EOF
{
  "file_path": "$log_file",
  "issue_number": "$ISSUE_NUM",
  "age_days": $AGE_DAYS,
  "modified_time": $FILE_TIME
}
EOF
)
    fi
done <<< "$SESSION_LOGS"

OLD_LOGS+="]"

echo "$OLD_LOGS"
