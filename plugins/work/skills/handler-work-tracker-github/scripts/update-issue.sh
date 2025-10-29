#!/bin/bash
# Handler: GitHub Update Issue
# Updates issue title and/or description

set -euo pipefail

if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [title] [description]" >&2
    exit 2
fi

ISSUE_ID="$1"
NEW_TITLE="${2:-}"
NEW_DESCRIPTION="${3:-}"

if [ -z "$ISSUE_ID" ]; then
    echo "Error: issue_id required" >&2
    exit 2
fi

if [ -z "$NEW_TITLE" ] && [ -z "$NEW_DESCRIPTION" ]; then
    echo "Error: At least one of title or description must be provided" >&2
    exit 2
fi

if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found" >&2
    exit 3
fi

if ! gh auth status >/dev/null 2>&1; then
    echo "Error: GitHub authentication failed" >&2
    exit 11
fi

# Build command
gh_cmd="gh issue edit \"$ISSUE_ID\""

if [ -n "$NEW_TITLE" ]; then
    gh_cmd="$gh_cmd --title \"$NEW_TITLE\""
fi

if [ -n "$NEW_DESCRIPTION" ]; then
    gh_cmd="$gh_cmd --body \"$NEW_DESCRIPTION\""
fi

# Execute
if ! eval "$gh_cmd" 2>&1; then
    echo "Error: Failed to update issue #$ISSUE_ID" >&2
    exit 1
fi

# Fetch updated issue
issue_json=$(gh issue view "$ISSUE_ID" --json number,title,body,url 2>/dev/null)
echo "$issue_json" | jq -c '{id: .number | tostring, identifier: ("#" + (.number | tostring)), title: .title, description: .body, url: .url, platform: "github"}'
exit 0
