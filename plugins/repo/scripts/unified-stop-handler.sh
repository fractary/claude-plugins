#!/bin/bash

# Unified Stop Hook Handler
# This script orchestrates both repo and work plugin stop hooks
# Part of fractary-repo plugin - coordinates auto-commit and auto-comment hooks
#
# OPTIMIZATION (Option 7): Combines both Stop hooks to share work:
# - Single sub-agent check
# - Single git repo detection
# - Single branch info lookup
# - Shared early exit logic
# - Sequential execution: commit first, then comment (logical order)
#
# Configuration:
#   hooks.unified.enabled: true/false (default: false - use individual hooks)
#   hooks.unified.run_commit: true/false (default: true)
#   hooks.unified.run_comment: true/false (default: true)

# Skip execution if running as a sub-agent (single check for both hooks)
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
REPO_CONFIG_FILE="${HOME}/.fractary/plugins/repo/config.json"
WORK_CONFIG_FILE="${HOME}/.fractary/plugins/work/config.json"
CACHE_DIR="${HOME}/.fractary/repo"
LOG_FILE="${CACHE_DIR}/unified-stop.log"

mkdir -p "${CACHE_DIR}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Logging function
log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date -u +"%Y-%m-%d %H:%M:%S UTC")] [$level] $message" >> "${LOG_FILE}"
}

log_message "INFO" "Unified stop handler started"

# =============================================================================
# Check if unified mode is enabled
# =============================================================================
UNIFIED_ENABLED=false
RUN_COMMIT=true
RUN_COMMENT=true

if [ -f "$REPO_CONFIG_FILE" ] && command -v jq &> /dev/null; then
    UNIFIED_ENABLED=$(jq -r '.hooks.unified.enabled // false' "$REPO_CONFIG_FILE" 2>/dev/null || echo "false")
    RUN_COMMIT=$(jq -r '.hooks.unified.run_commit // true' "$REPO_CONFIG_FILE" 2>/dev/null || echo "true")
    RUN_COMMENT=$(jq -r '.hooks.unified.run_comment // true' "$REPO_CONFIG_FILE" 2>/dev/null || echo "true")
fi

if [ "$UNIFIED_ENABLED" != "true" ]; then
    log_message "INFO" "Unified mode not enabled, running individual hooks"

    # Fall back to running individual hooks
    if [ "$RUN_COMMIT" = "true" ] && [ -f "${SCRIPT_DIR}/auto-commit-on-stop.sh" ]; then
        "${SCRIPT_DIR}/auto-commit-on-stop.sh"
    fi

    # Work plugin hook (relative path from repo plugin)
    WORK_HOOK="${SCRIPT_DIR}/../../work/scripts/auto-comment-on-stop.sh"
    if [ "$RUN_COMMENT" = "true" ] && [ -f "$WORK_HOOK" ]; then
        "$WORK_HOOK"
    fi

    exit 0
fi

echo -e "${BLUE}🔄 Running unified stop handler...${NC}"

# =============================================================================
# Shared: Check if we're in a git repository
# =============================================================================
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo -e "${YELLOW}ℹ️  Not in a git repository${NC}"
    log_message "INFO" "Not in git repository, exiting"
    exit 0
fi

# =============================================================================
# Shared: Get repository and branch info (reused by both hooks)
# =============================================================================
REPO_PATH=$(git rev-parse --show-toplevel 2>/dev/null || pwd)
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)
CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)

echo -e "${BLUE}📍 Repository: ${REPO_PATH##*/}${NC}"
echo -e "${BLUE}🌿 Branch: ${CURRENT_BRANCH}${NC}"
log_message "INFO" "Repo: $REPO_PATH, Branch: $CURRENT_BRANCH"

# =============================================================================
# Shared: Check for changes (single check for both hooks)
# =============================================================================
HAS_UNCOMMITTED=false
HAS_UNTRACKED=false

if ! git diff-index --quiet HEAD -- 2>/dev/null; then
    HAS_UNCOMMITTED=true
fi

if [ -n "$(git ls-files --others --exclude-standard 2>/dev/null)" ]; then
    HAS_UNTRACKED=true
fi

# Export shared variables for child scripts
export UNIFIED_REPO_PATH="$REPO_PATH"
export UNIFIED_BRANCH="$CURRENT_BRANCH"
export UNIFIED_HEAD="$CURRENT_HEAD"
export UNIFIED_HAS_UNCOMMITTED="$HAS_UNCOMMITTED"
export UNIFIED_HAS_UNTRACKED="$HAS_UNTRACKED"
export UNIFIED_MODE="true"

# =============================================================================
# Phase 1: Auto-commit (repo plugin)
# =============================================================================
COMMIT_MADE=false

if [ "$RUN_COMMIT" = "true" ]; then
    if [ "$HAS_UNCOMMITTED" = "true" ] || [ "$HAS_UNTRACKED" = "true" ]; then
        echo -e "${YELLOW}📝 Running auto-commit...${NC}"
        log_message "INFO" "Running auto-commit hook"

        if [ -f "${SCRIPT_DIR}/auto-commit-on-stop.sh" ]; then
            if "${SCRIPT_DIR}/auto-commit-on-stop.sh"; then
                COMMIT_MADE=true
                # Update HEAD reference after commit
                CURRENT_HEAD=$(git rev-parse HEAD 2>/dev/null)
                export UNIFIED_HEAD="$CURRENT_HEAD"
                log_message "INFO" "Auto-commit completed successfully"
            else
                log_message "WARN" "Auto-commit failed or had no changes"
            fi
        else
            echo -e "${YELLOW}⚠️  Auto-commit script not found${NC}"
            log_message "WARN" "Auto-commit script not found"
        fi
    else
        echo -e "${GREEN}✅ No changes to commit${NC}"
        log_message "INFO" "No changes to commit"
    fi
fi

# =============================================================================
# Phase 2: Auto-comment (work plugin)
# =============================================================================
if [ "$RUN_COMMENT" = "true" ]; then
    # Work plugin hook
    WORK_HOOK="${SCRIPT_DIR}/../../work/scripts/auto-comment-on-stop.sh"

    if [ -f "$WORK_HOOK" ]; then
        echo -e "${YELLOW}💬 Running auto-comment...${NC}"
        log_message "INFO" "Running auto-comment hook"

        if "$WORK_HOOK"; then
            log_message "INFO" "Auto-comment completed successfully"
        else
            log_message "WARN" "Auto-comment failed or skipped"
        fi
    else
        log_message "INFO" "Work plugin hook not found, skipping auto-comment"
    fi
fi

echo -e "${GREEN}✨ Unified stop handler completed${NC}"
log_message "INFO" "Unified stop handler completed"
