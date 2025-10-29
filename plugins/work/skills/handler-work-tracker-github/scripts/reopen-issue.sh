#!/bin/bash
# Handler: GitHub Reopen Issue
# Reopens a closed GitHub issue with optional comment

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [reopen_comment] [work_id]" >&2
    exit 2
fi

ISSUE_ID="$1"
REOPEN_COMMENT="${2:-Reopened by FABER workflow}"
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

# Format reopen comment with FABER metadata if work_id provided
if [ -n "$WORK_ID" ]; then
    FORMATTED_COMMENT="$REOPEN_COMMENT

---
_FABER Work ID: \`$WORK_ID\` | Reopened by workflow_"
else
    FORMATTED_COMMENT="$REOPEN_COMMENT"
fi

# Reopen the issue
if ! gh issue reopen "$ISSUE_ID" --comment "$FORMATTED_COMMENT" 2>/dev/null; then
    # Check if issue exists
    if gh issue view "$ISSUE_ID" --json number >/dev/null 2>&1; then
        # Issue exists but reopen failed (might already be open)
        issue_state=$(gh issue view "$ISSUE_ID" --json state -q '.state' 2>/dev/null)
        if [ "$issue_state" = "OPEN" ]; then
            echo "Warning: Issue #$ISSUE_ID is already open" >&2
            exit 3
        else
            echo "Error: Failed to reopen issue #$ISSUE_ID" >&2
            exit 1
        fi
    else
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    fi
fi

# Fetch updated issue to confirm reopening
issue_json=$(gh issue view "$ISSUE_ID" --json number,state,updatedAt,url 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Warning: Issue reopened but couldn't fetch updated details" >&2
    # Return basic success JSON
    echo "{\"id\":\"$ISSUE_ID\",\"identifier\":\"#$ISSUE_ID\",\"state\":\"open\",\"platform\":\"github\"}"
    exit 0
fi

# Output normalized JSON
echo "$issue_json" | jq -c '{
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  state: (.state | ascii_downcase),
  updatedAt: .updatedAt,
  url: .url,
  platform: "github"
}'

exit 0
