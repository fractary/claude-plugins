#!/bin/bash
# Handler: Jira Fetch Issue
# Fetches issue details from Jira using REST API v3

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_key>" >&2
    echo "  Example: $0 PROJ-123" >&2
    exit 2
fi

ISSUE_KEY="$1"

# Validate issue key format (PROJECT-NUMBER)
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    echo "  Expected format: PROJECT-123" >&2
    exit 2
fi

# Check required environment variables
if [ -z "${JIRA_URL:-}" ]; then
    echo "Error: JIRA_URL environment variable not set" >&2
    exit 3
fi

if [ -z "${JIRA_EMAIL:-}" ]; then
    echo "Error: JIRA_EMAIL environment variable not set" >&2
    exit 3
fi

if [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_TOKEN environment variable not set" >&2
    exit 3
fi

# Generate Basic Auth header
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install it for JSON processing" >&2
    exit 3
fi

# Fetch issue from Jira API
response=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=summary,description,status,issuetype,labels,assignee,reporter,created,updated,priority" 2>&1)

# Extract HTTP status code (last line)
http_code=$(echo "$response" | tail -n 1)
# Extract response body (all but last line)
body=$(echo "$response" | sed '$d')

# Handle errors based on HTTP status
if [ "$http_code" -ne 200 ]; then
    case "$http_code" in
        401)
            echo "Error: Jira authentication failed" >&2
            echo "  Check JIRA_EMAIL and JIRA_TOKEN" >&2
            exit 11
            ;;
        403)
            echo "Error: Permission denied for issue $ISSUE_KEY" >&2
            exit 11
            ;;
        404)
            echo "Error: Issue $ISSUE_KEY not found" >&2
            echo "  Verify issue exists and you have permission to view it" >&2
            exit 10
            ;;
        *)
            echo "Error: Failed to fetch issue $ISSUE_KEY (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Parse and normalize issue JSON
# Convert Jira format to universal format
normalized=$(echo "$body" | jq -c '{
  id: .id,
  number: .key,
  title: .fields.summary,
  body: (.fields.description.content[]?.content[]?.text // "" | join(" ")),
  state: .fields.status.name,
  labels: (.fields.labels | join(",")),
  author: {
    login: .fields.reporter.emailAddress,
    name: .fields.reporter.displayName
  },
  assignee: (if .fields.assignee then {
    login: .fields.assignee.emailAddress,
    name: .fields.assignee.displayName
  } else null end),
  createdAt: .fields.created,
  updatedAt: .fields.updated,
  url: (env.JIRA_URL + "/browse/" + .key),
  issueType: .fields.issuetype.name,
  priority: .fields.priority.name,
  platform: "jira"
}')

# Output normalized JSON
echo "$normalized"
exit 0
