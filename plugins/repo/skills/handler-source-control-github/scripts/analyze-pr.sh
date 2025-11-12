#!/bin/bash
# Repo Manager: GitHub Analyze Pull Request
# Fetches PR details, comments, reviews, and CI status for analysis

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <pr_number>" >&2
    exit 2
fi

PR_NUMBER="$1"

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

# Fetch PR details
PR_DETAILS=$(gh pr view "$PR_NUMBER" --json \
    number,title,body,state,isDraft,url,\
    headRefName,baseRefName,\
    author,createdAt,updatedAt,\
    mergeable,reviewDecision,\
    statusCheckRollup,\
    additions,deletions,changedFiles \
    2>&1)

if [ $? -ne 0 ]; then
    if echo "$PR_DETAILS" | grep -q "authentication"; then
        echo "Error: GitHub authentication failed" >&2
        exit 11
    elif echo "$PR_DETAILS" | grep -q "not found"; then
        echo "Error: Pull request #$PR_NUMBER not found" >&2
        exit 1
    else
        echo "Error: Failed to fetch PR details" >&2
        echo "$PR_DETAILS" >&2
        exit 1
    fi
fi

# Fetch PR comments (issue comments)
PR_COMMENTS=$(gh pr view "$PR_NUMBER" --json comments -q '.comments' 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch PR comments" >&2
    exit 1
fi

# Fetch PR reviews
PR_REVIEWS=$(gh api "/repos/{owner}/{repo}/pulls/$PR_NUMBER/reviews" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch PR reviews" >&2
    exit 1
fi

# Fetch review comments (code review comments on specific lines)
PR_REVIEW_COMMENTS=$(gh api "/repos/{owner}/{repo}/pulls/$PR_NUMBER/comments" 2>&1)

if [ $? -ne 0 ]; then
    echo "Error: Failed to fetch review comments" >&2
    exit 1
fi

# Extract mergeable state and check for conflicts
MERGEABLE=$(echo "$PR_DETAILS" | jq -r '.mergeable')
HEAD_BRANCH=$(echo "$PR_DETAILS" | jq -r '.headRefName')
BASE_BRANCH=$(echo "$PR_DETAILS" | jq -r '.baseRefName')

# Initialize conflict info
CONFLICTS_DETECTED="false"
CONFLICTING_FILES="[]"
CONFLICT_DETAILS=""

# If not mergeable, try to identify conflicting files
if [ "$MERGEABLE" = "CONFLICTING" ]; then
    CONFLICTS_DETECTED="true"

    # Try to fetch the base branch and compare to find conflicts
    # Note: This requires the branches to be available locally or we fetch them
    CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")

    # Fetch latest changes (silently)
    git fetch origin "$BASE_BRANCH" 2>/dev/null || true
    git fetch origin "$HEAD_BRANCH" 2>/dev/null || true

    # Try to get a list of files that would conflict
    # We do a test merge in a safe way to identify conflicts
    CONFLICT_CHECK=$(git merge-tree "origin/$BASE_BRANCH" "origin/$HEAD_BRANCH" 2>&1 || true)

    if echo "$CONFLICT_CHECK" | grep -q "changed in both"; then
        # Extract conflicting files from merge-tree output
        CONFLICTING_FILES_LIST=$(echo "$CONFLICT_CHECK" | grep "changed in both" | sed 's/.*changed in both$//' | sed 's/^[[:space:]]*//' || echo "")

        if [ -n "$CONFLICTING_FILES_LIST" ]; then
            # Convert to JSON array
            CONFLICTING_FILES=$(echo "$CONFLICTING_FILES_LIST" | jq -R -s 'split("\n") | map(select(length > 0))')
            CONFLICT_DETAILS="Files modified in both branches require manual resolution"
        fi
    else
        # If we can't determine specific files, just note that conflicts exist
        CONFLICT_DETAILS="Merge conflicts detected. Fetch branches locally to see specific files."
    fi
fi

# Combine all data into a structured JSON response
jq -n \
    --argjson details "$PR_DETAILS" \
    --argjson comments "$PR_COMMENTS" \
    --argjson reviews "$PR_REVIEWS" \
    --argjson review_comments "$PR_REVIEW_COMMENTS" \
    --arg conflicts_detected "$CONFLICTS_DETECTED" \
    --argjson conflicting_files "$CONFLICTING_FILES" \
    --arg conflict_details "$CONFLICT_DETAILS" \
    '{
        status: "success",
        pr: {
            number: $details.number,
            title: $details.title,
            body: $details.body,
            state: $details.state,
            isDraft: $details.isDraft,
            url: $details.url,
            headRefName: $details.headRefName,
            baseRefName: $details.baseRefName,
            author: $details.author.login,
            createdAt: $details.createdAt,
            updatedAt: $details.updatedAt,
            mergeable: $details.mergeable,
            reviewDecision: $details.reviewDecision,
            statusCheckRollup: $details.statusCheckRollup,
            stats: {
                additions: $details.additions,
                deletions: $details.deletions,
                changedFiles: $details.changedFiles
            }
        },
        comments: $comments,
        reviews: $reviews,
        review_comments: $review_comments,
        conflicts: {
            detected: ($conflicts_detected == "true"),
            files: $conflicting_files,
            details: $conflict_details
        }
    }'

exit 0
