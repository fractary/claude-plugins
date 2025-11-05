#!/usr/bin/env bash
#
# validate-output.sh - Validate generated documentation
#
# Usage: validate-output.sh --file <path> [--doc-type <type>] [--required-sections <json>]
#

set -euo pipefail

# Default values
FILE_PATH=""
DOC_TYPE="unknown"
REQUIRED_SECTIONS="[]"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --doc-type)
      DOC_TYPE="$2"
      shift 2
      ;;
    --required-sections)
      REQUIRED_SECTIONS="$2"
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
  echo "Error: File not found: $FILE_PATH" >&2
  exit 1
fi

# Initialize issues array
ISSUES=()

# Check 1: Validate front matter exists and is valid YAML
echo "Checking front matter..." >&2
if ! head -n 1 "$FILE_PATH" | grep -q "^---$"; then
  ISSUES+=('{"severity": "error", "check": "frontmatter", "message": "Missing front matter"}')
else
  # Extract front matter
  FM_CONTENT=$(sed -n '/^---$/,/^---$/p' "$FILE_PATH" | sed '1d;$d')

  # Check if yq is available for YAML validation
  if command -v yq &> /dev/null; then
    if ! echo "$FM_CONTENT" | yq eval '.' &>/dev/null; then
      ISSUES+=('{"severity": "error", "check": "frontmatter", "message": "Invalid YAML in front matter"}')
    else
      # Check required fields
      if ! echo "$FM_CONTENT" | yq eval '.title' &>/dev/null || [[ "$(echo "$FM_CONTENT" | yq eval '.title')" == "null" ]]; then
        ISSUES+=('{"severity": "warning", "check": "frontmatter", "message": "Missing required field: title"}')
      fi
      if ! echo "$FM_CONTENT" | yq eval '.type' &>/dev/null || [[ "$(echo "$FM_CONTENT" | yq eval '.type')" == "null" ]]; then
        ISSUES+=('{"severity": "warning", "check": "frontmatter", "message": "Missing required field: type"}')
      fi
      if ! echo "$FM_CONTENT" | yq eval '.date' &>/dev/null || [[ "$(echo "$FM_CONTENT" | yq eval '.date')" == "null" ]]; then
        ISSUES+=('{"severity": "warning", "check": "frontmatter", "message": "Missing required field: date"}')
      fi
    fi
  fi
fi

# Check 2: Validate required sections based on doc type
if [[ "$REQUIRED_SECTIONS" != "[]" ]]; then
  echo "Checking required sections..." >&2
  # Parse required sections from JSON
  if command -v jq &> /dev/null; then
    REQUIRED=$(echo "$REQUIRED_SECTIONS" | jq -r '.[]')
    while IFS= read -r section; do
      # Check if section exists in document (as markdown heading)
      if ! grep -q "^## $section$" "$FILE_PATH" && ! grep -q "^### $section$" "$FILE_PATH"; then
        ISSUES+=("{\"severity\": \"error\", \"check\": \"structure\", \"message\": \"Missing required section: $section\"}")
      fi
    done <<< "$REQUIRED"
  fi
else
  # Default required sections by doc type
  case "$DOC_TYPE" in
    adr)
      for section in "Context" "Decision" "Consequences"; do
        if ! grep -q "^## $section$" "$FILE_PATH"; then
          ISSUES+=("{\"severity\": \"error\", \"check\": \"structure\", \"message\": \"Missing required section: $section\"}")
        fi
      done
      ;;
    design)
      for section in "Overview" "Architecture" "Implementation"; do
        if ! grep -q "^## $section$" "$FILE_PATH"; then
          ISSUES+=("{\"severity\": \"warning\", \"check\": \"structure\", \"message\": \"Missing recommended section: $section\"}")
        fi
      done
      ;;
    runbook)
      for section in "Purpose" "Steps"; do
        if ! grep -q "^## $section$" "$FILE_PATH"; then
          ISSUES+=("{\"severity\": \"error\", \"check\": \"structure\", \"message\": \"Missing required section: $section\"}")
        fi
      done
      ;;
  esac
fi

# Check 3: Basic markdown linting (if markdownlint is available)
if command -v markdownlint &> /dev/null; then
  echo "Running markdown linter..." >&2
  LINT_OUTPUT=$(markdownlint "$FILE_PATH" 2>&1 || true)
  if [[ -n "$LINT_OUTPUT" ]]; then
    # Parse markdownlint output and add to issues
    while IFS= read -r line; do
      if [[ -n "$line" ]]; then
        ISSUES+=("{\"severity\": \"info\", \"check\": \"markdown-lint\", \"message\": \"$line\"}")
      fi
    done <<< "$LINT_OUTPUT"
  fi
fi

# Check 4: Check for broken internal links (simple check for .md files)
echo "Checking for broken links..." >&2
DOC_DIR=$(dirname "$FILE_PATH")
while IFS= read -r link; do
  if [[ "$link" == *.md* ]] && [[ ! "$link" =~ ^http ]]; then
    # Extract path from markdown link
    LINK_PATH=$(echo "$link" | sed 's/.*(\([^)]*\)).*/\1/')
    # Resolve relative path
    if [[ "$LINK_PATH" == /* ]]; then
      FULL_PATH="$LINK_PATH"
    else
      FULL_PATH="$DOC_DIR/$LINK_PATH"
    fi
    # Check if file exists
    if [[ ! -f "$FULL_PATH" ]]; then
      ISSUES+=("{\"severity\": \"warning\", \"check\": \"links\", \"message\": \"Broken link: $LINK_PATH\"}")
    fi
  fi
done < <(grep -o '\[.*\](.*\.md.*)' "$FILE_PATH" || true)

# Determine overall validation status
VALIDATION_STATUS="passed"
ERROR_COUNT=0
WARNING_COUNT=0

for issue in "${ISSUES[@]}"; do
  severity=$(echo "$issue" | jq -r '.severity')
  if [[ "$severity" == "error" ]]; then
    ((ERROR_COUNT++))
  elif [[ "$severity" == "warning" ]]; then
    ((WARNING_COUNT++))
  fi
done

if [[ $ERROR_COUNT -gt 0 ]]; then
  VALIDATION_STATUS="failed"
elif [[ $WARNING_COUNT -gt 0 ]]; then
  VALIDATION_STATUS="warnings"
fi

# Build issues JSON array
ISSUES_JSON="["
for i in "${!ISSUES[@]}"; do
  if [[ $i -gt 0 ]]; then
    ISSUES_JSON+=","
  fi
  ISSUES_JSON+="${ISSUES[$i]}"
done
ISSUES_JSON+="]"

# Return validation result
cat <<EOF
{
  "success": true,
  "validation": "$VALIDATION_STATUS",
  "file": "$FILE_PATH",
  "issues": $ISSUES_JSON,
  "error_count": $ERROR_COUNT,
  "warning_count": $WARNING_COUNT,
  "info_count": $((${#ISSUES[@]} - ERROR_COUNT - WARNING_COUNT))
}
EOF
