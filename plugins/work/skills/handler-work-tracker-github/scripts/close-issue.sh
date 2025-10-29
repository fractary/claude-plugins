#!/bin/bash
# Handler: GitHub Close Issue
# Closes a GitHub issue with optional comment

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [close_comment] [work_id]" >&2
    exit 2
fi

ISSUE_ID="$1"
CLOSE_COMMENT="${2:-Closed by FABER workflow}"
WORK_ID="${3:-}"

# Validate issue ID
if [ -z "$ISSUE_ID" ]; then
    echo "Error: ISSUE_ID required" >&2
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

# Format close comment with FABER metadata if work_id provided
if [ -n "$WORK_ID" ]; then
    FORMATTED_COMMENT="$CLOSE_COMMENT

---
_FABER Work ID: \`$WORK_ID\` | Closed by workflow_"
else
    FORMATTED_COMMENT="$CLOSE_COMMENT"
fi

# Close the issue
if ! gh issue close "$ISSUE_ID" --comment "$FORMATTED_COMMENT" 2>/dev/null; then
    # Check if issue exists
    if gh issue view "$ISSUE_ID" --json number >/dev/null 2>&1; then
        # Issue exists but close failed (might already be closed)
        issue_state=$(gh issue view "$ISSUE_ID" --json state -q '.state' 2>/dev/null)
        if [ "$issue_state" = "CLOSED" ]; then
            echo "Warning: Issue #$ISSUE_ID is already closed" >&2
            exit 3
        else
            echo "Error: Failed to close issue #$ISSUE_ID" >&2
            exit 1
        fi
    else
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    fi
fi

# Fetch updated issue to confirm closure
issue_json=$(gh issue view "$ISSUE_ID" --json number,state,closedAt,url 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Warning: Issue closed but couldn't fetch updated details" >&2
    # Return basic success JSON
    echo "{\"id\":\"$ISSUE_ID\",\"identifier\":\"#$ISSUE_ID\",\"state\":\"closed\",\"platform\":\"github\"}"
    exit 0
fi

# Output normalized JSON
echo "$issue_json" | jq -c '{
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  state: (.state | ascii_downcase),
  closedAt: .closedAt,
  url: .url,
  platform: "github"
}'

exit 0
