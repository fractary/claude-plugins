#!/bin/bash
# Work Manager: GitHub Create Comment
# Posts a comment to a GitHub issue
# Supports both FABER workflow comments (with metadata) and standalone comments

set -euo pipefail

# Check arguments - minimum 2 required (issue_id, message)
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <message> [work_id] [author]" >&2
    exit 2
fi

ISSUE_ID="$1"
MESSAGE="$2"
WORK_ID="${3:-}"
AUTHOR="${4:-}"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Format comment based on whether FABER context is provided
if [ -n "$WORK_ID" ] && [ -n "$AUTHOR" ]; then
    # FABER workflow comment - include metadata footer
    FORMATTED_COMMENT="$MESSAGE

---
_FABER Work ID: \`$WORK_ID\` | Author: $AUTHOR_"
else
    # Standalone comment - no metadata footer
    FORMATTED_COMMENT="$MESSAGE"
fi

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
