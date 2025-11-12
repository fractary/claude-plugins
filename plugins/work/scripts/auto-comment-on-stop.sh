#!/bin/bash

# Auto-comment on Claude Code session stop
# This hook runs when Claude Code session ends
# Part of fractary-work plugin - posts session summary to associated issue
# Note: Only posts comment if current branch is tied to an issue

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
CACHE_DIR="${HOME}/.fractary/work"
LOG_FILE="${CACHE_DIR}/auto-comment.log"

mkdir -p "${CACHE_DIR}"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] [$level] $message" >> "${LOG_FILE}"
}

echo -e "${YELLOW}🔄 Checking for issue-linked branch...${NC}"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  Not in a git repository - skipping issue comment${NC}"
    log_message "INFO" "Not in git repository, skipping"
    exit 0
fi

# Get current branch
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if [ -z "$CURRENT_BRANCH" ] || [ "$CURRENT_BRANCH" = "HEAD" ]; then
    echo -e "${YELLOW}ℹ️  Detached HEAD or no branch - skipping issue comment${NC}"
    log_message "INFO" "Detached HEAD, skipping"
    exit 0
fi

echo -e "${BLUE}📍 Current branch: ${CURRENT_BRANCH}${NC}"
log_message "INFO" "Current branch: $CURRENT_BRANCH"

# Try to get issue ID from repo plugin cache first (fast path)
ISSUE_ID=""
REPO_CACHE_SCRIPT="/home/user/claude-plugins/plugins/repo/scripts/read-status-cache.sh"

if [ -f "$REPO_CACHE_SCRIPT" ]; then
    ISSUE_ID=$("$REPO_CACHE_SCRIPT" issue_id 2>/dev/null | tr -d ' \n' || echo "")
    # Filter out "0" which read script returns for empty fields
    if [ "$ISSUE_ID" = "0" ]; then
        ISSUE_ID=""
    fi
    if [ -n "$ISSUE_ID" ]; then
        echo -e "${GREEN}✅ Found issue ID from cache: #${ISSUE_ID}${NC}"
        log_message "INFO" "Retrieved issue ID from repo cache: $ISSUE_ID"
    fi
fi

# Fallback: Extract issue ID from branch name if cache unavailable or empty
if [ -z "$ISSUE_ID" ]; then
    echo -e "${YELLOW}⚙️  Repo cache unavailable, parsing branch name...${NC}"
    log_message "INFO" "Falling back to branch name parsing"

    if [[ "$CURRENT_BRANCH" =~ ^(feat|fix|chore|hotfix|patch)/([0-9]+)- ]]; then
        ISSUE_ID="${BASH_REMATCH[2]}"
        echo -e "${GREEN}✅ Found issue ID: #${ISSUE_ID}${NC}"
        log_message "INFO" "Extracted issue ID from branch: $ISSUE_ID"
    elif [[ "$CURRENT_BRANCH" =~ ^[a-z]+/([0-9]+) ]]; then
        # Fallback pattern: any-prefix/123
        ISSUE_ID="${BASH_REMATCH[1]}"
        echo -e "${GREEN}✅ Found issue ID: #${ISSUE_ID}${NC}"
        log_message "INFO" "Extracted issue ID from branch (fallback): $ISSUE_ID"
    else
        echo -e "${YELLOW}ℹ️  Branch not linked to an issue (no issue ID in branch name)${NC}"
        echo -e "${YELLOW}ℹ️  Expected format: feat/123-description or fix/456-bug${NC}"
        log_message "INFO" "No issue ID in branch name, skipping"
        exit 0
    fi
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check if there's meaningful work to report (early exit optimization)
# Load last stop reference to check for changes
LAST_STOP_FILE="${CACHE_DIR}/last_stop_ref"
LAST_STOP_REF=""
if [ -f "$LAST_STOP_FILE" ]; then
    LAST_STOP_REF=$(grep "^${CURRENT_BRANCH}:" "$LAST_STOP_FILE" 2>/dev/null | cut -d: -f2 || echo "")
fi

# Check for commits or uncommitted changes
HAS_WORK=false

