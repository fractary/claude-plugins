#!/usr/bin/env bash
#
# check-frontmatter.sh - Validate YAML front matter structure and fields
#
# Usage: check-frontmatter.sh --file <path> [--strict]
#

set -euo pipefail

# Default values
FILE_PATH=""
STRICT_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --strict)
      STRICT_MODE=true
      shift
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]]; then
  echo "Error: Missing required argument: --file" >&2
  exit 1
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "File not found: $FILE_PATH",
  "error_code": "FILE_NOT_FOUND"
}
EOF
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  cat <<EOF
{
  "success": false,
  "error": "jq is required but not installed",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

# Initialize issues array
ISSUES="[]"

# Check if file has front matter
if ! head -n 1 "$FILE_PATH" | grep -q "^---$"; then
  cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "check": "frontmatter",
  "has_frontmatter": false,
  "total_issues": 1,
  "errors": 1,
  "warnings": 0,
  "info": 0,
  "issues": [
    {
      "severity": "error",
      "field": "frontmatter",
      "message": "Missing YAML front matter"
    }
  ]
}
EOF
  exit 0
fi

# Extract front matter (between first two --- markers)
FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$FILE_PATH" | sed '1d;$d')

if [[ -z "$FM_CONTENT" ]]; then
  cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "check": "frontmatter",
  "has_frontmatter": false,
  "total_issues": 1,
  "errors": 1,
  "warnings": 0,
  "info": 0,
  "issues": [
    {
      "severity": "error",
      "field": "frontmatter",
      "message": "Empty front matter block"
    }
  ]
}
EOF
  exit 0
fi

# Parse YAML to JSON
if command -v yq &> /dev/null; then
  FM_JSON=$(echo "$FM_CONTENT" | yq eval -o json 2>/dev/null || echo "{}")
else
  # Basic YAML to JSON (limited support)
  FM_JSON="{"
  first=true
  while IFS=: read -r key value; do
    if [[ -n "$key" && -n "$value" ]]; then
      [[ "$first" == "false" ]] && FM_JSON+=","
      key=$(echo "$key" | xargs)
      value=$(echo "$value" | xargs)
      FM_JSON+="\"$key\":\"$value\""
      first=false
    fi
  done <<< "$FM_CONTENT"
  FM_JSON+="}"
fi

# Valid document types
VALID_TYPES=("adr" "design" "runbook" "api-spec" "test-report" "deployment" "changelog" "architecture" "troubleshooting" "postmortem")

# Valid status values
VALID_ADR_STATUS=("proposed" "accepted" "deprecated" "superseded")
VALID_OTHER_STATUS=("draft" "review" "approved" "deprecated")

# Check required fields
add_issue() {
  local severity=$1
  local field=$2
  local message=$3

  ISSUES=$(echo "$ISSUES" | jq \
    --arg severity "$severity" \
    --arg field "$field" \
    --arg msg "$message" \
    '. += [{"severity": $severity, "field": $field, "message": $msg}]')
}

# Required field: title
TITLE=$(echo "$FM_JSON" | jq -r '.title // empty')
if [[ -z "$TITLE" ]]; then
  add_issue "error" "title" "Missing required field: title"
fi

# Required field: type
DOC_TYPE=$(echo "$FM_JSON" | jq -r '.type // empty')
if [[ -z "$DOC_TYPE" ]]; then
  add_issue "error" "type" "Missing required field: type"
else
  # Validate type is one of valid values
  VALID=false
  for valid_type in "${VALID_TYPES[@]}"; do
    if [[ "$DOC_TYPE" == "$valid_type" ]]; then
      VALID=true
      break
    fi
  done

  if [[ "$VALID" == "false" ]]; then
    add_issue "error" "type" "Invalid document type: '$DOC_TYPE'. Must be one of: ${VALID_TYPES[*]}"
  fi
fi

# Required field: date
DATE=$(echo "$FM_JSON" | jq -r '.date // empty')
if [[ -z "$DATE" ]]; then
  add_issue "error" "date" "Missing required field: date"
