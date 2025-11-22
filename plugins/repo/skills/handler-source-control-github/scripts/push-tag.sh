#!/bin/bash
# Repo Manager: GitHub Push Tag
# Pushes a tag to remote repository

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <tag_name|--all> [--force]" >&2
    exit 2
fi

TAG_NAME="$1"
FORCE_FLAG=""

# Parse optional flags
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --force)
            FORCE_FLAG="--force"
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

# Check if remote 'origin' exists
if ! git remote get-url origin > /dev/null 2>&1; then
    echo "Error: No remote 'origin' configured" >&2
    exit 12
fi

# Push tags
if [ "$TAG_NAME" = "--all" ]; then
    # Push all tags
    if [ -n "$FORCE_FLAG" ]; then
        echo "Warning: Force pushing ALL tags to remote" >&2
    fi

    git push origin --tags $FORCE_FLAG

    if [ $? -ne 0 ]; then
        echo "Error: Failed to push tags to origin" >&2
        exit 12
    fi

    echo "All tags pushed to origin"
else
    # Push specific tag
    # Verify tag exists locally
    if ! git rev-parse --verify "refs/tags/$TAG_NAME" > /dev/null 2>&1; then
        echo "Error: Tag '$TAG_NAME' does not exist locally" >&2
        exit 1
    fi

    # Check if tag already exists on remote
    if git ls-remote --tags origin | grep -q "refs/tags/$TAG_NAME$"; then
        if [ -z "$FORCE_FLAG" ]; then
            echo "Error: Tag '$TAG_NAME' already exists on remote" >&2
            echo "Hint: Use --force flag to overwrite remote tag" >&2
            exit 10
        else
            echo "Warning: Overwriting existing remote tag '$TAG_NAME'" >&2
        fi
    fi

    # Push tag
    git push origin "refs/tags/$TAG_NAME" $FORCE_FLAG

    if [ $? -ne 0 ]; then
        echo "Error: Failed to push tag '$TAG_NAME' to origin" >&2
        exit 12
    fi

    echo "Tag '$TAG_NAME' pushed to origin"
fi

# Show remote tags
echo ""
echo "Remote tags:"
git ls-remote --tags origin | tail -5

exit 0
