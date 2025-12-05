#!/bin/bash
#
# gather-issue-context.sh
# Fetches issue details including all comments from GitHub
#
# Usage: gather-issue-context.sh <work_id>
#
# Output: JSON with issue details and comments
#

set -euo pipefail

WORK_ID="${1:-}"

if [[ -z "$WORK_ID" ]]; then
  echo '{"error": "work_id is required"}' >&2
  exit 1
fi

# Determine repository from git remote
get_repo_info() {
  local remote_url
  remote_url=$(git config --get remote.origin.url 2>/dev/null || echo "")

  if [[ -z "$remote_url" ]]; then
    echo ""
    return
  fi

  # Handle both SSH and HTTPS formats
  # git@github.com:owner/repo.git -> owner/repo
  # https://github.com/owner/repo.git -> owner/repo
  echo "$remote_url" | sed -E 's|\.git$||' | sed -E 's|^.*[:/]([^/]+/[^/]+)$|\1|'
}

REPO=$(get_repo_info)

if [[ -z "$REPO" ]]; then
  echo '{"error": "Could not determine repository from git remote"}' >&2
  exit 1
fi

# Fetch issue details
fetch_issue() {
  gh api "repos/${REPO}/issues/${WORK_ID}" \
    --jq '{
      number: .number,
      title: .title,
      body: .body,
      state: .state,
      labels: [.labels[].name],
      author: .user.login,
      created_at: .created_at,
      updated_at: .updated_at,
      url: .html_url
    }' 2>/dev/null
}

# Fetch issue comments
fetch_comments() {
  gh api "repos/${REPO}/issues/${WORK_ID}/comments" \
    --jq '[.[] | {
      id: .id,
      author: .user.login,
      body: .body,
      created_at: .created_at,
      updated_at: .updated_at
    }]' 2>/dev/null
}

# Main execution with retry
MAX_RETRIES=3
RETRY_DELAY=2

issue_result=""
comments_result=""

for attempt in $(seq 1 $MAX_RETRIES); do
  if [[ -z "$issue_result" ]]; then
    issue_result=$(fetch_issue) || true
  fi

  if [[ -n "$issue_result" ]]; then
    break
  fi

  if [[ $attempt -lt $MAX_RETRIES ]]; then
    sleep $((RETRY_DELAY * attempt))
  fi
done

if [[ -z "$issue_result" ]]; then
  # Use jq --arg to safely escape WORK_ID and avoid JSON injection
  jq -n --arg work_id "$WORK_ID" '{
    "error": "Failed to fetch issue after retries",
    "work_id": $work_id
  }' >&2
  exit 1
fi

# Fetch comments (non-critical, continue if fails)
comments_result=$(fetch_comments) || comments_result="[]"

# Combine results
jq -n \
  --argjson issue "$issue_result" \
  --argjson comments "$comments_result" \
  '{
    "issue": $issue,
    "comments": $comments,
    "fetched_at": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  }'
