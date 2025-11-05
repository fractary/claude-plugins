#!/bin/bash
# Generate session summary
set -euo pipefail

SESSION_FILE="${1:?Session file path required}"

if [[ ! -f "$SESSION_FILE" ]]; then
    echo "Error: Session file not found: $SESSION_FILE" >&2
    exit 1
fi

# Extract metadata from frontmatter
SESSION_ID=$(grep "^session_id:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "Unknown")
ISSUE_NUMBER=$(grep "^issue_number:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "Unknown")
ISSUE_TITLE=$(grep "^issue_title:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "Unknown")
STARTED=$(grep "^started:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "Unknown")
ENDED=$(grep "^ended:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "")
DURATION=$(grep "^duration_minutes:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "")
STATUS=$(grep "^status:" "$SESSION_FILE" | cut -d: -f2- | xargs || echo "Unknown")

# Count messages
MESSAGE_COUNT=$(grep -c "^### \[" "$SESSION_FILE" 2>/dev/null || echo "0")

# Count code blocks
CODE_BLOCK_COUNT=$(grep -c "^\`\`\`" "$SESSION_FILE" 2>/dev/null || echo "0")
CODE_BLOCK_COUNT=$((CODE_BLOCK_COUNT / 2))  # Opening and closing

# Extract key sections (if present)
KEY_DECISIONS=$(sed -n '/## Key Decisions/,/^##/p' "$SESSION_FILE" | grep -v "^##" || echo "")
FILES_MODIFIED=$(sed -n '/## Files /,/^##/p' "$SESSION_FILE" | grep -v "^##" || echo "")
ISSUES_ENCOUNTERED=$(sed -n '/## Issues Encountered/,/^##/p' "$SESSION_FILE" | grep -v "^##" || echo "")

# Format duration
DURATION_STR="Unknown"
if [[ -n "$DURATION" && "$DURATION" != "0" ]]; then
    HOURS=$((DURATION / 60))
    MINUTES=$((DURATION % 60))
    if [[ $HOURS -gt 0 ]]; then
        DURATION_STR="${HOURS}h ${MINUTES}m"
    else
        DURATION_STR="${MINUTES}m"
    fi
fi

# Generate summary
cat <<EOF
Session Summary: Issue #$ISSUE_NUMBER

**Title**: $ISSUE_TITLE
**Session ID**: $SESSION_ID
**Started**: $STARTED
EOF

if [[ -n "$ENDED" ]]; then
    echo "**Ended**: $ENDED"
fi

cat <<EOF
**Duration**: $DURATION_STR
**Status**: $STATUS
**Messages**: $MESSAGE_COUNT
**Code Blocks**: $CODE_BLOCK_COUNT

EOF

if [[ -n "$KEY_DECISIONS" ]]; then
    echo "**Key Decisions**:"
    echo "$KEY_DECISIONS"
    echo
fi

if [[ -n "$FILES_MODIFIED" ]]; then
    echo "**Files Modified**:"
    echo "$FILES_MODIFIED"
    echo
fi

if [[ -n "$ISSUES_ENCOUNTERED" ]]; then
    echo "**Issues Encountered**:"
    echo "$ISSUES_ENCOUNTERED"
    echo
fi
