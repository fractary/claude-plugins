#!/bin/bash
# Repo Manager: GitHub Review Pull Request
# Submits a review on a pull request
#
# Usage (preferred - environment variables):
#   REVIEW_PR_NUMBER="..." REVIEW_TYPE="..." [REVIEW_BODY="..."] ./review-pr.sh
#
# Usage (legacy - positional arguments):
#   review-pr.sh <pr_number> <review_type> [review_body]
#
# Environment Variables (preferred for special characters):
#   REVIEW_PR_NUMBER - PR number to review (required)
#   REVIEW_TYPE      - Review type: approve, request-changes, comment (required)
#   REVIEW_BODY      - Review comment in markdown (optional)
#
# Note: Environment variables take precedence over positional arguments.
#       Use environment variables when parameters contain special characters
#       (commas, quotes, backticks, newlines, etc.) to avoid shell escaping issues.

set -euo pipefail

# Read from environment variables first, fall back to positional arguments
PR_NUMBER="${REVIEW_PR_NUMBER:-${1:-}}"
REVIEW_TYPE="${REVIEW_TYPE:-${2:-}}"
REVIEW_BODY="${REVIEW_BODY:-${3:-}}"

# Check required parameters
if [ -z "$PR_NUMBER" ] || [ -z "$REVIEW_TYPE" ]; then
    echo "Error: Missing required parameters. Set REVIEW_PR_NUMBER and REVIEW_TYPE environment variables, or pass as positional arguments." >&2
    echo "Review types: approve, request-changes, comment" >&2
    exit 2
fi

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

# Validate review type
case "$REVIEW_TYPE" in
    approve|request-changes|comment) ;;
    *)
        echo "Error: Invalid review type '$REVIEW_TYPE'" >&2
        echo "Valid types: approve, request-changes, comment" >&2
        exit 2
        ;;
esac

# Check if PR exists
PR_STATUS=$(gh pr view "$PR_NUMBER" --json state,isDraft -q '{state: .state, isDraft: .isDraft}' 2>&1)

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

# Check if PR is in draft state
IS_DRAFT=$(echo "$PR_STATUS" | grep -o '"isDraft":[^,}]*' | cut -d':' -f2)
if [ "$IS_DRAFT" = "true" ] && [ "$REVIEW_TYPE" = "approve" ]; then
    echo "Warning: Cannot approve draft pull request" >&2
    echo "Hint: Mark PR as ready for review first" >&2
    exit 1
fi

# Submit review
if [ -z "$REVIEW_BODY" ]; then
    # Review without body
    REVIEW_RESULT=$(gh pr review "$PR_NUMBER" --$REVIEW_TYPE 2>&1)
else
    # Review with body
    REVIEW_RESULT=$(gh pr review "$PR_NUMBER" --$REVIEW_TYPE --body "$REVIEW_BODY" 2>&1)
fi

if [ $? -ne 0 ]; then
    if echo "$REVIEW_RESULT" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    elif echo "$REVIEW_RESULT" | grep -q "already reviewed"; then
        echo "Error: You have already reviewed this PR" >&2
        echo "Hint: Submit a new comment instead" >&2
        exit 1
    else
        echo "Error: Failed to submit review on PR #$PR_NUMBER" >&2
        echo "$REVIEW_RESULT" >&2
        exit 1
    fi
fi

# Format review type for output
case "$REVIEW_TYPE" in
    approve)
        REVIEW_ACTION="approved"
        ;;
    request-changes)
        REVIEW_ACTION="requested changes on"
        ;;
    comment)
        REVIEW_ACTION="commented on"
        ;;
esac

echo "Successfully $REVIEW_ACTION pull request #$PR_NUMBER"

# Show PR info
echo ""
echo "Pull request info:"
gh pr view "$PR_NUMBER" --json number,title,state,url,reviewDecision -q '"#\(.number): \(.title)\nState: \(.state)\nReview Decision: \(.reviewDecision // "NONE")\nURL: \(.url)"'

exit 0
