#!/usr/bin/env bash
#
# render-template.sh - Render Mustache-style template with variable substitution
#
# Usage: render-template.sh --template <path> --data <json> --output <path>
#

set -euo pipefail

# Default values
TEMPLATE_PATH=""
DATA_JSON=""
OUTPUT_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --template)
      TEMPLATE_PATH="$2"
      shift 2
      ;;
    --data)
      DATA_JSON="$2"
      shift 2
      ;;
    --output)
      OUTPUT_PATH="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Security: Validate file paths to prevent path traversal
validate_path() {
  local file_path=$1
  local context=$2

  # Resolve to absolute path
  local abs_path=$(realpath -m "$file_path" 2>/dev/null || echo "$file_path")

  # Get script directory and allowed roots
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local plugin_root="$(cd "$script_dir/../../.." && pwd)"

  # For templates, must be within plugin directory
  if [[ "$context" == "template" ]]; then
    if [[ ! "$abs_path" =~ ^"$plugin_root" ]]; then
      echo "Error: Template path outside plugin directory: $file_path" >&2
      exit 1
    fi
  fi

  # For output, must not contain path traversal sequences
  if [[ "$context" == "output" ]]; then
    if [[ "$file_path" =~ \.\./.*\.\. ]] || [[ "$file_path" =~ ^/ && ! "$abs_path" =~ ^"$plugin_root" ]]; then
      echo "Error: Invalid output path (path traversal detected): $file_path" >&2
      exit 1
    fi
  fi
}

# Validate required arguments
if [[ -z "$TEMPLATE_PATH" ]] || [[ -z "$DATA_JSON" ]] || [[ -z "$OUTPUT_PATH" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: render-template.sh --template <path> --data <json> --output <path>" >&2
  exit 1
fi

# Security: Validate paths
validate_path "$TEMPLATE_PATH" "template"
validate_path "$OUTPUT_PATH" "output"

# Check if template file exists
if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "Error: Template file not found: $TEMPLATE_PATH" >&2
  exit 1
fi

# Check if jq is available for JSON parsing
if ! command -v jq &> /dev/null; then
  echo "Error: jq is required but not installed" >&2
  exit 1
fi

# Validate JSON data
if ! echo "$DATA_JSON" | jq empty 2>/dev/null; then
  echo "Error: Invalid JSON data" >&2
  exit 1
fi

# Function to get value from JSON using jq
get_value() {
  local path="$1"
  echo "$DATA_JSON" | jq -r "$path // empty" 2>/dev/null
}

# Function to check if a path exists in JSON
has_value() {
  local path="$1"
  local value
  value=$(echo "$DATA_JSON" | jq -r "$path // empty" 2>/dev/null)
  [[ -n "$value" && "$value" != "null" ]]
}

# Read template
TEMPLATE_CONTENT=$(cat "$TEMPLATE_PATH")

# Simple Mustache-style rendering
# This is a simplified implementation that handles:
# - Simple variables: {{variable}}
# - Nested objects: {{object.field}}
# - Conditionals: {{#condition}}...{{/condition}} and {{^condition}}...{{/condition}}
# - Loops: {{#array}}{{.}}{{/array}}

# Start with the template content
RENDERED="$TEMPLATE_CONTENT"

# Phase 1: Handle loops and conditionals (process from innermost to outermost)
# We'll do multiple passes to handle nested structures
for pass in {1..5}; do
  # Handle positive conditionals {{#key}}...{{/key}}
  while [[ "$RENDERED" =~ \{\{#([a-zA-Z0-9_\.]+)\}\}(.*)\{\{/\1\}\} ]]; do
    local key="${BASH_REMATCH[1]}"
    local content="${BASH_REMATCH[2]}"
    local full_match="${BASH_REMATCH[0]}"

    # Check if key exists and has truthy value
    local jq_path=".${key}"
    local value
    value=$(get_value "$jq_path")

    if [[ -n "$value" && "$value" != "null" && "$value" != "false" && "$value" != "[]" ]]; then
      # Check if it's an array
      local is_array
      is_array=$(echo "$DATA_JSON" | jq -r "if ($jq_path | type) == \"array\" then \"true\" else \"false\" end")

      if [[ "$is_array" == "true" ]]; then
        # Handle array loop
        local array_content=""
        local array_length
        array_length=$(echo "$DATA_JSON" | jq -r "${jq_path} | length")

        for (( i=0; i<array_length; i++ )); do
          local item_content="$content"
          # Replace {{.}} with array item
          local item_value
          item_value=$(echo "$DATA_JSON" | jq -r "${jq_path}[$i]")
          item_content="${item_content//\{\{.\}\}/$item_value}"

          # Handle object properties in arrays
          while [[ "$item_content" =~ \{\{([a-zA-Z0-9_]+)\}\} ]]; do
            local prop="${BASH_REMATCH[1]}"
            local prop_value
            prop_value=$(echo "$DATA_JSON" | jq -r "${jq_path}[$i].$prop // empty")
            item_content="${item_content//\{\{$prop\}\}/$prop_value}"
          done

          array_content+="$item_content"
        done

        RENDERED="${RENDERED//$full_match/$array_content}"
      else
        # Not an array, just include the content
        RENDERED="${RENDERED//$full_match/$content}"
      fi
    else
      # Key doesn't exist or is falsy, remove the section
      RENDERED="${RENDERED//$full_match/}"
    fi
  done

  # Handle negative conditionals {{^key}}...{{/key}}
  while [[ "$RENDERED" =~ \{\{\^([a-zA-Z0-9_\.]+)\}\}(.*)\{\{/\1\}\} ]]; do
    local key="${BASH_REMATCH[1]}"
    local content="${BASH_REMATCH[2]}"
    local full_match="${BASH_REMATCH[0]}"

    # Check if key exists and has truthy value
    local jq_path=".${key}"
    local value
    value=$(get_value "$jq_path")

    if [[ -z "$value" || "$value" == "null" || "$value" == "false" || "$value" == "[]" ]]; then
      # Key doesn't exist or is falsy, include the content
      RENDERED="${RENDERED//$full_match/$content}"
    else
      # Key exists and is truthy, remove the section
      RENDERED="${RENDERED//$full_match/}"
    fi
  done
done

# Phase 2: Replace simple variables {{variable}} and {{object.field}}
while [[ "$RENDERED" =~ \{\{([a-zA-Z0-9_\.]+)\}\} ]]; do
  local var="${BASH_REMATCH[1]}"
  local jq_path=".${var}"
  local value
  value=$(get_value "$jq_path")

  # If value is empty, replace with empty string
  if [[ -z "$value" || "$value" == "null" ]]; then
    value=""
  fi

  # Replace all occurrences of this variable
  RENDERED="${RENDERED//\{\{$var\}\}/$value}"
done

# Write output
echo "$RENDERED" > "$OUTPUT_PATH"

# Return success JSON
cat <<EOF
{
  "success": true,
  "template": "$TEMPLATE_PATH",
  "output": "$OUTPUT_PATH",
  "size_bytes": $(stat -f%z "$OUTPUT_PATH" 2>/dev/null || stat -c%s "$OUTPUT_PATH" 2>/dev/null)
}
EOF
