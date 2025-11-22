#!/bin/bash
# Handler: GitHub Update Issue
# Updates issue title and/or description

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$(cd "$SCRIPT_DIR/../../work-common/scripts" && pwd)"

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

# Load repository info from configuration
REPO_INFO=$("$WORK_COMMON_DIR/get-repo-info.sh" 2>&1)
if [ $? -ne 0 ]; then
    echo "Error: Failed to load repository configuration" >&2
    echo "$REPO_INFO" >&2
    exit 3
fi

REPO_OWNER=$(echo "$REPO_INFO" | jq -r '.owner')
REPO_NAME=$(echo "$REPO_INFO" | jq -r '.repo')
REPO_SPEC="$REPO_OWNER/$REPO_NAME"

# Build command
gh_cmd="gh issue edit \"$ISSUE_ID\" --repo \"$REPO_SPEC\""

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
issue_json=$(gh issue view "$ISSUE_ID" --repo "$REPO_SPEC" --json number,title,body,url 2>/dev/null)
echo "$issue_json" | jq -c '{id: .number | tostring, identifier: ("#" + (.number | tostring)), title: .title, description: .body, url: .url, platform: "github"}'
exit 0
