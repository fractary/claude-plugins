#!/bin/bash
# Handler: Linear Update Issue
# Updates issue title and/or description

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_id> <title> [description]" >&2
    exit 2
fi

ISSUE_ID="$1"
TITLE="$2"
DESCRIPTION="${3:-}"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Build update mutation based on what's provided
read -r -d '' UPDATE_MUTATION <<'EOF' || true
mutation UpdateIssue($issueId: String!, $title: String, $description: String) {
  issueUpdate(id: $issueId, input: {
    title: $title,
    description: $description
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

# Build request
UPDATE_REQUEST=$(jq -n \
  --arg query "$UPDATE_MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg title "$TITLE" \
  '{query: $query, variables: {issueId: $issueId, title: $title}}')

# Add description if provided
if [ -n "$DESCRIPTION" ]; then
    UPDATE_REQUEST=$(echo "$UPDATE_REQUEST" | jq --arg desc "$DESCRIPTION" \
      '.variables.description = $desc')
fi

RESPONSE=$(curl -s -X POST https://api.linear.app/graphql \
  -H "Authorization: ${LINEAR_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_REQUEST")

# Check for errors
if echo "$RESPONSE" | jq -e '.errors' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$RESPONSE" | jq -r '.errors[0].message')
    if echo "$ERROR_MSG" | grep -q "not found"; then
        echo "Error: Issue $ISSUE_ID not found" >&2
        exit 10
    else
        echo "Error: Failed to update issue: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Output updated issue
echo "$RESPONSE" | jq '.data.issueUpdate.issue | {
  id: .identifier,
  identifier: .identifier,
  title: .title,
  description: .description,
  url: .url,
  platform: "linear"
}'

exit 0
