#!/bin/bash
# Work Manager: Jira List Comments
# Lists comments on a Jira issue with optional filtering

set -euo pipefail

# Check arguments - minimum 1 required (issue_key)
if [ $# -lt 1 ]; then
    echo "Usage: $0 <issue_key> [limit] [since]" >&2
    exit 2
fi

ISSUE_KEY="$1"
LIMIT="${2:-10}"
SINCE="${3:-}"

# Validate issue key format
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

# Validate limit
if ! [[ "$LIMIT" =~ ^[0-9]+$ ]] || [ "$LIMIT" -lt 1 ] || [ "$LIMIT" -gt 100 ]; then
    echo "Error: limit must be a number between 1 and 100" >&2
    exit 2
fi

# Validate since date format if provided (YYYY-MM-DD)
if [ -n "$SINCE" ]; then
    if ! [[ "$SINCE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
        echo "Error: since date must be in YYYY-MM-DD format" >&2
        exit 2
    fi
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

# Fetch comments from Jira API
response=$(curl -s -w "\n%{http_code}" -X GET \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  "$JIRA_URL/rest/api/3/issue/$ISSUE_KEY/comment" 2>&1)

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
            echo "Error: Failed to fetch comments (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Convert ADF content to plain text for body field
# This is a simplified conversion - for full ADF parsing, use a dedicated tool
adf_to_text() {
    local adf="$1"
    echo "$adf" | jq -r '
        if type == "object" and .content then
            .content
            | map(
                if .type == "paragraph" and .content then
                    .content | map(if .type == "text" then .text else "" end) | join("")
                else
                    ""
                end
            )
            | join("\n")
        else
            ""
        end
    '
}

# Parse and filter comments
if [ -n "$SINCE" ]; then
    # Convert YYYY-MM-DD to ISO 8601 timestamp for comparison
    since_timestamp="${SINCE}T00:00:00.000+0000"
    comments=$(echo "$body" | jq --arg limit "$LIMIT" --arg since "$since_timestamp" --arg jira_url "$JIRA_URL" --arg issue_key "$ISSUE_KEY" '
        .comments
        | map({
            id: .id,
            author: .author.displayName,
            body: (.body | tostring),
            created_at: .created,
            updated_at: .updated,
            url: ($jira_url + "/browse/" + $issue_key + "?focusedCommentId=" + .id)
        })
        | map(select(.created_at >= $since))
        | sort_by(.created_at)
        | reverse
        | limit($limit | tonumber)
    ')
else
    comments=$(echo "$body" | jq --arg limit "$LIMIT" --arg jira_url "$JIRA_URL" --arg issue_key "$ISSUE_KEY" '
        .comments
        | map({
            id: .id,
            author: .author.displayName,
            body: (.body | tostring),
            created_at: .created,
            updated_at: .updated,
            url: ($jira_url + "/browse/" + $issue_key + "?focusedCommentId=" + .id)
        })
        | sort_by(.created_at)
        | reverse
        | limit($limit | tonumber)
    ')
fi

# Output the filtered comments
echo "$comments"
exit 0
