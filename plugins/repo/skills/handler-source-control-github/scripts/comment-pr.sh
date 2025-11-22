#!/bin/bash
# Repo Manager: GitHub Comment on Pull Request
# Adds a comment to an existing pull request

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <pr_number> <comment_body>" >&2
    exit 2
fi

PR_NUMBER="$1"
COMMENT_BODY="$2"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Validate PR number
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR number must be a positive integer" >&2
    exit 2
fi

# Check if PR exists
PR_STATUS=$(gh pr view "$PR_NUMBER" --json state -q '.state' 2>&1)

if [ $? -ne 0 ]; then
    if echo "$PR_STATUS" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    elif echo "$PR_STATUS" | grep -q "not found"; then
        echo "Error: Pull request #$PR_NUMBER not found" >&2
        exit 1
    else
        echo "Error: Failed to check PR status" >&2
        echo "$PR_STATUS" >&2
        exit 1
    fi
fi

# Add comment
COMMENT_RESULT=$(gh pr comment "$PR_NUMBER" --body "$COMMENT_BODY" 2>&1)

if [ $? -ne 0 ]; then
    if echo "$COMMENT_RESULT" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to add comment to PR #$PR_NUMBER" >&2
        echo "$COMMENT_RESULT" >&2
        exit 1
    fi
fi

echo "Comment added to pull request #$PR_NUMBER"

# Show PR info
echo ""
echo "Pull request info:"
gh pr view "$PR_NUMBER" --json number,title,state,url -q '"#\(.number): \(.title)\nState: \(.state)\nURL: \(.url)"'

exit 0
