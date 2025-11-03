#!/bin/bash

# Update Git Status Cache
# This script queries git status and stores it in a structured cache file
# Part of fractary-repo plugin - reduces concurrent git operations
# Safe to run concurrently (uses atomic writes)

set -e

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"
TEMP_FILE="${CACHE_FILE}.tmp.$$"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure cache directory exists
mkdir -p "${CACHE_DIR}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}" >&2
    exit 1
fi

# Get repository root path
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)

# Get current branch
BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")

# Count uncommitted changes (both staged and unstaged)
UNCOMMITTED_CHANGES=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')

# Count untracked files
UNTRACKED_FILES=$(git ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')

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

# Check for merge conflicts
HAS_CONFLICTS=false
if git status --porcelain 2>/dev/null | grep -q "^UU\|^AA\|^DD"; then
    HAS_CONFLICTS=true
fi

# Count stashes
STASH_COUNT=$(git stash list 2>/dev/null | wc -l | tr -d ' ')

# Determine if working tree is clean
CLEAN=false
if [ "$UNCOMMITTED_CHANGES" -eq 0 ] && [ "$UNTRACKED_FILES" -eq 0 ]; then
    CLEAN=true
fi

# Get current timestamp in ISO 8601 format
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Build JSON output
cat > "${TEMP_FILE}" <<EOF
{
  "timestamp": "${TIMESTAMP}",
  "repo_path": "${REPO_PATH}",
  "branch": "${BRANCH}",
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
if [ "${1}" != "--quiet" ]; then
    echo -e "${GREEN}✅ Status cache updated${NC}"
fi

exit 0
