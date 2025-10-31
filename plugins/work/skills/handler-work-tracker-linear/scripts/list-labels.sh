#!/bin/bash
# Work Manager: Linear List Labels
# Lists all labels on a Linear issue

set -euo pipefail

# Check arguments - minimum 1 required (issue_id)
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

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Build GraphQL query to fetch issue labels
read -r -d '' QUERY <<'EOF' || true
query GetIssueLabels($issueId: String!) {
  issue(id: $issueId) {
    id
    labels {
      nodes {
        id
        name
        color
        description
      }
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
    if echo "$ERROR_MSG" | grep -qi "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    elif echo "$ERROR_MSG" | grep -qi "authentication\|unauthorized"; then
        echo "Error: Linear authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to fetch labels: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check if issue was found
if echo "$RESPONSE" | jq -e '.data.issue == null' > /dev/null 2>&1; then
    echo "Error: Issue $ISSUE_ID not found" >&2
    exit 10
fi

# Parse and format labels
labels=$(echo "$RESPONSE" | jq '.data.issue.labels.nodes | map({
    name: .name,
    color: .color,
    description: (.description // "")
})')

# Output the labels array
echo "$labels"
exit 0
