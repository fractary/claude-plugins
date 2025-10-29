#!/bin/bash
# Handler: Jira Add Label
# Adds label to Jira issue

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <label_name>" >&2
    exit 2
fi

ISSUE_KEY="$1"
LABEL_NAME="$2"

# Validate inputs
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

if [ -z "$LABEL_NAME" ]; then
    echo "Error: Label name is required" >&2
    exit 2
fi

# Check environment variables
if [ -z "${JIRA_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_URL, JIRA_EMAIL, and JIRA_TOKEN must be set" >&2
    exit 3
fi

AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check jq
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Build update payload using Jira's update notation
UPDATE_PAYLOAD=$(jq -n --arg label "$LABEL_NAME" '{
  update: {
    labels: [{add: $label}]
  }
}')

# Update issue
response=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 204 ]; then
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
            echo "Error: Failed to add label (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Output success
jq -n --arg key "$ISSUE_KEY" --arg label "$LABEL_NAME" '{
  issue_key: $key,
  label_added: $label,
  platform: "jira"
}'

exit 0
