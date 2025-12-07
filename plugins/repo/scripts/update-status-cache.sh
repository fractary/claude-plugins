#!/bin/bash

# Update Git Status Cache
# This script queries git status and stores it in a structured cache file
# Part of fractary-repo plugin - reduces concurrent git operations
# Safe to run concurrently (uses flock for serialization)

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"

# Check if we're in a git repository first (needed for repo path)
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}" >&2
    exit 1
fi

# Get repository root path for cache key
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Use repo-scoped cache based on repository path hash
# This ensures each repository has its own cache, shared across all sessions
# Work trees share the same .git directory, so they correctly share the cache
# Try multiple hash commands for cross-platform compatibility (md5sum=GNU, md5=BSD, shasum=fallback)
REPO_ID=$(echo "$REPO_PATH" | (md5sum 2>/dev/null || md5 2>/dev/null || shasum 2>/dev/null) | cut -d' ' -f1 | cut -c1-16 || echo "global")
CACHE_FILE="${CACHE_DIR}/status-${REPO_ID}.cache"
LOCK_FILE="${CACHE_DIR}/status-${REPO_ID}.lock"
TEMP_FILE="${CACHE_FILE}.tmp.$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure cache directory exists
mkdir -p "${CACHE_DIR}"

# Clean up old orphaned temp files (older than 1 hour)
# These can accumulate if processes crash before trap cleanup fires
find "${CACHE_DIR}" -name "status-*.cache.tmp.*" -type f -mmin +60 -delete 2>/dev/null || true

# Note: No time-based cleanup for repo-scoped caches since repositories don't expire
# Stale caches are handled by emergency refresh in read-status-cache.sh

# Parse arguments
SKIP_LOCK=false
QUIET_MODE=false
for arg in "$@"; do
    case "$arg" in
        --skip-lock)
            SKIP_LOCK=true
            ;;
        --quiet)
            QUIET_MODE=true
            ;;
    esac
done

# Acquire exclusive lock (wait up to 5 seconds, then fail)
# This ensures only one update runs at a time, preventing git lock conflicts
# Skip lock acquisition if --skip-lock flag is passed (caller already holds lock)
#
# File Descriptor 200 is used for locking throughout this script
# Assumptions:
#   - FD 200 is not used by calling scripts or processes
#   - FD 200 is available for exclusive lock coordination
#   - Lock mechanism retained for future parallel batch worker support
#
# Using <> (read-write) instead of > (write/truncate) for atomic lock file access
if [ "$SKIP_LOCK" = false ]; then
    # Open lock file atomically with read-write mode (no truncation)
    exec 200<>"${LOCK_FILE}"
    if ! flock -w 5 200; then
        if [ "$QUIET_MODE" = false ]; then
            echo -e "${RED}❌ Could not acquire lock (another update in progress)${NC}" >&2
        fi
        exit 1
    fi

    # Lock auto-releases when FD closes (on script exit)
    # Temp file cleanup on exit/interrupt
    trap "rm -f '${TEMP_FILE}' 2>/dev/null || true" EXIT
else
    # Even when skipping lock, ensure temp file cleanup on interruption
    trap "rm -f '${TEMP_FILE}' 2>/dev/null || true" EXIT
fi

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Get git status once and reuse for multiple checks (reduces git operations)
GIT_STATUS_OUTPUT=$(git status --porcelain 2>/dev/null)

# Count uncommitted changes (both staged and unstaged)
# Explicit empty check for clarity and portability (avoids grep -c fragility)
if [ -z "$GIT_STATUS_OUTPUT" ]; then
    UNCOMMITTED_CHANGES=0
else
    UNCOMMITTED_CHANGES=$(printf '%s\n' "$GIT_STATUS_OUTPUT" | wc -l)
fi

# Count untracked files
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l)

# Initialize ahead/behind counts
COMMITS_AHEAD=0
COMMITS_BEHIND=0

