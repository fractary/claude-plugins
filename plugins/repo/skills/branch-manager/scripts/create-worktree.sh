#!/bin/bash
# Create worktree in .worktrees/ subfolder
# Usage: create-worktree.sh <branch_name> <work_id>
# Returns: 0 on success, 1 on failure
# Outputs: worktree path to stdout

set -euo pipefail

BRANCH_NAME="$1"
WORK_ID="$2"

# Get repository root
REPO_ROOT=$(git rev-parse --show-toplevel)

# Generate worktree path with truncation for long branch names
BRANCH_SLUG=$(echo "$BRANCH_NAME" | sed 's/\//-/g')  # feat/123-add-export → feat-123-add-export

# Truncate if too long (keep first 80 chars to stay well under filesystem limits)
if [ ${#BRANCH_SLUG} -gt 80 ]; then
    # Keep first 70 chars + hash of full name for uniqueness
    HASH=$(echo "$BRANCH_SLUG" | md5sum | cut -c1-8)
    BRANCH_SLUG="${BRANCH_SLUG:0:70}-${HASH}"
fi

WORKTREE_PATH="$REPO_ROOT/.worktrees/$BRANCH_SLUG"

# Create worktree directory
git worktree add "$WORKTREE_PATH" "$BRANCH_NAME"

if [ $? -ne 0 ]; then
    echo "❌ Failed to create worktree at $WORKTREE_PATH" >&2
    exit 1
fi

echo "$WORKTREE_PATH"
exit 0
