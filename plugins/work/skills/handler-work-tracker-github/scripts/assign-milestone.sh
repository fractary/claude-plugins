#!/bin/bash
# Handler: GitHub Assign Milestone
# Assigns issue to a milestone or removes milestone assignment

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$(cd "$SCRIPT_DIR/../../work-common/scripts" && pwd)"

# Parse arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <milestone_id>" >&2
    echo "  Use 'none' as milestone_id to remove milestone" >&2
    exit 2
fi

ISSUE_ID="$1"
MILESTONE_ID="$2"

# Validate required parameters
if [ -z "$ISSUE_ID" ]; then
    echo "Error: Issue ID is required" >&2
    exit 2
fi

if [ -z "$MILESTONE_ID" ]; then
    echo "Error: Milestone ID is required (use 'none' to remove)" >&2
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

# Verify issue exists
if ! gh issue view "$ISSUE_ID" --repo "$REPO_SPEC" --json number >/dev/null 2>&1; then
    echo "Error: Issue #$ISSUE_ID not found" >&2
    echo "  Verify issue exists in the repository" >&2
    exit 10
fi

# Assign or remove milestone
if [ "$MILESTONE_ID" = "none" ]; then
    # Remove milestone assignment
    result=$(gh issue edit "$ISSUE_ID" --repo "$REPO_SPEC" --milestone "" 2>&1)
    if [ $? -ne 0 ]; then
        echo "Error: Failed to remove milestone from issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
else
    # Verify milestone exists (by trying to fetch it)
    # Note: gh doesn't have a direct milestone view, so we try to assign it
    result=$(gh issue edit "$ISSUE_ID" --repo "$REPO_SPEC" --milestone "$MILESTONE_ID" 2>&1)
    if [ $? -ne 0 ]; then
        if echo "$result" | grep -qi "not found\|does not exist"; then
            echo "Error: Milestone #$MILESTONE_ID not found" >&2
            echo "  Verify milestone exists in the repository" >&2
            exit 10
        else
            echo "Error: Failed to assign milestone to issue #$ISSUE_ID" >&2
            echo "$result" >&2
            exit 1
        fi
    fi
fi

# Fetch updated issue to get milestone info
issue_json=$(gh issue view "$ISSUE_ID" --repo "$REPO_SPEC" --json number,milestone 2>/dev/null)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch updated issue #$ISSUE_ID" >&2
    exit 1
fi

# Output normalized JSON
echo "$issue_json" | jq -c '{
  issue_id: .number | tostring,
  milestone: (.milestone.title // null),
  milestone_id: (if .milestone then .milestone.number | tostring else null end),
  platform: "github"
}'

exit 0
