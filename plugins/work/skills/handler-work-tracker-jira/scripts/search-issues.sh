#!/bin/bash
# Handler: Jira Search Issues
# Full-text search across issues using JQL

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <query_text> [limit]" >&2
    echo "  Example: $0 'login crash' 20" >&2
    exit 2
fi

QUERY_TEXT="$1"
LIMIT="${2:-20}"

# Check environment variables
if [ -z "${JIRA_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_TOKEN:-}" ] || [ -z "${JIRA_PROJECT_KEY:-}" ]; then
    echo "Error: JIRA_URL, JIRA_EMAIL, JIRA_TOKEN, and JIRA_PROJECT_KEY must be set" >&2
    exit 3
fi

AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Build JQL query for text search
JQL_QUERY="project = $JIRA_PROJECT_KEY AND text ~ \"$QUERY_TEXT\" ORDER BY created DESC"

# Build search request payload
SEARCH_PAYLOAD=$(jq -n \
  --arg jql "$JQL_QUERY" \
  --argjson maxResults "$LIMIT" \
  '{
    jql: $jql,
    maxResults: $maxResults,
    fields: ["summary", "status", "issuetype", "labels", "created", "updated"]
  }')

# Execute JQL search
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$SEARCH_PAYLOAD" \
  "$JIRA_URL/rest/api/3/search" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 200 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid search query" >&2
            echo "$body" >&2
            exit 3
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to search issues (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Normalize results
echo "$body" | jq -c '.issues | map({
  id: .id,
  number: .key,
  title: .fields.summary,
  state: .fields.status.name,
  labels: (.fields.labels | join(",")),
  createdAt: .fields.created,
  updatedAt: .fields.updated,
  url: (env.JIRA_URL + "/browse/" + .key),
  issueType: .fields.issuetype.name,
  platform: "jira"
})'

exit 0
