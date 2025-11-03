#!/bin/bash
# Handler: GitHub Assign Issue
# Assigns issue to user(s)

set -euo pipefail

if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <assignee_username>" >&2
    exit 2
fi

ISSUE_ID="$1"
ASSIGNEE="$2"

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found" >&2
    exit 3
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed" >&2
    exit 11
fi

# Assign
if ! gh issue edit "$ISSUE_ID" --add-assignee "$ASSIGNEE" 2>&1; then
    echo "Error: Failed to assign issue #$ISSUE_ID to $ASSIGNEE" >&2
    exit 1
fi

echo "{\"status\":\"success\",\"issue_id\":\"$ISSUE_ID\",\"assignee\":\"$ASSIGNEE\"}"
exit 0