if [ -n "$LAST_STOP_REF" ] && git rev-parse "$LAST_STOP_REF" &>/dev/null; then
    # We have a last reference - check if there are new commits
    if ! git diff --quiet "$LAST_STOP_REF..HEAD" 2>/dev/null; then
        HAS_WORK=true
        echo -e "${BLUE}📝 Found new commits since last update${NC}"
        log_message "INFO" "New commits detected"
    fi
else
    # No reference - check for recent commits (last 15 minutes)
    RECENT_COMMITS=$(git log --since="15 minutes ago" --oneline 2>/dev/null | wc -l | tr -d ' ')
    if [ "$RECENT_COMMITS" -gt 0 ]; then
        HAS_WORK=true
        echo -e "${BLUE}📝 Found recent commits${NC}"
        log_message "INFO" "Recent commits detected"
    fi
fi

# Also check for uncommitted changes
UNCOMMITTED=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
if [ "$UNCOMMITTED" -gt 0 ]; then
    HAS_WORK=true
    echo -e "${BLUE}📝 Found uncommitted changes${NC}"
    log_message "INFO" "Uncommitted changes detected"
fi

# Early exit if no work to report
if [ "$HAS_WORK" = false ]; then
    echo -e "${GREEN}✅ No changes to report - skipping comment${NC}"
    log_message "INFO" "No changes detected, skipping comment"
    exit 0
fi

# Generate session summary
echo -e "${BLUE}📊 Generating session summary...${NC}"
SESSION_SUMMARY=$("${SCRIPT_DIR}/generate-session-summary.sh" 2>/dev/null)

if [ $? -ne 0 ] || [ -z "$SESSION_SUMMARY" ]; then
    echo -e "${YELLOW}⚠️  Could not generate session summary${NC}"
    log_message "WARN" "Session summary generation failed"
    exit 0
fi

echo -e "${GREEN}✅ Session summary generated${NC}"

# Find the work plugin handler script
WORK_PLUGIN_ROOT="${SCRIPT_DIR}/.."
HANDLER_SCRIPT=""

# Try to find active handler from config
CONFIG_FILE="${HOME}/.fractary/plugins/work/config.json"

if [ -f "$CONFIG_FILE" ]; then
    # Extract active handler (default to github if not specified)
    ACTIVE_HANDLER=$(jq -r '.handlers["work-tracker"].active // "github"' "$CONFIG_FILE" 2>/dev/null || echo "github")
    echo -e "${BLUE}📋 Active work tracker: ${ACTIVE_HANDLER}${NC}"
    log_message "INFO" "Active handler: $ACTIVE_HANDLER"

    HANDLER_SCRIPT="${WORK_PLUGIN_ROOT}/skills/handler-work-tracker-${ACTIVE_HANDLER}/scripts/create-comment.sh"
else
    # Default to GitHub if no config
    echo -e "${YELLOW}⚠️  No config found, defaulting to GitHub${NC}"
    log_message "WARN" "No config found, using github handler"
    HANDLER_SCRIPT="${WORK_PLUGIN_ROOT}/skills/handler-work-tracker-github/scripts/create-comment.sh"
fi

# Verify handler script exists
if [ ! -f "$HANDLER_SCRIPT" ]; then
    echo -e "${RED}❌ Handler script not found: ${HANDLER_SCRIPT}${NC}"
    log_message "ERROR" "Handler script not found: $HANDLER_SCRIPT"
    exit 0
fi

# Check if gh CLI is available (required for GitHub)
if [ "$ACTIVE_HANDLER" = "github" ] && ! command -v gh &> /dev/null; then
    echo -e "${YELLOW}⚠️  gh CLI not found - cannot post comment${NC}"
    echo -e "${YELLOW}ℹ️  Install from https://cli.github.com${NC}"
    log_message "WARN" "gh CLI not found"
    exit 0
fi

# Post comment to issue
echo -e "${BLUE}💬 Posting session summary to issue #${ISSUE_ID}...${NC}"
log_message "INFO" "Posting comment to issue #$ISSUE_ID"

