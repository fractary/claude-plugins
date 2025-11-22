#!/bin/bash
# Handler: Linear Close Issue
# Closes a Linear issue by transitioning to "Done" state

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [close_comment] [work_id]" >&2
    exit 2
fi

ISSUE_ID="$1"
CLOSE_COMMENT="${2:-Closed by FABER workflow}"
WORK_ID="${3:-}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Load configuration to get team_id and state mappings
CONFIG_FILE=".fractary/plugins/work/config.json"
if [ -f "$CONFIG_FILE" ]; then
    TEAM_ID=$(jq -r '.handlers["work-tracker"].linear.team_id // ""' "$CONFIG_FILE")
    DONE_STATE=$(jq -r '.handlers["work-tracker"].linear.states.done // "Done"' "$CONFIG_FILE")
else
    TEAM_ID=""
    DONE_STATE="Done"
fi

# Step 1: Get team's workflow states to find "Done" state UUID
read -r -d '' QUERY_STATES <<'EOF' || true
query GetTeamStates($teamId: String!) {
  team(id: $teamId) {
    states {
      nodes {
        id
        name
        type
      }
    }
  }
}
EOF

if [ -n "$TEAM_ID" ]; then
    STATES_REQUEST=$(jq -n \
      --arg query "$QUERY_STATES" \
      --arg teamId "$TEAM_ID" \
      '{query: $query, variables: {teamId: $teamId}}')

    STATES_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$STATES_REQUEST")

    # Find state UUID for "Done"
    DONE_STATE_ID=$(echo "$STATES_RESPONSE" | jq -r --arg stateName "$DONE_STATE" \
      '.data.team.states.nodes[] | select(.name == $stateName or .type == "completed") | .id' | head -1)
else
    # Try to find issue's team and then get states
    ISSUE_QUERY=$(jq -n \
      --arg query 'query GetIssue($id: String!) { issue(id: $id) { team { id states { nodes { id name type } } } } }' \
      --arg id "$ISSUE_ID" \
      '{query: $query, variables: {id: $id}}')

    ISSUE_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$ISSUE_QUERY")

    DONE_STATE_ID=$(echo "$ISSUE_RESPONSE" | jq -r --arg stateName "$DONE_STATE" \
      '.data.issue.team.states.nodes[] | select(.name == $stateName or .type == "completed") | .id' | head -1)
fi

if [ -z "$DONE_STATE_ID" ] || [ "$DONE_STATE_ID" = "null" ]; then
    echo "Error: Could not find 'Done' state for issue" >&2
    exit 3
fi

# Step 2: Post close comment if provided
if [ -n "$CLOSE_COMMENT" ]; then
    FORMATTED_COMMENT="$CLOSE_COMMENT"
    if [ -n "$WORK_ID" ]; then
        FORMATTED_COMMENT="$FORMATTED_COMMENT

---
_FABER Work ID: \`$WORK_ID\` | Closed by workflow_"
    fi

    read -r -d '' COMMENT_MUTATION <<'EOF' || true
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) {
    success
    comment {
      id
    }
  }
}
EOF

    COMMENT_REQUEST=$(jq -n \
      --arg query "$COMMENT_MUTATION" \
      --arg issueId "$ISSUE_ID" \
      --arg body "$FORMATTED_COMMENT" \
      '{query: $query, variables: {issueId: $issueId, body: $body}}')

    curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$COMMENT_REQUEST" > /dev/null
fi

# Step 3: Update issue state to "Done"
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
      completedAt
      url
    }
  }
}
EOF

UPDATE_REQUEST=$(jq -n \
  --arg query "$UPDATE_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg stateId "$DONE_STATE_ID" \
  '{query: $query, variables: {issueId: $issueId, stateId: $stateId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    else
        echo "Error: Failed to close issue: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Extract updated issue data
UPDATED_ISSUE=$(echo "$RESPONSE" | jq '.data.issueUpdate.issue')

# Check if already completed
STATE_TYPE=$(echo "$UPDATED_ISSUE" | jq -r '.state.type')
if [ "$STATE_TYPE" = "completed" ]; then
    # Output normalized JSON
    echo "$UPDATED_ISSUE" | jq '{
      id: .identifier,
      identifier: .identifier,
      state: "done",
      closedAt: .completedAt,
      url: .url,
      platform: "linear"
    }'
    exit 0
else
    echo "Warning: Issue state updated but not marked as completed" >&2
    echo "$UPDATED_ISSUE" | jq '{
      id: .identifier,
      identifier: .identifier,
      state: "done",
      url: .url,
      platform: "linear"
    }'
    exit 0
fi