# Get commits ahead/behind (if remote tracking branch exists)
if git rev-parse --abbrev-ref @{u} >/dev/null 2>&1; then
    # Remote tracking branch exists
    UPSTREAM="@{u}"

    # Commits ahead (local commits not in remote)
    COMMITS_AHEAD=$(git rev-list --count ${UPSTREAM}..HEAD 2>/dev/null || echo "0")

    # Commits behind (remote commits not in local)
    COMMITS_BEHIND=$(git rev-list --count HEAD..${UPSTREAM} 2>/dev/null || echo "0")
fi

# Check for merge conflicts (reuse status output from above)
HAS_CONFLICTS=false
if echo "$GIT_STATUS_OUTPUT" | grep -q "^UU\|^AA\|^DD"; then
    HAS_CONFLICTS=true
fi

# Count stashes
STASH_COUNT=$(git stash list 2>/dev/null | wc -l)

# Determine if working tree is clean
CLEAN=false
if [ "$UNCOMMITTED_CHANGES" -eq 0 ] && [ "$UNTRACKED_FILES" -eq 0 ]; then
    CLEAN=true
fi

# Extract issue ID from branch name (if present)
# Supports patterns: feat/123-description, fix/456-bug, hotfix/789-urgent, etc.
ISSUE_ID=""
if [[ "$BRANCH" =~ ^(feat|fix|chore|hotfix|patch)/([0-9]+)- ]]; then
    ISSUE_ID="${BASH_REMATCH[2]}"
elif [[ "$BRANCH" =~ ^[a-z]+/([0-9]+) ]]; then
    # Fallback pattern: any-prefix/123
    ISSUE_ID="${BASH_REMATCH[1]}"
fi

# =============================================================================
# OPTIMIZATION: Async PR number lookup (Option 1)
# PR number is now fetched asynchronously to avoid blocking the main cache update
# Results are stored in a separate file and merged into the main cache
# =============================================================================
PR_NUMBER=""
CACHED_BRANCH=""
CACHED_PR_NUMBER=""
PR_CACHE_FILE="${CACHE_DIR}/pr-${REPO_ID}.cache"

# Read previous cache to check if branch changed
if [ -f "${CACHE_FILE}" ]; then
    CACHED_BRANCH=$(grep '"branch"' "${CACHE_FILE}" 2>/dev/null | sed -E 's/.*: *"([^"]*).*/\1/' || echo "")
    CACHED_PR_NUMBER=$(grep '"pr_number"' "${CACHE_FILE}" 2>/dev/null | sed -E 's/.*: *"([^"]*).*/\1/' || echo "")
fi

# Check if async PR lookup result is available
if [ -f "$PR_CACHE_FILE" ]; then
    PR_CACHE_BRANCH=$(grep '"branch"' "$PR_CACHE_FILE" 2>/dev/null | sed -E 's/.*: *"([^"]*).*/\1/' || echo "")
    PR_CACHE_TIMESTAMP=$(grep '"timestamp"' "$PR_CACHE_FILE" 2>/dev/null | sed -E 's/.*: *"([^"]*).*/\1/' || echo "")

    # Validate cache freshness (max 5 minutes old)
    if [ -n "$PR_CACHE_TIMESTAMP" ]; then
        CACHE_AGE_SECONDS=0
        if command -v date &> /dev/null; then
            CACHE_EPOCH=$(date -d "$PR_CACHE_TIMESTAMP" +%s 2>/dev/null || echo "0")
            NOW_EPOCH=$(date +%s)
            CACHE_AGE_SECONDS=$((NOW_EPOCH - CACHE_EPOCH))
        fi

        # Only use cache if fresh (< 300 seconds) and branch matches
        if [ "$PR_CACHE_BRANCH" = "$BRANCH" ] && [ "$CACHE_AGE_SECONDS" -lt 300 ]; then
            PR_NUMBER=$(grep '"pr_number"' "$PR_CACHE_FILE" 2>/dev/null | sed -E 's/.*: *"([^"]*).*/\1/' || echo "")
        fi
    fi
fi

# Detect if we need to refresh PR number:
# - Branch changed (new branch, need fresh lookup)
# - Same branch but no cached PR (PR may have been created since last check)
NEED_ASYNC_LOOKUP=false

