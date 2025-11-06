#!/usr/bin/env bash
#
# append-section.sh - Add new section to markdown document
#
# Usage: append-section.sh --file <path> --heading <heading> --content <content> [--after <heading>] [--level <number>]
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
FILE_PATH=""
SECTION_HEADING=""
CONTENT=""
AFTER_HEADING=""
HEADING_LEVEL=2

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --heading)
      SECTION_HEADING="$2"
      shift 2
      ;;
    --content)
      CONTENT="$2"
      shift 2
      ;;
    --after)
      AFTER_HEADING="$2"
      shift 2
      ;;
    --level)
      HEADING_LEVEL="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]] || [[ -z "$SECTION_HEADING" ]] || [[ -z "$CONTENT" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: append-section.sh --file <path> --heading <heading> --content <content>" >&2
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

# Parse document
PARSE_RESULT=$("$SCRIPT_DIR/parse-document.sh" --file "$FILE_PATH")

if ! echo "$PARSE_RESULT" | jq -e '.success' &>/dev/null; then
  echo "Error: Failed to parse document" >&2
  exit 1
fi

# Determine insertion point
INSERTION_LINE=0

if [[ -n "$AFTER_HEADING" ]]; then
  # Find the section to insert after
  AFTER_SECTION=$(echo "$PARSE_RESULT" | jq -r --arg heading "$AFTER_HEADING" '.sections[] | select(.heading == $heading)')

  if [[ -z "$AFTER_SECTION" || "$AFTER_SECTION" == "null" ]]; then
    cat <<EOF
{
  "success": false,
  "error": "Reference section not found: $AFTER_HEADING",
  "error_code": "SECTION_NOT_FOUND"
}
EOF
    exit 1
  fi

  # Insert after this section (at its end line)
  INSERTION_LINE=$(echo "$AFTER_SECTION" | jq -r '.line_end')
else
  # Insert at end of document
  INSERTION_LINE=$(wc -l < "$FILE_PATH")
fi

# Create temp file
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Build new document with inserted section
{
  # Part 1: Everything up to insertion point
  if [[ $INSERTION_LINE -gt 0 ]]; then
    sed -n "1,${INSERTION_LINE}p" "$FILE_PATH"
  fi

  # Part 2: Blank line separator
  echo ""

  # Part 3: New section
  HEADING_MARKS=$(printf '#%.0s' $(seq 1 $HEADING_LEVEL))
  echo "${HEADING_MARKS} ${SECTION_HEADING}"
  echo ""
  echo "$CONTENT"

  # Part 4: Everything after insertion point
  TOTAL_LINES=$(wc -l < "$FILE_PATH")
  if [[ $INSERTION_LINE -lt $TOTAL_LINES ]]; then
    echo ""
    sed -n "$((INSERTION_LINE + 1)),${TOTAL_LINES}p" "$FILE_PATH"
  fi
} > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$FILE_PATH"

# Return success
cat <<EOF
{
  "success": true,
  "operation": "append-section",
  "file": "$FILE_PATH",
  "section_added": "$SECTION_HEADING",
  "heading_level": $HEADING_LEVEL,
  "inserted_after": "${AFTER_HEADING:-end of document}",
  "insertion_line": $INSERTION_LINE,
  "content_length": ${#CONTENT}
}
EOF
