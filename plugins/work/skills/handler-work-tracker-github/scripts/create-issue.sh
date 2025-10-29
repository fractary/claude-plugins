#!/bin/bash
# Handler: GitHub Create Issue
# Creates a new issue in GitHub repository

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <title> [description] [labels] [assignees]" >&2
    exit 2
fi

TITLE="$1"
DESCRIPTION="${2:-}"
LABELS="${3:-}"
ASSIGNEES="${4:-}"

# Validate title
if [ -z "$TITLE" ]; then
    echo "Error: Title is required" >&2
    exit 2
fi

# Check gh CLI
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found" >&2
    exit 3
fi

# Check auth
if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed" >&2
    exit 11
fi

# Build gh issue create command
gh_cmd="gh issue create --title \"$TITLE\""

if [ -n "$DESCRIPTION" ]; then
    gh_cmd="$gh_cmd --body \"$DESCRIPTION\""
fi

if [ -n "$LABELS" ]; then
    # Convert comma-separated to multiple --label flags
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    for label in "${LABEL_ARRAY[@]}"; then
        label_trimmed="$(echo "$label" | xargs)"
        if [ -n "$label_trimmed" ]; then
            gh_cmd="$gh_cmd --label \"$label_trimmed\""
        fi
    done
fi

if [ -n "$ASSIGNEES" ]; then
    # Convert comma-separated to multiple --assignee flags
    IFS=',' read -ra ASSIGNEE_ARRAY <<< "$ASSIGNEES"
    for assignee in "${ASSIGNEE_ARRAY[@]}"; then
        assignee_trimmed="$(echo "$assignee" | xargs)"
        if [ -n "$assignee_trimmed" ]; then
            gh_cmd="$gh_cmd --assignee \"$assignee_trimmed\""
        fi
    done
fi

# Execute and capture URL
issue_url=$(eval "$gh_cmd" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to create issue" >&2
    echo "$issue_url" >&2
    exit 1
fi

# Extract issue number from URL
issue_number=$(echo "$issue_url" | grep -oP '/issues/\K\d+' || echo "unknown")

# Output normalized JSON
echo "{\"id\":\"$issue_number\",\"identifier\":\"#$issue_number\",\"title\":\"$TITLE\",\"url\":\"$issue_url\",\"platform\":\"github\"}"
exit 0
