#!/bin/bash
# Retry failed uploads from a partial archive
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Input validation: Issue number should be numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Issue number must be numeric" >&2
    exit 1
fi

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
INDEX_FILE="$LOG_DIR/.archive-index.json"

# Check if index exists
if [[ ! -f "$INDEX_FILE" ]]; then
    echo "Error: Archive index not found at $INDEX_FILE" >&2
    exit 1
fi

# Find archive entry for this issue
ARCHIVE_ENTRY=$(jq --arg issue "$ISSUE_NUMBER" \
    '.archives[] | select(.issue_number == $issue)' \
    "$INDEX_FILE" 2>/dev/null || true)

if [[ -z "$ARCHIVE_ENTRY" ]]; then
    echo "Error: No archive entry found for issue #$ISSUE_NUMBER" >&2
    exit 1
fi

# Check if this is a partial archive
IS_PARTIAL=$(echo "$ARCHIVE_ENTRY" | jq -r '.partial_archive // false')

if [[ "$IS_PARTIAL" != "true" ]]; then
    echo "Issue #$ISSUE_NUMBER archive is complete, no retry needed" >&2
    exit 0
fi

# Extract failed files
FAILED_FILES=$(echo "$ARCHIVE_ENTRY" | jq -c '.logs[] | select(.upload_status == "failed" or .upload_status == "pending")')

if [[ -z "$FAILED_FILES" ]]; then
    echo "No failed files found to retry" >&2
    exit 0
fi

# Count failed files
FAILED_COUNT=$(echo "$FAILED_FILES" | wc -l | xargs)

echo "Found $FAILED_COUNT failed/pending file(s) for issue #$ISSUE_NUMBER"
echo

# Output JSON array of files to retry (for agent consumption)
cat <<EOF
{
  "issue_number": "$ISSUE_NUMBER",
  "retry_count": $FAILED_COUNT,
  "files_to_retry": [
EOF

# Output each failed file metadata
FIRST=true
while IFS= read -r FILE_ENTRY; do
    if [[ "$FIRST" != "true" ]]; then
        echo "    ,"
    fi
    FIRST=false

    # Extract file info
    LOCAL_PATH=$(echo "$FILE_ENTRY" | jq -r '.local_path')
    REMOTE_PATH=$(echo "$FILE_ENTRY" | jq -r '.remote_path')
    TYPE=$(echo "$FILE_ENTRY" | jq -r '.type')

    # Check if local file still exists
    FILE_EXISTS="false"
    if [[ -f "$LOCAL_PATH" ]]; then
        FILE_EXISTS="true"
    fi

    cat <<ENTRY
    {
      "local_path": "$LOCAL_PATH",
      "remote_path": "$REMOTE_PATH",
      "type": "$TYPE",
      "file_exists": $FILE_EXISTS,
      "metadata": $(echo "$FILE_ENTRY" | jq -c '.')
    }
ENTRY
done <<< "$FAILED_FILES"

cat <<EOF

  ]
}
EOF
