#!/usr/bin/env bash
#
# update-metadata.sh - Update front matter fields in markdown document
#
# Usage: update-metadata.sh --file <path> --field <field> --value <value> [--auto-timestamp]
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
FILE_PATH=""
FIELD=""
VALUE=""
AUTO_TIMESTAMP=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --field)
      FIELD="$2"
      shift 2
      ;;
    --value)
      VALUE="$2"
      shift 2
      ;;
    --auto-timestamp)
      AUTO_TIMESTAMP="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]] || [[ -z "$FIELD" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: update-metadata.sh --file <path> --field <field> --value <value>" >&2
  exit 1
fi

# Security: Validate file path to prevent path traversal
validate_path() {
  local file_path=$1
  if [[ "$file_path" =~ \.\./.*\.\. ]] || [[ "$file_path" =~ ^/(etc|sys|proc|dev|bin|sbin|usr/bin|usr/sbin) ]]; then
    cat <<EOF
{
  "success": false,
  "error": "Invalid file path (security violation): $file_path",
  "error_code": "SECURITY_VIOLATION"
}
EOF
    exit 1
  fi
}

validate_path "$FILE_PATH"

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

# Check if file has front matter
if ! head -n 1 "$FILE_PATH" | grep -q "^---$"; then
  cat <<EOF
{
  "success": false,
  "error": "No front matter found in document",
  "error_code": "NO_FRONTMATTER"
}
EOF
  exit 1
fi

# Check if yq is available (preferred) or jq
HAS_YQ=false
if command -v yq &> /dev/null; then
  HAS_YQ=true
fi

# Extract front matter
FM_START=1
FM_END=$(tail -n +2 "$FILE_PATH" | grep -n "^---$" | head -1 | cut -d: -f1)
FM_END=$((FM_END + 1))

FM_CONTENT=$(sed -n "${FM_START},${FM_END}p" "$FILE_PATH" | sed '1d;$d')

# Get document body (everything after front matter)
TOTAL_LINES=$(wc -l < "$FILE_PATH")
BODY_START=$((FM_END + 1))
BODY_CONTENT=""
if [[ $BODY_START -le $TOTAL_LINES ]]; then
  BODY_CONTENT=$(sed -n "${BODY_START},${TOTAL_LINES}p" "$FILE_PATH")
fi

# Update field value
if [[ "$HAS_YQ" == "true" ]]; then
  # Use yq for proper YAML manipulation
  UPDATED_FM=$(echo "$FM_CONTENT" | yq eval ".${FIELD} = \"${VALUE}\"" -)

  # Auto-update timestamp if enabled
  if [[ "$AUTO_TIMESTAMP" == "true" ]]; then
    CURRENT_DATE=$(date +%Y-%m-%d)
    UPDATED_FM=$(echo "$UPDATED_FM" | yq eval ".updated = \"${CURRENT_DATE}\"" -)
  fi
else
  # Fallback: manual field update
  UPDATED_FM="$FM_CONTENT"

  # Check if field exists and update, or add if new
  if echo "$FM_CONTENT" | grep -q "^${FIELD}:"; then
    # Field exists, replace it
    UPDATED_FM=$(echo "$FM_CONTENT" | sed "s|^${FIELD}:.*|${FIELD}: ${VALUE}|")
  else
    # Field doesn't exist, add it
    UPDATED_FM="${FM_CONTENT}"$'\n'"${FIELD}: ${VALUE}"
  fi

  # Auto-update timestamp
  if [[ "$AUTO_TIMESTAMP" == "true" ]]; then
    CURRENT_DATE=$(date +%Y-%m-%d)
    if echo "$UPDATED_FM" | grep -q "^updated:"; then
      UPDATED_FM=$(echo "$UPDATED_FM" | sed "s|^updated:.*|updated: ${CURRENT_DATE}|")
    else
      UPDATED_FM="${UPDATED_FM}"$'\n'"updated: ${CURRENT_DATE}"
    fi
  fi
fi

# Create temp file
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Rebuild document
{
  echo "---"
  echo "$UPDATED_FM"
  echo "---"
  if [[ -n "$BODY_CONTENT" ]]; then
    echo "$BODY_CONTENT"
  fi
} > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$FILE_PATH"

# Extract updated value for confirmation
UPDATED_VALUE="$VALUE"
if [[ "$HAS_YQ" == "true" ]]; then
  UPDATED_VALUE=$(echo "$UPDATED_FM" | yq eval ".${FIELD}" -)
fi

# Return success
cat <<EOF
{
  "success": true,
  "operation": "update-metadata",
  "file": "$FILE_PATH",
  "field_updated": "$FIELD",
  "old_value": null,
  "new_value": "$UPDATED_VALUE",
  "auto_timestamp": $AUTO_TIMESTAMP,
  "timestamp_updated": $AUTO_TIMESTAMP
}
EOF
