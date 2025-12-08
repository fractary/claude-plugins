#!/usr/bin/env bash
# status-line.sh - Generates custom status line for Claude Code
# Shows: branch, file changes, issue number, PR number, sync status, last prompt, context metrics
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

# OSC 8 hyperlink format (for clickable terminal links)
# Usage: create_hyperlink "URL" "TEXT" "COLOR"
# Note: In web IDE mode (CLAUDE_CODE_REMOTE), the TEXT parameter is ignored
#       and only the URL is output for auto-linking
create_hyperlink() {
  local url="$1"
  local text="$2"
  local color="${3:-$NC}"

  # Check if we're in Claude Code web IDE (OSC 8 not supported there)
  if [ -n "${CLAUDE_CODE_REMOTE:-}" ]; then
    # Web IDE: output plain URL only for auto-linking
    # The URL itself is clickable and self-documenting
    # Format: "https://github.com/owner/repo/issues/123"
    echo -en "${url}"
  else
    # Terminal: use OSC 8 format for clickable links
    # OSC 8 format: \033]8;;URL\033\\TEXT\033]8;;\033\\
    echo -en "${color}\033]8;;${url}\033\\${text}\033]8;;\033\\${NC}"
  fi
}

# Format a status link with label and URL
# Usage: format_status_link "LABEL" "URL" "COLOR"
# Web IDE: outputs "LABEL URL" (URL auto-clickable)
# Terminal: outputs clickable link with LABEL as text
format_status_link() {
  local label="$1"
  local url="$2"
  local color="$3"

  if [ -n "${CLAUDE_CODE_REMOTE:-}" ]; then
    # Web IDE: show label + plain URL (URL will be auto-clickable)
    echo -en " ${color}${label}${NC} $(create_hyperlink "$url" "$label" "$color")"
  else
    # Terminal: use OSC 8 for embedded clickable link
    echo -en " $(create_hyperlink "$url" "$label" "$color")"
  fi
}

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo "not a git repository"
  exit 0
fi

