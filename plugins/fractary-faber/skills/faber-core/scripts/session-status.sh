#!/bin/bash
# FABER Core: Session Status Retriever
# Gets the current status of a FABER workflow session

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <session_id>" >&2
    exit 2
fi

SESSION_ID="$1"

# Load configuration to get session storage path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_JSON=$("$SCRIPT_DIR/config-loader.sh")

if [ $? -ne 0 ]; then
    echo "Error: Failed to load configuration" >&2
    exit 3
fi

# Get session storage path
SESSION_STORAGE=$(echo "$CONFIG_JSON" | jq -r '.session.session_storage // ".faber/sessions"')
SESSION_FILE="$SESSION_STORAGE/${SESSION_ID}.json"

# Check if session exists
if [ ! -f "$SESSION_FILE" ]; then
    echo "Error: Session not found: $SESSION_ID" >&2
    exit 4
fi

# Output session JSON
cat "$SESSION_FILE"
exit 0
