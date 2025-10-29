#!/bin/bash
# Handler: Linear List Issues
# List/filter issues by state, labels, assignee

set -euo pipefail

# Check arguments (all optional)
STATE="${1:-}"
LABELS="${2:-}"
ASSIGNEE="${3:-}"
LIMIT="${4:-50}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Load team_id from config if available
CONFIG_FILE=".faber/plugins/work/config.json"
TEAM_ID=""
if [ -f "$CONFIG_FILE" ]; then
    TEAM_ID=$(jq -r '.handlers["work-tracker"].linear.team_id // ""' "$CONFIG_FILE")
fi

# Build filter object based on parameters
FILTER="{}"

# Add team filter if available
if [ -n "$TEAM_ID" ]; then
    FILTER=$(echo "$FILTER" | jq --arg teamId "$TEAM_ID" '.team = {id: {eq: $teamId}}')
fi

# Add state filter if provided
if [ -n "$STATE" ]; then
    # Map universal state to Linear state type
    case "$STATE" in
        "open")
            FILTER=$(echo "$FILTER" | jq '.state = {type: {in: ["backlog", "unstarted"]}}')
            ;;
        "in_progress")
            FILTER=$(echo "$FILTER" | jq '.state = {type: {eq: "started"}}')
            ;;
        "done")
            FILTER=$(echo "$FILTER" | jq '.state = {type: {eq: "completed"}}')
            ;;
        "closed")
            FILTER=$(echo "$FILTER" | jq '.state = {type: {eq: "canceled"}}')
            ;;
        *)
            # Assume it's a Linear state name
            FILTER=$(echo "$FILTER" | jq --arg state "$STATE" '.state = {name: {eq: $state}}')
            ;;
    esac
fi

# Add label filter if provided
if [ -n "$LABELS" ]; then
    # Linear uses label names in filter
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    LABEL_NAMES=$(printf '%s\n' "${LABEL_ARRAY[@]}" | jq -R . | jq -s .)
    FILTER=$(echo "$FILTER" | jq --argjson labels "$LABEL_NAMES" '.labels = {some: {name: {in: $labels}}}')
fi

# Add assignee filter if provided
if [ -n "$ASSIGNEE" ]; then
    # Need to lookup user UUID first
    USERS_QUERY=$(jq -n \
      --arg query 'query GetUsers { users { nodes { id email name } } }' \
      '{query: $query}')

    USERS_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$USERS_QUERY")

    USER_ID=$(echo "$USERS_RESPONSE" | jq -r --arg user "$ASSIGNEE" \
      '.data.users.nodes[] | select(.email == $user or .name == $user) | .id' | head -1)

    if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        FILTER=$(echo "$FILTER" | jq --arg userId "$USER_ID" '.assignee = {id: {eq: $userId}}')
    fi
fi

# GraphQL query to list issues
read -r -d '' LIST_QUERY <<'EOF' || true
query ListIssues($filter: IssueFilter!, $limit: Int) {
  issues(
    first: $limit,
    filter: $filter
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
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$LIST_QUERY" \
  --argjson filter "$FILTER" \
  --argjson limit "$LIMIT" \
  '{query: $query, variables: {filter: $filter, limit: $limit}}')

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$GRAPHQL_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    echo "Error: List failed: $ERROR_MSG" >&2
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
