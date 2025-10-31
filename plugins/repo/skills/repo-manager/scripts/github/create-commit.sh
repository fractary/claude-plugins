#!/bin/bash
# Repo Manager: GitHub Create Commit
# Creates a semantic commit with FABER metadata

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <work_id> <author> <issue_id> <work_type> [message]" >&2
    exit 2
fi

WORK_ID="$1"
AUTHOR="$2"
ISSUE_ID="$3"
WORK_TYPE="$4"
CUSTOM_MESSAGE="${5:-}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Determine commit type prefix
case "$WORK_TYPE" in
    /feature|feature)
        TYPE="feat"
        ;;
    /bug|bug)
        TYPE="fix"
        ;;
    /chore|chore)
        TYPE="chore"
        ;;
    /patch|patch|hotfix)
        TYPE="hotfix"
        ;;
    *)
        TYPE="feat"
        ;;
esac

# Generate commit message
if [ -n "$CUSTOM_MESSAGE" ]; then
    COMMIT_MSG="$TYPE: $CUSTOM_MESSAGE"
else
    # Default message based on author
    case "$AUTHOR" in
        architect)
            COMMIT_MSG="$TYPE: Add specification for issue #$ISSUE_ID"
            ;;
        implementor)
            COMMIT_MSG="$TYPE: Implement changes for issue #$ISSUE_ID"
            ;;
        tester)
            COMMIT_MSG="$TYPE: Add tests for issue #$ISSUE_ID"
            ;;
        reviewer)
            COMMIT_MSG="$TYPE: Review and refine for issue #$ISSUE_ID"
            ;;
        *)
            COMMIT_MSG="$TYPE: Updates for issue #$ISSUE_ID"
            ;;
    esac
fi

# Create full commit message with metadata
FULL_COMMIT_MSG="$COMMIT_MSG

Refs: #$ISSUE_ID
Work-ID: $WORK_ID
Author: $AUTHOR

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"

# Create commit
git commit -m "$FULL_COMMIT_MSG"

if [ $? -ne 0 ]; then
    echo "Error: Failed to create commit" >&2
    exit 1
fi

# Get commit SHA
COMMIT_SHA=$(git rev-parse HEAD)

# Output commit SHA
echo "$COMMIT_SHA"
exit 0