# Detect GitHub repository for clickable links
GITHUB_REPO=""
REMOTE_URL=$(git config --get remote.origin.url 2>/dev/null || echo "")
if [[ -n "$REMOTE_URL" ]]; then
  # Parse GitHub owner/repo from remote URL
  # Handles both HTTPS and SSH formats:
  # - https://github.com/owner/repo.git
  # - git@github.com:owner/repo.git
  if [[ "$REMOTE_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
    GITHUB_REPO="https://github.com/${REPO_OWNER}/${REPO_NAME}"
  fi
fi

# Read git status from cache (uses fractary-repo plugin)
read_git_status() {
  if [ -n "$REPO_SCRIPTS_DIR" ] && [ -f "$REPO_SCRIPTS_DIR/read-status-cache.sh" ]; then
    "$REPO_SCRIPTS_DIR/read-status-cache.sh" "$@" 2>/dev/null || true
  else
    echo "0"
  fi
}

# Get project name
PROJECT=$(read_git_status project_name | tr -d '\n')
if [ -z "$PROJECT" ] || [ "$PROJECT" = "0" ]; then
  PROJECT=$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")
fi

# Get branch name
BRANCH=$(read_git_status branch | tr -d '\n')
if [ -z "$BRANCH" ] || [ "$BRANCH" = "0" ]; then
  BRANCH=$(git branch --show-current 2>/dev/null || echo "unknown")
fi

# Get issue number from cache or branch name
ISSUE_ID=$(read_git_status issue_id | tr -d '\n')
if [ -z "$ISSUE_ID" ] || [ "$ISSUE_ID" = "0" ]; then
  # Fallback: extract from branch name using same pattern as cache update
  # Supports: feat/123-description, fix/456-bug, etc.
  # Bug fix #275: Require non-digit after dash to avoid matching dates like "bug/2022-12-07-description"
  if [[ "$BRANCH" =~ ^(feat|fix|chore|hotfix|patch)/([0-9]+)-([^0-9]|$) ]]; then
    ISSUE_ID="${BASH_REMATCH[2]}"
  elif [[ "$BRANCH" =~ ^[a-z]+/([0-9]+)-([^0-9]|$) ]]; then
    # Fallback pattern: any-prefix/123-description (requires non-digit after dash)
    # This prevents matching numeric prefixes like dates (e.g., bug/2022-12-07)
    ISSUE_ID="${BASH_REMATCH[1]}"
  else
    ISSUE_ID=""
  fi
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
  # Extract the actual user prompt from the nested JSON
  LAST_PROMPT=$(jq -r '.prompt // "" | fromjson | .prompt // ""' "$PROMPT_CACHE" 2>/dev/null || echo "")
  # Truncate to 120 characters if longer
  if [ ${#LAST_PROMPT} -gt 120 ]; then
    LAST_PROMPT="${LAST_PROMPT:0:120}..."
  fi
fi

# Get context free percentage and token cost (from environment or FABER state)
CONTEXT_FREE=""
TOKEN_COST=""

# Read context free percentage (from environment or FABER state)
if [ -n "${CLAUDE_CONTEXT_FREE:-}" ]; then
  CONTEXT_FREE="$CLAUDE_CONTEXT_FREE"
elif [ -d ".fractary/plugins/faber/runs" ]; then
  # Try to read from FABER state (newest run)
  CONTEXT_FREE=$(find .fractary/plugins/faber/runs -name "state.json" -type f \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | \
    xargs jq -r '.metrics.context_free_percent // empty' 2>/dev/null)
fi

# Read token cost (from environment or FABER state)
if [ -n "${CLAUDE_SESSION_COST:-}" ]; then
  TOKEN_COST="$CLAUDE_SESSION_COST"
elif [ -d ".fractary/plugins/faber/runs" ]; then
  # Try to read from FABER state (newest run)
  TOKEN_COST=$(find .fractary/plugins/faber/runs -name "state.json" -type f \
    -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -1 | cut -d' ' -f2- | \
    xargs jq -r '.metrics.token_cost // empty' 2>/dev/null)
fi

# Build status line
STATUS_LINE=""

# Project name in square brackets (cyan)
STATUS_LINE="${STATUS_LINE}${CYAN}[${PROJECT}]${NC}"

# Branch name (cyan)
STATUS_LINE="${STATUS_LINE} ${CYAN}${BRANCH}${NC}"

# File changes (yellow if dirty, green if clean)
if [ "$TOTAL_CHANGES" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${YELLOW}±${TOTAL_CHANGES}${NC}"
else
  STATUS_LINE="${STATUS_LINE} ${GREEN}±0${NC}"
fi

# Ahead/behind (green for ahead, red for behind)
if [ "$AHEAD" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${GREEN}↑${AHEAD}${NC}"
fi
if [ "$BEHIND" -gt 0 ]; then
  STATUS_LINE="${STATUS_LINE} ${RED}↓${BEHIND}${NC}"
fi

# Issue number (magenta, clickable if GitHub repo detected)
if [ -n "$ISSUE_ID" ]; then
  if [ -n "$GITHUB_REPO" ]; then
    # Create clickable link to GitHub issue
    ISSUE_URL="${GITHUB_REPO}/issues/${ISSUE_ID}"
    STATUS_LINE="${STATUS_LINE}$(format_status_link "WORK#${ISSUE_ID}" "$ISSUE_URL" "$MAGENTA")"
  else
    # Fallback: non-clickable
    STATUS_LINE="${STATUS_LINE} ${MAGENTA}WORK#${ISSUE_ID}${NC}"
  fi
fi

# PR number (blue, clickable if GitHub repo detected)
if [ -n "$PR_NUMBER" ] && [ "$PR_NUMBER" != "0" ]; then
  if [ -n "$GITHUB_REPO" ]; then
    # Create clickable link to GitHub PR
    PR_URL="${GITHUB_REPO}/pull/${PR_NUMBER}"
    STATUS_LINE="${STATUS_LINE}$(format_status_link "PR#${PR_NUMBER}" "$PR_URL" "$BLUE")"
  else
    # Fallback: non-clickable
    STATUS_LINE="${STATUS_LINE} ${BLUE}PR#${PR_NUMBER}${NC}"
  fi
fi

# Build metrics display (right-aligned, dim color)
METRICS_LINE=""
if [ -n "$CONTEXT_FREE" ] && [ "$CONTEXT_FREE" != "0" ]; then
  METRICS_LINE="${DIM}${CONTEXT_FREE}%FREE${NC}"
fi

if [ -n "$TOKEN_COST" ] && [ "$TOKEN_COST" != "0" ]; then
  if [ -n "$METRICS_LINE" ]; then
    METRICS_LINE="${METRICS_LINE} ${DIM}|${NC}"
  fi
  METRICS_LINE="${METRICS_LINE} ${DIM}\$${TOKEN_COST}${NC}"
fi

# Append metrics to status line (right-aligned with spacing)
if [ -n "$METRICS_LINE" ]; then
  STATUS_LINE="${STATUS_LINE}  ${METRICS_LINE}"
fi

# Output first line (strip color codes if NO_COLOR is set)
if [ -n "${NO_COLOR:-}" ]; then
  echo "$STATUS_LINE" | sed 's/\x1b\[[0-9;]*m//g'
else
  echo -e "$STATUS_LINE"
fi

# Last prompt on second line (dim)
if [ -n "$LAST_PROMPT" ]; then
  PROMPT_LINE="${DIM}last: ${LAST_PROMPT}${NC}"
  if [ -n "${NO_COLOR:-}" ]; then
    echo "$PROMPT_LINE" | sed 's/\x1b\[[0-9;]*m//g'
  else
    echo -e "$PROMPT_LINE"
  fi
fi

exit 0
