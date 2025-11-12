#!/usr/bin/env bash
#
# create.sh - Create a git worktree for a branch
#
# Usage: create.sh <branch_name> <worktree_path> [base_branch]
#
# Arguments:
#   branch_name    - Name of the branch to create worktree for
#   worktree_path  - Path where worktree should be created
#   base_branch    - Optional base branch (default: current branch)
#
# Exit codes:
#   0 - Success
#   1 - Git error
#   2 - Invalid arguments
#   10 - Worktree already exists
#   11 - Branch doesn't exist

set -euo pipefail

# Parse arguments
BRANCH_NAME="${1:-}"
WORKTREE_PATH="${2:-}"
BASE_BRANCH="${3:-}"

# Validate arguments
if [ -z "$BRANCH_NAME" ]; then
  echo "Error: branch_name is required" >&2
  exit 2
fi

if [ -z "$WORKTREE_PATH" ]; then
  echo "Error: worktree_path is required" >&2
  exit 2
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "Error: Not a Git repository" >&2
  exit 1
fi

# Check if branch exists
if ! git show-ref --verify --quiet "refs/heads/$BRANCH_NAME"; then
  echo "Error: Branch does not exist: $BRANCH_NAME" >&2
  exit 11
fi

# Check if worktree path already exists
if [ -d "$WORKTREE_PATH" ]; then
  echo "Error: Directory already exists: $WORKTREE_PATH" >&2
  exit 10
fi

# Check if worktree already exists for this branch
if git worktree list | grep -qF "[$BRANCH_NAME]"; then
  EXISTING_PATH=$(git worktree list | grep -F "[$BRANCH_NAME]" | awk '{print $1}')
  echo "Error: Worktree already exists for branch $BRANCH_NAME at $EXISTING_PATH" >&2
  exit 10
fi

# Create the worktree
echo "Creating worktree for branch $BRANCH_NAME at $WORKTREE_PATH..." >&2

if ! git worktree add "$WORKTREE_PATH" "$BRANCH_NAME" 2>&1; then
  echo "Error: Failed to create worktree" >&2
  exit 1
fi

# Get commit SHA
COMMIT_SHA=$(git -C "$WORKTREE_PATH" rev-parse HEAD)

# Output success information (JSON format for parsing)
cat <<EOF
{
  "status": "success",
  "worktree_path": "$WORKTREE_PATH",
  "branch_name": "$BRANCH_NAME",
  "commit_sha": "$COMMIT_SHA"
}
EOF

exit 0
