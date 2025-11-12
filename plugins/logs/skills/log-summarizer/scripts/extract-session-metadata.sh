#!/bin/bash
# Extract session metadata for summary generation
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

# Extract file references (common patterns)
FILES_MENTIONED=$(grep -oE '`[^`]+\.(ts|js|json|md|py|sh|yml|yaml|toml|tsx|jsx|go|rs)`' "$SESSION_FILE" 2>/dev/null | sort -u || echo "")
FILE_COUNT=$(echo "$FILES_MENTIONED" | grep -c '.' || echo "0")

# Count errors mentioned
ERROR_COUNT=$(grep -ciE '(error|exception|failed|failure):' "$SESSION_FILE" 2>/dev/null || echo "0")

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

# Estimate complexity (simple heuristic)
COMPLEXITY="low"
if [[ $MESSAGE_COUNT -gt 50 ]] || [[ $CODE_BLOCK_COUNT -gt 10 ]] || [[ $FILE_COUNT -gt 5 ]]; then
    COMPLEXITY="medium"
fi
if [[ $MESSAGE_COUNT -gt 100 ]] || [[ $CODE_BLOCK_COUNT -gt 20 ]] || [[ $FILE_COUNT -gt 10 ]]; then
    COMPLEXITY="high"
fi

# Output as JSON
cat <<EOF
{
  "session_id": "$SESSION_ID",
  "issue_number": "$ISSUE_NUMBER",
  "issue_title": "$ISSUE_TITLE",
  "started": "$STARTED",
  "ended": "$ENDED",
  "duration_minutes": $DURATION,
  "duration_formatted": "$DURATION_STR",
  "status": "$STATUS",
  "message_count": $MESSAGE_COUNT,
  "code_block_count": $CODE_BLOCK_COUNT,
  "file_count": $FILE_COUNT,
  "error_count": $ERROR_COUNT,
  "complexity": "$COMPLEXITY"
}
EOF
