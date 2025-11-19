#!/bin/bash
# Repo Manager: GitHub Merge Pull Request
# Merges a pull request using GitHub CLI

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <pr_number> <strategy> [delete_branch]" >&2
    echo "  pr_number: Pull request number (e.g., 123)" >&2
    echo "  strategy: Merge strategy (merge|squash|rebase)" >&2
    echo "  delete_branch: Delete branch after merge (true|false, default: false)" >&2
    exit 2
fi

PR_NUMBER="$1"
STRATEGY="$2"
DELETE_BRANCH="${3:-false}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: GitHub CLI (gh) is not installed" >&2
    exit 3
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed (required for JSON parsing)" >&2
    exit 3
fi

# Validate PR number
if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Invalid PR number '$PR_NUMBER'. Must be a positive integer" >&2
    exit 2
fi

# Validate merge strategy
# Note: The command uses 'no-ff', 'squash', 'ff-only' but gh CLI uses 'merge', 'squash', 'rebase'
# Map the strategies appropriately
GH_STRATEGY="$STRATEGY"
case "$STRATEGY" in
    no-ff|merge)
        GH_STRATEGY="merge"
        ;;
    squash)
        GH_STRATEGY="squash"
        ;;
    ff-only|rebase)
        GH_STRATEGY="rebase"
        ;;
    *)
        echo "Error: Invalid merge strategy '$STRATEGY'. Must be one of: merge, no-ff, squash, rebase, ff-only" >&2
        exit 2
        ;;
esac

# Check if PR exists and is mergeable
if ! PR_STATE=$(gh pr view "$PR_NUMBER" --json state,mergeable,isDraft --jq '{state: .state, mergeable: .mergeable, isDraft: .isDraft}' 2>&1); then
    echo "Error: Pull request #$PR_NUMBER not found" >&2
    echo "$PR_STATE" >&2
    exit 1
fi

# Parse PR state
STATE=$(echo "$PR_STATE" | jq -r '.state')
MERGEABLE=$(echo "$PR_STATE" | jq -r '.mergeable')
IS_DRAFT=$(echo "$PR_STATE" | jq -r '.isDraft')

# Validate PR state
if [ "$STATE" != "OPEN" ]; then
    echo "Error: Pull request #$PR_NUMBER is not open (state: $STATE)" >&2
    exit 1
fi

if [ "$IS_DRAFT" = "true" ]; then
    echo "Error: Pull request #$PR_NUMBER is a draft. Convert to ready for review first" >&2
    exit 1
fi

if [ "$MERGEABLE" = "CONFLICTING" ]; then
    echo "Error: Pull request #$PR_NUMBER has merge conflicts that must be resolved first" >&2
    exit 13
fi

if [ "$MERGEABLE" = "UNKNOWN" ]; then
    echo "Error: Pull request #$PR_NUMBER merge status is unknown" >&2
    echo "GitHub is still computing mergability. Please wait a moment and try again." >&2
    exit 1
fi

# Build gh pr merge command
GH_CMD="gh pr merge $PR_NUMBER --$GH_STRATEGY"

# Add delete-branch flag if requested
if [ "$DELETE_BRANCH" = "true" ]; then
    GH_CMD="$GH_CMD --delete-branch"
fi

# Execute merge
echo "Merging PR #$PR_NUMBER using strategy: $GH_STRATEGY" >&2
if [ "$DELETE_BRANCH" = "true" ]; then
    echo "Branch will be deleted after merge" >&2
fi

# Capture output and exit code
if ! MERGE_OUTPUT=$($GH_CMD 2>&1); then
    echo "Error: Failed to merge PR #$PR_NUMBER" >&2
    echo "$MERGE_OUTPUT" >&2

    # Check for specific error conditions
    if echo "$MERGE_OUTPUT" | grep -q "not satisfy the required approvals"; then
        exit 15  # Review requirements not met
    elif echo "$MERGE_OUTPUT" | grep -q "required status checks"; then
        exit 14  # CI checks failing
    elif echo "$MERGE_OUTPUT" | grep -q "conflicts"; then
        exit 13  # Merge conflicts
    else
        exit 1   # General error
    fi
fi

# Get merge commit SHA reliably using gh pr view
MERGE_SHA=$(gh pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || echo "")

# Output success message
echo "Successfully merged PR #$PR_NUMBER using $GH_STRATEGY strategy" >&2
if [ -n "$MERGE_SHA" ]; then
    echo "Merge SHA: $MERGE_SHA" >&2
fi
if [ "$DELETE_BRANCH" = "true" ]; then
    echo "Branch deleted" >&2
fi

# Output JSON response for parsing by skill
cat <<EOF
{
  "status": "success",
  "pr_number": $PR_NUMBER,
  "strategy": "$GH_STRATEGY",
  "merge_sha": "${MERGE_SHA:-unknown}",
  "branch_deleted": $DELETE_BRANCH
}
EOF

exit 0
