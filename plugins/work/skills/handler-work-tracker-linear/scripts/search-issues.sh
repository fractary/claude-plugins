#!/bin/bash
# Handler: Linear Search Issues
# Full-text search across issues using searchableContent filter

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <query_text> [limit]" >&2
    exit 2
fi

QUERY_TEXT="$1"
LIMIT="${2:-50}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Load team_id from config if available
CONFIG_FILE=".fractary/plugins/work/config.json"
TEAM_ID=""
if [ -f "$CONFIG_FILE" ]; then
    TEAM_ID=$(jq -r '.handlers["work-tracker"].linear.team_id // ""' "$CONFIG_FILE")
fi

# GraphQL query to search issues
read -r -d '' SEARCH_QUERY <<'EOF' || true
query SearchIssues($query: String!, $limit: Int, $teamId: [ID!]) {
  issues(
    first: $limit,
    filter: {
      searchableContent: {containsIgnoreCase: $query},
      team: {id: {in: $teamId}}
    }
  ) {
    nodes {
      id
      identifier
      title
      description
      state {
        name
        type
      }
      labels {
        nodes {
          name
        }
      }
      assignee {
        name
        email
      }
      creator {
        name
      }
      createdAt
      updatedAt
      completedAt
      url
    }
  }
}
EOF

# Build GraphQL request
if [ -n "$TEAM_ID" ]; then
    GRAPHQL_REQUEST=$(jq -n \
      --arg query "$SEARCH_QUERY" \
      --arg queryText "$QUERY_TEXT" \
      --argjson limit "$LIMIT" \
      --arg teamId "$TEAM_ID" \
      '{query: $query, variables: {query: $queryText, limit: $limit, teamId: [$teamId]}}')
else
    GRAPHQL_REQUEST=$(jq -n \
      --arg query "$SEARCH_QUERY" \
      --arg queryText "$QUERY_TEXT" \
      --argjson limit "$LIMIT" \
      '{query: $query, variables: {query: $queryText, limit: $limit}}')
fi

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$GRAPHQL_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    echo "Error: Search failed: $ERROR_MSG" >&2
    exit 1
fi

# Process and normalize results
echo "$RESPONSE" | jq -r '.data.issues.nodes[] |
{
  id: .identifier,
  identifier: .identifier,
  title: .title,
  description: .description,
  state: (
    if .state.type == "backlog" or .state.type == "unstarted" then "open"
    elif .state.type == "started" then "in_progress"
    elif .state.type == "completed" then "done"
    elif .state.type == "canceled" then "closed"
    else "open"
    end
  ),
  labels: [.labels.nodes[].name],
  assignee: (if .assignee then {username: .assignee.name, email: .assignee.email} else null end),
  author: {username: .creator.name},
  createdAt: .createdAt,
  updatedAt: .updatedAt,
  closedAt: .completedAt,
  url: .url,
  platform: "linear"
}' | jq -s '.'

exit 0
