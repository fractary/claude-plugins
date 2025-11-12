#!/bin/bash

# Update Git Status Cache
# This script queries git status and stores it in a structured cache file
# Part of fractary-repo plugin - reduces concurrent git operations
# Safe to run concurrently (uses flock for serialization)

set -euo pipefail

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"
LOCK_FILE="${CACHE_DIR}/status.lock"
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
find "${CACHE_DIR}" -name "status.cache.tmp.*" -type f -mmin +60 -delete 2>/dev/null || true

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
# File Descriptor 200 is used for locking throughout this script and auto-commit-on-stop.sh
# Assumptions:
#   - FD 200 is not used by calling scripts or processes
#   - FD 200 is available for exclusive lock coordination
#   - Same FD number must be used across all scripts sharing this lock
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

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}" >&2
    exit 1
fi

# Get repository root path
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

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

# Get PR number if PR exists for current branch
# Use gh CLI if available (fast, ~100-200ms)
PR_NUMBER=""
if command -v gh &> /dev/null; then
    PR_NUMBER=$(gh pr view --json number -q .number 2>/dev/null || echo "")
fi

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON output
# Note: issue_id and pr_number are strings (may be empty)
cat > "${TEMP_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "repo_path": "${REPO_PATH}",
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
