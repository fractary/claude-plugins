#!/bin/bash
# Update archive index with new entry
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
METADATA_JSON="${2:?Metadata JSON required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
INDEX_FILE="$LOG_DIR/.archive-index.json"

# Create index if doesn't exist
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

# Write updated index
echo "$UPDATED_INDEX" | jq . > "$INDEX_FILE"

echo "Archive index updated: $INDEX_FILE"
