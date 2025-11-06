#!/usr/bin/env bash
#
# add-frontmatter.sh - Add YAML front matter to markdown document
#
# Usage: add-frontmatter.sh --file <path> --frontmatter <json>
#

set -euo pipefail

# Source security utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../common/security-utils.sh"

# Default values
FILE_PATH=""
FRONTMATTER_JSON=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --frontmatter)
      FRONTMATTER_JSON="$2"
      shift 2
      ;;
    *)
      echo "Error [$SCRIPT_NAME]: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]] || [[ -z "$FRONTMATTER_JSON" ]]; then
  echo "Error [$SCRIPT_NAME]: Missing required arguments" >&2
  echo "Usage: add-frontmatter.sh --file <path> --frontmatter <json>" >&2
  exit 1
fi

# Security: Validate file path (write operation since we'll modify the file)
if ! validate_file_path "$FILE_PATH" "write"; then
  exit 1
fi

# Security: Validate JSON
if ! validate_json "$FRONTMATTER_JSON"; then
  exit 1
fi

# Check dependencies
if ! check_dependencies jq; then
  exit 1
fi

# Check if file exists
if [[ ! -f "$FILE_PATH" ]]; then
  echo "Error [$SCRIPT_NAME]: File not found: $FILE_PATH" >&2
  exit 1
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Check if yq is available (optional, we'll use jq if not available)
HAS_YQ=false
if command -v yq &> /dev/null; then
  HAS_YQ=true
fi

# Validate JSON
if ! echo "$FRONTMATTER_JSON" | jq empty 2>/dev/null; then
  echo "Error: Invalid JSON for front matter" >&2
  exit 1
fi

# Create secure temp file with proper cleanup
TEMP_FILE=$(create_secure_temp)
setup_trap_handler "$TEMP_FILE"

# Check if file already has front matter
if head -n 1 "$FILE_PATH" | grep -q "^---$"; then
  echo "Warning: File already has front matter, merging..." >&2

  # SECURITY FIX: Only match first two --- markers, not horizontal rules in content
  # Find line number of second --- marker (end of front matter)
  SECOND_DELIM_LINE=$(grep -n "^---$" "$FILE_PATH" | head -n 2 | tail -n 1 | cut -d: -f1)

  # Extract existing front matter (between line 2 and second delimiter, exclusive)
  EXISTING_FM=$(sed -n "2,$(($SECOND_DELIM_LINE - 1))p" "$FILE_PATH")

  # Get content after front matter (everything after second --- marker)
  CONTENT=$(tail -n +$(($SECOND_DELIM_LINE + 1)) "$FILE_PATH")

  # Merge front matter (new values take precedence)
  if [[ "$HAS_YQ" == "true" ]]; then
    # Use yq for proper YAML merging
    MERGED_FM=$(echo "$EXISTING_FM" | yq eval -o json | jq -s ".[0] * $FRONTMATTER_JSON" | yq eval -P -)
  else
    # Fallback: just use new front matter
    echo "Warning: yq not available, replacing front matter entirely" >&2
    MERGED_FM_JSON="$FRONTMATTER_JSON"
  fi
else
  # No existing front matter, use content as-is
  CONTENT=$(cat "$FILE_PATH")
  MERGED_FM_JSON="$FRONTMATTER_JSON"
fi

# Convert JSON to YAML format
# We'll create YAML manually from JSON for simplicity
YAML_FM=""

# Function to convert JSON to YAML (simple implementation)
json_to_yaml() {
  local json="$1"
  local indent="${2:-0}"
  local prefix=$(printf '%*s' "$indent" '')

  echo "$json" | jq -r 'to_entries[] | "\(.key): \(.value | @json)"' | while IFS=: read -r key value; do
    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    # Handle different types
    if [[ "$value" == "null" ]]; then
      echo "${prefix}${key}:"
    elif [[ "$value" =~ ^\[.*\]$ ]]; then
      # Array
      echo "${prefix}${key}:"
      echo "$FRONTMATTER_JSON" | jq -r ".${key}[]" | while read -r item; do
        echo "${prefix}  - $item"
      done
    elif [[ "$value" =~ ^\{.*\}$ ]]; then
      # Object (nested) - simplified handling
      echo "${prefix}${key}:"
      echo "$FRONTMATTER_JSON" | jq -r ".${key} | to_entries[] | \"  \(.key): \(.value)\"" | while read -r line; do
        echo "${prefix}${line}"
      done
    elif [[ "$value" =~ ^\".*\"$ ]]; then
      # String (remove quotes and re-quote if needed)
      clean_value=$(echo "$value" | sed 's/^"//; s/"$//')
      if [[ "$clean_value" == *":"* ]] || [[ "$clean_value" == *"#"* ]] || [[ "$clean_value" == *"["* ]]; then
        # Quote strings that contain special YAML characters
        echo "${prefix}${key}: \"${clean_value}\""
      else
        echo "${prefix}${key}: ${clean_value}"
      fi
    else
      # Number, boolean, etc
      echo "${prefix}${key}: ${value}"
    fi
  done
}

# Generate YAML from JSON
YAML_FM=$(json_to_yaml "$FRONTMATTER_JSON")

# Build final document
{
  echo "---"
  echo "$YAML_FM"
  echo "---"
  echo ""
  echo "$CONTENT"
} > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$FILE_PATH"

# Return success JSON
cat <<EOF
{
  "success": true,
  "file": "$FILE_PATH",
  "frontmatter_added": true,
  "size_bytes": $(get_file_size "$FILE_PATH")
}
EOF
