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
# This mapping is intentional to maintain consistency with git terminology while using gh CLI
# The script handles this mapping automatically - no manual intervention needed
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
if ! PR_STATE=$(gh pr view "$PR_NUMBER" --json state,mergeable,isDraft,autoMergeRequest --jq '{state: .state, mergeable: .mergeable, isDraft: .isDraft, autoMerge: .autoMergeRequest}' 2>&1); then
    echo "Error: Pull request #$PR_NUMBER not found" >&2
    echo "$PR_STATE" >&2
    exit 1
fi

# Parse PR state
STATE=$(echo "$PR_STATE" | jq -r '.state')
MERGEABLE=$(echo "$PR_STATE" | jq -r '.mergeable')
IS_DRAFT=$(echo "$PR_STATE" | jq -r '.isDraft')
AUTO_MERGE=$(echo "$PR_STATE" | jq -r '.autoMerge')

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

# Check for auto-merge
if [ "$AUTO_MERGE" != "null" ] && [ -n "$AUTO_MERGE" ]; then
    echo "Warning: Pull request #$PR_NUMBER has auto-merge enabled" >&2
    echo "The PR will be automatically merged when requirements are met" >&2
    echo "Manual merge may conflict with auto-merge settings" >&2
fi

# Build gh pr merge command as array for proper quoting
GH_CMD=(gh pr merge "$PR_NUMBER" "--$GH_STRATEGY")

# Add delete-branch flag if requested
if [ "$DELETE_BRANCH" = "true" ]; then
    GH_CMD+=(--delete-branch)
fi

# Execute merge
echo "Merging PR #$PR_NUMBER using strategy: $GH_STRATEGY" >&2
if [ "$DELETE_BRANCH" = "true" ]; then
    echo "Branch will be deleted after merge" >&2
fi

# Proactively check merge requirements before attempting merge
# This provides better error detection than parsing error messages
echo "Checking merge requirements..." >&2
MERGE_REQS=$(gh pr view "$PR_NUMBER" --json reviewDecision,statusCheckRollup 2>/dev/null)
REVIEW_DECISION=$(echo "$MERGE_REQS" | jq -r '.reviewDecision // "null"')
STATUS_CHECKS=$(echo "$MERGE_REQS" | jq -r '.statusCheckRollup // [] | map(select(.conclusion != "SUCCESS")) | length')

# Check review requirements
if [ "$REVIEW_DECISION" = "CHANGES_REQUESTED" ]; then
    echo "Error: Pull request #$PR_NUMBER has requested changes that must be addressed" >&2
    exit 15  # Review requirements not met
fi

# Check CI status
if [ "$STATUS_CHECKS" != "0" ] && [ "$STATUS_CHECKS" != "null" ]; then
    echo "Error: Pull request #$PR_NUMBER has failing status checks" >&2
    exit 14  # CI checks failing
fi

# Capture output and exit code with timeout protection (120s for large PRs)
# Use array execution with proper quoting to prevent command injection
if ! MERGE_OUTPUT=$(timeout 120 "${GH_CMD[@]}" 2>&1); then
    TIMEOUT_EXIT=$?

    # Check if command timed out (exit code 124)
    if [ $TIMEOUT_EXIT -eq 124 ]; then
        echo "Error: Merge operation timed out after 120 seconds" >&2
        echo "This may indicate a slow GitHub API response or a very large PR" >&2
        echo "Please wait a moment and try again, or check PR status manually" >&2
        exit 12  # Network/timeout error
    fi

    # Merge failed - report error with output
    echo "Error: Failed to merge PR #$PR_NUMBER" >&2
    echo "$MERGE_OUTPUT" >&2

    # Fallback error message parsing for any issues we didn't catch proactively
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

# Get merge commit SHA reliably using gh pr view with retry loop
# GitHub API may not have updated immediately after merge, so retry with delays
MERGE_SHA=""
for attempt in 1 2 3; do
    MERGE_SHA=$(gh pr view "$PR_NUMBER" --json mergeCommit --jq '.mergeCommit.oid' 2>/dev/null || echo "")

    # If we got a SHA (not empty and not "null"), we're done
    if [ -n "$MERGE_SHA" ] && [ "$MERGE_SHA" != "null" ]; then
        break
    fi

    # If this isn't the last attempt, wait before retrying
    if [ $attempt -lt 3 ]; then
        echo "Waiting for GitHub API to update (attempt $attempt/3)..." >&2
        sleep 1
    fi
done

# If we still don't have a SHA after retries, that's okay - set to unknown
if [ -z "$MERGE_SHA" ] || [ "$MERGE_SHA" = "null" ]; then
    MERGE_SHA="unknown"
fi

# Output success message
echo "Successfully merged PR #$PR_NUMBER using $GH_STRATEGY strategy" >&2
if [ -n "$MERGE_SHA" ]; then
    echo "Merge SHA: $MERGE_SHA" >&2
fi
if [ "$DELETE_BRANCH" = "true" ]; then
    echo "Branch deleted" >&2
fi

# =============================================================================
# Clear PR from status cache since the PR is now merged
# Fix for issue #260: Stale PR number persisted after merge
# This proactively clears the cache so users don't see the old PR number
# even if they stay on the same branch after merging
# =============================================================================
CACHE_DIR="${HOME}/.fractary/repo"
if [ -d "$CACHE_DIR" ]; then
    REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
    REPO_ID=$(echo "$REPO_PATH" | (md5sum 2>/dev/null || md5 2>/dev/null || shasum 2>/dev/null) | cut -d' ' -f1 | cut -c1-16 || echo "global")
    CACHE_FILE="${CACHE_DIR}/status-${REPO_ID}.cache"
    PR_CACHE_FILE="${CACHE_DIR}/pr-${REPO_ID}.cache"

    # Clear PR from main status cache (use temp file for atomic update)
    if [ -f "$CACHE_FILE" ]; then
        TEMP_CACHE="${CACHE_FILE}.tmp.$$"
        if sed 's/"pr_number": "[^"]*"/"pr_number": ""/' "$CACHE_FILE" > "$TEMP_CACHE" 2>/dev/null; then
            mv -f "$TEMP_CACHE" "$CACHE_FILE" 2>/dev/null || rm -f "$TEMP_CACHE" 2>/dev/null
        else
            rm -f "$TEMP_CACHE" 2>/dev/null
        fi
    fi

    # Clear PR cache file entirely
    rm -f "$PR_CACHE_FILE" 2>/dev/null || true

    echo "Status cache cleared (PR merged)" >&2
fi

# Output JSON response for parsing by skill
# Convert bash string boolean to proper JSON boolean
BRANCH_DELETED_JSON=$([ "$DELETE_BRANCH" = "true" ] && echo "true" || echo "false")

cat <<EOF
{
  "status": "success",
  "pr_number": $PR_NUMBER,
  "strategy": "$GH_STRATEGY",
  "merge_sha": "${MERGE_SHA:-unknown}",
  "branch_deleted": $BRANCH_DELETED_JSON
}
EOF

exit 0
