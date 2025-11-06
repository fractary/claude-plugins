#!/usr/bin/env bash
#
# lint-markdown.sh - Lint markdown syntax and style
#
# Usage: lint-markdown.sh --file <path>
#

set -euo pipefail

# Default values
FILE_PATH=""

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
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

# Initialize issues array
ISSUES="[]"

# Check if markdownlint is available
if command -v markdownlint &> /dev/null; then
  # Use markdownlint CLI
  LINT_OUTPUT=$(markdownlint "$FILE_PATH" 2>&1 || true)

  if [[ -n "$LINT_OUTPUT" ]]; then
    # Parse markdownlint output
    # Format: file:line MD### message
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        # Extract components
        if [[ "$line" =~ :([0-9]+)\ (MD[0-9]+)\ (.*)$ ]]; then
          LINE_NUM="${BASH_REMATCH[1]}"
          RULE="${BASH_REMATCH[2]}"
          MESSAGE="${BASH_REMATCH[3]}"

          # Add to issues
          ISSUES=$(echo "$ISSUES" | jq \
            --arg line "$LINE_NUM" \
            --arg rule "$RULE" \
            --arg msg "$MESSAGE" \
            '. += [{"line": ($line|tonumber), "rule": $rule, "severity": "warning", "message": $msg}]')
        fi
      fi
    done <<< "$LINT_OUTPUT"
  fi
else
  # Fallback: basic manual checks
  LINE_NUM=0

  while IFS= read -r line; do
    ((LINE_NUM++))

    # Check 1: Line length (warning if > 120 chars)
    if [[ ${#line} -gt 120 ]]; then
      ISSUES=$(echo "$ISSUES" | jq \
        --arg line "$LINE_NUM" \
        --arg msg "Line length exceeds 120 characters (${#line} chars)" \
        '. += [{"line": ($line|tonumber), "rule": "LINE_LENGTH", "severity": "info", "message": $msg}]')
    fi

    # Check 2: Trailing whitespace
    if [[ "$line" =~ [[:space:]]$ ]]; then
      ISSUES=$(echo "$ISSUES" | jq \
        --arg line "$LINE_NUM" \
        '. += [{"line": ($line|tonumber), "rule": "TRAILING_SPACE", "severity": "info", "message": "Trailing whitespace"}]')
    fi

    # Check 3: Hard tabs (use spaces)
    if [[ "$line" == *$'\t'* ]]; then
      ISSUES=$(echo "$ISSUES" | jq \
        --arg line "$LINE_NUM" \
        '. += [{"line": ($line|tonumber), "rule": "HARD_TAB", "severity": "info", "message": "Use spaces instead of tabs"}]')
    fi

    # Check 4: Code blocks without language tag
    # BUG FIX: Match code blocks that are ONLY ``` without language identifier
    # Don't flag blocks like ```bash or ```python
    if [[ "$line" =~ ^[[:space:]]*\`\`\`[[:space:]]*$ ]]; then
      ISSUES=$(echo "$ISSUES" | jq \
        --arg line "$LINE_NUM" \
        '. += [{"line": ($line|tonumber), "rule": "CODE_LANG", "severity": "info", "message": "Code block missing language identifier"}]')
    fi

  done < "$FILE_PATH"
fi

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
  "check": "markdown-lint",
  "total_issues": $ISSUE_COUNT,
  "errors": $ERROR_COUNT,
  "warnings": $WARNING_COUNT,
  "info": $INFO_COUNT,
  "issues": $ISSUES
}
EOF
