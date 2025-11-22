#!/bin/bash
# Handler: GitHub Search Issues
# Full-text search across issues

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$(cd "$SCRIPT_DIR/../../work-common/scripts" && pwd)"

QUERY_TEXT="${1:-}"
LIMIT="${2:-20}"

if [ -z "$QUERY_TEXT" ]; then
    echo "Error: query_text required" >&2
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

# Search issues
issues_json=$(gh issue list --repo "$REPO_SPEC" --search "$QUERY_TEXT" --json number,title,body,state,labels,url --limit "$LIMIT" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Search failed" >&2
    echo "$issues_json" >&2
    exit 1
fi

# Normalize
echo "$issues_json" | jq -c '[.[] | {
  id: .number | tostring,
  identifier: ("#" + (.number | tostring)),
  title: .title,
  description: .body // "",
  state: (.state | ascii_downcase),
  labels: [.labels[]?.name // empty],
  url: .url,
  platform: "github"
}]'
exit 0
