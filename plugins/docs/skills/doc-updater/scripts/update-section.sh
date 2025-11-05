#!/usr/bin/env bash
#
# update-section.sh - Update specific section in markdown document
#
# Usage: update-section.sh --file <path> --heading <heading> --content <content> [--preserve-subsections]
#

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Default values
FILE_PATH=""
SECTION_HEADING=""
NEW_CONTENT=""
PRESERVE_SUBSECTIONS=true

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
      NEW_CONTENT="$2"
      shift 2
      ;;
    --preserve-subsections)
      PRESERVE_SUBSECTIONS="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]] || [[ -z "$SECTION_HEADING" ]] || [[ -z "$NEW_CONTENT" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: update-section.sh --file <path> --heading <heading> --content <content>" >&2
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

# Parse document to find section
PARSE_RESULT=$("$SCRIPT_DIR/parse-document.sh" --file "$FILE_PATH")

if ! echo "$PARSE_RESULT" | jq -e '.success' &>/dev/null; then
  echo "Error: Failed to parse document" >&2
  echo "$PARSE_RESULT" >&2
  exit 1
fi

# Find the target section
SECTION=$(echo "$PARSE_RESULT" | jq -r --arg heading "$SECTION_HEADING" '.sections[] | select(.heading == $heading)')

if [[ -z "$SECTION" || "$SECTION" == "null" ]]; then
  # Section not found, list available sections
  AVAILABLE=$(echo "$PARSE_RESULT" | jq -r '.sections[].heading' | paste -sd ',' -)
  cat <<EOF
{
  "success": false,
  "error": "Section not found: $SECTION_HEADING",
  "error_code": "SECTION_NOT_FOUND",
  "available_sections": ["$(echo "$AVAILABLE" | sed 's/,/", "/g')"]
}
EOF
  exit 1
fi

# Extract section details
HEADING_LEVEL=$(echo "$SECTION" | jq -r '.level')
LINE_START=$(echo "$SECTION" | jq -r '.line_start')
LINE_END=$(echo "$SECTION" | jq -r '.line_end')
SUBSECTIONS=$(echo "$SECTION" | jq '.subsections')

# Create temp file
TEMP_FILE=$(mktemp)
trap "rm -f $TEMP_FILE" EXIT

# Extract subsections content if preserving
SUBSECTIONS_CONTENT=""
if [[ "$PRESERVE_SUBSECTIONS" == "true" ]] && [[ "$SUBSECTIONS" != "[]" ]] && [[ "$SUBSECTIONS" != "null" ]]; then
  # Find first subsection line
  FIRST_SUBSECTION_LINE=$(echo "$SUBSECTIONS" | jq -r '.[0].line_start')
  if [[ -n "$FIRST_SUBSECTION_LINE" && "$FIRST_SUBSECTION_LINE" != "null" ]]; then
    # Extract from first subsection to end of main section
    SUBSECTIONS_CONTENT=$(sed -n "${FIRST_SUBSECTION_LINE},${LINE_END}p" "$FILE_PATH")
  fi
fi

# Build new section
{
  # Part 1: Everything before the section
  if [[ $LINE_START -gt 1 ]]; then
    sed -n "1,$((LINE_START - 1))p" "$FILE_PATH"
  fi

  # Part 2: Section heading (recreate with correct level)
  HEADING_MARKS=$(printf '#%.0s' $(seq 1 $HEADING_LEVEL))
  echo "${HEADING_MARKS} ${SECTION_HEADING}"
  echo ""

  # Part 3: New content
  echo "$NEW_CONTENT"

  # Part 4: Subsections if preserving
  if [[ -n "$SUBSECTIONS_CONTENT" ]]; then
    echo ""
    echo "$SUBSECTIONS_CONTENT"
  fi

  # Part 5: Everything after the section
  TOTAL_LINES=$(wc -l < "$FILE_PATH")
  if [[ $LINE_END -lt $TOTAL_LINES ]]; then
    echo ""
    sed -n "$((LINE_END + 1)),${TOTAL_LINES}p" "$FILE_PATH"
  fi
} > "$TEMP_FILE"

# Replace original file
mv "$TEMP_FILE" "$FILE_PATH"

# Calculate changes
LINES_CHANGED=$((LINE_END - LINE_START + 1))

# Return success
cat <<EOF
{
  "success": true,
  "operation": "update-section",
  "file": "$FILE_PATH",
  "section_updated": "$SECTION_HEADING",
  "heading_level": $HEADING_LEVEL,
  "line_range": {
    "start": $LINE_START,
    "end": $LINE_END
  },
  "lines_changed": $LINES_CHANGED,
  "subsections_preserved": $PRESERVE_SUBSECTIONS,
  "content_length": ${#NEW_CONTENT}
}
EOF
