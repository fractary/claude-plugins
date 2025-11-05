#!/bin/bash

# Auto-commit git changes on Claude Code stop
# This hook runs when Claude Code session ends
# Part of fractary-repo plugin - respects configured source control provider
# Note: Only commits locally; use /fractary-repo:push to push changes

# Skip execution if running as a sub-agent
if [ -n "$CLAUDE_SUB_AGENT" ] || [ -n "$CLAUDE_AGENT_NAME" ]; then
    exit 0
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"
LOCK_FILE="${CACHE_DIR}/status.lock"
LOG_FILE="${CACHE_DIR}/auto-commit.log"
MAX_LOCK_RETRIES=2
RETRY_DELAY=2

mkdir -p "${CACHE_DIR}"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] [$level] $message" >> "${LOG_FILE}"
}

# Acquire lock to prevent concurrent cache updates during commit
# This prevents UserPromptSubmit hook from updating cache while we're committing
# Using <> (read-write) instead of > (write/truncate) for atomic lock file access
# Retry logic: If lock acquisition fails, retry up to MAX_LOCK_RETRIES times
LOCK_ACQUIRED=false
for attempt in $(seq 1 $((MAX_LOCK_RETRIES + 1))); do
    exec 200<>"${LOCK_FILE}"
    if flock -w 10 200; then
        LOCK_ACQUIRED=true
        break
    fi

    # Lock failed
    if [ $attempt -le $MAX_LOCK_RETRIES ]; then
        echo -e "${YELLOW}⚠️  Lock acquisition failed (attempt $attempt/$((MAX_LOCK_RETRIES + 1))), retrying in ${RETRY_DELAY}s...${NC}"
        log_message "WARN" "Lock acquisition failed (attempt $attempt/$((MAX_LOCK_RETRIES + 1))), retrying in ${RETRY_DELAY}s"
        sleep $RETRY_DELAY
    fi
done

if [ "$LOCK_ACQUIRED" = false ]; then
    MSG="Failed to acquire lock after $((MAX_LOCK_RETRIES + 1)) attempts. Skipping auto-commit to prevent data loss."
    echo -e "${RED}❌ $MSG${NC}"
    echo -e "${YELLOW}ℹ️  Changes remain uncommitted. Review manually or commit will retry on next session end.${NC}"
    log_message "ERROR" "$MSG"
    exit 0
fi

# Lock auto-releases when FD closes (on script exit)
trap "log_message 'INFO' 'Auto-commit hook completed'" EXIT

echo -e "${YELLOW}🔄 Checking for git changes...${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 0
fi

# Get script directory for accessing cache utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Update cache first to ensure we have fresh data
# Pass --skip-lock because we already hold the lock
if [ -f "${SCRIPT_DIR}/update-status-cache.sh" ]; then
    "${SCRIPT_DIR}/update-status-cache.sh" --quiet --skip-lock 2>/dev/null || {
        echo -e "${YELLOW}⚠️  Could not update cache, falling back to direct git check${NC}"
        # Fallback to direct git check if cache update fails
        if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
            echo -e "${GREEN}✅ No changes to commit${NC}"
            exit 0
        fi
        echo -e "${YELLOW}📊 Git status:${NC}"
        git status --short
    }
else
    echo -e "${YELLOW}⚠️  Cache script not found, using direct git commands${NC}"
    # Fallback to direct git check if cache script missing
    if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
        echo -e "${GREEN}✅ No changes to commit${NC}"
        exit 0
    fi
    echo -e "${YELLOW}📊 Git status:${NC}"
    git status --short
fi

# Read from cache (cache was just updated above)
if [ -f "${SCRIPT_DIR}/read-status-cache.sh" ]; then
    CACHE_UNCOMMITTED=$("${SCRIPT_DIR}/read-status-cache.sh" uncommitted_changes 2>/dev/null || echo "0")
    CACHE_UNTRACKED=$("${SCRIPT_DIR}/read-status-cache.sh" untracked_files 2>/dev/null || echo "0")

    # Check for changes using cache
    if [ "$CACHE_UNCOMMITTED" -eq 0 ] && [ "$CACHE_UNTRACKED" -eq 0 ]; then
        echo -e "${GREEN}✅ No changes to commit${NC}"
        exit 0
    fi

    # Show status summary from cache
    echo -e "${YELLOW}📊 Status: $CACHE_UNCOMMITTED uncommitted changes, $CACHE_UNTRACKED untracked files${NC}"

    # Show detailed status for user visibility (single git call)
    echo -e "${YELLOW}📊 Git status:${NC}"
    git status --short
else
    echo -e "${YELLOW}⚠️  Cache read script not found, relying on direct git status shown above${NC}"
fi

# Attempt to use fractary-repo plugin commands (respects configured provider)
echo -e "${BLUE}💾 Using fractary-repo plugin to commit changes...${NC}"

# Check if we're in a Claude Code session that can invoke slash commands
if [ -n "$CLAUDE_PROJECT_DIR" ] && command -v claude &> /dev/null; then
    # Try to use the plugin's commit command (handles all providers: GitHub, GitLab, Bitbucket)
    echo -e "${YELLOW}📝 Invoking /fractary-repo:commit...${NC}"

    # Note: The /fractary-repo:commit command in auto mode will:
    # - Analyze changes and generate appropriate commit message
    # - Determine commit type automatically
    # - Include proper metadata and attribution
    # - Respect the configured source control provider
    if claude exec "/fractary-repo:commit" 2>/dev/null; then
        echo -e "${GREEN}✅ Commit created via fractary-repo plugin${NC}"

        # Update status cache for status line consumption
        # Pass --skip-lock because we already hold the lock
        echo -e "${BLUE}📊 Updating status cache...${NC}"
        if [ -f "${SCRIPT_DIR}/update-status-cache.sh" ]; then
            "${SCRIPT_DIR}/update-status-cache.sh" --quiet --skip-lock || echo -e "${YELLOW}⚠️  Status cache update failed (non-critical)${NC}"
        fi

        echo -e "${GREEN}✨ Auto-commit hook completed successfully${NC}"
        exit 0
    else
        echo -e "${YELLOW}⚠️  Plugin commit failed, falling back to direct git commands${NC}"
    fi
fi

# Fallback: Use direct git commands if plugin invocation unavailable or failed
echo -e "${YELLOW}ℹ️  Using direct git commands (fallback)${NC}"

# Stage all changes
echo -e "${YELLOW}📝 Staging changes...${NC}"
git add -A

# Generate commit message using external script
# Extracted to separate script for maintainability (was 95+ lines)
echo -e "${YELLOW}💬 Generating commit message...${NC}"
COMMIT_MSG=$("${SCRIPT_DIR}/generate-commit-message.sh")

# Commit changes
echo -e "${YELLOW}💾 Committing changes...${NC}"
git commit -m "$COMMIT_MSG"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Changes committed successfully${NC}"

    # Update status cache for status line consumption
    # Pass --skip-lock because we already hold the lock
    echo -e "${BLUE}📊 Updating status cache...${NC}"
    if [ -f "${SCRIPT_DIR}/update-status-cache.sh" ]; then
        "${SCRIPT_DIR}/update-status-cache.sh" --quiet --skip-lock || echo -e "${YELLOW}⚠️  Status cache update failed (non-critical)${NC}"
    fi

    echo -e "${GREEN}✨ Auto-commit hook completed${NC}"
else
    echo -e "${RED}❌ Commit failed${NC}"
    exit 1
fi