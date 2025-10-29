#!/bin/bash
# Handler: GitHub Update Milestone
# Updates milestone properties (title, description, due date, state)

set -euo pipefail

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <milestone_id> [title] [description] [due_date] [state]" >&2
    exit 2
fi

MILESTONE_ID="$1"
TITLE="${2:-}"
DESCRIPTION="${3:-}"
DUE_DATE="${4:-}"
STATE="${5:-}"

# Validate required parameters
if [ -z "$MILESTONE_ID" ]; then
    echo "Error: Milestone ID is required" >&2
    exit 2
fi

# Validate at least one update parameter provided
if [ -z "$TITLE" ] && [ -z "$DESCRIPTION" ] && [ -z "$DUE_DATE" ] && [ -z "$STATE" ]; then
    echo "Error: No update parameters provided" >&2
    echo "  Provide at least one of: title, description, due_date, state" >&2
    exit 2
fi

# Validate date format if provided (YYYY-MM-DD)
if [ -n "$DUE_DATE" ]; then
    if ! echo "$DUE_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "Error: Invalid due_date format: $DUE_DATE" >&2
        echo "  Date must be in YYYY-MM-DD format" >&2
        exit 3
    fi
fi

# Validate state if provided
if [ -n "$STATE" ]; then
    if [ "$STATE" != "open" ] && [ "$STATE" != "closed" ]; then
        echo "Error: Invalid state: $STATE" >&2
        echo "  State must be 'open' or 'closed'" >&2
        exit 3
    fi
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

# Build JSON request with only provided fields
REQUEST_JSON=$(jq -n \
  --arg title "$TITLE" \
  --arg desc "$DESCRIPTION" \
  --arg due "$DUE_DATE" \
  --arg state "$STATE" \
  '{
    title: (if $title != "" then $title else null end),
    description: (if $desc != "" then $desc else null end),
    due_on: (if $due != "" then $due else null end),
    state: (if $state != "" then $state else null end)
  } | with_entries(select(.value != null))')

# Update milestone via GitHub API
result=$(gh api repos/:owner/:repo/milestones/"$MILESTONE_ID" -X PATCH --input - <<< "$REQUEST_JSON" 2>&1)

# Check for errors
if [ $? -ne 0 ]; then
    if echo "$result" | grep -qi "not found"; then
        echo "Error: Milestone #$MILESTONE_ID not found" >&2
        echo "  Verify milestone exists in the repository" >&2
        exit 10
    else
        echo "Error: Failed to update milestone #$MILESTONE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Output normalized JSON
echo "$result" | jq -c '{
  id: .number | tostring,
  title: .title,
  description: (.description // ""),
  due_date: (.due_on // null),
  state: .state,
  url: .html_url,
  platform: "github"
}'

exit 0
