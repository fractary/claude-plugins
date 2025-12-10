#!/bin/bash
# Repo Manager: GitHub Create Pull Request
# Creates a pull request using gh CLI
#
# Usage (preferred - environment variables):
#   PR_WORK_ID="..." PR_BRANCH_NAME="..." PR_ISSUE_ID="..." PR_TITLE="..." [PR_BODY="..."] ./create-pr.sh
#
# Usage (legacy - positional arguments):
#   create-pr.sh <work_id> <branch_name> <issue_id> <title> [body]
#
# Environment Variables (preferred for special characters):
#   PR_WORK_ID     - Work item ID (required)
#   PR_BRANCH_NAME - Branch name for the PR (required)
#   PR_ISSUE_ID    - Issue ID to link (required)
#   PR_TITLE       - PR title (required)
#   PR_BODY        - PR body/description in markdown (optional)
#
# Note: Environment variables take precedence over positional arguments.
#       Use environment variables when parameters contain special characters
#       (commas, quotes, backticks, newlines, etc.) to avoid shell escaping issues.

set -euo pipefail

# Read from environment variables first, fall back to positional arguments
WORK_ID="${PR_WORK_ID:-${1:-}}"
BRANCH_NAME="${PR_BRANCH_NAME:-${2:-}}"
ISSUE_ID="${PR_ISSUE_ID:-${3:-}}"
TITLE="${PR_TITLE:-${4:-}}"
BODY="${PR_BODY:-${5:-}}"

# Check required parameters
if [ -z "$WORK_ID" ] || [ -z "$BRANCH_NAME" ] || [ -z "$ISSUE_ID" ] || [ -z "$TITLE" ]; then
    echo "Error: Missing required parameters. Set PR_WORK_ID, PR_BRANCH_NAME, PR_ISSUE_ID, and PR_TITLE environment variables, or pass as positional arguments." >&2
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

# Build PR body
if [ -z "$BODY" ]; then
    PR_BODY="## Summary

Changes for issue #$ISSUE_ID

## Related

- Closes #$ISSUE_ID
- Work ID: \`$WORK_ID\`

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)"
else
    PR_BODY="$BODY

## Related

- Closes #$ISSUE_ID
- Work ID: \`$WORK_ID\`

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)"
fi

# Create pull request
pr_url=$(gh pr create \
    --head "$BRANCH_NAME" \
    --title "$TITLE" \
    --body "$PR_BODY" \
    2>&1)

if [ $? -ne 0 ]; then
    if echo "$pr_url" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to create pull request" >&2
        echo "$pr_url" >&2
        exit 1
    fi
fi

# Extract PR URL from output (gh pr create outputs the URL)
# The gh CLI typically outputs the URL on a separate line
PR_URL=$(echo "$pr_url" | grep -oE 'https://github\.com/[^/]+/[^/]+/pull/[0-9]+' | head -1)

if [ -z "$PR_URL" ]; then
    echo "Error: Failed to extract PR URL from gh output" >&2
    echo "Raw output: $pr_url" >&2
    exit 1
fi

# Output PR URL - this MUST always be a valid GitHub PR URL
echo "$PR_URL"
exit 0