# Call handler script directly (no work_id or author for standalone comment)
if "${HANDLER_SCRIPT}" "$ISSUE_ID" "$SESSION_SUMMARY" 2>&1; then
    echo -e "${GREEN}✅ Session summary posted to issue #${ISSUE_ID}${NC}"
    log_message "INFO" "Comment posted successfully to issue #$ISSUE_ID"

    # Save current HEAD as reference for next time
    # This allows us to show "work since last comment" on the next stop
    LAST_STOP_FILE="${CACHE_DIR}/last_stop_ref"
    CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

    # Store as "branch:ref" format (one line per branch)
    # Remove old entry for this branch and append new one
    if [ -f "$LAST_STOP_FILE" ]; then
        grep -v "^${CURRENT_BRANCH}:" "$LAST_STOP_FILE" > "${LAST_STOP_FILE}.tmp" 2>/dev/null || true
        mv "${LAST_STOP_FILE}.tmp" "$LAST_STOP_FILE"
    fi
    echo "${CURRENT_BRANCH}:${CURRENT_HEAD}" >> "$LAST_STOP_FILE"

    echo -e "${BLUE}📌 Saved reference for next comment: ${CURRENT_HEAD:0:7}${NC}"
    log_message "INFO" "Saved stop reference: $CURRENT_HEAD"

    # Periodic cache cleanup (run every 20th execution)
    # Remove references for branches that no longer exist
    CLEANUP_COUNTER_FILE="${CACHE_DIR}/cleanup_counter"
    CLEANUP_INTERVAL=20

    if [ ! -f "$CLEANUP_COUNTER_FILE" ]; then
        echo "0" > "$CLEANUP_COUNTER_FILE"
    fi

    COUNTER=$(cat "$CLEANUP_COUNTER_FILE" 2>/dev/null || echo "0")
    COUNTER=$((COUNTER + 1))

    if [ "$COUNTER" -ge "$CLEANUP_INTERVAL" ]; then
        echo -e "${BLUE}🧹 Running cache cleanup...${NC}"
        log_message "INFO" "Running periodic cache cleanup"

        # Create temp file for valid references
        TEMP_REF_FILE="${LAST_STOP_FILE}.cleanup.tmp"
        > "$TEMP_REF_FILE"

        # Read through last_stop_ref and keep only valid branches
        if [ -f "$LAST_STOP_FILE" ]; then
            while IFS=: read -r branch ref; do
                if git rev-parse --verify "$branch" &>/dev/null; then
                    echo "${branch}:${ref}" >> "$TEMP_REF_FILE"
                else
                    log_message "INFO" "Cleaned up stale reference for branch: $branch"
                fi
            done < "$LAST_STOP_FILE"

            # Replace old file with cleaned version
            mv "$TEMP_REF_FILE" "$LAST_STOP_FILE"
        fi

        # Reset counter
        echo "0" > "$CLEANUP_COUNTER_FILE"
        echo -e "${GREEN}✅ Cache cleanup completed${NC}"
        log_message "INFO" "Cache cleanup completed"
    else
        echo "$COUNTER" > "$CLEANUP_COUNTER_FILE"
    fi
else
    EXIT_CODE=$?
    echo -e "${YELLOW}⚠️  Could not post comment (exit code: ${EXIT_CODE})${NC}"

    case $EXIT_CODE in
        10)
            echo -e "${YELLOW}ℹ️  Issue #${ISSUE_ID} not found in repository${NC}"
            log_message "WARN" "Issue not found: #$ISSUE_ID"
            ;;
        11)
            echo -e "${YELLOW}ℹ️  GitHub authentication required - run 'gh auth login'${NC}"
            log_message "WARN" "Authentication failed for issue #$ISSUE_ID"
            ;;
        *)
            echo -e "${YELLOW}ℹ️  Comment posting failed - see log for details${NC}"
            log_message "ERROR" "Comment posting failed with exit code $EXIT_CODE"
            ;;
    esac
fi

echo -e "${GREEN}✨ Auto-comment hook completed${NC}"
log_message "INFO" "Auto-comment hook completed"
