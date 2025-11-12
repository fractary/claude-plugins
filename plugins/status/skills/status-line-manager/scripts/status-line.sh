#!/usr/bin/env bash
# status-line.sh - Generates custom status line for Claude Code
# Shows: branch, file changes, issue number, PR number, sync status, last prompt
# Called by StatusLine hook
# Usage: Called automatically by Claude Code hooks system

set -euo pipefail

# Configuration
PLUGIN_DIR="${FRACTARY_PLUGINS_DIR:-.fractary/plugins}/status"
PROMPT_CACHE="$PLUGIN_DIR/last-prompt.json"

# Find repo plugin scripts directory
# Try multiple locations for robustness
if [ -n "${CLAUDE_PLUGINS_DIR:-}" ]; then
  # Use Claude plugins directory if set
  REPO_SCRIPTS_DIR="$CLAUDE_PLUGINS_DIR/repo/scripts"
elif [ -f "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../repo/scripts/read-status-cache.sh" ]; then
  # Use relative path from plugin directory
  REPO_SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../../repo/scripts"
else
  # Fallback: search from git root
  GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null || echo "")
  if [ -n "$GIT_ROOT" ] && [ -f "$GIT_ROOT/plugins/repo/scripts/read-status-cache.sh" ]; then
    REPO_SCRIPTS_DIR="$GIT_ROOT/plugins/repo/scripts"
  else
    REPO_SCRIPTS_DIR=""
  fi
fi

# Colors (if supported)
CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
MAGENTA='\033[0;35m'
BLUE='\033[0;34m'
RED='\033[0;31m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "not a git repository"
  exit 0
fi

# Read git status from cache (uses fractary-repo plugin)
read_git_status() {
  if [ -n "$REPO_SCRIPTS_DIR" ] && [ -f "$REPO_SCRIPTS_DIR/read-status-cache.sh" ]; then
    "$REPO_SCRIPTS_DIR/read-status-cache.sh" "$@" 2>/dev/null || true
  else
    echo "0"
  fi
}

# Get branch name
BRANCH=$(read_git_status branch | tr -d '\n')
if [ -z "$BRANCH" ] || [ "$BRANCH" = "0" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
fi

# Get issue number from cache or branch name
ISSUE_ID=$(read_git_status issue_id | tr -d '\n')
if [ -z "$ISSUE_ID" ] || [ "$ISSUE_ID" = "0" ]; then
  # Try to extract from branch name (e.g., feat/123-description)
  ISSUE_ID=$(echo "$BRANCH" | grep -oE '[0-9]+' | head -1 || echo "")
fi

# Get PR number from cache
PR_NUMBER=$(read_git_status pr_number | tr -d '\n')
if [ -z "$PR_NUMBER" ] || [ "$PR_NUMBER" = "0" ]; then
  PR_NUMBER=""
fi

# Get uncommitted changes (staged + unstaged + untracked)
# Use default value of 0 if empty or non-numeric
UNCOMMITTED=$(read_git_status uncommitted_changes | tr -d '\n')
UNCOMMITTED=${UNCOMMITTED:-0}
UNTRACKED=$(read_git_status untracked_files | tr -d '\n')
UNTRACKED=${UNTRACKED:-0}
TOTAL_CHANGES=$((UNCOMMITTED + UNTRACKED))

# Get ahead/behind counts
# Use default value of 0 if empty or non-numeric
AHEAD=$(read_git_status commits_ahead | tr -d '\n')
AHEAD=${AHEAD:-0}
BEHIND=$(read_git_status commits_behind | tr -d '\n')
BEHIND=${BEHIND:-0}

# Get last prompt
LAST_PROMPT=""
if [ -f "$PROMPT_CACHE" ]; then
  LAST_PROMPT=$(jq -r '.prompt_short // ""' "$PROMPT_CACHE" 2>/dev/null || echo "")
fi

# Build status line
STATUS_LINE=""

# Branch name (cyan)
STATUS_LINE="${STATUS_LINE}${CYAN}${BRANCH}${NC}"

# File changes (yellow if dirty, green if clean)
if [ "$TOTAL_CHANGES" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${YELLOW}±${TOTAL_CHANGES}${NC}"
else
  STATUS_LINE="${STATUS_LINE} ${GREEN}±0${NC}"
fi

# Issue number (magenta)
if [ -n "$ISSUE_ID" ]; then
  STATUS_LINE="${STATUS_LINE} ${MAGENTA}#${ISSUE_ID}${NC}"
fi

# PR number (blue)
if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "0" ]; then
  STATUS_LINE="${STATUS_LINE} ${BLUE}PR#${PR_NUMBER}${NC}"
fi

# Ahead/behind (green for ahead, red for behind)
if [ "$AHEAD" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${GREEN}↑${AHEAD}${NC}"
fi
if [ "$BEHIND" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${RED}↓${BEHIND}${NC}"
fi

# Last prompt (dim)
if [ -n "$LAST_PROMPT" ]; then
  STATUS_LINE="${STATUS_LINE} ${DIM}last: ${LAST_PROMPT}${NC}"
fi

# Output status line (strip color codes if NO_COLOR is set)
if [ -n "${NO_COLOR:-}" ]; then
  echo "$STATUS_LINE" | sed 's/\x1b\[[0-9;]*m//g'
else
  echo -e "$STATUS_LINE"
fi

exit 0
