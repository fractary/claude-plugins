#!/bin/bash
# Handler: Linear Create Milestone (Cycle)
# Creates a new cycle in Linear (Linear's equivalent of milestones/sprints)

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <team_id> <name> [description] [start_date] [end_date]" >&2
    exit 2
fi

TEAM_ID="$1"
NAME="$2"
DESCRIPTION="${3:-}"
START_DATE="${4:-}"
END_DATE="${5:-}"

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

# GraphQL mutation to create cycle
read -r -d '' CREATE_MUTATION <<'EOF' || true
mutation CreateCycle($teamId: String!, $name: String!, $description: String, $startsAt: TimelessDate, $endsAt: TimelessDate) {
  cycleCreate(input: {
    teamId: $teamId,
    name: $name,
    description: $description,
    startsAt: $startsAt,
    endsAt: $endsAt
  }) {
    success
    cycle {
      id
      name
      description
      startsAt
      endsAt
      url
    }
  }
}
EOF

# Build GraphQL request
CREATE_REQUEST=$(jq -n \
  --arg query "$CREATE_MUTATION" \
  --arg teamId "$TEAM_ID" \
  --arg name "$NAME" \
  '{query: $query, variables: {teamId: $teamId, name: $name}}')

# Add optional description
if [ -n "$DESCRIPTION" ]; then
    CREATE_REQUEST=$(echo "$CREATE_REQUEST" | jq --arg desc "$DESCRIPTION" \
      '.variables.description = $desc')
fi

# Add optional start date (format: YYYY-MM-DD)
if [ -n "$START_DATE" ]; then
    CREATE_REQUEST=$(echo "$CREATE_REQUEST" | jq --arg date "$START_DATE" \
      '.variables.startsAt = $date')
fi

# Add optional end date (format: YYYY-MM-DD)
if [ -n "$END_DATE" ]; then
    CREATE_REQUEST=$(echo "$CREATE_REQUEST" | jq --arg date "$END_DATE" \
      '.variables.endsAt = $date')
fi

# Execute GraphQL request
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
        echo "Error: Failed to create cycle: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.cycleCreate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to create cycle" >&2
    exit 1
fi

# Output created cycle info
echo "$RESPONSE" | jq '.data.cycleCreate.cycle | {
  id: .id,
  name: .name,
  description: .description,
  start_date: .startsAt,
  end_date: .endsAt,
  url: .url,
  platform: "linear"
}'

exit 0
