#!/bin/bash
# Handler: Linear Remove Label
# Removes a label from an issue (requires UUID lookup)

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <label_name>" >&2
    exit 2
fi

ISSUE_ID="$1"
LABEL_NAME="$2"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Step 1: Get issue's team to query labels
ISSUE_QUERY=$(jq -n \
  --arg query 'query GetIssue($id: String!) { issue(id: $id) { team { id labels { nodes { id name } } } } }' \
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

# Find label UUID by name
LABEL_ID=$(echo "$ISSUE_RESPONSE" | jq -r --arg name "$LABEL_NAME" \
  '.data.issue.team.labels.nodes[] | select(.name == $name) | .id')

if [ -z "$LABEL_ID" ] || [ "$LABEL_ID" = "null" ]; then
    echo "Warning: Label '$LABEL_NAME' not found, may already be removed" >&2
    echo "{\"success\": true, \"label\": \"$LABEL_NAME\", \"issue\": \"$ISSUE_ID\"}"
    exit 0
fi

# Step 2: Remove label from issue
read -r -d '' REMOVE_LABEL_MUTATION <<'EOF' || true
mutation RemoveLabel($issueId: String!, $labelId: String!) {
  issueRemoveLabel(id: $issueId, labelId: $labelId) {
    success
    issue {
      id
      identifier
    }
  }
}
EOF

REMOVE_REQUEST=$(jq -n \
  --arg query "$REMOVE_LABEL_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg labelId "$LABEL_ID" \
  '{query: $query, variables: {issueId: $issueId, labelId: $labelId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$REMOVE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    echo "Error: Failed to remove label: $ERROR_MSG" >&2
    exit 1
fi

SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueRemoveLabel.success')
if [ "$SUCCESS" = "true" ]; then
    echo "{\"success\": true, \"label\": \"$LABEL_NAME\", \"issue\": \"$ISSUE_ID\"}"
    exit 0
else
    echo "Error: Failed to remove label" >&2
    exit 1
fi
