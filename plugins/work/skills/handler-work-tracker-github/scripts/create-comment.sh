#!/bin/bash
# Work Manager: GitHub Create Comment
# Posts a comment to a GitHub issue

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <issue_id> <work_id> <author> <message>" >&2
    exit 2
fi

ISSUE_ID="$1"
WORK_ID="$2"
AUTHOR="$3"
MESSAGE="$4"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Format comment with FABER context
FORMATTED_COMMENT="$MESSAGE

---
_FABER Work ID: \`$WORK_ID\` | Author: $AUTHOR_"

# Post comment using gh CLI
result=$(gh issue comment "$ISSUE_ID" --body "$FORMATTED_COMMENT" 2>&1)

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to post comment to issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Output success message
echo "Comment posted to issue #$ISSUE_ID"
exit 0
