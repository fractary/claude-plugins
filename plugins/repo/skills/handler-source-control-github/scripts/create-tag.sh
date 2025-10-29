#!/bin/bash
# Repo Manager: GitHub Create Tag
# Creates a Git tag (lightweight or annotated)

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <tag_name> [--message <message>] [--sign] [--ref <commit>]" >&2
    exit 2
fi

TAG_NAME="$1"
MESSAGE=""
SIGN_FLAG=""
REF="HEAD"

# Parse optional flags
shift
while [ $# -gt 0 ]; do
    case "$1" in
        --message)
            shift
            MESSAGE="$1"
            ;;
        --sign)
            SIGN_FLAG="-s"
            ;;
        --ref)
            shift
            REF="$1"
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

# Validate semantic version format (optional - allow any tag name)
if [[ "$TAG_NAME" =~ ^v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?(\+[a-zA-Z0-9.-]+)?$ ]]; then
    echo "Creating semantic version tag: $TAG_NAME"
elif [[ "$TAG_NAME" =~ ^v ]]; then
    echo "Warning: Tag name starts with 'v' but doesn't follow semantic versioning" >&2
fi

# Check if tag already exists
if git rev-parse --verify "refs/tags/$TAG_NAME" > /dev/null 2>&1; then
    echo "Error: Tag '$TAG_NAME' already exists" >&2
    exit 10
fi

# Verify reference exists
if ! git rev-parse --verify "$REF" > /dev/null 2>&1; then
    echo "Error: Reference '$REF' does not exist" >&2
    exit 1
fi

# Create tag
if [ -n "$MESSAGE" ]; then
    # Annotated tag
    if [ -n "$SIGN_FLAG" ]; then
        # Signed annotated tag
        git tag -a $SIGN_FLAG -m "$MESSAGE" "$TAG_NAME" "$REF"
    else
        # Unsigned annotated tag
        git tag -a -m "$MESSAGE" "$TAG_NAME" "$REF"
    fi

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create annotated tag '$TAG_NAME'" >&2
        exit 1
    fi

    echo "Annotated tag '$TAG_NAME' created at $REF"
    if [ -n "$SIGN_FLAG" ]; then
        echo "Tag is GPG signed"
    fi
else
    # Lightweight tag
    if [ -n "$SIGN_FLAG" ]; then
        echo "Warning: --sign flag requires --message (creating unsigned lightweight tag)" >&2
    fi

    git tag "$TAG_NAME" "$REF"

    if [ $? -ne 0 ]; then
        echo "Error: Failed to create lightweight tag '$TAG_NAME'" >&2
        exit 1
    fi

    echo "Lightweight tag '$TAG_NAME' created at $REF"
fi

# Show tag details
echo ""
echo "Tag details:"
git show "$TAG_NAME" --no-patch --format="Tag: %D%nCommit: %H%nAuthor: %an <%ae>%nDate: %ai%nMessage: %s"

exit 0
