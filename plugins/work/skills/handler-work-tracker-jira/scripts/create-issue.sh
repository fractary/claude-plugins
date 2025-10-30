#!/bin/bash
# Handler: Jira Create Issue
# Creates new issue in Jira project with title, description, labels, and assignee

set -euo pipefail

# Check arguments
if [ $# -lt 1 ]; then
    echo "Usage: $0 <title> [description] [labels] [assignee_email]" >&2
    echo "  Example: $0 'Fix login bug' 'Users report crash...' 'bug,urgent' 'user@example.com'" >&2
    exit 2
fi

TITLE="$1"
DESCRIPTION="${2:-}"
LABELS="${3:-}"
ASSIGNEE_EMAIL="${4:-}"

# Validate title
if [ -z "$TITLE" ]; then
    echo "Error: Issue title is required" >&2
    exit 2
fi

# Check required environment variables
if [ -z "${JIRA_URL:-}" ] || [ -z "${JIRA_EMAIL:-}" ] || [ -z "${JIRA_TOKEN:-}" ]; then
    echo "Error: JIRA_URL, JIRA_EMAIL, and JIRA_TOKEN must be set" >&2
    exit 3
fi

if [ -z "${JIRA_PROJECT_KEY:-}" ]; then
    echo "Error: JIRA_PROJECT_KEY environment variable not set" >&2
    exit 3
fi

# Generate Basic Auth header
AUTH_HEADER=$(echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64 -w 0 2>/dev/null || echo -n "$JIRA_EMAIL:$JIRA_TOKEN" | base64)

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found" >&2
    exit 3
fi

# Convert description from markdown to ADF if provided
DESCRIPTION_ADF=""
if [ -n "$DESCRIPTION" ]; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    WORK_COMMON_DIR="$SCRIPT_DIR/../../../work-common/scripts"

    DESCRIPTION_ADF=$("$WORK_COMMON_DIR/markdown-to-adf.sh" "$DESCRIPTION" 2>/dev/null)

    # Fallback if conversion fails
    if [ $? -ne 0 ] || [ -z "$DESCRIPTION_ADF" ]; then
        DESCRIPTION_ADF=$(jq -n --arg text "$DESCRIPTION" '{
          type: "doc",
          version: 1,
          content: [{
            type: "paragraph",
            content: [{type: "text", text: $text}]
          }]
        }')
    fi
fi

# Determine issue type (default to Task)
# Can be enhanced to auto-detect from labels or config
CONFIG_FILE=".fractary/plugins/work/config.json"
ISSUE_TYPE="Task"

if [ -f "$CONFIG_FILE" ]; then
    # Try to infer issue type from labels
    if echo "$LABELS" | grep -qiE "bug|defect|error"; then
        ISSUE_TYPE=$(jq -r '.handlers["work-tracker"].jira.issue_types.bug // "Bug"' "$CONFIG_FILE")
    elif echo "$LABELS" | grep -qiE "feature|story|enhancement"; then
        ISSUE_TYPE=$(jq -r '.handlers["work-tracker"].jira.issue_types.feature // "Story"' "$CONFIG_FILE")
    elif echo "$LABELS" | grep -qiE "hotfix|urgent|patch"; then
        ISSUE_TYPE=$(jq -r '.handlers["work-tracker"].jira.issue_types.patch // "Bug"' "$CONFIG_FILE")
    else
        ISSUE_TYPE=$(jq -r '.handlers["work-tracker"].jira.issue_types.chore // "Task"' "$CONFIG_FILE")
    fi
fi

# Build labels array
LABELS_JSON="[]"
if [ -n "$LABELS" ]; then
    # Split comma-separated labels and build JSON array
    IFS=',' read -ra LABEL_ARRAY <<< "$LABELS"
    LABELS_JSON=$(printf '%s\n' "${LABEL_ARRAY[@]}" | jq -R . | jq -s .)
fi

# Look up assignee account ID if email provided
ASSIGNEE_ACCOUNT_ID=""
if [ -n "$ASSIGNEE_EMAIL" ]; then
    # Search for user by email
    user_search=$(curl -s -X GET \
      -H "Authorization: Basic $AUTH_HEADER" \
      -H "Content-Type: application/json" \
      "$JIRA_URL/rest/api/3/user/search?query=$ASSIGNEE_EMAIL" 2>/dev/null)

    ASSIGNEE_ACCOUNT_ID=$(echo "$user_search" | jq -r '.[0].accountId // ""')

    if [ -z "$ASSIGNEE_ACCOUNT_ID" ]; then
        echo "Warning: User $ASSIGNEE_EMAIL not found, creating issue without assignee" >&2
    fi
fi

# Build create issue payload
if [ -n "$DESCRIPTION_ADF" ]; then
    FIELDS_JSON=$(jq -n \
      --arg project "$JIRA_PROJECT_KEY" \
      --arg summary "$TITLE" \
      --argjson description "$DESCRIPTION_ADF" \
      --arg issuetype "$ISSUE_TYPE" \
      --argjson labels "$LABELS_JSON" \
      --arg assignee "$ASSIGNEE_ACCOUNT_ID" \
      '{
        project: {key: $project},
        summary: $summary,
        description: $description,
        issuetype: {name: $issuetype},
        labels: $labels
      } + (if $assignee != "" then {assignee: {accountId: $assignee}} else {} end)')
else
    FIELDS_JSON=$(jq -n \
      --arg project "$JIRA_PROJECT_KEY" \
      --arg summary "$TITLE" \
      --arg issuetype "$ISSUE_TYPE" \
      --argjson labels "$LABELS_JSON" \
      --arg assignee "$ASSIGNEE_ACCOUNT_ID" \
      '{
        project: {key: $project},
        summary: $summary,
        issuetype: {name: $issuetype},
        labels: $labels
      } + (if $assignee != "" then {assignee: {accountId: $assignee}} else {} end)')
fi

CREATE_PAYLOAD=$(jq -n --argjson fields "$FIELDS_JSON" '{fields: $fields}')

# Create issue via Jira API
response=$(curl -s -w "\n%{http_code}" -X POST \
  -H "Authorization: Basic $AUTH_HEADER" \
  -H "Content-Type: application/json" \
  -d "$CREATE_PAYLOAD" \
  "$JIRA_URL/rest/api/3/issue" 2>&1)

http_code=$(echo "$response" | tail -n 1)
body=$(echo "$response" | sed '$d')

# Handle errors
if [ "$http_code" -ne 201 ]; then
    case "$http_code" in
        400)
            echo "Error: Invalid request - check issue type, labels, or required fields" >&2
            echo "$body" | jq -r '.errorMessages[]?, .errors | to_entries[] | "  \(.key): \(.value)"' 2>/dev/null || echo "$body" >&2
            exit 3
            ;;
        401|403)
            echo "Error: Authentication failed or permission denied" >&2
            exit 11
            ;;
        *)
            echo "Error: Failed to create issue (HTTP $http_code)" >&2
            echo "$body" >&2
            exit 1
            ;;
    esac
fi

# Parse response and normalize
ISSUE_KEY=$(echo "$body" | jq -r '.key')
ISSUE_ID=$(echo "$body" | jq -r '.id')
ISSUE_URL="$JIRA_URL/browse/$ISSUE_KEY"

# Output normalized JSON
jq -n \
  --arg id "$ISSUE_ID" \
  --arg key "$ISSUE_KEY" \
  --arg url "$ISSUE_URL" \
  --arg title "$TITLE" \
  '{
    id: $id,
    number: $key,
    title: $title,
    url: $url,
    state: "open",
    platform: "jira"
  }'

exit 0
