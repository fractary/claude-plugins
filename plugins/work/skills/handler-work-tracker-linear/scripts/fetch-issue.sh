#!/bin/bash
# Handler: Linear Fetch Issue
# Fetches issue details from Linear using GraphQL API

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

# GraphQL query to fetch issue details
read -r -d '' QUERY <<'EOF' || true
query GetIssue($issueId: String!) {
  issue(id: $issueId) {
    id
    identifier
    title
    description
    createdAt
    updatedAt
    completedAt
    url
    state {
      id
      name
      type
    }
    labels {
      nodes {
        id
        name
      }
    }
    assignee {
      id
      name
      email
    }
    creator {
      id
      name
      email
    }
    priority
    estimate
    cycle {
      id
      name
    }
  }
}
EOF

# Build GraphQL request
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$QUERY" \
  --arg issueId "$ISSUE_ID" \
  '{query: $query, variables: {issueId: $issueId}}')

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$GRAPHQL_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    elif echo "$ERROR_MSG" | grep -q "authentication"; then
        echo "Error: Linear authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch issue $ISSUE_ID: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Extract issue data
ISSUE_DATA=$(echo "$RESPONSE" | jq '.data.issue')

# Check if issue exists
if [ "$ISSUE_DATA" = "null" ]; then
    echo "Error: Issue $ISSUE_ID not found" >&2
    exit 10
fi

# Normalize state to universal format
STATE_NAME=$(echo "$ISSUE_DATA" | jq -r '.state.name')
case "$STATE_NAME" in
    "Todo"|"Backlog")
        NORMALIZED_STATE="open"
        ;;
    "In Progress"|"Started")
        NORMALIZED_STATE="in_progress"
        ;;
    "In Review")
        NORMALIZED_STATE="in_review"
        ;;
    "Done"|"Completed")
        NORMALIZED_STATE="done"
        ;;
    "Canceled"|"Archived")
        NORMALIZED_STATE="closed"
        ;;
    *)
        NORMALIZED_STATE="open"
        ;;
esac

# Format labels as array of names
LABELS=$(echo "$ISSUE_DATA" | jq -r '[.labels.nodes[].name]')

# Format assignee (Linear allows single assignee)
if echo "$ISSUE_DATA" | jq -e '.assignee' > /dev/null 2>&1 && [ "$(echo "$ISSUE_DATA" | jq -r '.assignee')" != "null" ]; then
    ASSIGNEES=$(echo "$ISSUE_DATA" | jq '[.assignee | {id: .id, username: .name, email: .email}]')
else
    ASSIGNEES="[]"
fi

# Format author
AUTHOR=$(echo "$ISSUE_DATA" | jq '{id: .creator.id, username: .creator.name}')

# Get cycle info for metadata
CYCLE_NAME=$(echo "$ISSUE_DATA" | jq -r '.cycle.name // ""')

# Output normalized JSON
echo "$ISSUE_DATA" | jq \
  --arg state "$NORMALIZED_STATE" \
  --argjson labels "$LABELS" \
  --argjson assignees "$ASSIGNEES" \
  --argjson author "$AUTHOR" \
  --arg cycleName "$CYCLE_NAME" \
  '{
    id: .identifier,
    identifier: .identifier,
    title: .title,
    description: .description,
    state: $state,
    labels: $labels,
    assignees: $assignees,
    author: $author,
    createdAt: .createdAt,
    updatedAt: .updatedAt,
    closedAt: .completedAt,
    url: .url,
    platform: "linear",
    metadata: {
      priority: .priority,
      estimate: .estimate,
      cycle: $cycleName
    }
  }'

exit 0
