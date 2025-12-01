#!/bin/bash
# Handler: Jira Link Issues
# Creates native issue link relationship between two issues

set -euo pipefail

# Check arguments
if [ $# -lt 2 ]; then
    echo "Usage: $0 <issue_key> <related_issue_key> [relationship_type]" >&2
    echo "  relationship_type: relates_to|blocks|blocked_by|duplicates (default: relates_to)" >&2
    exit 2
fi

ISSUE_KEY="$1"
RELATED_ISSUE_KEY="$2"
RELATIONSHIP_TYPE="${3:-relates_to}"

# Validate issue keys
if ! echo "$ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid issue key format: $ISSUE_KEY" >&2
    exit 2
fi

if ! echo "$RELATED_ISSUE_KEY" | grep -qE '^[A-Z]+-[0-9]+$'; then
    echo "Error: Invalid related issue key format: $RELATED_ISSUE_KEY" >&2
    exit 2
fi

# Check for self-reference
if [ "$ISSUE_KEY" = "$RELATED_ISSUE_KEY" ]; then
    echo "Error: Cannot link issue to itself" >&2
    exit 3
fi

# Validate relationship type
case "$RELATIONSHIP_TYPE" in
    relates_to|blocks|blocked_by|duplicates)
        ;;
    *)
        echo "Error: Invalid relationship_type: $RELATIONSHIP_TYPE" >&2
        echo "  Must be one of: relates_to, blocks, blocked_by, duplicates" >&2
        exit 3
        ;;
esac

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

# Map universal relationship to Jira link type
case "$RELATIONSHIP_TYPE" in
    relates_to)
        JIRA_LINK_TYPE="Relates"
        INWARD_KEY="$ISSUE_KEY"
        OUTWARD_KEY="$RELATED_ISSUE_KEY"
        ;;
    blocks)
        JIRA_LINK_TYPE="Blocks"
        INWARD_KEY="$RELATED_ISSUE_KEY"  # Issue being blocked
        OUTWARD_KEY="$ISSUE_KEY"          # Issue doing the blocking
        ;;
    blocked_by)
        JIRA_LINK_TYPE="Blocks"
        INWARD_KEY="$ISSUE_KEY"           # Issue being blocked
        OUTWARD_KEY="$RELATED_ISSUE_KEY"  # Issue doing the blocking
        ;;
    duplicates)
        JIRA_LINK_TYPE="Duplicate"
        INWARD_KEY="$ISSUE_KEY"           # Duplicate issue
        OUTWARD_KEY="$RELATED_ISSUE_KEY"  # Original issue
        ;;
esac

# Build link payload
LINK_PAYLOAD=$(jq -n \
  --arg linkType "$JIRA_LINK_TYPE" \
  --arg inward "$INWARD_KEY" \
  --arg outward "$OUTWARD_KEY" \
  '{
    type: {name: $linkType},
    inwardIssue: {key: $inward},
    outwardIssue: {key: $outward}
  }')

# Create issue link
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$LINK_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issueLink" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

if [ "$http_code" -ne 201 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid link request" >&2
            echo "$body" | jq -r '.errorMessages[]?, .errors | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "$body" >&2
            exit 3
            ;;
        404)
            echo "Error: One or both issues not found" >&2
            exit 10
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to create link (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Output success JSON
jq -n \
  --arg issue "$ISSUE_KEY" \
  --arg related "$RELATED_ISSUE_KEY" \
  --arg relationship "$RELATIONSHIP_TYPE" \
  --arg jiraType "$JIRA_LINK_TYPE" \
  --arg method "native_link" \
  '{
    issue_id: $issue,
    related_issue_id: $related,
    relationship: $relationship,
    jira_link_type: $jiraType,
    link_method: $method,
    message: "\($issue) \($relationship) \($related)",
    platform: "jira"
  }'

exit 0
