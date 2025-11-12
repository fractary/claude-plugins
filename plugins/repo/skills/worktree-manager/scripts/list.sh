#!/usr/bin/env bash
#
# list.sh - List all git worktrees
#
# Usage: list.sh [--format json|text]
#
# Arguments:
#   --format  - Output format (json or text, default: json)
#
# Exit codes:
#   0 - Success
#   1 - Git error

set -euo pipefail

# Parse arguments
FORMAT="json"
while [[ $# -gt 0 ]]; do
  case $1 in
    --format)
      FORMAT="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a Git repository" >&2
  exit 1
fi

# Get worktree list
WORKTREE_DATA=$(git worktree list --porcelain)

if [ "$FORMAT" = "json" ]; then
  # Parse and output as JSON
  echo "{"
  echo "  \"worktrees\": ["

  FIRST=true
  CURRENT_PATH=""
  CURRENT_HEAD=""
  CURRENT_BRANCH=""

  while IFS= read -r line; do
    if [[ $line == worktree* ]]; then
      # Start of a new worktree entry
      if [ "$FIRST" = false ] && [ -n "$CURRENT_PATH" ]; then
        echo "    },"
      fi
      CURRENT_PATH="${line#worktree }"
      FIRST=false
      echo "    {"
      echo "      \"path\": \"$CURRENT_PATH\","
    elif [[ $line == HEAD* ]]; then
      CURRENT_HEAD="${line#HEAD }"
      echo "      \"commit_sha\": \"$CURRENT_HEAD\","
    elif [[ $line == branch* ]]; then
      CURRENT_BRANCH="${line#branch }"
      CURRENT_BRANCH="${CURRENT_BRANCH#refs/heads/}"
      echo "      \"branch\": \"$CURRENT_BRANCH\""
    elif [[ $line == detached ]]; then
      echo "      \"branch\": \"(detached HEAD)\""
    fi
  done <<< "$WORKTREE_DATA"

  # Close last entry
  if [ "$FIRST" = false ]; then
    echo "    }"
  fi

  echo "  ]"
  echo "}"
else
  # Text format
  git worktree list
fi

exit 0
