#!/bin/bash
#
# gather-code-changes.sh
# Gets code changes between current branch and base branch
#
# Usage: gather-code-changes.sh [base_branch]
#
# Output: JSON with diff summary and file changes
#

set -euo pipefail

BASE_BRANCH="${1:-}"

# Auto-detect base branch if not provided
if [[ -z "$BASE_BRANCH" ]]; then
  if git show-ref --verify --quiet refs/heads/main 2>/dev/null; then
    BASE_BRANCH="main"
  elif git show-ref --verify --quiet refs/heads/master 2>/dev/null; then
    BASE_BRANCH="master"
  else
    echo '{"error": "Could not determine base branch"}' >&2
    exit 1
  fi
fi

# Get current branch
CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "HEAD")

# Capture HEAD SHA at start to ensure consistency across all operations
# This prevents race conditions if commits are made during script execution
HEAD_SHA=$(git rev-parse HEAD 2>/dev/null) || {
  echo '{"error": "Could not determine HEAD commit"}' >&2
  exit 1
}

# Check if we have commits since base
COMMIT_COUNT=$(git rev-list --count "${BASE_BRANCH}..${HEAD_SHA}" 2>/dev/null || echo "0")

if [[ "$COMMIT_COUNT" == "0" ]]; then
  jq -n \
    --arg base "$BASE_BRANCH" \
    --arg branch "$CURRENT_BRANCH" \
    '{
      "base_branch": $base,
      "branch_name": $branch,
      "commit_count": 0,
      "files_changed": [],
      "summary": {
        "total_files": 0,
        "added": 0,
        "modified": 0,
        "deleted": 0,
        "total_additions": 0,
        "total_deletions": 0
      },
      "test_files": [],
      "message": "No commits since base branch"
    }'
  exit 0
fi

# Get file changes with stats (uses HEAD_SHA for consistency)
get_file_changes() {
  git diff --stat --name-status "${BASE_BRANCH}...${HEAD_SHA}" 2>/dev/null | while read -r line; do
    if [[ -z "$line" ]]; then continue; fi

    # Parse status and filename
    local status file
    status=$(echo "$line" | cut -f1)
    file=$(echo "$line" | cut -f2-)

    # Map git status to human-readable
    case "$status" in
      A) status_name="added" ;;
      M) status_name="modified" ;;
      D) status_name="deleted" ;;
      R*) status_name="renamed" ;;
      C*) status_name="copied" ;;
      *) status_name="unknown" ;;
    esac

    # Get line stats (uses HEAD_SHA for consistency)
    local stats
    stats=$(git diff --numstat "${BASE_BRANCH}...${HEAD_SHA}" -- "$file" 2>/dev/null | head -1)
    local additions deletions
    additions=$(echo "$stats" | awk '{print $1}')
    deletions=$(echo "$stats" | awk '{print $2}')

    # Determine file type
    local file_type="other"
    case "$file" in
      *.md) file_type="markdown" ;;
      *.sh) file_type="script" ;;
      *.ts|*.tsx|*.js|*.jsx) file_type="source" ;;
      *.json) file_type="config" ;;
      *test*|*spec*) file_type="test" ;;
      SKILL.md|*agent*.md) file_type="skill" ;;
    esac

    echo "{\"path\":\"$file\",\"status\":\"$status_name\",\"additions\":${additions:-0},\"deletions\":${deletions:-0},\"type\":\"$file_type\"}"
  done
}

# Get diff content (summarized if large)
# Uses HEAD_SHA for consistency with other operations
get_diff_content() {
  local diff
  diff=$(git diff "${BASE_BRANCH}...${HEAD_SHA}" 2>/dev/null)

  local line_count
  line_count=$(echo "$diff" | wc -l)

  if [[ $line_count -gt 5000 ]]; then
    echo "# Diff too large ($line_count lines) - showing summary only"
    echo ""
    git diff --stat "${BASE_BRANCH}...${HEAD_SHA}" 2>/dev/null
    echo ""
    echo "# End of summary (full diff: $line_count lines)"
  else
    echo "$diff"
  fi
}

# Collect file changes as JSON array
FILES_JSON="["
first=true
while IFS= read -r file_json; do
  if [[ -z "$file_json" ]]; then continue; fi
  if [[ "$first" == "true" ]]; then
    FILES_JSON+="$file_json"
    first=false
  else
    FILES_JSON+=",$file_json"
  fi
done < <(get_file_changes)
FILES_JSON+="]"

# Calculate summary
ADDED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "added")] | length')
MODIFIED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "modified")] | length')
DELETED=$(echo "$FILES_JSON" | jq '[.[] | select(.status == "deleted")] | length')
TOTAL_ADDITIONS=$(echo "$FILES_JSON" | jq '[.[].additions] | add // 0')
TOTAL_DELETIONS=$(echo "$FILES_JSON" | jq '[.[].deletions] | add // 0')
TOTAL_FILES=$(echo "$FILES_JSON" | jq 'length')

# Find test files
TEST_FILES=$(echo "$FILES_JSON" | jq '[.[] | select(.type == "test" or (.path | test("test|spec"; "i"))) | .path]')

# Get diff content
DIFF_CONTENT=$(get_diff_content)

# Build output
jq -n \
  --arg base "$BASE_BRANCH" \
  --arg branch "$CURRENT_BRANCH" \
  --argjson commit_count "$COMMIT_COUNT" \
  --argjson files "$FILES_JSON" \
  --argjson added "$ADDED" \
  --argjson modified "$MODIFIED" \
  --argjson deleted "$DELETED" \
  --argjson additions "$TOTAL_ADDITIONS" \
  --argjson deletions "$TOTAL_DELETIONS" \
  --argjson total "$TOTAL_FILES" \
  --argjson test_files "$TEST_FILES" \
  --arg diff "$DIFF_CONTENT" \
  '{
    "base_branch": $base,
    "branch_name": $branch,
    "commit_count": $commit_count,
    "files_changed": $files,
    "summary": {
      "total_files": $total,
      "added": $added,
      "modified": $modified,
      "deleted": $deleted,
      "total_additions": $additions,
      "total_deletions": $deletions
    },
    "test_files": $test_files,
    "diff_content": $diff,
    "gathered_at": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  }'
