#!/bin/bash
# Handler: GitHub Create Milestone
# Creates a new milestone in the repository with optional description and due date

set -euo pipefail

# Parse arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <title> [description] [due_date]" >&2
    exit 2
fi

TITLE="$1"
DESCRIPTION="${2:-}"
DUE_DATE="${3:-}"

# Validate required parameters
if [ -z "$TITLE" ]; then
    echo "Error: Milestone title is required" >&2
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
  '{
    title: $title,
    description: (if $desc != "" then $desc else null end),
    due_on: (if $due != "" then $due else null end)
  } | with_entries(select(.value != null))')

# Create milestone via GitHub API
result=$(gh api repos/:owner/:repo/milestones -X POST --input - <<< "$REQUEST_JSON" 2>&1)

# Check for errors
if [ $? -ne 0 ]; then
    echo "Error: Failed to create milestone" >&2
    echo "$result" >&2
    exit 1
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
