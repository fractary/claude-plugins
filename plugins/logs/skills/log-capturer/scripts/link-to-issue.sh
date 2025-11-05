#!/bin/bash
# Link session log to GitHub issue with a comment
set -euo pipefail

SESSION_FILE="${1:?Session file path required}"
ISSUE_NUMBER="${2:?Issue number required}"

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Warning: gh CLI not found. Cannot comment on issue."
    echo "Session logged locally: $SESSION_FILE"
    exit 0
fi

# Extract session metadata
SESSION_ID=$(grep "session_id:" "$SESSION_FILE" | head -1 | cut -d: -f2- | xargs)
START_TIME=$(grep "started:" "$SESSION_FILE" | head -1 | cut -d: -f2- | xargs)
DURATION=$(grep "duration_minutes:" "$SESSION_FILE" | head -1 | cut -d: -f2- | xargs || echo "ongoing")

# Format duration
if [[ "$DURATION" != "ongoing" ]]; then
    HOURS=$((DURATION / 60))
    MINUTES=$((DURATION % 60))
    if [[ $HOURS -gt 0 ]]; then
        DURATION_STR="${HOURS}h ${MINUTES}m"
    else
        DURATION_STR="${MINUTES}m"
    fi
else
    DURATION_STR="ongoing"
fi

# Create comment on issue
COMMENT=$(cat <<EOF
💬 **Session Logged**

Claude Code session captured:
- **Session**: $SESSION_ID
- **Started**: $(date -d "$START_TIME" '+%Y-%m-%d %H:%M UTC' 2>/dev/null || echo "$START_TIME")
- **Duration**: $DURATION_STR

Log location: \`$SESSION_FILE\`

This session will be archived with other logs when work completes.
EOF
)

# Post comment
gh issue comment "$ISSUE_NUMBER" --body "$COMMENT"

echo "Comment posted to issue #$ISSUE_NUMBER"
