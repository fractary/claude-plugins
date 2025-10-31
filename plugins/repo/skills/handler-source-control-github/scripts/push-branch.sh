#!/bin/bash
# Repo Manager: GitHub Push Branch
# Pushes branch to remote repository

set -euo pipefail

# Check arguments
# If branch name not provided, use current branch
if [ $# -lt 1 ] || [ -z "$1" ]; then
    BRANCH_NAME=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
    if [ -z "$BRANCH_NAME" ] || [ "$BRANCH_NAME" = "HEAD" ]; then
        echo "Error: Not on a branch and no branch name provided" >&2
        exit 2
    fi
    FORCE="${1:-false}"
    SET_UPSTREAM="${2:-false}"
else
    BRANCH_NAME="$1"
    FORCE="${2:-false}"
    SET_UPSTREAM="${3:-false}"
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Check if branch exists
if ! git rev-parse --verify "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Error: Branch '$BRANCH_NAME' does not exist" >&2
    exit 1
fi

# Build push command
PUSH_CMD="git push"

# Add force flag if requested
if [ "$FORCE" = "true" ]; then
    PUSH_CMD="$PUSH_CMD --force-with-lease"
fi

# Add upstream flag if requested
if [ "$SET_UPSTREAM" = "true" ]; then
    PUSH_CMD="$PUSH_CMD -u"
fi

# Add remote and branch
PUSH_CMD="$PUSH_CMD origin $BRANCH_NAME"

# Execute push
eval $PUSH_CMD

if [ $? -ne 0 ]; then
    echo "Error: Failed to push branch '$BRANCH_NAME'" >&2
    exit 12
fi

echo "Branch '$BRANCH_NAME' pushed to origin"
exit 0
