#!/bin/bash
# Work Manager: Linear Set Labels
# Sets exact labels on a Linear issue (replaces all existing labels)

set -euo pipefail

# Check arguments - minimum 1 required (issue_id), labels can be empty
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_id> [label1,label2,...]" >&2
    exit 2
fi

ISSUE_ID="$1"
LABELS="${2:-}"  # Empty string means remove all labels

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

# Parse labels into array
if [ -z "$LABELS" ]; then
    LABEL_IDS="[]"
else
    # First, fetch all team labels to get label IDs
    # We need to query labels by name to get their IDs
    # This requires fetching the team's labels first

    # Get issue to find team
    read -r -d '' TEAM_QUERY <<'EOF' || true
query GetIssueTeam($issueId: String!) {
  issue(id: $issueId) {
    id
    team {
      id
      labels {
        nodes {
          id
          name
        }
      }
    }
  }
}
EOF

    TEAM_REQUEST=$(jq -n \
      --arg query "$TEAM_QUERY" \
      --arg issueId "$ISSUE_ID" \
      '{query: $query, variables: {issueId: $issueId}}')

    TEAM_RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
      -H "Authorization: ${LINEAR_API_KEY}" \
      -H "Content-Type: application/json" \
      -d "$TEAM_REQUEST")

    # Check for errors
    if echo "$TEAM_RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$TEAM_RESPONSE" | jq -r '.errors[0].message')
        if echo "$ERROR_MSG" | grep -qi "not found"; then
            echo "Error: Issue $ISSUE_ID not found" >&2
            exit 10
        elif echo "$ERROR_MSG" | grep -qi "authentication\|unauthorized"; then
            echo "Error: Linear authentication failed" >&2
            exit 11
        else
            echo "Error: Failed to fetch issue: $ERROR_MSG" >&2
            exit 1
        fi
    fi

    # Convert comma-separated label names to array of label IDs
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    LABEL_IDS="["
    FIRST=true
    for label_name in "${LABEL_ARRAY[@]}"; do
        label_name_trimmed="$(echo "$label_name" | xargs)"  # Trim whitespace
        if [ -n "$label_name_trimmed" ]; then
            # Find label ID by name
            label_id=$(echo "$TEAM_RESPONSE" | jq -r --arg name "$label_name_trimmed" \
                '.data.issue.team.labels.nodes[] | select(.name == $name) | .id')

            if [ -n "$label_id" ] && [ "$label_id" != "null" ]; then
                if [ "$FIRST" = false ]; then
                    LABEL_IDS="$LABEL_IDS,"
                fi
                LABEL_IDS="$LABEL_IDS\"$label_id\""
                FIRST=false
            else
                echo "Warning: Label '$label_name_trimmed' not found in team, skipping" >&2
            fi
        fi
    done
    LABEL_IDS="$LABEL_IDS]"
fi

# GraphQL mutation to set labels
read -r -d '' MUTATION <<'EOF' || true
mutation SetLabels($issueId: String!, $labelIds: [String!]!) {
  issueUpdate(id: $issueId, input: {labelIds: $labelIds}) {
    success
    issue {
      id
      labels {
        nodes {
          id
          name
        }
      }
    }
  }
}
EOF

# Build GraphQL request
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --argjson labelIds "$LABEL_IDS" \
  '{query: $query, variables: {issueId: $issueId, labelIds: $labelIds}}')

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
        echo "Error: Failed to set labels: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.issueUpdate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to set labels" >&2
    exit 1
fi

# Output success message
echo "Labels set on issue $ISSUE_ID: $LABELS"
exit 0
