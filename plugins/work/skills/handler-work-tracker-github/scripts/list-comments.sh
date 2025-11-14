#!/bin/bash
# Work Manager: GitHub List Comments
# Lists comments on a GitHub issue with optional filtering

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$(cd "$SCRIPT_DIR/../../work-common/scripts" && pwd)"

# Check arguments - minimum 1 required (issue_id)
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [limit] [since]" >&2
    exit 2
fi

ISSUE_ID="$1"
LIMIT="${2:-10}"
SINCE="${3:-}"

# Validate limit
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
    echo "Error: limit must be a number between 1 and 100" >&2
    exit 2
fi

# Validate since date format if provided (YYYY-MM-DD)
if [ -n "$SINCE" ]; then
    if ! [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Error: since date must be in YYYY-MM-DD format" >&2
        exit 2
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

# Fetch comments using gh CLI
result=$(gh issue view "$ISSUE_ID" --repo "$REPO_SPEC" --json comments 2>&1)

if [ $? -ne 0 ]; then
    if echo "$result" | grep -q "Could not resolve to an Issue"; then
        echo "Error: Issue #$ISSUE_ID not found" >&2
        exit 10
    elif echo "$result" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch comments for issue #$ISSUE_ID" >&2
        echo "$result" >&2
        exit 1
    fi
fi

# Parse and filter comments using jq
# Filter by date if since is provided, then limit results
if [ -n "$SINCE" ]; then
    # Convert YYYY-MM-DD to ISO 8601 timestamp for comparison
    since_timestamp="${SINCE}T00:00:00Z"
    comments=$(echo "$result" | jq --arg limit "$LIMIT" --arg since "$since_timestamp" '
        .comments
        | map({
            id: .id,
            author: .author.login,
            body: .body,
            created_at: .createdAt,
            updated_at: .updatedAt,
            url: .url
        })
        | map(select(.created_at >= $since))
        | sort_by(.created_at)
        | reverse
        | .[:($limit | tonumber)]
    ')
else
    comments=$(echo "$result" | jq --arg limit "$LIMIT" '
        .comments
        | map({
            id: .id,
            author: .author.login,
            body: .body,
            created_at: .createdAt,
            updated_at: .updatedAt,
            url: .url
        })
        | sort_by(.created_at)
        | reverse
        | .[:($limit | tonumber)]
    ')
fi

# Output the filtered comments
echo "$comments"
exit 0