if [ "$BRANCH" != "$CACHED_BRANCH" ]; then
    # Branch changed - CLEAR PR number, don't carry over from old branch
    # Fix for issue #260: Stale PR number persisted after branch switch
    # Rationale: "No PR" is better UX than "Wrong PR" - showing a PR from
    # a different branch is confusing and can interfere with PR operations
    PR_NUMBER=""

    # Also clear the PR cache file since it's for the old branch
    rm -f "$PR_CACHE_FILE" 2>/dev/null || true

    NEED_ASYNC_LOOKUP=true
elif [ -z "$CACHED_PR_NUMBER" ]; then
    # Same branch but no cached PR - PR may have been created since last check
    # Start async lookup to discover new PR
    NEED_ASYNC_LOOKUP=true
else
    # Same branch with existing PR - reuse cached PR number (fast, no network)
    PR_NUMBER="$CACHED_PR_NUMBER"
fi

# Start async PR lookup in background if needed (non-blocking)
# This writes results to PR_CACHE_FILE for next cache read
if [ "$NEED_ASYNC_LOOKUP" = true ]; then
    (
        ASYNC_PR=""
        # Try gh CLI first (fastest, most reliable)
        if command -v gh &> /dev/null; then
            ASYNC_PR=$(gh pr view --json number -q .number 2>/dev/null || echo "")
        # Fallback: use GitHub API directly (for environments without gh, like web IDE)
        elif command -v curl &> /dev/null; then
            # Extract GitHub repo from remote URL
            REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
            if [[ -n "$REMOTE_URL" ]]; then
                # Parse owner/repo from various URL formats
                GITHUB_REPO_PATH=$(echo "$REMOTE_URL" | sed -E 's|.*github\.com[:/]([^/]+/[^/]+)(\.git)?$|\1|; s|.*/git/([^/]+/[^/]+)$|\1|')

                if [[ -n "$GITHUB_REPO_PATH" ]] && [[ "$GITHUB_REPO_PATH" =~ ^[^/]+/[^/]+$ ]]; then
                    REPO_OWNER=$(echo "$GITHUB_REPO_PATH" | cut -d/ -f1)
                    API_URL="https://api.github.com/repos/${GITHUB_REPO_PATH}/pulls?head=${REPO_OWNER}:${BRANCH}&state=open"
                    ASYNC_PR=$(timeout 3 curl -s "$API_URL" 2>/dev/null | grep -o '"number":[0-9]*' | head -1 | cut -d: -f2 || echo "")
                fi
            fi
        fi

        # Write async result to PR cache file
        cat > "${PR_CACHE_FILE}.tmp" <<PREOF
{"branch": "${BRANCH}", "pr_number": "${ASYNC_PR}", "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"}
PREOF
        mv -f "${PR_CACHE_FILE}.tmp" "${PR_CACHE_FILE}" 2>/dev/null || true
    ) &
    # Disown to prevent waiting for background job
    disown 2>/dev/null || true
fi

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Extract project name from repo path (last directory component)
PROJECT_NAME=$(basename "${REPO_PATH}")

# Build JSON output
# Note: issue_id and pr_number are strings (may be empty)
cat > "${TEMP_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "repo_path": "${REPO_PATH}",
  "project_name": "${PROJECT_NAME}",
  "branch": "${BRANCH}",
  "issue_id": "${ISSUE_ID}",
  "pr_number": "${PR_NUMBER}",
  "uncommitted_changes": ${UNCOMMITTED_CHANGES},
  "untracked_files": ${UNTRACKED_FILES},
  "commits_ahead": ${COMMITS_AHEAD},
  "commits_behind": ${COMMITS_BEHIND},
  "has_conflicts": ${HAS_CONFLICTS},
  "stash_count": ${STASH_COUNT},
  "clean": ${CLEAN}
}
EOF

# Atomic move (replaces old cache file)
mv -f "${TEMP_FILE}" "${CACHE_FILE}"

# Output success message (can be silenced if called in quiet mode)
if [ "$QUIET_MODE" = false ]; then
    echo -e "${GREEN}✅ Status cache updated${NC}"
fi

exit 0
