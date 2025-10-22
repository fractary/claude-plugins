#!/bin/bash
# Repo Manager: GitHub Merge Pull Request
# Merges a pull request or branch directly

set -euo pipefail

# Check arguments
if [ $# -lt 5 ]; then
    echo "Usage: $0 <source_branch> <target_branch> <strategy> <work_id> <issue_id>" >&2
    exit 2
fi

SOURCE_BRANCH="$1"
TARGET_BRANCH="$2"
STRATEGY="$3"
WORK_ID="$4"
ISSUE_ID="$5"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Validate merge strategy
case "$STRATEGY" in
    no-ff|squash|ff-only) ;;
    *)
        echo "Error: Invalid merge strategy '$STRATEGY'. Must be: no-ff, squash, or ff-only" >&2
        exit 2
        ;;
esac

# Safety check for protected branches
if [ "$TARGET_BRANCH" = "main" ] || [ "$TARGET_BRANCH" = "master" ] || [ "$TARGET_BRANCH" = "production" ]; then
    echo "Warning: Merging to protected branch: $TARGET_BRANCH" >&2
fi

# Save current branch
ORIGINAL_BRANCH=$(git rev-parse --abbrev-ref HEAD)

# Fetch latest from remote
git fetch origin

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch from origin" >&2
    exit 12
fi

# Checkout target branch
git checkout "$TARGET_BRANCH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to checkout $TARGET_BRANCH" >&2
    git checkout "$ORIGINAL_BRANCH"
    exit 1
fi

# Pull latest changes
git pull origin "$TARGET_BRANCH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to pull $TARGET_BRANCH" >&2
    git checkout "$ORIGINAL_BRANCH"
    exit 1
fi

# Perform merge based on strategy
case "$STRATEGY" in
    no-ff)
        git merge "$SOURCE_BRANCH" --no-ff -m "Merge branch '$SOURCE_BRANCH' via FABER

Resolves #$ISSUE_ID
Work ID: $WORK_ID

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        ;;
    squash)
        git merge "$SOURCE_BRANCH" --squash
        if [ $? -eq 0 ]; then
            git commit -m "Merge $SOURCE_BRANCH (squashed)

Resolves #$ISSUE_ID
Work ID: $WORK_ID

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
        fi
        ;;
    ff-only)
        git merge "$SOURCE_BRANCH" --ff-only
        ;;
esac

if [ $? -ne 0 ]; then
    echo "Error: Merge failed. There may be conflicts." >&2
    git merge --abort 2>/dev/null || true
    git checkout "$ORIGINAL_BRANCH"
    exit 13
fi

# Push merged result
git push origin "$TARGET_BRANCH"

if [ $? -ne 0 ]; then
    echo "Error: Failed to push merged $TARGET_BRANCH" >&2
    git checkout "$ORIGINAL_BRANCH"
    exit 12
fi

# Restore original branch
git checkout "$ORIGINAL_BRANCH"

echo "Successfully merged $SOURCE_BRANCH into $TARGET_BRANCH using $STRATEGY strategy"
exit 0
