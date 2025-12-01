#!/bin/bash
# Handler: Jira Update Issue
# Updates issue summary and/or description

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <title> [description]" >&2
    echo "  Example: $0 PROJ-123 'New title' 'Updated description'" >&2
    exit 2
fi

ISSUE_KEY="$1"
TITLE="${2:-}"
DESCRIPTION="${3:-}"

# Validate issue key format
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

# At least one field must be provided
if [ -z "$TITLE" ] && [ -z "$DESCRIPTION" ]; then
    echo "Error: At least title or description must be provided" >&2
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

# Build update payload
FIELDS_JSON="{}"

# Add summary if provided
if [ -n "$TITLE" ]; then
    FIELDS_JSON=$(echo "$FIELDS_JSON" | jq --arg summary "$TITLE" '. + {summary: $summary}')
fi

# Add description if provided (convert to ADF)
if [ -n "$DESCRIPTION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORK_COMMON_DIR="$SCRIPT_DIR/../../../work-common/scripts"

    DESCRIPTION_ADF=$("$WORK_COMMON_DIR/markdown-to-adf.sh" "$DESCRIPTION" 2>/dev/null)

    # Fallback if conversion fails
    if [ $? -ne 0 ] || [ -z "$DESCRIPTION_ADF" ]; then
        DESCRIPTION_ADF=$(jq -n --arg text "$DESCRIPTION" '{
          type: "doc",
          version: 1,
          content: [{
            type: "paragraph",
            content: [{type: "text", text: $text}]
          }]
        }')
    fi

    FIELDS_JSON=$(echo "$FIELDS_JSON" | jq --argjson description "$DESCRIPTION_ADF" '. + {description: $description}')
fi

UPDATE_PAYLOAD=$(jq -n --argjson fields "$FIELDS_JSON" '{fields: $fields}')

# Update issue via Jira API
response=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 204 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid request" >&2
            echo "$body" | jq -r '.errorMessages[]?, .errors | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "$body" >&2
            exit 3
            ;;
        404)
            echo "Error: Issue $ISSUE_KEY not found" >&2
            exit 10
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to update issue (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Fetch updated issue to confirm
updated_issue=$(curl -s -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=summary,updated" 2>/dev/null)

# Output success JSON
echo "$updated_issue" | jq -c '{
  issue_key: .key,
  title: .fields.summary,
  updated: .fields.updated,
  platform: "jira"
}'

exit 0
