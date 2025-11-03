#!/bin/bash
# Handler: Linear Unassign Issue
# Removes assignee from an issue

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id>" >&2
    exit 2
fi

ISSUE_ID="$1"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Unassign issue by setting assigneeId to null
read -r -d '' UNASSIGN_MUTATION <<'EOF' || true
mutation UnassignIssue($issueId: String!) {
  issueUpdate(id: $issueId, input: {assigneeId: null}) {
    success
    issue {
      id
      identifier
    }
  }
}
EOF

UNASSIGN_REQUEST=$(jq -n \
  --arg query "$UNASSIGN_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  '{query: $query, variables: {issueId: $issueId}}')

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UNASSIGN_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    else
        echo "Error: Failed to unassign issue: $ERROR_MSG" >&2
        exit 1
    fi
fi

SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueUpdate.success')
if [ "$SUCCESS" = "true" ]; then
    echo "{\"success\": true, \"issue\": \"$ISSUE_ID\", \"assignee\": null}"
    exit 0
else
    echo "Error: Failed to unassign issue" >&2
    exit 1
fi
