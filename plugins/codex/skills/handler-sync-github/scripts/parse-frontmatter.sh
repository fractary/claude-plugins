#!/bin/bash
# Parse frontmatter from markdown files to extract codex sync rules
#
# Usage:
#   ./parse-frontmatter.sh <file-path>
#
# Looks for:
#   codex_sync_include: ["pattern1", "pattern2"]
#   codex_sync_exclude: ["pattern1", "pattern2"]
#
# Output: JSON object with parsed rules

set -euo pipefail

FILE_PATH="${1:-}"

if [ -z "$FILE_PATH" ]; then
  echo '{"success": false, "error": "File path required"}' | jq .
  exit 1
fi

if [ ! -f "$FILE_PATH" ]; then
  echo '{"success": false, "error": "File not found: '"$FILE_PATH"'"}' | jq .
  exit 1
fi

# Check if file has frontmatter (starts with ---)
if ! head -n 1 "$FILE_PATH" | grep -q '^---$'; then
  # No frontmatter
  echo '{"success": true, "has_frontmatter": false, "include": [], "exclude": []}' | jq .
  exit 0
fi

# Extract frontmatter (between first and second ---)
FRONTMATTER=$(awk '/^---$/{if(++n==2)exit;next}n==1' "$FILE_PATH")

if [ -z "$FRONTMATTER" ]; then
  # Empty frontmatter
  echo '{"success": true, "has_frontmatter": true, "include": [], "exclude": []}' | jq .
  exit 0
fi

# Check for yq (YAML parser)
if ! command -v yq &> /dev/null; then
  # Fallback: try to parse with grep and sed
  INCLUDE_PATTERN=$(echo "$FRONTMATTER" | grep -E '^\s*codex_sync_include:' || true)
  EXCLUDE_PATTERN=$(echo "$FRONTMATTER" | grep -E '^\s*codex_sync_exclude:' || true)

  # Basic parsing for inline arrays: codex_sync_include: ["pattern1", "pattern2"]
  INCLUDE_ARRAY="[]"
  EXCLUDE_ARRAY="[]"

  if [ -n "$INCLUDE_PATTERN" ]; then
    # Extract the array part after the colon
    INCLUDE_VALUE=$(echo "$INCLUDE_PATTERN" | sed 's/^[^:]*://; s/^[ \t]*//')
    # If it's a JSON array, use it directly
    if echo "$INCLUDE_VALUE" | jq empty 2>/dev/null; then
      INCLUDE_ARRAY="$INCLUDE_VALUE"
    fi
  fi

  if [ -n "$EXCLUDE_PATTERN" ]; then
    EXCLUDE_VALUE=$(echo "$EXCLUDE_PATTERN" | sed 's/^[^:]*://; s/^[ \t]*//')
    if echo "$EXCLUDE_VALUE" | jq empty 2>/dev/null; then
      EXCLUDE_ARRAY="$EXCLUDE_VALUE"
    fi
  fi

  jq -n \
    --argjson include "$INCLUDE_ARRAY" \
    --argjson exclude "$EXCLUDE_ARRAY" \
    '{
      success: true,
      has_frontmatter: true,
      include: $include,
      exclude: $exclude,
      parser: "fallback"
    }'
  exit 0
fi

# Use yq to parse YAML frontmatter
echo "$FRONTMATTER" | yq eval -o=json '.' 2>/dev/null | jq '{
  success: true,
  has_frontmatter: true,
  include: (.codex_sync_include // []),
  exclude: (.codex_sync_exclude // []),
  parser: "yq"
}'

exit 0
