#!/bin/bash
# Work Manager: Jira List Labels
# Lists all labels on a Jira issue

set -euo pipefail

# Check arguments - minimum 1 required (issue_key)
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_key>" >&2
    exit 2
fi

ISSUE_KEY="$1"

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

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Generate Basic Auth header
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Fetch issue with labels from Jira API
response=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=labels" 2>&1)

# Extract HTTP status code
http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 200 ]; then
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
            echo "Error: Failed to fetch labels (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Parse and format labels
# Note: Jira labels are simple strings without color or description
labels=$(echo "$body" | jq '.fields.labels | map({
    name: .,
    color: "",
    description: ""
})')

# Output the labels array
echo "$labels"
exit 0
