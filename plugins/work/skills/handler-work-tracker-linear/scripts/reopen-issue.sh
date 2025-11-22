#!/bin/bash
# Handler: Linear Reopen Issue
# Reopens a closed Linear issue by transitioning to "Todo" state

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [reopen_comment]" >&2
    exit 2
fi

ISSUE_ID="$1"
REOPEN_COMMENT="${2:-Reopened by FABER workflow}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Load configuration to get state mappings
CONFIG_FILE=".fractary/plugins/work/config.json"
if [ -f "$CONFIG_FILE" ]; then
    OPEN_STATE=$(jq -r '.handlers["work-tracker"].linear.states.open // "Todo"' "$CONFIG_FILE")
else
    OPEN_STATE="Todo"
fi

# Step 1: Get issue's team and find "Todo" state UUID
ISSUE_QUERY=$(jq -n \
  --arg query 'query GetIssue($id: String!) { issue(id: $id) { team { id states { nodes { id name type } } } state { type } } }' \
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

# Check if issue is already open
CURRENT_STATE_TYPE=$(echo "$ISSUE_RESPONSE" | jq -r '.data.issue.state.type')
if [ "$CURRENT_STATE_TYPE" != "completed" ] && [ "$CURRENT_STATE_TYPE" != "canceled" ]; then
    echo "Warning: Issue $ISSUE_ID is not closed" >&2
    exit 3
fi

# Find Todo state UUID
TODO_STATE_ID=$(echo "$ISSUE_RESPONSE" | jq -r --arg stateName "$OPEN_STATE" \
  '.data.issue.team.states.nodes[] | select(.name == $stateName or .type == "backlog" or .type == "unstarted") | .id' | head -1)

if [ -z "$TODO_STATE_ID" ] || [ "$TODO_STATE_ID" = "null" ]; then
    echo "Error: Could not find 'Todo' state for issue" >&2
    exit 3
fi

# Step 2: Post reopen comment if provided
if [ -n "$REOPEN_COMMENT" ]; then
    read -r -d '' COMMENT_MUTATION <<'EOF' || true
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) {
    success
  }
}
EOF

    COMMENT_REQUEST=$(jq -n \
      --arg query "$COMMENT_MUTATION" \
      --arg issueId "$ISSUE_ID" \
      --arg body "$REOPEN_COMMENT" \
      '{query: $query, variables: {issueId: $issueId, body: $body}}')

    curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$COMMENT_REQUEST" > /dev/null
fi

# Step 3: Update issue state to "Todo"
read -r -d '' UPDATE_MUTATION <<'EOF' || true
mutation UpdateIssueState($issueId: String!, $stateId: String!) {
  issueUpdate(id: $issueId, input: {stateId: $stateId}) {
    success
    issue {
      id
      identifier
      state {
        name
      }
      url
    }
  }
}
EOF

UPDATE_REQUEST=$(jq -n \
  --arg query "$UPDATE_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg stateId "$TODO_STATE_ID" \
  '{query: $query, variables: {issueId: $issueId, stateId: $stateId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    echo "Error: Failed to reopen issue: $ERROR_MSG" >&2
    exit 1
fi

# Output normalized JSON
echo "$RESPONSE" | jq '.data.issueUpdate.issue | {
  id: .identifier,
  identifier: .identifier,
  state: "open",
  url: .url,
  platform: "linear"
}'

exit 0
