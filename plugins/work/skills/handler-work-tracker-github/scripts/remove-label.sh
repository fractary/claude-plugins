#!/bin/bash
# Handler: GitHub Remove Label
# Removes a label from a GitHub issue

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <label>" >&2
    exit 2
fi

ISSUE_ID="$1"
LABEL="$2"

# Validate inputs
if [ -z "$ISSUE_ID" ] || [ -z "$LABEL" ]; then
    echo "Error: Both issue_id and label are required" >&2
    exit 2
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Check authentication
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed. Run 'gh auth login'" >&2
    exit 11
fi

# Remove label using gh CLI
# Silently succeed if label doesn't exist on issue (idempotent)
result=$(gh issue edit "$ISSUE_ID" --remove-label "$LABEL" 2>&1)

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    elif echo "$result" | grep -q "label.*not found\|does not have"; then
        # Label not on issue - treat as success (idempotent)
        echo "Label '$LABEL' not found on issue #$ISSUE_ID (already removed)"
        exit 0
    else
        echo "Error: Failed to remove label from issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Output success message
echo "Label '$LABEL' removed from issue #$ISSUE_ID"
exit 0
