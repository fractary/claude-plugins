#!/bin/bash
# Handler: GitHub Assign Issue
# Assigns issue to user(s)

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$(cd "$SCRIPT_DIR/../../work-common/scripts" && pwd)"

if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <assignee_username>" >&2
    exit 2
fi

ISSUE_ID="$1"
ASSIGNEE="$2"

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

# Assign
if ! gh issue edit "$ISSUE_ID" --repo "$REPO_SPEC" --add-assignee "$ASSIGNEE" 2>&1; then
    echo "Error: Failed to assign issue #$ISSUE_ID to $ASSIGNEE" >&2
    exit 1
fi

echo "{\"status\":\"success\",\"issue_id\":\"$ISSUE_ID\",\"assignee\":\"$ASSIGNEE\"}"
exit 0
