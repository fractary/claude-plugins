#!/usr/bin/env bash
#
# state-write.sh - Atomically write FABER workflow state
#
# Usage:
#   state-write.sh [<state-file>] < state.json
#   echo '{"status":"completed"}' | state-write.sh
#
# Features:
#   - Atomic write (temp file + mv)
#   - Automatic backup before write
#   - Timestamp update
#   - JSON validation

set -euo pipefail

STATE_FILE="${1:-.fractary/plugins/faber/state.json}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Create state directory if needed
STATE_DIR=$(dirname "$STATE_FILE")
mkdir -p "$STATE_DIR"

# Read new state from stdin
NEW_STATE=$(cat)

# Validate JSON
if ! echo "$NEW_STATE" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON provided" >&2
    exit 1
fi

# Update timestamp
NEW_STATE=$(echo "$NEW_STATE" | jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" '.updated_at = $ts')

# Backup existing state if it exists
if [ -f "$STATE_FILE" ]; then
    "$SCRIPT_DIR/state-backup.sh" "$STATE_FILE" 2>/dev/null || true
fi

# Atomic write: temp file + mv
TEMP_FILE="${STATE_FILE}.tmp.$$"
echo "$NEW_STATE" > "$TEMP_FILE"
mv "$TEMP_FILE" "$STATE_FILE"

exit 0
