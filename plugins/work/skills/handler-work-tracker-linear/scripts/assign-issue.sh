#!/bin/bash
# Handler: Linear Assign Issue
# Assigns an issue to a user (requires UUID lookup)

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <assignee_email_or_name>" >&2
    exit 2
fi

ISSUE_ID="$1"
ASSIGNEE="$2"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Step 1: Query users to find assignee UUID
USERS_QUERY=$(jq -n \
  --arg query 'query GetUsers { users { nodes { id email name } } }' \
  '{query: $query}')

USERS_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$USERS_QUERY")

# Try to match by email first, then by name
USER_ID=$(echo "$USERS_RESPONSE" | jq -r --arg user "$ASSIGNEE" \
  '.data.users.nodes[] | select(.email == $user or .name == $user) | .id' | head -1)

if [ -z "$USER_ID" ] || [ "$USER_ID" = "null" ]; then
    echo "Error: User '$ASSIGNEE' not found" >&2
    exit 3
fi

# Step 2: Assign issue to user
read -r -d '' ASSIGN_MUTATION <<'EOF' || true
mutation AssignIssue($issueId: String!, $assigneeId: String!) {
  issueUpdate(id: $issueId, input: {assigneeId: $assigneeId}) {
    success
    issue {
      id
      identifier
      assignee {
        id
        name
        email
      }
    }
  }
}
EOF

ASSIGN_REQUEST=$(jq -n \
  --arg query "$ASSIGN_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg assigneeId "$USER_ID" \
  '{query: $query, variables: {issueId: $issueId, assigneeId: $assigneeId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$ASSIGN_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    else
        echo "Error: Failed to assign issue: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Output assignee info
echo "$RESPONSE" | jq '.data.issueUpdate.issue | {
  id: .identifier,
  identifier: .identifier,
  assignee: {
    id: .assignee.id,
    username: .assignee.name,
    email: .assignee.email
  },
  platform: "linear"
}'

exit 0
