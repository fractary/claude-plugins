#!/bin/bash
# Handler: GitHub Add Label
# Adds a label to a GitHub issue

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

# Add label using gh CLI
result=$(gh issue edit "$ISSUE_ID" --add-label "$LABEL" 2>&1)

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to add label to issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Output success message
echo "Label '$LABEL' added to issue #$ISSUE_ID"
exit 0
