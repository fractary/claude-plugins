#!/usr/bin/env bash
#
# state-cancel.sh - Cancel FABER workflow
#
# Usage:
#   state-cancel.sh [reason]
#
# Arguments:
#   reason  - Optional cancellation reason (default: "User cancelled")
#
# Example:
#   state-cancel.sh "User requested cancellation"
#

set -euo pipefail

REASON="${1:-User cancelled}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATE_FILE=".fractary/plugins/faber/state.json"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    echo "No active workflow to cancel" >&2
    exit 1
fi

# Read current state
CURRENT_STATE=$("$SCRIPT_DIR/state-read.sh" "$STATE_FILE")

# Current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Update state to cancelled
echo "$CURRENT_STATE" | jq \
    --arg status "cancelled" \
    --arg reason "$REASON" \
    --arg timestamp "$TIMESTAMP" \
    '.status = $status |
     .cancelled_at = $timestamp |
     if .errors then . else .errors = [] end |
     .errors += [{
       "type": "cancellation",
       "timestamp": $timestamp,
       "reason": $reason
     }]' | \
    "$SCRIPT_DIR/state-write.sh" "$STATE_FILE"

echo "Workflow cancelled: $REASON"
exit 0
