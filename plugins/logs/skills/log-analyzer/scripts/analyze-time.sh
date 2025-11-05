#!/bin/bash
# Analyze time spent on work
set -euo pipefail

SINCE_DATE="${1:?Since date required (YYYY-MM-DD)}"
UNTIL_DATE="${2:-$(date +%Y-%m-%d)}"
CONFIG_FILE="${FRACTARY_LOGS_CONFIG:-.fractary/plugins/logs/config.json}"

# Load configuration
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "Error: Configuration not found at $CONFIG_FILE" >&2
    exit 1
fi

LOG_DIR=$(jq -r '.storage.local_path // "/logs"' "$CONFIG_FILE")
SESSION_DIR="$LOG_DIR/sessions"

# Check if sessions directory exists
if [[ ! -d "$SESSION_DIR" ]]; then
    echo "No sessions directory found"
    exit 0
fi

# Find session logs in date range
SESSIONS=$(find "$SESSION_DIR" -type f -newermt "$SINCE_DATE" ! -newermt "$UNTIL_DATE" 2>/dev/null || true)

if [[ -z "$SESSIONS" ]]; then
    echo "No sessions found between $SINCE_DATE and $UNTIL_DATE"
    exit 0
fi

echo "Time Analysis ($SINCE_DATE to $UNTIL_DATE)"
echo

# Track statistics
TOTAL_DURATION=0
SESSION_COUNT=0
declare -A DURATIONS_BY_ISSUE

# Process each session
while IFS= read -r SESSION_FILE; do
    # Extract duration
    DURATION=$(grep "^duration_minutes:" "$SESSION_FILE" | cut -d: -f2- | xargs 2>/dev/null || echo "0")

    if [[ "$DURATION" -gt 0 ]]; then
        TOTAL_DURATION=$((TOTAL_DURATION + DURATION))
        ((SESSION_COUNT++))

        # Extract issue number
        ISSUE=$(grep "^issue_number:" "$SESSION_FILE" | cut -d: -f2- | xargs 2>/dev/null || echo "unknown")

        # Track by issue
        CURRENT=${DURATIONS_BY_ISSUE["$ISSUE"]:-0}
        DURATIONS_BY_ISSUE["$ISSUE"]=$((CURRENT + DURATION))
    fi
done <<< "$SESSIONS"

# Calculate averages
if [[ $SESSION_COUNT -eq 0 ]]; then
    echo "No completed sessions found"
    exit 0
fi

AVG_DURATION=$((TOTAL_DURATION / SESSION_COUNT))

# Format total duration
TOTAL_HOURS=$((TOTAL_DURATION / 60))
TOTAL_MINUTES=$((TOTAL_DURATION % 60))

# Format average duration
AVG_HOURS=$((AVG_DURATION / 60))
AVG_MINUTES=$((AVG_DURATION % 60))

# Display results
cat <<EOF
**Overall Statistics**:
- Total sessions: $SESSION_COUNT
- Total development time: ${TOTAL_HOURS}h ${TOTAL_MINUTES}m
- Average session duration: ${AVG_HOURS}h ${AVG_MINUTES}m

**Time by Issue**:
EOF

# Sort issues by time spent (descending)
for ISSUE in "${!DURATIONS_BY_ISSUE[@]}"; do
    DUR=${DURATIONS_BY_ISSUE[$ISSUE]}
    echo "$DUR $ISSUE"
done | sort -rn | head -10 | while read -r DUR ISSUE; do
    HOURS=$((DUR / 60))
    MINUTES=$((DUR % 60))
    echo "- Issue #$ISSUE: ${HOURS}h ${MINUTES}m"
done

echo
echo "Analysis complete"
