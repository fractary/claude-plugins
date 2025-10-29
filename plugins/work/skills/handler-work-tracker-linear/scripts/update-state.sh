#!/bin/bash
# Handler: Linear Update State
# Universal state transition handler for Linear issues

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <target_state>" >&2
    exit 2
fi

ISSUE_ID="$1"
TARGET_STATE="$2"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Load configuration for state mappings
CONFIG_FILE=".faber/plugins/work/config.json"
if [ -f "$CONFIG_FILE" ]; then
    LINEAR_STATE=$(jq -r --arg state "$TARGET_STATE" '.handlers["work-tracker"].linear.states[$state] // ""' "$CONFIG_FILE")
else
    LINEAR_STATE=""
fi

# Map universal states to Linear state names
if [ -z "$LINEAR_STATE" ]; then
    case "$TARGET_STATE" in
        "open")
            LINEAR_STATE="Todo"
            ;;
        "in_progress")
            LINEAR_STATE="In Progress"
            ;;
        "in_review")
            LINEAR_STATE="In Review"
            ;;
        "done")
            LINEAR_STATE="Done"
            ;;
        "closed")
            LINEAR_STATE="Canceled"
            ;;
        *)
            # Assume it's already a Linear state name
            LINEAR_STATE="$TARGET_STATE"
            ;;
    esac
fi

# Step 1: Get issue's team and find state UUID
ISSUE_QUERY=$(jq -n \
  --arg query 'query GetIssue($id: String!) { issue(id: $id) { team { id states { nodes { id name type } } } } }' \
  --arg id "$ISSUE_ID" \
  '{query: $query, variables: {id: $id}}')

ISSUE_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$ISSUE_QUERY")

# Check if issue exists
if echo "$ISSUE_RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    echo "Error: Issue $ISSUE_ID not found" >&2
    exit 10
fi

# Find target state UUID
STATE_ID=$(echo "$ISSUE_RESPONSE" | jq -r --arg stateName "$LINEAR_STATE" \
  '.data.issue.team.states.nodes[] | select(.name == $stateName) | .id' | head -1)

if [ -z "$STATE_ID" ] || [ "$STATE_ID" = "null" ]; then
    echo "Error: Could not find state '$LINEAR_STATE' for issue" >&2
    exit 3
fi

# Step 2: Update issue state
read -r -d '' UPDATE_MUTATION <<'EOF' || true
mutation UpdateIssueState($issueId: String!, $stateId: String!) {
  issueUpdate(id: $issueId, input: {stateId: $stateId}) {
    success
    issue {
      id
      identifier
      state {
        name
        type
      }
      url
    }
  }
}
EOF

UPDATE_REQUEST=$(jq -n \
  --arg query "$UPDATE_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg stateId "$STATE_ID" \
  '{query: $query, variables: {issueId: $issueId, stateId: $stateId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    echo "Error: Failed to update state: $ERROR_MSG" >&2
    exit 1
fi

# Normalize state back to universal format
STATE_TYPE=$(echo "$RESPONSE" | jq -r '.data.issueUpdate.issue.state.type')
case "$STATE_TYPE" in
    "backlog"|"unstarted")
        NORMALIZED_STATE="open"
        ;;
    "started")
        NORMALIZED_STATE="in_progress"
        ;;
    "completed")
        NORMALIZED_STATE="done"
        ;;
    "canceled")
        NORMALIZED_STATE="closed"
        ;;
    *)
        NORMALIZED_STATE="$TARGET_STATE"
        ;;
esac

# Output normalized JSON
echo "$RESPONSE" | jq --arg state "$NORMALIZED_STATE" '.data.issueUpdate.issue | {
  id: .identifier,
  identifier: .identifier,
  state: $state,
  url: .url,
  platform: "linear"
}'

exit 0
