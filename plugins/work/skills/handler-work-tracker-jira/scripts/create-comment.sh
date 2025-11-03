#!/bin/bash
# Handler: Jira Create Comment
# Posts comment to Jira issue with FABER metadata in ADF format

set -euo pipefail

# Check arguments
if [ $# -lt 4 ]; then
    echo "Usage: $0 <issue_key> <work_id> <author_context> <message>" >&2
    echo "  Example: $0 PROJ-123 'faber-abc123' 'architect' 'Solution designed'" >&2
    exit 2
fi

ISSUE_KEY="$1"
WORK_ID="$2"
AUTHOR_CONTEXT="$3"
MESSAGE="$4"

# Validate issue key format
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

# Check required environment variables
if [ -z "${JIRA_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_URL, JIRA_EMAIL, and JIRA_TOKEN must be set" >&2
    exit 3
fi

# Generate Basic Auth header
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Build comment with FABER metadata
# Format markdown comment with work metadata
COMMENT_TEXT="---
**FABER Work ID:** $WORK_ID
**Phase:** $AUTHOR_CONTEXT
**Author:** Claude
---

$MESSAGE"

# Convert markdown to ADF using markdown-to-adf utility
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORK_COMMON_DIR="$SCRIPT_DIR/../../../work-common/scripts"

# Convert comment to ADF format
COMMENT_ADF=$("$WORK_COMMON_DIR/markdown-to-adf.sh" "$COMMENT_TEXT" 2>/dev/null)

# Check if conversion succeeded
if [ $? -ne 0 ] || [ -z "$COMMENT_ADF" ]; then
    # Fallback to simple ADF text
    ESCAPED_TEXT=$(echo "$COMMENT_TEXT" | jq -Rs .)
    COMMENT_ADF=$(jq -n --arg text "$COMMENT_TEXT" '{
      type: "doc",
      version: 1,
      content: [{
        type: "paragraph",
        content: [{type: "text", text: $text}]
      }]
    }')
fi

# Build API request payload
REQUEST_PAYLOAD=$(jq -n --argjson body "$COMMENT_ADF" '{body: $body}')

# Post comment to Jira
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$REQUEST_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY/comment" 2>&1)

# Extract HTTP status code
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 201 ]; then
    case "$http_code" in
        404)
            echo "Error: Issue $ISSUE_KEY not found" >&2
            exit 10
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to create comment (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Parse response and output comment details
echo "$body" | jq -c '{
  comment_id: .id,
  author: .author.displayName,
  created: .created,
  url: (env.JIRA_URL + "/browse/" + env.ISSUE_KEY + "?focusedCommentId=" + .id),
  platform: "jira"
}' | ISSUE_KEY="$ISSUE_KEY" envsubst

exit 0
