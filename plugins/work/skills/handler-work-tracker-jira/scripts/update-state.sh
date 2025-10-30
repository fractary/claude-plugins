#!/bin/bash
# Handler: Jira Update State
# Transitions issue to any universal state via Jira workflow transitions

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <target_state>" >&2
    echo "  Universal states: open, in_progress, in_review, done, closed" >&2
    echo "  Example: $0 PROJ-123 in_progress" >&2
    exit 2
fi

ISSUE_KEY="$1"
TARGET_STATE="$2"

# Validate issue key format
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

# Validate target state
case "$TARGET_STATE" in
    open|in_progress|in_review|done|closed)
        # Valid universal state
        ;;
    *)
        echo "Error: Invalid target state: $TARGET_STATE" >&2
        echo "  Must be one of: open, in_progress, in_review, done, closed" >&2
        exit 3
        ;;
esac

# Check required environment variables
if [ -z "${JIRA_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_URL, JIRA_EMAIL, and JIRA_TOKEN must be set" >&2
    exit 3
fi

# Generate Basic Auth header
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Load state mappings from config
CONFIG_FILE=".fractary/plugins/work/config.json"
if [ -f "$CONFIG_FILE" ]; then
    case "$TARGET_STATE" in
        open)
            JIRA_STATE=$(jq -r '.handlers["work-tracker"].jira.states.open // "To Do"' "$CONFIG_FILE")
            JIRA_STATES="$JIRA_STATE|Open|To Do|Backlog"
            ;;
        in_progress)
            JIRA_STATE=$(jq -r '.handlers["work-tracker"].jira.states.in_progress // "In Progress"' "$CONFIG_FILE")
            JIRA_STATES="$JIRA_STATE|In Progress|In Development"
            ;;
        in_review)
            JIRA_STATE=$(jq -r '.handlers["work-tracker"].jira.states.in_review // "In Review"' "$CONFIG_FILE")
            JIRA_STATES="$JIRA_STATE|In Review|Code Review|Review"
            ;;
        done)
            JIRA_STATE=$(jq -r '.handlers["work-tracker"].jira.states.done // "Done"' "$CONFIG_FILE")
            JIRA_STATES="$JIRA_STATE|Done|Resolved"
            ;;
        closed)
            JIRA_STATE=$(jq -r '.handlers["work-tracker"].jira.states.closed // "Closed"' "$CONFIG_FILE")
            JIRA_STATES="$JIRA_STATE|Closed|Cancelled"
            ;;
    esac
else
    # Default state mappings
    case "$TARGET_STATE" in
        open)
            JIRA_STATES="To Do|Open|Backlog"
            ;;
        in_progress)
            JIRA_STATES="In Progress|In Development"
            ;;
        in_review)
            JIRA_STATES="In Review|Code Review|Review"
            ;;
        done)
            JIRA_STATES="Done|Resolved"
            ;;
        closed)
            JIRA_STATES="Closed|Cancelled"
            ;;
    esac
fi

# Step 1: Get available transitions for the issue
transitions_response=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY/transitions" 2>&1)

http_code=$(echo "$transitions_response" | tail -n 1)
transitions_body=$(echo "$transitions_response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 200 ]; then
    case "$http_code" in
        404)
            echo "Error: Issue $ISSUE_KEY not found" >&2
            exit 10
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to get transitions (HTTP $http_code)" >&2
            echo "$transitions_body" >&2
            exit 1
            ;;
    esac
fi

# Step 2: Find transition to target state
# Try each possible Jira state name
IFS='|' read -ra STATE_ARRAY <<< "$JIRA_STATES"
transition_id=""
transition_name=""
target_jira_state=""

for state in "${STATE_ARRAY[@]}"; do
    # Try exact match first
    found_id=$(echo "$transitions_body" | jq -r --arg state "$state" \
      '.transitions[] | select(.to.name == $state) | .id' | head -1)

    if [ -n "$found_id" ] && [ "$found_id" != "null" ]; then
        transition_id="$found_id"
        target_jira_state="$state"
        transition_name=$(echo "$transitions_body" | jq -r --arg id "$transition_id" \
          '.transitions[] | select(.id == $id) | .name')
        break
    fi

    # Try case-insensitive match
    found_id=$(echo "$transitions_body" | jq -r --arg state "$state" \
      '.transitions[] | select(.to.name | ascii_downcase == ($state | ascii_downcase)) | .id' | head -1)

    if [ -n "$found_id" ] && [ "$found_id" != "null" ]; then
        transition_id="$found_id"
        target_jira_state="$state"
        transition_name=$(echo "$transitions_body" | jq -r --arg id "$transition_id" \
          '.transitions[] | select(.id == $id) | .name')
        break
    fi
done

if [ -z "$transition_id" ] || [ "$transition_id" = "null" ]; then
    echo "Error: No valid transition to '$TARGET_STATE' state for issue $ISSUE_KEY" >&2
    echo "  Available transitions:" >&2
    echo "$transitions_body" | jq -r '.transitions[] | "  - \(.name) → \(.to.name)"' >&2
    echo "  Tried target states: $JIRA_STATES" >&2
    exit 3
fi

# Step 3: Build transition payload (no comment for simple state update)
TRANSITION_PAYLOAD=$(jq -n --arg id "$transition_id" '{transition: {id: $id}}')

# Step 4: Execute transition
transition_response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$TRANSITION_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY/transitions" 2>&1)

http_code=$(echo "$transition_response" | tail -n 1)
transition_result=$(echo "$transition_response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 204 ] && [ "$http_code" -ne 200 ]; then
    echo "Error: Failed to transition issue $ISSUE_KEY (HTTP $http_code)" >&2
    echo "$transition_result" >&2
    exit 1
fi

# Step 5: Fetch updated issue to confirm
final_issue=$(curl -s -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=status,updated" 2>/dev/null)

# Output success JSON
echo "$final_issue" | jq -c \
  --arg universal "$TARGET_STATE" \
  --arg transition "$transition_name" \
  --arg target "$target_jira_state" \
  '{
    issue_key: .key,
    status: .fields.status.name,
    updated: .fields.updated,
    universal_state: $universal,
    transition_used: $transition,
    target_state: $target,
    platform: "jira"
  }'

exit 0
