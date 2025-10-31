#!/bin/bash
# Work Manager: Linear List Comments
# Lists comments on a Linear issue with optional filtering

set -euo pipefail

# Check arguments - minimum 1 required (issue_id)
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [limit] [since]" >&2
    exit 2
fi

ISSUE_ID="$1"
LIMIT="${2:-10}"
SINCE="${3:-}"

# Validate limit
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
    echo "Error: limit must be a number between 1 and 100" >&2
    exit 2
fi

# Validate since date format if provided (YYYY-MM-DD)
if [ -n "$SINCE" ]; then
    if ! [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Error: since date must be in YYYY-MM-DD format" >&2
        exit 2
    fi
fi

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

# Build GraphQL query to fetch comments
# Note: Linear uses first/after for pagination, we'll fetch enough to satisfy the limit
read -r -d '' QUERY <<'EOF' || true
query GetIssueComments($issueId: String!, $first: Int!) {
  issue(id: $issueId) {
    id
    comments(first: $first, orderBy: createdAt) {
      nodes {
        id
        body
        createdAt
        updatedAt
        url
        user {
          name
          displayName
        }
      }
    }
  }
}
EOF

# Build GraphQL request
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$QUERY" \
  --arg issueId "$ISSUE_ID" \
  --argjson first "$LIMIT" \
  '{query: $query, variables: {issueId: $issueId, first: $first}}')

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
        echo "Error: Failed to fetch comments: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check if issue was found
if echo "$RESPONSE" | jq -e '.data.issue == null' > /dev/null 2>&1; then
    echo "Error: Issue $ISSUE_ID not found" >&2
    exit 10
fi

# Parse and filter comments
if [ -n "$SINCE" ]; then
    # Convert YYYY-MM-DD to ISO 8601 timestamp for comparison
    since_timestamp="${SINCE}T00:00:00.000Z"
    comments=$(echo "$RESPONSE" | jq --arg limit "$LIMIT" --arg since "$since_timestamp" '
        .data.issue.comments.nodes
        | map({
            id: .id,
            author: (.user.displayName // .user.name // "Unknown"),
            body: .body,
            created_at: .createdAt,
            updated_at: .updatedAt,
            url: .url
        })
        | map(select(.created_at >= $since))
        | sort_by(.created_at)
        | reverse
        | limit($limit | tonumber)
    ')
else
    comments=$(echo "$RESPONSE" | jq --arg limit "$LIMIT" '
        .data.issue.comments.nodes
        | map({
            id: .id,
            author: (.user.displayName // .user.name // "Unknown"),
            body: .body,
            created_at: .createdAt,
            updated_at: .updatedAt,
            url: .url
        })
        | sort_by(.created_at)
        | reverse
        | limit($limit | tonumber)
    ')
fi

# Output the filtered comments
echo "$comments"
exit 0
