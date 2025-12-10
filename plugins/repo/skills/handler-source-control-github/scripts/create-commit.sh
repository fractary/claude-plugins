#!/bin/bash
# Repo Manager: GitHub Create Commit
# Creates a semantic commit following Conventional Commits + optional FABER metadata
#
# Usage: create-commit.sh <message> <type> [work_id] [author_context] [description]
#
# Parameters:
#   message        - Commit message summary (required)
#   type           - Commit type: feat|fix|chore|docs|test|refactor|style|perf (required)
#   work_id        - Work item reference e.g., "#123", "PROJ-456" (optional)
#   author_context - FABER context: architect|implementor|tester|reviewer (optional)
#   description    - Extended commit body description (optional)
#
# Output: JSON with status, commit_sha, message, work_id

set -euo pipefail

# Check minimum arguments
if [ $# -lt 2 ]; then
    echo '{"status": "failure", "error": "Usage: create-commit.sh <message> <type> [work_id] [author_context] [description]", "error_code": 2}' >&2
    exit 2
fi

MESSAGE="$1"
TYPE="$2"
WORK_ID="${3:-}"
AUTHOR_CONTEXT="${4:-}"
DESCRIPTION="${5:-}"

# Validate commit type
VALID_TYPES="feat fix chore docs test refactor style perf hotfix"
if ! echo "$VALID_TYPES" | grep -qw "$TYPE"; then
    echo "{\"status\": \"failure\", \"error\": \"Invalid commit type: $TYPE. Valid types: $VALID_TYPES\", \"error_code\": 2}" >&2
    exit 2
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo '{"status": "failure", "error": "Not in a git repository", "error_code": 3}' >&2
    exit 3
fi

# Check for changes to commit
if git diff --cached --quiet 2>/dev/null; then
    # Nothing staged, check if there are unstaged changes
    if git diff --quiet 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        # Working directory is clean - this is success (idempotent behavior)
        CURRENT_SHA=$(git rev-parse HEAD 2>/dev/null || echo "none")
        echo "{\"status\": \"success\", \"message\": \"No changes to commit - working directory is clean\", \"commit_sha\": \"$CURRENT_SHA\", \"skipped\": true}"
        exit 0
    fi
    # Stage all changes
    git add .
fi

# Build commit message header
COMMIT_HEADER="$TYPE: $MESSAGE"

# Build commit body
COMMIT_BODY=""

# Add description if provided
if [ -n "$DESCRIPTION" ]; then
    COMMIT_BODY="$DESCRIPTION"
fi

# Add FABER metadata section if any metadata provided
METADATA=""
if [ -n "$WORK_ID" ]; then
    METADATA="${METADATA}Work-Item: $WORK_ID"$'\n'
fi
if [ -n "$AUTHOR_CONTEXT" ]; then
    METADATA="${METADATA}Author-Context: $AUTHOR_CONTEXT"$'\n'
fi

# Build full commit message
if [ -n "$COMMIT_BODY" ] && [ -n "$METADATA" ]; then
    FULL_COMMIT_MSG="$COMMIT_HEADER

$COMMIT_BODY

$METADATA
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
elif [ -n "$COMMIT_BODY" ]; then
    FULL_COMMIT_MSG="$COMMIT_HEADER

$COMMIT_BODY

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
elif [ -n "$METADATA" ]; then
    FULL_COMMIT_MSG="$COMMIT_HEADER

$METADATA
🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
else
    FULL_COMMIT_MSG="$COMMIT_HEADER

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>"
fi

# Create commit
if ! git commit -m "$FULL_COMMIT_MSG" 2>/dev/null; then
    echo '{"status": "failure", "error": "Failed to create commit", "error_code": 1}' >&2
    exit 1
fi

# Get commit SHA
COMMIT_SHA=$(git rev-parse HEAD)

# Output success JSON
# Escape message for JSON
ESCAPED_MESSAGE=$(echo "$COMMIT_HEADER" | sed 's/"/\\"/g')
ESCAPED_WORK_ID=$(echo "$WORK_ID" | sed 's/"/\\"/g')

echo "{\"status\": \"success\", \"commit_sha\": \"$COMMIT_SHA\", \"message\": \"$ESCAPED_MESSAGE\", \"work_id\": \"$ESCAPED_WORK_ID\"}"
exit 0
