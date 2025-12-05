#!/bin/bash

# Auto-commit git changes on Claude Code stop
# This hook runs when Claude Code session ends
# Part of fractary-repo plugin - respects configured source control provider
# Note: Only commits locally; use /fractary-repo:push to push changes

# Skip execution if running as a sub-agent
if [ -n "$CLAUDE_SUB_AGENT" ] || [ -n "$CLAUDE_AGENT_NAME" ]; then
    exit 0
fi

# =============================================================================
# OPTIMIZATION: Check if running in unified mode (Option 7)
# If unified mode is active, skip redundant checks as they're already done
# =============================================================================
RUNNING_UNIFIED=false
if [ "$UNIFIED_MODE" = "true" ]; then
    RUNNING_UNIFIED=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CACHE_DIR="${HOME}/.fractary/repo"
LOG_FILE="${CACHE_DIR}/auto-commit.log"
CONFIG_FILE="${HOME}/.fractary/plugins/repo/config.json"
MAX_LOCK_RETRIES=2
RETRY_DELAY=2

mkdir -p "${CACHE_DIR}"

# =============================================================================
# OPTIMIZATION: Check config to see if hook is enabled (Option 6)
# =============================================================================
if [ -f "$CONFIG_FILE" ] && command -v jq &> /dev/null; then
    HOOK_ENABLED=$(jq -r '.hooks.auto_commit.enabled // true' "$CONFIG_FILE" 2>/dev/null || echo "true")
    if [ "$HOOK_ENABLED" = "false" ]; then
        exit 0
    fi

    # Throttle check: skip if last run was within throttle window
    THROTTLE_MINUTES=$(jq -r '.hooks.auto_commit.throttle_minutes // 0' "$CONFIG_FILE" 2>/dev/null || echo "0")
    if [ "$THROTTLE_MINUTES" -gt 0 ]; then
        LAST_RUN_FILE="${CACHE_DIR}/auto-commit-last-run"
        if [ -f "$LAST_RUN_FILE" ]; then
            LAST_RUN=$(cat "$LAST_RUN_FILE" 2>/dev/null || echo "0")
            NOW=$(date +%s)
            ELAPSED=$(( (NOW - LAST_RUN) / 60 ))
            if [ "$ELAPSED" -lt "$THROTTLE_MINUTES" ]; then
                exit 0
            fi
        fi
    fi
fi

# =============================================================================
# OPTIMIZATION: Early exit BEFORE acquiring lock (Option 2)
# Check if there are any changes worth committing before taking the expensive lock
# =============================================================================

# Check if we're in a git repository first
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${RED}❌ Not in a git repository${NC}"
    exit 0
fi

# Quick check for changes WITHOUT acquiring lock
# This avoids lock contention when there's nothing to commit
if git diff-index --quiet HEAD -- 2>/dev/null && [ -z "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    echo -e "${GREEN}✅ No changes to commit${NC}"
    exit 0
fi

# Get repository root path for cache key (same as update-status-cache.sh)
# This ensures we use the same repo-scoped lock file
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
# Use repo-scoped lock based on repository path hash
# Try multiple hash commands for cross-platform compatibility
REPO_ID=$(echo "$REPO_PATH" | (md5sum 2>/dev/null || md5 2>/dev/null || shasum 2>/dev/null) | cut -d' ' -f1 | cut -c1-16 || echo "global")
LOCK_FILE="${CACHE_DIR}/status-${REPO_ID}.lock"

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

# =============================================================================
# OPTIMIZATION: Removed duplicate git repo check (already done before lock)
# OPTIMIZATION: Removed first cache update call (Option 4 - was redundant)
# We already checked for changes before acquiring lock, so we know there's work
# =============================================================================

echo -e "${YELLOW}🔄 Preparing to commit changes...${NC}"

# Get script directory for accessing cache utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Show current status for user visibility (single git call)
echo -e "${YELLOW}📊 Git status:${NC}"
git status --short

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

    # Update throttle timestamp (Option 6)
    LAST_RUN_FILE="${CACHE_DIR}/auto-commit-last-run"
    date +%s > "$LAST_RUN_FILE" 2>/dev/null || true

    echo -e "${GREEN}✨ Auto-commit hook completed${NC}"
else
    echo -e "${RED}❌ Commit failed${NC}"
    exit 1
fi