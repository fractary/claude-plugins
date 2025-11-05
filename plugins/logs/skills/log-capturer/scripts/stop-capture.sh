#!/bin/bash
# Stop the active session capture
set -euo pipefail

CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Find active session file in secure temp directory
if [[ -n "${XDG_RUNTIME_DIR:-}" && -f "$XDG_RUNTIME_DIR/fractary-logs/active-session" ]]; then
    ACTIVE_SESSION_FILE="$XDG_RUNTIME_DIR/fractary-logs/active-session"
else
    # Try to find temp dir from session marker
    LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE" 2>/dev/null || echo "/logs")
    if [[ -f "${LOG_DIR}/.session-tmp-dir" ]]; then
        SESSION_TMP=$(cat "${LOG_DIR}/.session-tmp-dir")
        ACTIVE_SESSION_FILE="$SESSION_TMP/active-session"
    else
        # Fallback to old location for backwards compatibility
        ACTIVE_SESSION_FILE="/tmp/fractary-logs/active-session"
    fi
fi

# Check for active session
if [[ ! -f "$ACTIVE_SESSION_FILE" ]]; then
    echo "No active session to stop"
    exit 0
fi

# Load session context
SESSION_INFO=$(cat "$ACTIVE_SESSION_FILE")
SESSION_ID=$(echo "$SESSION_INFO" | jq -r '.session_id')
LOG_FILE=$(echo "$SESSION_INFO" | jq -r '.log_file')
START_TIME=$(echo "$SESSION_INFO" | jq -r '.start_time')
TEMP_DIR=$(echo "$SESSION_INFO" | jq -r '.temp_dir // ""')

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Session file not found: $LOG_FILE" >&2
    exit 1
fi

# Calculate duration
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
START_EPOCH=$(date -d "$START_TIME" +%s 2>/dev/null || date -j -f "%Y-%m-%dT%H:%M:%SZ" "$START_TIME" +%s 2>/dev/null || echo "0")
END_EPOCH=$(date +%s)
DURATION_SECONDS=$((END_EPOCH - START_EPOCH))
DURATION_MINUTES=$((DURATION_SECONDS / 60))

# Count messages in session
MESSAGE_COUNT=$(grep -c "^### \[" "$LOG_FILE" || echo "0")

# Update frontmatter with completion info
# This is a simple approach - insert ended, duration_minutes, and change status before the closing ---
TEMP_FILE=$(mktemp)

# Read the file and update frontmatter
awk -v end_time="$END_TIME" -v duration="$DURATION_MINUTES" '
BEGIN { in_frontmatter=0; frontmatter_done=0 }
/^---$/ {
    if (!frontmatter_done) {
        if (in_frontmatter) {
            # Closing frontmatter, add our fields
            print "ended: " end_time
            print "duration_minutes: " duration
            frontmatter_done=1
        } else {
            in_frontmatter=1
        }
    }
    print
    next
}
/^status:/ {
    if (in_frontmatter && !frontmatter_done) {
        print "status: completed"
        next
    }
}
{ print }
' "$LOG_FILE" > "$TEMP_FILE"

mv "$TEMP_FILE" "$LOG_FILE"

# Append session summary
cat >> "$LOG_FILE" <<EOF

## Session Summary

**Total Messages**: $MESSAGE_COUNT
**Duration**: ${DURATION_MINUTES}m
**Ended**: $(date -u '+%Y-%m-%d %H:%M UTC')
**Status**: Completed
EOF

# Clear active session
rm "$ACTIVE_SESSION_FILE"

# Clean up temp directory if it was created by us (not XDG_RUNTIME_DIR)
if [[ -n "$TEMP_DIR" && "$TEMP_DIR" != "${XDG_RUNTIME_DIR:-}/fractary-logs" && -d "$TEMP_DIR" ]]; then
    rmdir "$TEMP_DIR" 2>/dev/null || true
fi

# Remove temp dir marker
if [[ -f "${LOG_DIR}/.session-tmp-dir" ]]; then
    rm "${LOG_DIR}/.session-tmp-dir" 2>/dev/null || true
fi

echo "Session capture completed: $LOG_FILE"
echo "Duration: ${DURATION_MINUTES} minutes"
echo "Messages: $MESSAGE_COUNT"
