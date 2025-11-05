#!/bin/bash
# Start capturing a session for an issue
set -euo pipefail

ISSUE_NUMBER="${1:?Issue number required}"

# Input validation: Issue number should be numeric
if ! [[ "$ISSUE_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: Issue number must be numeric" >&2
    exit 1
fi

CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE"
    echo "Run /fractary-logs:init to initialize"
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
SESSION_DIR="$LOG_DIR/sessions"

# Get model name from config or environment, fallback to default
MODEL_NAME="${CLAUDE_MODEL:-$(jq -r '.session_logging.model_name // "claude-sonnet-4-5-20250929"' "$CONFIG_FILE")}"

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
model: $MODEL_NAME
log_type: session
status: active
---

# Session Log: ${ISSUE_TITLE:-"Issue #$ISSUE_NUMBER"}

**Issue**: ${ISSUE_URL:+"[$ISSUE_NUMBER]($ISSUE_URL)"}${ISSUE_URL:-"#$ISSUE_NUMBER"}
**Started**: $(date -u '+%Y-%m-%d %H:%M UTC')

## Conversation

EOF

# Save session context in secure temp directory
# Use XDG_RUNTIME_DIR if available (secure per-user temp), otherwise create secure temp dir
if [[ -n "${XDG_RUNTIME_DIR:-}" && -d "$XDG_RUNTIME_DIR" ]]; then
    SESSION_TMP="$XDG_RUNTIME_DIR/fractary-logs"
    mkdir -p "$SESSION_TMP"
    chmod 700 "$SESSION_TMP"
else
    # Create secure temp directory
    SESSION_TMP=$(mktemp -d -t fractary-logs.XXXXXX)
    chmod 700 "$SESSION_TMP"
    # Store temp dir location for cleanup
    echo "$SESSION_TMP" > "${LOG_DIR}/.session-tmp-dir" 2>/dev/null || true
fi

cat > "$SESSION_TMP/active-session" <<EOF
{
  "session_id": "$SESSION_ID",
  "issue_number": "$ISSUE_NUMBER",
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "log_file": "$LOG_FILE",
  "temp_dir": "$SESSION_TMP"
}
EOF

# Output result
echo "Session capture started: $LOG_FILE"
echo "$SESSION_ID"
