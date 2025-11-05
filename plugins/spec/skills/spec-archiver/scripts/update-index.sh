#!/usr/bin/env bash
#
# update-index.sh - Update archive index with new entry (two-tier storage)
#
# Usage: update-index.sh <local_index_file> <entry_json> [cloud_index_path]
#
# Two-tier storage:
#   1. Updates local cache (fast access)
#   2. Backs up to cloud (durability, recoverability)
#
# Adds archive entry to index

set -euo pipefail

INDEX_FILE="${1:?Index file path required}"
ENTRY_JSON="${2:?Entry JSON required}"
CLOUD_INDEX="${3:-}"

# Create index if doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    # Create parent directory if needed
    mkdir -p "$(dirname "$INDEX_FILE")"
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

# Write updated index to local cache
echo "$UPDATED_INDEX" > "$INDEX_FILE"

echo "✓ Local index updated: $INDEX_FILE"
echo "✓ Entry added for issue #$(echo "$ENTRY_JSON" | jq -r '.issue_number')"

# If cloud index path provided, back up to cloud
if [[ -n "$CLOUD_INDEX" ]]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if "$SCRIPT_DIR/sync-index.sh" upload "$INDEX_FILE" "$CLOUD_INDEX" 2>&1; then
        echo "✓ Cloud backup updated"
    else
        echo "⚠ Cloud backup failed (non-critical, local cache updated)"
    fi
fi
