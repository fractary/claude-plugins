#!/bin/bash
# Handler: Linear Assign Milestone (Cycle)
# Assigns an issue to a cycle

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <cycle_id>" >&2
    exit 2
fi

ISSUE_ID="$1"
CYCLE_ID="$2"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# GraphQL mutation to assign issue to cycle
read -r -d '' ASSIGN_MUTATION <<'EOF' || true
mutation AssignIssueToCycle($issueId: String!, $cycleId: String!) {
  issueUpdate(id: $issueId, input: {cycleId: $cycleId}) {
    success
    issue {
      id
      identifier
      cycle {
        id
        name
        startsAt
        endsAt
      }
    }
  }
}
EOF

# Build GraphQL request
ASSIGN_REQUEST=$(jq -n \
  --arg query "$ASSIGN_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg cycleId "$CYCLE_ID" \
  '{query: $query, variables: {issueId: $issueId, cycleId: $cycleId}}')

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$ASSIGN_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        if echo "$ERROR_MSG" | grep -q "issue"; then
            echo "Error: Issue $ISSUE_ID not found" >&2
            exit 10
        else
            echo "Error: Cycle $CYCLE_ID not found" >&2
            exit 3
        fi
    else
        echo "Error: Failed to assign issue to cycle: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueUpdate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to assign issue to cycle" >&2
    exit 1
fi

# Output result
echo "$RESPONSE" | jq '.data.issueUpdate.issue | {
  id: .identifier,
  identifier: .identifier,
  cycle: {
    id: .cycle.id,
    name: .cycle.name,
    start_date: .cycle.startsAt,
    end_date: .cycle.endsAt
  },
  platform: "linear"
}'

exit 0
