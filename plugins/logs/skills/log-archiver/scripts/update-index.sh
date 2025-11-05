#!/bin/bash
# Update archive index with new entry
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
METADATA_JSON="${2:?Metadata JSON required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Input validation: Issue number should be numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Issue number must be numeric" >&2
    exit 1
fi

# Input validation: Metadata JSON should be valid JSON
if ! echo "$METADATA_JSON" | jq empty 2>/dev/null; then
    echo "Error: Metadata is not valid JSON" >&2
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

# Function to update index with file locking
update_index_locked() {
    # Acquire exclusive lock (wait up to 30 seconds)
    if ! flock -x -w 30 200; then
        echo "Error: Could not acquire lock on index file (timeout)" >&2
        exit 1
    fi

    # Create index if doesn't exist (within lock)
    if [[ ! -f "$INDEX_FILE" ]]; then
        cat > "$INDEX_FILE" <<EOF
{
  "schema_version": "1.0",
  "last_updated": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "archives": []
}
EOF
    fi

    # Parse metadata JSON (expecting object with archive entry)
    ARCHIVE_ENTRY=$(echo "$METADATA_JSON" | jq -c .)

    # Load existing index
    EXISTING_INDEX=$(cat "$INDEX_FILE")

    # Check if entry already exists for this issue
    EXISTING_ENTRY=$(echo "$EXISTING_INDEX" | jq --arg issue "$ISSUE_NUMBER" \
        '.archives[] | select(.issue_number == $issue)' || true)

    if [[ -n "$EXISTING_ENTRY" ]]; then
        # Update existing entry
        UPDATED_INDEX=$(echo "$EXISTING_INDEX" | jq --argjson entry "$ARCHIVE_ENTRY" \
            --arg issue "$ISSUE_NUMBER" \
            '.archives |= map(if .issue_number == $issue then $entry else . end) |
             .last_updated = (now | todate)')
    else
        # Add new entry
        UPDATED_INDEX=$(echo "$EXISTING_INDEX" | jq --argjson entry "$ARCHIVE_ENTRY" \
            '.archives += [$entry] |
             .archives |= sort_by(.issue_number | tonumber) | reverse |
             .last_updated = (now | todate)')
    fi

    # Write updated index atomically (within lock)
    TEMP_INDEX=$(mktemp)
    echo "$UPDATED_INDEX" | jq . > "$TEMP_INDEX"
    mv "$TEMP_INDEX" "$INDEX_FILE"

    echo "Archive index updated: $INDEX_FILE"

    # Lock is automatically released when fd 200 closes
} 200>"$LOCK_FILE"

# Execute update with file locking
update_index_locked
