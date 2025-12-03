#!/bin/bash
# Repo Manager: GitHub Create Branch
# Creates a new git branch

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch_name> [base_branch] [checkout]" >&2
    exit 2
fi

BRANCH_NAME="$1"
BASE_BRANCH="${2:-main}"
CHECKOUT="${3:-true}"

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

# Create branch from base (will exit on error due to set -e)
git branch "$BRANCH_NAME" "$BASE_BRANCH"

# Checkout the branch if requested (will exit on error due to set -e)
if [ "$CHECKOUT" = "true" ]; then
    git checkout "$BRANCH_NAME"
    echo "Branch '$BRANCH_NAME' created from '$BASE_BRANCH' and checked out"

    # Update status cache to reflect branch change (triggers issue_id extraction)
    # This ensures the status line immediately shows the new branch
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    CACHE_UPDATE_SCRIPT="${SCRIPT_DIR}/../../../scripts/update-status-cache.sh"
    if [ -f "$CACHE_UPDATE_SCRIPT" ]; then
        "$CACHE_UPDATE_SCRIPT" --quiet 2>/dev/null || true
    fi
else
    echo "Branch '$BRANCH_NAME' created from '$BASE_BRANCH' (not checked out)"
fi

exit 0
