#!/bin/bash
# Handler: Jira Assign Milestone (Version)
# Assigns issue to version (fixVersions field)

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <version_name>" >&2
    echo "  Use 'none' as version_name to remove version" >&2
    exit 2
fi

ISSUE_KEY="$1"
VERSION_NAME="$2"

# Validate issue key
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
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

# Build update payload
if [ "$VERSION_NAME" = "none" ]; then
    # Remove all versions
    UPDATE_PAYLOAD='{"fields": {"fixVersions": []}}'
else
    # Assign to version
    UPDATE_PAYLOAD=$(jq -n --arg version "$VERSION_NAME" '{
      fields: {
        fixVersions: [{name: $version}]
      }
    }')
fi

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
        400)
            echo "Error: Invalid request - version may not exist" >&2
            echo "$body" | jq -r '.errorMessages[]?, .errors | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "$body" >&2
            exit 10
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
            echo "Error: Failed to assign version (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Fetch updated issue to confirm
updated_issue=$(curl -s -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY?fields=fixVersions" 2>/dev/null)

# Normalize output
echo "$updated_issue" | jq -c --arg assigned "$VERSION_NAME" '{
  issue_key: .key,
  milestone: (if (.fields.fixVersions | length) > 0 then .fields.fixVersions[0].name else null end),
  milestone_id: (if (.fields.fixVersions | length) > 0 then .fields.fixVersions[0].id else null end),
  assigned_version: $assigned,
  platform: "jira"
}'

exit 0
