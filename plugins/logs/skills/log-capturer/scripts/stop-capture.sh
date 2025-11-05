#!/bin/bash
# Stop the active session capture
set -euo pipefail

# Check for active session
ACTIVE_SESSION_FILE="/tmp/fractary-logs/active-session"
if [[ ! -f "$ACTIVE_SESSION_FILE" ]]; then
    echo "No active session to stop"
    exit 0
fi

# Load session context
SESSION_INFO=$(cat "$ACTIVE_SESSION_FILE")
SESSION_ID=$(echo "$SESSION_INFO" | jq -r '.session_id')
LOG_FILE=$(echo "$SESSION_INFO" | jq -r '.log_file')
START_TIME=$(echo "$SESSION_INFO" | jq -r '.start_time')

if [[ ! -f "$LOG_FILE" ]]; then
    echo "Error: Session file not found: $LOG_FILE"
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

echo "Session capture completed: $LOG_FILE"
echo "Duration: ${DURATION_MINUTES} minutes"
echo "Messages: $MESSAGE_COUNT"
