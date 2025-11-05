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

# Function to generate meaningful commit message based on changes
generate_commit_message() {
    local timestamp=$(date +"%Y-%m-%d %H:%M:%S")

    # Get change statistics
    local stats=$(git diff --cached --numstat)
    local name_status=$(git diff --cached --name-status)

    # Count changes by type (with defensive fallback)
    local added=$(($(echo "$name_status" | grep "^A" | wc -l | tr -d ' ') + 0))
    local modified=$(($(echo "$name_status" | grep "^M" | wc -l | tr -d ' ') + 0))
    local deleted=$(($(echo "$name_status" | grep "^D" | wc -l | tr -d ' ') + 0))
    local renamed=$(($(echo "$name_status" | grep "^R" | wc -l | tr -d ' ') + 0))

    # Get file extensions and paths
    local files=$(git diff --cached --name-only)
    local file_count=$(($(echo "$files" | wc -l | tr -d ' ') + 0))

    # Analyze file types (with defensive fallback)
    local has_docs=$(($(echo "$files" | grep -iE "\.(md|rst|txt|adoc)$" | wc -l | tr -d ' ') + 0))
    local has_scripts=$(($(echo "$files" | grep -E "\.(sh|bash|zsh|fish)$" | wc -l | tr -d ' ') + 0))
    local has_config=$(($(echo "$files" | grep -E "\.(toml|yaml|yml|json|ini|conf)$" | wc -l | tr -d ' ') + 0))
    local has_source=$(($(echo "$files" | grep -E "\.(js|ts|py|rb|go|rs|java|c|cpp|h|hpp)$" | wc -l | tr -d ' ') + 0))

    # Determine commit type and generate summary
    local commit_type="chore"
    local summary=""

    if [ "$file_count" -eq 1 ]; then
        # Single file change
        local filename=$(basename "$files")

        if [ "$added" -eq 1 ]; then
            commit_type="feat"
            summary="Add $filename"
        elif [ "$deleted" -eq 1 ]; then
            commit_type="chore"
            summary="Remove $filename"
        elif [ "$modified" -eq 1 ]; then
            if [[ "$filename" =~ \.(md|rst|txt)$ ]]; then
                commit_type="docs"
                summary="Update $filename"
            elif [[ "$filename" =~ \.(sh|bash)$ ]]; then
                commit_type="fix"
                summary="Update $filename"
            else
                commit_type="chore"
                summary="Update $filename"
            fi
        fi
    else
        # Multiple files changed
        if [ "$has_docs" -gt 0 ] && [ "$has_source" -eq 0 ] && [ "$has_scripts" -eq 0 ]; then
            commit_type="docs"
            summary="Update documentation ($file_count files)"
        elif [ "$has_scripts" -gt "$has_source" ]; then
            commit_type="chore"
            summary="Update scripts ($file_count files)"
        elif [ "$has_config" -eq "$file_count" ]; then
            commit_type="chore"
            summary="Update configuration ($file_count files)"
        elif [ "$added" -gt 0 ] && [ "$modified" -eq 0 ] && [ "$deleted" -eq 0 ]; then
            commit_type="feat"
            summary="Add $file_count files"
        elif [ "$deleted" -gt 0 ] && [ "$added" -eq 0 ] && [ "$modified" -eq 0 ]; then
            commit_type="chore"
            summary="Remove $file_count files"
        else
            # Mixed changes - try to identify the main pattern
            local dir_pattern=$(echo "$files" | head -1 | cut -d'/' -f1-2)
            local common_prefix=$(echo "$files" | sed -e 'N;s/^\(.*\).*\n\1.*$/\1\n\1/;D')

            if [ -n "$common_prefix" ] && [ "$common_prefix" != "/" ]; then
                summary="Update $common_prefix ($file_count files)"
            else
                summary="Update $file_count files"
            fi

            # Set type based on what changed most
            if [ "$has_docs" -gt 0 ]; then
                commit_type="docs"
            elif [ "$modified" -gt "$added" ]; then
                commit_type="chore"
            else
                commit_type="feat"
            fi
        fi
    fi

    # Build commit message with conventional commit format
    cat <<EOF
$commit_type: $summary

Auto-committed on Claude Code session end at $timestamp
EOF
}

# Generate meaningful commit message
# Generate meaningful commit message using external script
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