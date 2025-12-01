#!/bin/bash
# Repo Manager: GitHub Delete Branch
# Deletes a branch locally and/or remotely

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <branch_name> [--force] [--local-only] [--remote-only]" >&2
    exit 2
fi

BRANCH_NAME="$1"
FORCE=""
DELETE_LOCAL=true
DELETE_REMOTE=true

# Parse optional flags
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            FORCE="-D"
            ;;
        --local-only)
            DELETE_REMOTE=false
            ;;
        --remote-only)
            DELETE_LOCAL=false
            ;;
        *)
            echo "Error: Unknown option '$1'" >&2
            exit 2
            ;;
    esac
    shift
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Protected branch safety check
PROTECTED_BRANCHES=("main" "master" "production" "staging" "develop")
for protected in "${PROTECTED_BRANCHES[@]}"; do
    if [ "$BRANCH_NAME" = "$protected" ]; then
        echo "Error: Cannot delete protected branch '$BRANCH_NAME'" >&2
        exit 14
    fi
done

# Check if currently on the branch to delete
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
if [ "$CURRENT_BRANCH" = "$BRANCH_NAME" ]; then
    echo "Error: Cannot delete current branch. Switch to another branch first." >&2
    exit 1
fi

# Delete local branch
if [ "$DELETE_LOCAL" = true ]; then
    if git rev-parse --verify "$BRANCH_NAME" > /dev/null 2>&1; then
        if [ -n "$FORCE" ]; then
            git branch -D "$BRANCH_NAME"
        else
            git branch -d "$BRANCH_NAME"
        fi

        if [ $? -ne 0 ]; then
            echo "Error: Failed to delete local branch '$BRANCH_NAME'" >&2
            echo "Hint: Use --force flag to force delete unmerged branch" >&2
            exit 1
        fi
        echo "Local branch '$BRANCH_NAME' deleted"
    else
        echo "Local branch '$BRANCH_NAME' does not exist (skipping)" >&2
    fi
fi

# Delete remote branch
if [ "$DELETE_REMOTE" = true ]; then
    # Check if remote branch exists
    if git ls-remote --heads origin "$BRANCH_NAME" | grep -q "$BRANCH_NAME"; then
        git push origin --delete "$BRANCH_NAME"

        if [ $? -ne 0 ]; then
            echo "Error: Failed to delete remote branch '$BRANCH_NAME'" >&2
            exit 12
        fi
        echo "Remote branch '$BRANCH_NAME' deleted"
    else
        echo "Remote branch '$BRANCH_NAME' does not exist (skipping)" >&2
    fi
fi

echo "Branch '$BRANCH_NAME' successfully deleted"
exit 0
