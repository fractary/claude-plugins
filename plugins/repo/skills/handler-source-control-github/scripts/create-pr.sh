#!/bin/bash
# Repo Manager: GitHub Create Pull Request
# Creates a pull request using gh CLI

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <work_id> <branch_name> <issue_id> <title> [body]" >&2
    exit 2
fi

WORK_ID="$1"
BRANCH_NAME="$2"
ISSUE_ID="$3"
TITLE="$4"
BODY="${5:-}"

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
