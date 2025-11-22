#!/usr/bin/env bash
#
# link-to-issue.sh - Link spec to GitHub issue via comment
#
# Usage: link-to-issue.sh <issue_number> <spec_path> [phase]
#
# Comments on GitHub issue with spec location

set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
SPEC_PATH="${2:?Spec path required}"
PHASE="${3:-}"

SPEC_FILENAME=$(basename "$SPEC_PATH")

# Get repository info from git
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")

# Parse GitHub owner/repo from remote URL
# Handles both HTTPS and SSH formats:
# - https://github.com/owner/repo.git
# - git@github.com:owner/repo.git
REPO_OWNER=""
REPO_NAME=""
if [[ -n "$REMOTE_URL" && "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "main")

# Get default branch from remote
DEFAULT_BRANCH=$(git remote show origin 2>/dev/null | grep 'HEAD branch' | cut -d' ' -f5 || echo "")
if [[ -z "$DEFAULT_BRANCH" ]]; then
    # Fallback to common defaults
    if git show-ref --verify --quiet refs/remotes/origin/main 2>/dev/null; then
        DEFAULT_BRANCH="main"
    elif git show-ref --verify --quiet refs/remotes/origin/master 2>/dev/null; then
        DEFAULT_BRANCH="master"
    else
        DEFAULT_BRANCH="main"  # Final fallback
    fi
fi

# Construct full GitHub URLs (dual-link approach)
if [[ -n "$REPO_OWNER" && -n "$REPO_NAME" ]]; then
    # Remove leading slash from spec path if present
    CLEAN_PATH="${SPEC_PATH#/}"

    # Preview link: current branch
    PREVIEW_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/blob/${CURRENT_BRANCH}/${CLEAN_PATH}"

    # Permanent link: default branch
    PERMANENT_URL="https://github.com/${REPO_OWNER}/${REPO_NAME}/blob/${DEFAULT_BRANCH}/${CLEAN_PATH}"
else
    # Fallback: use relative paths if GitHub detection fails
    PREVIEW_URL="$SPEC_PATH"
    PERMANENT_URL="$SPEC_PATH"
fi

# Build comment message with dual links
if [[ -n "$PHASE" ]]; then
    COMMENT_BODY="📋 Specification Created (Phase $PHASE)

Specification generated for this issue:
- **Preview:** [$SPEC_FILENAME]($PREVIEW_URL) (current branch: \`$CURRENT_BRANCH\`)
- **Permanent:** [$SPEC_FILENAME]($PERMANENT_URL) (after merge to \`$DEFAULT_BRANCH\`)

This spec will guide implementation and be validated before archival."
else
    COMMENT_BODY="📋 Specification Created

Specification generated for this issue:
- **Preview:** [$SPEC_FILENAME]($PREVIEW_URL) (current branch: \`$CURRENT_BRANCH\`)
- **Permanent:** [$SPEC_FILENAME]($PERMANENT_URL) (after merge to \`$DEFAULT_BRANCH\`)

This spec will guide implementation and be validated before archival."
fi

# Comment on issue
gh issue comment "$ISSUE_NUMBER" --body "$COMMENT_BODY" 2>/dev/null || {
    echo "Warning: Failed to comment on issue #$ISSUE_NUMBER" >&2
    exit 0  # Non-critical, don't fail
}

echo "GitHub comment added to issue #$ISSUE_NUMBER"
