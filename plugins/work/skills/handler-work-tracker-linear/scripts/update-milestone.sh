#!/bin/bash
# Handler: Linear Update Milestone (Cycle)
# Updates an existing cycle in Linear

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <cycle_id> <name> [description] [start_date] [end_date] [state]" >&2
    exit 2
fi

CYCLE_ID="$1"
NAME="$2"
DESCRIPTION="${3:-}"
START_DATE="${4:-}"
END_DATE="${5:-}"
STATE="${6:-}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# GraphQL mutation to update cycle
read -r -d '' UPDATE_MUTATION <<'EOF' || true
mutation UpdateCycle($cycleId: String!, $name: String, $description: String, $startsAt: TimelessDate, $endsAt: TimelessDate, $completedAt: DateTime) {
  cycleUpdate(id: $cycleId, input: {
    name: $name,
    description: $description,
    startsAt: $startsAt,
    endsAt: $endsAt,
    completedAt: $completedAt
  }) {
    success
    cycle {
      id
      name
      description
      startsAt
      endsAt
      completedAt
      url
    }
  }
}
EOF

# Build GraphQL request
UPDATE_REQUEST=$(jq -n \
  --arg query "$UPDATE_MUTATION" \
  --arg cycleId "$CYCLE_ID" \
  '{query: $query, variables: {cycleId: $cycleId}}')

# Add optional name
if [ -n "$NAME" ] && [ "$NAME" != "null" ]; then
    UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg name "$NAME" \
      '.variables.name = $name')
fi

# Add optional description
if [ -n "$DESCRIPTION" ] && [ "$DESCRIPTION" != "null" ]; then
    UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg desc "$DESCRIPTION" \
      '.variables.description = $desc')
fi

# Add optional start date
if [ -n "$START_DATE" ] && [ "$START_DATE" != "null" ]; then
    UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg date "$START_DATE" \
      '.variables.startsAt = $date')
fi

# Add optional end date
if [ -n "$END_DATE" ] && [ "$END_DATE" != "null" ]; then
    UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg date "$END_DATE" \
      '.variables.endsAt = $date')
fi

# Handle state (completed/active)
if [ -n "$STATE" ]; then
    if [ "$STATE" = "completed" ] || [ "$STATE" = "done" ]; then
        # Mark as completed with current timestamp
        COMPLETED_AT=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
        UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg completedAt "$COMPLETED_AT" \
          '.variables.completedAt = $completedAt')
    elif [ "$STATE" = "active" ] || [ "$STATE" = "open" ]; then
        # Mark as not completed
        UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq \
          '.variables.completedAt = null')
    fi
fi

# Execute GraphQL request
RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Cycle $CYCLE_ID not found" >&2
        exit 10
    else
        echo "Error: Failed to update cycle: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Check success
SUCCESS=$(echo "$RESPONSE" | jq -r '.data.cycleUpdate.success')
if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to update cycle" >&2
    exit 1
fi

# Output updated cycle info
echo "$RESPONSE" | jq '.data.cycleUpdate.cycle | {
  id: .id,
  name: .name,
  description: .description,
  start_date: .startsAt,
  end_date: .endsAt,
  completed_at: .completedAt,
  url: .url,
  platform: "linear"
}'

exit 0
