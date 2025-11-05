#!/bin/bash
# Update upload status for a specific file in the archive index
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
FILE_PATH="${2:?File path required}"
STATUS="${3:?Status required (pending|uploaded|failed)}"
CLOUD_URL="${4:-}"  # Optional: Cloud URL if uploaded successfully
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Input validation: Issue number should be numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Issue number must be numeric" >&2
    exit 1
fi

# Input validation: File path should not contain path traversal
if [[ "$FILE_PATH" =~ \.\. ]]; then
    echo "Error: File path contains invalid characters" >&2
    exit 1
fi

# Input validation: Status must be one of the allowed values
if ! [[ "$STATUS" =~ ^(pending|uploaded|failed)$ ]]; then
    echo "Error: Status must be 'pending', 'uploaded', or 'failed'" >&2
    exit 1
fi

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
INDEX_FILE="$LOG_DIR/.archive-index.json"
LOCK_FILE="$INDEX_FILE.lock"

# Function to update file status with file locking
update_file_status_locked() {
    # Acquire exclusive lock (wait up to 30 seconds)
    if ! flock -x -w 30 200; then
        echo "Error: Could not acquire lock on index file (timeout)" >&2
        exit 1
    fi

    # Check if index exists
    if [[ ! -f "$INDEX_FILE" ]]; then
        echo "Error: Archive index not found at $INDEX_FILE" >&2
        exit 1
    fi

    # Load existing index
    EXISTING_INDEX=$(cat "$INDEX_FILE")

    # Update file status in the archive entry
    UPDATED_INDEX=$(echo "$EXISTING_INDEX" | jq --arg issue "$ISSUE_NUMBER" \
        --arg filepath "$FILE_PATH" \
        --arg status "$STATUS" \
        --arg url "$CLOUD_URL" \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        '
        .archives |= map(
            if .issue_number == $issue then
                .logs |= map(
                    if .local_path == $filepath then
                        . + {
                            "upload_status": $status,
                            "upload_timestamp": $timestamp
                        } + (if $url != "" then {"cloud_url": $url} else {} end)
                    else
                        .
                    end
                ) |
                # Recalculate partial_archive flag
                . + {
                    "partial_archive": ([.logs[].upload_status] | any(. == "failed" or . == "pending")),
                    "upload_complete": ([.logs[].upload_status] | all(. == "uploaded"))
                }
            else
                .
            end
        ) |
        .last_updated = (now | todate)
        ')

    # Write updated index atomically (within lock)
    TEMP_INDEX=$(mktemp)
    echo "$UPDATED_INDEX" | jq . > "$TEMP_INDEX"
    mv "$TEMP_INDEX" "$INDEX_FILE"

    echo "Updated upload status for $FILE_PATH: $STATUS"

    # Lock is automatically released when fd 200 closes
} 200>"$LOCK_FILE"

# Execute update with file locking
update_file_status_locked
