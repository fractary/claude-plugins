#!/bin/bash
# Handler: Jira Assign Issue
# Assigns issue to user by email

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <assignee_email>" >&2
    exit 2
fi

ISSUE_KEY="$1"
ASSIGNEE_EMAIL="$2"

# Validate inputs
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

if [ -z "$ASSIGNEE_EMAIL" ]; then
    echo "Error: Assignee email is required" >&2
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

# Step 1: Look up user by email to get accountId
user_search=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/user/search?query=$ASSIGNEE_EMAIL" 2>&1)

http_code=$(echo "$user_search" | tail -n 1)
user_body=$(echo "$user_search" | sed '$d')

if [ "$http_code" -ne 200 ]; then
    echo "Error: Failed to search for user (HTTP $http_code)" >&2
    exit 1
fi

ACCOUNT_ID=$(echo "$user_body" | jq -r '.[0].accountId // ""')

if [ -z "$ACCOUNT_ID" ] || [ "$ACCOUNT_ID" = "null" ]; then
    echo "Error: User $ASSIGNEE_EMAIL not found" >&2
    exit 10
fi

DISPLAY_NAME=$(echo "$user_body" | jq -r '.[0].displayName // ""')

# Step 2: Assign issue to user
ASSIGN_PAYLOAD=$(jq -n --arg accountId "$ACCOUNT_ID" '{accountId: $accountId}')

response=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$ASSIGN_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY/assignee" 2>&1)

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
            echo "Error: Failed to assign issue (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Output success
jq -n \
  --arg key "$ISSUE_KEY" \
  --arg email "$ASSIGNEE_EMAIL" \
  --arg name "$DISPLAY_NAME" \
  --arg accountId "$ACCOUNT_ID" \
  '{
    issue_key: $key,
    assignee_email: $email,
    assignee_name: $name,
    assignee_account_id: $accountId,
    platform: "jira"
  }'

exit 0
