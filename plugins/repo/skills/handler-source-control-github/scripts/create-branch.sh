#!/bin/bash
# Repo Manager: GitHub Create Branch
# Creates a new git branch

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch_name> [base_branch]" >&2
    exit 2
fi

BRANCH_NAME="$1"
BASE_BRANCH="${2:-main}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Check if branch already exists
if git rev-parse --verify "$BRANCH_NAME" > /dev/null 2>&1; then
    echo "Error: Branch '$BRANCH_NAME' already exists" >&2
    exit 10
fi

# Ensure base branch exists
if ! git rev-parse --verify "$BASE_BRANCH" > /dev/null 2>&1; then
    echo "Error: Base branch '$BASE_BRANCH' does not exist" >&2
    exit 1
fi

# Create branch from base
git branch "$BRANCH_NAME" "$BASE_BRANCH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create branch '$BRANCH_NAME'" >&2
    exit 1
fi

echo "Branch '$BRANCH_NAME' created from '$BASE_BRANCH'"
exit 0
