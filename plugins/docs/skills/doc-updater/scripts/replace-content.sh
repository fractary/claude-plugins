#!/usr/bin/env bash
#
# replace-content.sh - Pattern-based content replacement in markdown document
#
# Usage: replace-content.sh --file <path> --pattern <pattern> --replacement <text> [--regex] [--global]
#

set -euo pipefail

# Default values
FILE_PATH=""
PATTERN=""
REPLACEMENT=""
USE_REGEX=false
GLOBAL=true

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --pattern)
      PATTERN="$2"
      shift 2
      ;;
    --replacement)
      REPLACEMENT="$2"
      shift 2
      ;;
    --regex)
      USE_REGEX="$2"
      shift 2
      ;;
    --global)
      GLOBAL="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$FILE_PATH" ]] || [[ -z "$PATTERN" ]]; then
  echo "Error: Missing required arguments" >&2
  echo "Usage: replace-content.sh --file <path> --pattern <pattern> --replacement <text>" >&2
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

# Read file content
CONTENT=$(cat "$FILE_PATH")

# Track if in code block (don't replace inside code blocks)
IN_CODE_BLOCK=false
RESULT=""
REPLACEMENTS=0
FIRST_REPLACEMENT=true

while IFS= read -r line; do
  # Check for code block markers
  if [[ "$line" =~ ^```  ]]; then
    IN_CODE_BLOCK=$([ "$IN_CODE_BLOCK" == "true" ] && echo "false" || echo "true")
    RESULT+="$line"$'\n'
    continue
  fi

  # If in code block, don't replace
  if [[ "$IN_CODE_BLOCK" == "true" ]]; then
    RESULT+="$line"$'\n'
    continue
  fi

  # Perform replacement
  if [[ "$USE_REGEX" == "true" ]]; then
    # Regex replacement
    if [[ "$GLOBAL" == "true" ]]; then
      # Global replacement (all occurrences)
      if [[ "$line" =~ $PATTERN ]]; then
        NEW_LINE=$(echo "$line" | sed -E "s|${PATTERN}|${REPLACEMENT}|g")
        RESULT+="$NEW_LINE"$'\n'
        ((REPLACEMENTS++))
      else
        RESULT+="$line"$'\n'
      fi
    else
      # Single replacement (first occurrence only)
      if [[ "$line" =~ $PATTERN ]] && [[ "$FIRST_REPLACEMENT" == "true" ]]; then
        NEW_LINE=$(echo "$line" | sed -E "s|${PATTERN}|${REPLACEMENT}|")
        RESULT+="$NEW_LINE"$'\n'
        FIRST_REPLACEMENT=false
        ((REPLACEMENTS++))
      else
        RESULT+="$line"$'\n'
      fi
    fi
  else
    # Literal replacement
    if [[ "$line" == *"$PATTERN"* ]]; then
      if [[ "$GLOBAL" == "true" ]]; then
        # Replace all occurrences in line
        NEW_LINE="${line//$PATTERN/$REPLACEMENT}"
        RESULT+="$NEW_LINE"$'\n'
        # Count occurrences
        COUNT=$(echo "$line" | grep -o "$PATTERN" | wc -l)
        REPLACEMENTS=$((REPLACEMENTS + COUNT))
      else
        # Replace first occurrence only
        if [[ "$FIRST_REPLACEMENT" == "true" ]]; then
          NEW_LINE="${line/$PATTERN/$REPLACEMENT}"
          RESULT+="$NEW_LINE"$'\n'
          FIRST_REPLACEMENT=false
          ((REPLACEMENTS++))
        else
          RESULT+="$line"$'\n'
        fi
      fi
    else
      RESULT+="$line"$'\n'
    fi
  fi
done <<< "$CONTENT"

# Check if any replacements were made
if [[ $REPLACEMENTS -eq 0 ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Pattern not found: $PATTERN",
  "error_code": "PATTERN_NOT_FOUND",
  "replacements": 0
}
EOF
  exit 1
fi

# Write updated content
echo -n "$RESULT" > "$FILE_PATH"

# Return success
cat <<EOF
{
  "success": true,
  "operation": "replace-content",
  "file": "$FILE_PATH",
  "pattern": "$PATTERN",
  "replacement": "$REPLACEMENT",
  "use_regex": $USE_REGEX,
  "global": $GLOBAL,
  "replacements": $REPLACEMENTS
}
EOF
