#!/bin/bash
# Repo Manager: GitHub Push Branch
# Pushes branch to remote repository

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch_name> [force] [set_upstream]" >&2
    exit 2
fi

BRANCH_NAME="$1"
FORCE="${2:-false}"
SET_UPSTREAM="${3:-false}"

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
