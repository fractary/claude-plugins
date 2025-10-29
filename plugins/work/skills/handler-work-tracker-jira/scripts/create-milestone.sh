#!/bin/bash
# Handler: Jira Create Milestone (Version)
# Creates new version in Jira project for release planning

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <name> [description] [release_date]" >&2
    echo "  release_date format: YYYY-MM-DD" >&2
    exit 2
fi

NAME="$1"
DESCRIPTION="${2:-}"
RELEASE_DATE="${3:-}"

# Validate name
if [ -z "$NAME" ]; then
    echo "Error: Version name is required" >&2
    exit 2
fi

# Validate date format if provided
if [ -n "$RELEASE_DATE" ]; then
    if ! echo "$RELEASE_DATE" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
        echo "Error: Invalid release_date format: $RELEASE_DATE" >&2
        echo "  Expected format: YYYY-MM-DD" >&2
        exit 3
    fi
fi

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

# Build version payload
VERSION_PAYLOAD=$(jq -n \
  --arg name "$NAME" \
  --arg description "$DESCRIPTION" \
  --arg releaseDate "$RELEASE_DATE" \
  --arg project "$JIRA_PROJECT_KEY" \
  '{
    name: $name,
    description: (if $description != "" then $description else null end),
    releaseDate: (if $releaseDate != "" then $releaseDate else null end),
    projectId: null,
    project: $project
  } | with_entries(select(.value != null))')

# Create version
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$VERSION_PAYLOAD" \
  "$JIRA_URL/rest/api/3/version" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 201 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid version request" >&2
            echo "$body" | jq -r '.errorMessages[]?, .errors | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "$body" >&2
            exit 3
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to create version (HTTP $http_code)" >&2
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
  url: .self,
  platform: "jira"
}'

exit 0
