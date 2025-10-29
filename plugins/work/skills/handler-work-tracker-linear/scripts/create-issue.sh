#!/bin/bash
# Handler: Linear Create Issue
# Creates a new issue in Linear

set -euo pipefail

# Check arguments
if [ $# -lt 3 ]; then
    echo "Usage: $0 <team_id> <title> <description> [labels] [assignee]" >&2
    exit 2
fi

TEAM_ID="$1"
TITLE="$2"
DESCRIPTION="$3"
LABELS="${4:-}"
ASSIGNEE="${5:-}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# If team_id is empty, try to load from config
if [ -z "$TEAM_ID" ]; then
    CONFIG_FILE=".faber/plugins/work/config.json"
    if [ -f "$CONFIG_FILE" ]; then
        TEAM_ID=$(jq -r '.handlers["work-tracker"].linear.team_id // ""' "$CONFIG_FILE")
    fi
fi

if [ -z "$TEAM_ID" ]; then
    echo "Error: team_id required (not found in config)" >&2
    exit 2
fi

# Step 1: Lookup label UUIDs if labels provided
LABEL_IDS="[]"
if [ -n "$LABELS" ]; then
    # Query team's labels
    LABELS_QUERY=$(jq -n \
      --arg query 'query GetTeamLabels($teamId: String!) { team(id: $teamId) { labels { nodes { id name } } } }' \
      --arg teamId "$TEAM_ID" \
      '{query: $query, variables: {teamId: $teamId}}')

    LABELS_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$LABELS_QUERY")

    # Convert comma-separated labels to UUIDs
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    LABEL_IDS_ARRAY=()
    for LABEL_NAME in "${LABEL_ARRAY[@]}"; do
        LABEL_ID=$(echo "$LABELS_RESPONSE" | jq -r --arg name "$LABEL_NAME" \
          '.data.team.labels.nodes[] | select(.name == $name) | .id')
        if [ -n "$LABEL_ID" ] && [ "$LABEL_ID" != "null" ]; then
            LABEL_IDS_ARRAY+=("\"$LABEL_ID\"")
        fi
    done

    if [ ${#LABEL_IDS_ARRAY[@]} -gt 0 ]; then
        LABEL_IDS="[$(IFS=,; echo "${LABEL_IDS_ARRAY[*]}")]"
    fi
fi

# Step 2: Lookup assignee UUID if provided
ASSIGNEE_ID="null"
if [ -n "$ASSIGNEE" ]; then
    # Query users by email or name
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

    if [ -n "$USER_ID" ] && [ "$USER_ID" != "null" ]; then
        ASSIGNEE_ID="\"$USER_ID\""
    fi
fi

# Step 3: Create the issue
read -r -d '' CREATE_MUTATION <<'EOF' || true
mutation CreateIssue($teamId: String!, $title: String!, $description: String, $labelIds: [String!], $assigneeId: String) {
  issueCreate(input: {
    teamId: $teamId,
    title: $title,
    description: $description,
    labelIds: $labelIds,
    assigneeId: $assigneeId
  }) {
    success
    issue {
      id
      identifier
      title
      description
      url
    }
  }
}
EOF

# Build request with proper JSON
CREATE_REQUEST=$(jq -n \
  --arg query "$CREATE_MUTATION" \
  --arg teamId "$TEAM_ID" \
  --arg title "$TITLE" \
  --arg description "$DESCRIPTION" \
  --argjson labelIds "$LABEL_IDS" \
  '{
    query: $query,
    variables: {
      teamId: $teamId,
      title: $title,
      description: $description,
      labelIds: $labelIds
    }
  }')

# Add assigneeId only if it's not null
if [ "$ASSIGNEE_ID" != "null" ]; then
    CREATE_REQUEST=$(echo "$CREATE_REQUEST" | jq --argjson assigneeId "$ASSIGNEE_ID" \
      '.variables.assigneeId = $assigneeId')
fi

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$CREATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "authentication"; then
        echo "Error: Linear authentication failed" >&2
        exit 11
    else
        echo "Error: Failed to create issue: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueCreate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to create issue" >&2
    exit 1
fi

# Output created issue info
echo "$RESPONSE" | jq '.data.issueCreate.issue | {
  id: .identifier,
  identifier: .identifier,
  title: .title,
  url: .url,
  platform: "linear"
}'

exit 0
