#!/bin/bash
# Handler: Linear Create Comment
# Posts a markdown comment to a Linear issue

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <issue_id> <work_id> <author_context> <message>" >&2
    exit 2
fi

ISSUE_ID="$1"
WORK_ID="$2"
AUTHOR_CONTEXT="$3"
MESSAGE="$4"

# Check if LINEAR_API_KEY is set
if [ -z "${LINEAR_API_KEY:-}" ]; then
    echo "Error: LINEAR_API_KEY environment variable not set" >&2
    exit 11
fi

# Format comment with FABER metadata
FORMATTED_MESSAGE="$MESSAGE

---
_FABER Work ID: \`$WORK_ID\` | Author: $AUTHOR_CONTEXT_"

# GraphQL mutation to create comment
read -r -d '' MUTATION <<'EOF' || true
mutation CreateComment($issueId: String!, $body: String!) {
  commentCreate(input: {issueId: $issueId, body: $body}) {
    success
    comment {
      id
      url
      createdAt
    }
  }
}
EOF

# Build GraphQL request
GRAPHQL_REQUEST=$(jq -n \
  --arg query "$MUTATION" \
  --arg issueId "$ISSUE_ID" \
  --arg body "$FORMATTED_MESSAGE" \
  '{query: $query, variables: {issueId: $issueId, body: $body}}')

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
        echo "Error: Failed to create comment: $ERROR_MSG" >&2
        exit 1
    fi
fi

# Extract comment data
COMMENT_DATA=$(echo "$RESPONSE" | jq '.data.commentCreate')
SUCCESS=$(echo "$COMMENT_DATA" | jq -r '.success')

if [ "$SUCCESS" != "true" ]; then
    echo "Error: Failed to create comment" >&2
    exit 1
fi

# Output result
echo "$COMMENT_DATA" | jq '{
  comment_id: .comment.id,
  comment_url: .comment.url,
  created_at: .comment.createdAt
}'

exit 0
