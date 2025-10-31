#!/bin/bash
# Handler: GitHub List Issues
# Lists/filters issues by criteria

set -euo pipefail

# Parse arguments (all optional)
STATE="${1:-all}"           # all, open, closed
LABELS="${2:-}"             # Comma-separated label list
ASSIGNEE="${3:-}"           # Username or "none"
LIMIT="${4:-50}"            # Default 50 results

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

# Build gh issue list command
gh_cmd="gh issue list --json number,title,body,state,labels,assignees,author,createdAt,updatedAt,url --limit $LIMIT"

# Add state filter
case "$STATE" in
    all) gh_cmd="$gh_cmd --state all" ;;
    open) gh_cmd="$gh_cmd --state open" ;;
    closed) gh_cmd="$gh_cmd --state closed" ;;
    *)
        echo "Warning: Unknown state '$STATE', using 'all'" >&2
        gh_cmd="$gh_cmd --state all"
        ;;
esac

# Add label filter (comma-separated labels)
if [ -n "$LABELS" ]; then
    # Split comma-separated labels and add each one
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    for label in "${LABEL_ARRAY[@]}"; then
        label_trimmed="$(echo "$label" | xargs)"  # Trim whitespace
        if [ -n "$label_trimmed" ]; then
            gh_cmd="$gh_cmd --label \"$label_trimmed\""
        fi
    done
fi

# Add assignee filter
if [ -n "$ASSIGNEE" ]; then
    if [ "$ASSIGNEE" = "none" ]; then
        gh_cmd="$gh_cmd --assignee @me"  # No assignee filter
    else
        gh_cmd="$gh_cmd --assignee \"$ASSIGNEE\""
    fi
fi

# Execute command
issues_json=$(eval "$gh_cmd" 2>&1)
exit_code=$?

if [ $exit_code -ne 0 ]; then
    if echo "$issues_json" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to list issues" >&2
        echo "$issues_json" >&2
        exit 1
    fi
fi

# Check if no issues found
if [ "$issues_json" = "[]" ] || [ -z "$issues_json" ]; then
    echo "[]"
    exit 0
fi

# Normalize each issue in the array
normalized_json=$(echo "$issues_json" | jq -c '[.[] | {
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  title: .title,
  description: .body // "",
  state: (.state | ascii_downcase),
  labels: [.labels[]?.name // empty],
  assignees: [.assignees[]? | {
    id: .id // "",
    username: .login,
    email: .email // ""
  }],
  author: {
    id: .author.id // "",
    username: .author.login
  },
  createdAt: .createdAt,
  updatedAt: .updatedAt,
  closedAt: .closedAt // null,
  url: .url,
  platform: "github"
}]')

# Output normalized JSON array
echo "$normalized_json"
exit 0
