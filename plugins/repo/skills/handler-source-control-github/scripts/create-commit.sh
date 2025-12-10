#!/bin/bash
# Repo Manager: GitHub Create Commit
# Creates a semantic commit following Conventional Commits + optional FABER metadata
#
# Usage (preferred - environment variables):
#   COMMIT_MESSAGE="message" COMMIT_TYPE="feat" [COMMIT_WORK_ID="..."] [COMMIT_AUTHOR_CONTEXT="..."] [COMMIT_DESCRIPTION="..."] ./create-commit.sh
#
# Usage (legacy - positional arguments):
#   create-commit.sh <message> <type> [work_id] [author_context] [description]
#
# Environment Variables (preferred for special characters):
#   COMMIT_MESSAGE        - Commit message summary (required)
#   COMMIT_TYPE           - Commit type: feat|fix|chore|docs|test|refactor|style|perf (required)
#   COMMIT_WORK_ID        - Work item reference e.g., "#123", "PROJ-456" (optional)
#   COMMIT_AUTHOR_CONTEXT - FABER context: architect|implementor|tester|reviewer (optional)
#   COMMIT_DESCRIPTION    - Extended commit body description (optional)
#
# Note: Environment variables take precedence over positional arguments.
#       Use environment variables when parameters contain special characters
#       (commas, quotes, backticks, newlines, etc.) to avoid shell escaping issues.
#
# Output: JSON with status, commit_sha, message, work_id

set -euo pipefail

# Read from environment variables first, fall back to positional arguments
MESSAGE="${COMMIT_MESSAGE:-${1:-}}"
TYPE="${COMMIT_TYPE:-${2:-}}"
WORK_ID="${COMMIT_WORK_ID:-${3:-}}"
AUTHOR_CONTEXT="${COMMIT_AUTHOR_CONTEXT:-${4:-}}"
DESCRIPTION="${COMMIT_DESCRIPTION:-${5:-}}"

# Check required parameters
if [ -z "$MESSAGE" ] || [ -z "$TYPE" ]; then
    echo '{"status": "failure", "error": "Missing required parameters. Set COMMIT_MESSAGE and COMMIT_TYPE environment variables, or pass as positional arguments.", "error_code": 2}' >&2
    exit 2
fi

# Validate commit type
VALID_TYPES="feat fix chore docs test refactor style perf hotfix"
if ! echo "$VALID_TYPES" | grep -qw "$TYPE"; then
    # Use jq for safe JSON output if available, otherwise use simple escaping
    if command -v jq &> /dev/null; then
        jq -n --arg type "$TYPE" --arg valid "$VALID_TYPES" \
            '{"status": "failure", "error": ("Invalid commit type: " + $type + ". Valid types: " + $valid), "error_code": 2}' >&2
    else
        SAFE_TYPE=$(printf '%s' "$TYPE" | sed 's/["\]/\\&/g')
        echo "{\"status\": \"failure\", \"error\": \"Invalid commit type: $SAFE_TYPE. Valid types: $VALID_TYPES\", \"error_code\": 2}" >&2
    fi
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
        if command -v jq &> /dev/null; then
            jq -n --arg sha "$CURRENT_SHA" \
                '{"status": "success", "message": "No changes to commit - working directory is clean", "commit_sha": $sha, "skipped": true}'
        else
            echo "{\"status\": \"success\", \"message\": \"No changes to commit - working directory is clean\", \"commit_sha\": \"$CURRENT_SHA\", \"skipped\": true}"
        fi
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

# Create commit using stdin to handle special characters safely
# Using -F - reads from stdin, avoiding shell escaping issues with -m
if ! printf '%s' "$FULL_COMMIT_MSG" | git commit -F - 2>/dev/null; then
    echo '{"status": "failure", "error": "Failed to create commit", "error_code": 1}' >&2
    exit 1
fi

# Get commit SHA
COMMIT_SHA=$(git rev-parse HEAD)

# Output success JSON with proper escaping
# Use jq if available for reliable JSON escaping, otherwise fall back to sed
if command -v jq &> /dev/null; then
    jq -n \
        --arg status "success" \
        --arg sha "$COMMIT_SHA" \
        --arg msg "$COMMIT_HEADER" \
        --arg work_id "$WORK_ID" \
        '{"status": $status, "commit_sha": $sha, "message": $msg, "work_id": $work_id}'
else
    # Fallback: escape quotes, backslashes, and control characters
    escape_json() {
        printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e 's/	/\\t/g' | tr -d '\n\r'
    }
    ESCAPED_MESSAGE=$(escape_json "$COMMIT_HEADER")
    ESCAPED_WORK_ID=$(escape_json "$WORK_ID")
    echo "{\"status\": \"success\", \"commit_sha\": \"$COMMIT_SHA\", \"message\": \"$ESCAPED_MESSAGE\", \"work_id\": \"$ESCAPED_WORK_ID\"}"
fi
exit 0