else
  # Validate date format (YYYY-MM-DD)
  if ! [[ "$DATE" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
    add_issue "error" "date" "Invalid date format: '$DATE'. Expected YYYY-MM-DD"
  fi
fi

# Recommended field: status
STATUS=$(echo "$FM_JSON" | jq -r '.status // empty')
if [[ -z "$STATUS" ]]; then
  if [[ "$STRICT_MODE" == "true" ]]; then
    add_issue "warning" "status" "Missing recommended field: status"
  fi
else
  # Validate status based on document type
  if [[ "$DOC_TYPE" == "adr" ]]; then
    VALID=false
    for valid_status in "${VALID_ADR_STATUS[@]}"; do
      if [[ "$STATUS" == "$valid_status" ]]; then
        VALID=true
        break
      fi
    done
    if [[ "$VALID" == "false" ]]; then
      add_issue "warning" "status" "Invalid ADR status: '$STATUS'. Expected: ${VALID_ADR_STATUS[*]}"
    fi
  else
    VALID=false
    for valid_status in "${VALID_OTHER_STATUS[@]}"; do
      if [[ "$STATUS" == "$valid_status" ]]; then
        VALID=true
        break
      fi
    done
    if [[ "$VALID" == "false" ]]; then
      add_issue "warning" "status" "Invalid status: '$STATUS'. Expected: ${VALID_OTHER_STATUS[*]}"
    fi
  fi
fi

# Recommended field: author
AUTHOR=$(echo "$FM_JSON" | jq -r '.author // empty')
if [[ -z "$AUTHOR" ]] && [[ "$STRICT_MODE" == "true" ]]; then
  add_issue "info" "author" "Missing recommended field: author"
fi

# Recommended field: tags
TAGS=$(echo "$FM_JSON" | jq -r '.tags // empty')
if [[ -z "$TAGS" ]] && [[ "$STRICT_MODE" == "true" ]]; then
  add_issue "info" "tags" "Missing recommended field: tags"
fi

# Optional field: updated (if present, validate format)
UPDATED=$(echo "$FM_JSON" | jq -r '.updated // empty')
if [[ -n "$UPDATED" ]]; then
  if ! [[ "$UPDATED" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2} ]]; then
    add_issue "warning" "updated" "Invalid updated format: '$UPDATED'. Expected YYYY-MM-DD or ISO 8601"
  fi
fi

# Type-specific validations
case "$DOC_TYPE" in
  adr)
    # ADR should have number field
    NUMBER=$(echo "$FM_JSON" | jq -r '.number // empty')
    if [[ -z "$NUMBER" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "number" "ADR missing recommended field: number"
    fi
    ;;

  api-spec)
    # API spec should have version and base_url
    VERSION=$(echo "$FM_JSON" | jq -r '.version // empty')
    if [[ -z "$VERSION" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "version" "API spec missing recommended field: version"
    fi

    BASE_URL=$(echo "$FM_JSON" | jq -r '.base_url // empty')
    if [[ -z "$BASE_URL" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "base_url" "API spec missing recommended field: base_url"
    fi
    ;;

  test-report)
    # Test report should have environment
    ENVIRONMENT=$(echo "$FM_JSON" | jq -r '.environment // empty')
    if [[ -z "$ENVIRONMENT" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "environment" "Test report missing recommended field: environment"
    fi
    ;;

  deployment)
    # Deployment should have version and environment
    VERSION=$(echo "$FM_JSON" | jq -r '.version // empty')
    if [[ -z "$VERSION" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "version" "Deployment missing recommended field: version"
    fi

    ENVIRONMENT=$(echo "$FM_JSON" | jq -r '.environment // empty')
    if [[ -z "$ENVIRONMENT" ]] && [[ "$STRICT_MODE" == "true" ]]; then
      add_issue "warning" "environment" "Deployment missing recommended field: environment"
    fi
    ;;
esac

# Count issues by severity
ISSUE_COUNT=$(echo "$ISSUES" | jq 'length')
ERROR_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.severity == "error")] | length')
WARNING_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.severity == "warning")] | length')
INFO_COUNT=$(echo "$ISSUES" | jq '[.[] | select(.severity == "info")] | length')

# Return results
cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "check": "frontmatter",
  "has_frontmatter": true,
  "document_type": "$DOC_TYPE",
  "total_issues": $ISSUE_COUNT,
  "errors": $ERROR_COUNT,
  "warnings": $WARNING_COUNT,
  "info": $INFO_COUNT,
  "issues": $ISSUES,
  "frontmatter": $FM_JSON
}
EOF
