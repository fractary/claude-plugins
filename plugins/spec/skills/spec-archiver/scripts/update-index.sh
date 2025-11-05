#!/usr/bin/env bash
#
# update-index.sh - Update archive index with new entry
#
# Usage: update-index.sh <index_file> <entry_json>
#
# Adds archive entry to index

set -euo pipefail

INDEX_FILE="${1:?Index file path required}"
ENTRY_JSON="${2:?Entry JSON required}"

# Create index if doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    cat > "$INDEX_FILE" <<'EOF'
{
  "schema_version": "1.0",
  "last_updated": "",
  "archives": []
}
EOF
fi

# Load current index
CURRENT_INDEX=$(cat "$INDEX_FILE")

# Update last_updated timestamp
CURRENT_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Add new entry to archives array
UPDATED_INDEX=$(echo "$CURRENT_INDEX" | jq \
    --arg timestamp "$CURRENT_TIME" \
    --argjson entry "$ENTRY_JSON" \
    '.last_updated = $timestamp | .archives += [$entry]')

# Write updated index
echo "$UPDATED_INDEX" > "$INDEX_FILE"

echo "Archive index updated: $INDEX_FILE"
echo "Entry added for issue #$(echo "$ENTRY_JSON" | jq -r '.issue_number')"
