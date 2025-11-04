#!/bin/bash
# Discover repositories in an organization for codex sync operations
#
# Usage:
#   ./discover-repos.sh --organization <org> --codex-repo <repo> [options]
#
# Options:
#   --organization <name>    GitHub/GitLab organization name (required)
#   --codex-repo <name>      Codex repository name to exclude (required)
#   --exclude <patterns>     Comma-separated patterns to exclude (regex)
#   --include <patterns>     Comma-separated patterns to include (regex, default: all)
#   --limit <number>         Maximum repositories to return (default: 100)
#   --json                   Output JSON only (no progress messages)
#
# Output: JSON object with discovered repositories

set -euo pipefail

# Default values
ORGANIZATION=""
CODEX_REPO=""
EXCLUDE_PATTERNS=""
INCLUDE_PATTERNS=""
LIMIT=100
JSON_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --organization)
      ORGANIZATION="$2"
      shift 2
      ;;
    --codex-repo)
      CODEX_REPO="$2"
      shift 2
      ;;
    --exclude)
      EXCLUDE_PATTERNS="$2"
      shift 2
      ;;
    --include)
      INCLUDE_PATTERNS="$2"
      shift 2
      ;;
    --limit)
      LIMIT="$2"
      shift 2
      ;;
    --json)
      JSON_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validation
if [ -z "$ORGANIZATION" ]; then
  echo '{"success": false, "error": "Organization is required", "repositories": [], "total": 0, "filtered": 0}' | jq .
  exit 1
fi

if [ -z "$CODEX_REPO" ]; then
  echo '{"success": false, "error": "Codex repository is required", "repositories": [], "total": 0, "filtered": 0}' | jq .
  exit 1
fi

# Progress message (unless JSON-only mode)
if [ "$JSON_ONLY" = false ]; then
  echo "Discovering repositories in organization: $ORGANIZATION" >&2
  echo "Codex repository to exclude: $CODEX_REPO" >&2
fi

# Use gh CLI to list repositories
# NOTE: In production, this should delegate to repo plugin's handler
# For now, using gh directly for MVP implementation

if ! command -v gh &> /dev/null; then
  echo '{"success": false, "error": "gh CLI not found - repo plugin may not be configured", "repositories": [], "total": 0, "filtered": 0}' | jq .
  exit 1
fi

# Check gh authentication
if ! gh auth status &> /dev/null; then
  echo '{"success": false, "error": "GitHub authentication required - run: gh auth login", "repositories": [], "total": 0, "filtered": 0}' | jq .
  exit 1
fi

# Fetch repositories from organization
if [ "$JSON_ONLY" = false ]; then
  echo "Fetching repositories (limit: $LIMIT)..." >&2
fi

# Fetch repos with pagination
REPOS_JSON=$(gh repo list "$ORGANIZATION" \
  --json name,nameWithOwner,url,defaultBranchRef,visibility \
  --limit "$LIMIT" 2>/dev/null || echo '[]')

if [ "$REPOS_JSON" = "[]" ] || [ -z "$REPOS_JSON" ]; then
  if [ "$JSON_ONLY" = false ]; then
    echo "No repositories found in organization: $ORGANIZATION" >&2
  fi
  echo '{"success": true, "repositories": [], "total": 0, "filtered": 0}' | jq .
  exit 0
fi

# Parse and transform the repository data
TOTAL_COUNT=$(echo "$REPOS_JSON" | jq 'length')

if [ "$JSON_ONLY" = false ]; then
  echo "Found $TOTAL_COUNT repositories" >&2
fi

# Filter repositories
FILTERED_REPOS=$(echo "$REPOS_JSON" | jq --arg codex_repo "$CODEX_REPO" '
  map(select(.name != $codex_repo))
')

# Apply exclude patterns
if [ -n "$EXCLUDE_PATTERNS" ]; then
  IFS=',' read -ra PATTERNS <<< "$EXCLUDE_PATTERNS"
  for pattern in "${PATTERNS[@]}"; do
    pattern=$(echo "$pattern" | xargs) # Trim whitespace
    FILTERED_REPOS=$(echo "$FILTERED_REPOS" | jq --arg pattern "$pattern" '
      map(select(.name | test($pattern) | not))
    ')
  done
fi

# Apply include patterns
if [ -n "$INCLUDE_PATTERNS" ]; then
  IFS=',' read -ra PATTERNS <<< "$INCLUDE_PATTERNS"
  TEMP_REPOS='[]'
  for pattern in "${PATTERNS[@]}"; do
    pattern=$(echo "$pattern" | xargs) # Trim whitespace
    MATCHED=$(echo "$FILTERED_REPOS" | jq --arg pattern "$pattern" '
      map(select(.name | test($pattern)))
    ')
    TEMP_REPOS=$(echo "$TEMP_REPOS $MATCHED" | jq -s 'add | unique_by(.name)')
  done
  FILTERED_REPOS="$TEMP_REPOS"
fi

# Transform to our output format
OUTPUT_REPOS=$(echo "$FILTERED_REPOS" | jq 'map({
  name: .name,
  full_name: .nameWithOwner,
  url: .url,
  default_branch: .defaultBranchRef.name,
  visibility: .visibility
})')

FILTERED_COUNT=$((TOTAL_COUNT - $(echo "$OUTPUT_REPOS" | jq 'length')))
FINAL_COUNT=$(echo "$OUTPUT_REPOS" | jq 'length')

if [ "$JSON_ONLY" = false ]; then
  echo "Filtered: $FILTERED_COUNT repositories" >&2
  echo "Discovered: $FINAL_COUNT repositories for sync" >&2
fi

# Output final JSON result
jq -n \
  --argjson repos "$OUTPUT_REPOS" \
  --argjson total "$TOTAL_COUNT" \
  --argjson filtered "$FILTERED_COUNT" \
  '{
    success: true,
    repositories: $repos,
    total: $total,
    filtered: $filtered,
    error: null
  }'

exit 0
