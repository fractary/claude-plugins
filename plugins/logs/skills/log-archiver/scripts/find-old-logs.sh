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

# Build JSON array of old logs using jq for safe construction
OLD_LOGS_ARRAY=()

while IFS= read -r log_file; do
    [[ -z "$log_file" ]] && continue

    # Get file modification time with better error handling
    if FILE_TIME=$(stat -c %Y "$log_file" 2>/dev/null); then
        : # Linux stat succeeded
    elif FILE_TIME=$(stat -f %m "$log_file" 2>/dev/null); then
        : # BSD/macOS stat succeeded
    else
        echo "Warning: Failed to get modification time for: $log_file" >&2
        continue
    fi

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

        # Use jq to safely construct JSON object (prevents injection/escaping issues)
        JSON_ENTRY=$(jq -n \
            --arg file_path "$log_file" \
            --arg issue_number "$ISSUE_NUM" \
            --argjson age_days "$AGE_DAYS" \
            --argjson modified_time "$FILE_TIME" \
            '{
                file_path: $file_path,
                issue_number: $issue_number,
                age_days: $age_days,
                modified_time: $modified_time
            }')

        OLD_LOGS_ARRAY+=("$JSON_ENTRY")
    fi
done <<< "$SESSION_LOGS"

# Combine all JSON objects into a single array using jq
if [[ ${#OLD_LOGS_ARRAY[@]} -eq 0 ]]; then
    echo "[]"
else
    printf '%s\n' "${OLD_LOGS_ARRAY[@]}" | jq -s '.'
fi
