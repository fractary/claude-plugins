#!/bin/bash
# Start capturing a session for an issue
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE"
    echo "Run /fractary-logs:init to initialize"
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
SESSION_DIR="$LOG_DIR/sessions"

# Create session directory if needed
mkdir -p "$SESSION_DIR"

# Generate session ID
SESSION_ID="session-${ISSUE_NUMBER}-$(date +%Y-%m-%d-%H%M)"
LOG_FILE="$SESSION_DIR/$SESSION_ID.md"

# Check if session already exists
if [[ -f "$LOG_FILE" ]]; then
    echo "Error: Session file already exists: $LOG_FILE"
    exit 1
fi

# Get issue information from GitHub (if gh available and configured)
ISSUE_TITLE=""
ISSUE_URL=""
if command -v gh &> /dev/null; then
    ISSUE_INFO=$(gh issue view "$ISSUE_NUMBER" --json title,url 2>/dev/null || echo "{}")
    ISSUE_TITLE=$(echo "$ISSUE_INFO" | jq -r '.title // ""')
    ISSUE_URL=$(echo "$ISSUE_INFO" | jq -r '.url // ""')
fi

# Create session file with frontmatter
cat > "$LOG_FILE" <<EOF
---
session_id: $SESSION_ID
issue_number: $ISSUE_NUMBER
issue_title: ${ISSUE_TITLE:-"Issue #$ISSUE_NUMBER"}
issue_url: ${ISSUE_URL:-""}
started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
participant: Claude Code
model: claude-sonnet-4-5-20250929
log_type: session
status: active
---

# Session Log: ${ISSUE_TITLE:-"Issue #$ISSUE_NUMBER"}

**Issue**: ${ISSUE_URL:+"[$ISSUE_NUMBER]($ISSUE_URL)"}${ISSUE_URL:-"#$ISSUE_NUMBER"}
**Started**: $(date -u '+%Y-%m-%d %H:%M UTC')

## Conversation

EOF

# Save session context
mkdir -p /tmp/fractary-logs
cat > /tmp/fractary-logs/active-session <<EOF
{
  "session_id": "$SESSION_ID",
  "issue_number": "$ISSUE_NUMBER",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "log_file": "$LOG_FILE"
}
EOF

# Output result
echo "Session capture started: $LOG_FILE"
echo "$SESSION_ID"
