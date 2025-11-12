#!/usr/bin/env bash
#
# remove.sh - Remove a git worktree
#
# Usage: remove.sh <branch_name> [--force]
#
# Arguments:
#   branch_name  - Name of the branch whose worktree to remove
#   --force      - Force removal even with uncommitted changes
#
# Exit codes:
#   0 - Success
#   1 - Git error
#   2 - Invalid arguments
#   10 - Worktree not found
#   20 - Uncommitted changes (without --force)
#   21 - Worktree is current directory

set -euo pipefail

# Parse arguments
BRANCH_NAME="${1:-}"
FORCE=false

shift || true
while [[ $# -gt 0 ]]; do
  case $1 in
    --force)
      FORCE=true
      shift
      ;;
    *)
      echo "Error: Unknown argument: $1" >&2
      exit 2
      ;;
  esac
done

# Validate arguments
if [ -z "$BRANCH_NAME" ]; then
  echo "Error: branch_name is required" >&2
  exit 2
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a Git repository" >&2
  exit 1
fi

# Find worktree path for the branch
WORKTREE_PATH=$(git worktree list --porcelain | awk -v branch="$BRANCH_NAME" '
  /^worktree / { path=$2 }
  /^branch / {
    if ($2 == "refs/heads/"branch) {
      print path
      exit
    }
  }
')

if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: No worktree found for branch: $BRANCH_NAME" >&2
  exit 10
fi

# Check if worktree is the current directory
CURRENT_DIR=$(pwd)
if [[ "$CURRENT_DIR" == "$WORKTREE_PATH"* ]]; then
  echo "Error: Cannot remove worktree from within it. Change directory first." >&2
  exit 21
fi

# Check for uncommitted changes
if [ "$FORCE" = false ]; then
  cd "$WORKTREE_PATH"
  if [ -n "$(git status --porcelain)" ]; then
    MODIFIED_COUNT=$(git status --porcelain | wc -l)
    echo "Error: Worktree has $MODIFIED_COUNT uncommitted change(s)." >&2
    echo "Files:" >&2
    git status --porcelain >&2
    echo "" >&2
    echo "Use --force to remove anyway (changes will be lost)" >&2
    exit 20
  fi
  cd - > /dev/null
fi

# Remove the worktree
echo "Removing worktree for branch $BRANCH_NAME at $WORKTREE_PATH..." >&2

if ! git worktree remove "$WORKTREE_PATH" ${FORCE:+--force} 2>&1; then
  echo "Error: Failed to remove worktree" >&2
  exit 1
fi

# Output success information (JSON format for parsing)
cat <<EOF
{
  "status": "success",
  "worktree_path": "$WORKTREE_PATH",
  "branch_name": "$BRANCH_NAME"
}
EOF

exit 0
