#!/bin/bash
# Handler: Jira Reopen Issue
# Transitions issue from closed back to open state with optional comment

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_key> [reopen_comment] [work_id]" >&2
    echo "  Example: $0 PROJ-123 'Needs more work' 'faber-abc123'" >&2
    exit 2
fi

ISSUE_KEY="$1"
REOPEN_COMMENT="${2:-}"
WORK_ID="${3:-}"

# Validate issue key format
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

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

# Step 2: Find transition to "Open", "To Do", or "Backlog" state
# Load target states from config if available
CONFIG_FILE=".fractary/plugins/work/config.json"
if [ -f "$CONFIG_FILE" ]; then
    OPEN_STATE=$(jq -r '.handlers["work-tracker"].jira.states.open // "To Do"' "$CONFIG_FILE")
else
    OPEN_STATE="To Do"
fi

# Find transition that leads to Open, To Do, or Backlog
transition_id=$(echo "$transitions_body" | jq -r --arg open "$OPEN_STATE" \
  '.transitions[] | select(.to.name == $open or .to.name == "Open" or .to.name == "To Do" or .to.name == "Backlog" or .to.name == "Reopen") | .id' | head -1)

if [ -z "$transition_id" ] || [ "$transition_id" = "null" ]; then
    echo "Error: No valid transition to reopen issue $ISSUE_KEY" >&2
    echo "  Available transitions:" >&2
    echo "$transitions_body" | jq -r '.transitions[] | "  - \(.name) → \(.to.name)"' >&2
    exit 3
fi

transition_name=$(echo "$transitions_body" | jq -r --arg id "$transition_id" \
  '.transitions[] | select(.id == $id) | .name')
target_state=$(echo "$transitions_body" | jq -r --arg id "$transition_id" \
  '.transitions[] | select(.id == $id) | .to.name')

# Step 3: Build transition payload
# If reopen comment provided, include it in the transition
if [ -n "$REOPEN_COMMENT" ]; then
    # Build ADF for comment
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORK_COMMON_DIR="$SCRIPT_DIR/../../../work-common/scripts"

    # Build comment with FABER metadata
    if [ -n "$WORK_ID" ]; then
        FULL_COMMENT="**FABER Work ID:** $WORK_ID

**Status:** Reopened

$REOPEN_COMMENT"
    else
        FULL_COMMENT="$REOPEN_COMMENT"
    fi

    # Convert to ADF
    COMMENT_ADF=$("$WORK_COMMON_DIR/markdown-to-adf.sh" "$FULL_COMMENT" 2>/dev/null || echo '{"type":"doc","version":1,"content":[{"type":"paragraph","content":[{"type":"text","text":"'"$(echo "$FULL_COMMENT" | sed 's/"/\\"/g')"'"}]}]}')

    # Build transition payload with comment
    TRANSITION_PAYLOAD=$(jq -n \
      --arg id "$transition_id" \
      --argjson comment "$COMMENT_ADF" \
      '{
        transition: {id: $id},
        update: {
          comment: [{
            add: {body: $comment}
          }]
        }
      }')
else
    # Simple transition without comment
    TRANSITION_PAYLOAD=$(jq -n --arg id "$transition_id" '{transition: {id: $id}}')
fi

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
    echo "Error: Failed to reopen issue $ISSUE_KEY (HTTP $http_code)" >&2
    echo "$transition_result" >&2
    exit 1
fi

# Step 5: Fetch updated issue to confirm
final_issue=$(curl -s -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=status,updated" 2>/dev/null)

# Output success JSON
echo "$final_issue" | jq -c --arg transition "$transition_name" --arg target "$target_state" '{
  issue_key: .key,
  status: .fields.status.name,
  updated: .fields.updated,
  transition_used: $transition,
  target_state: $target,
  reopened: true,
  platform: "jira"
}'

exit 0
