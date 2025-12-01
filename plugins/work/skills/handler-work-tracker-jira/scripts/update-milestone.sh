#!/bin/bash
# Handler: Jira Update Milestone (Version)
# Updates version properties in Jira

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <version_id> [name] [description] [release_date] [released]" >&2
    echo "  released: true|false" >&2
    exit 2
fi

VERSION_ID="$1"
NAME="${2:-}"
DESCRIPTION="${3:-}"
RELEASE_DATE="${4:-}"
RELEASED="${5:-}"

# Validate version_id
if [ -z "$VERSION_ID" ]; then
    echo "Error: Version ID is required" >&2
    exit 2
fi

# At least one field must be provided
if [ -z "$NAME" ] && [ -z "$DESCRIPTION" ] && [ -z "$RELEASE_DATE" ] && [ -z "$RELEASED" ]; then
    echo "Error: At least one update parameter must be provided" >&2
    exit 2
fi

# Validate date format if provided
if [ -n "$RELEASE_DATE" ]; then
    if ! echo "$RELEASE_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "Error: Invalid release_date format: $RELEASE_DATE" >&2
        exit 3
    fi
fi

# Validate released flag if provided
if [ -n "$RELEASED" ]; then
    if [ "$RELEASED" != "true" ] && [ "$RELEASED" != "false" ]; then
        echo "Error: released must be 'true' or 'false'" >&2
        exit 3
    fi
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

# Build update payload with only provided fields
UPDATE_PAYLOAD=$(jq -n \
  --arg name "$NAME" \
  --arg description "$DESCRIPTION" \
  --arg releaseDate "$RELEASE_DATE" \
  --arg released "$RELEASED" \
  '{
    name: (if $name != "" then $name else null end),
    description: (if $description != "" then $description else null end),
    releaseDate: (if $releaseDate != "" then $releaseDate else null end),
    released: (if $released == "true" then true elif $released == "false" then false else null end)
  } | with_entries(select(.value != null))')

# Update version
response=$(curl -s -w "\n%{http_code}" -X PUT \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$UPDATE_PAYLOAD" \
  "$JIRA_URL/rest/api/3/version/$VERSION_ID" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 200 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid update request" >&2
            echo "$body" >&2
            exit 3
            ;;
        404)
            echo "Error: Version #$VERSION_ID not found" >&2
            exit 10
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to update version (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Normalize output
echo "$body" | jq -c '{
  id: .id,
  title: .name,
  description: (.description // ""),
  due_date: (.releaseDate // null),
  state: (if .released then "released" else "unreleased" end),
  platform: "jira"
}'

exit 0
