#!/usr/bin/env bash
#
# check-links.sh - Find broken internal and external links
#
# Usage: check-links.sh --file <path> [--check-external] [--timeout <seconds>]
#

set -euo pipefail

# Default values
FILE_PATH=""
CHECK_EXTERNAL=false
TIMEOUT=5

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --file)
      FILE_PATH="$2"
      shift 2
      ;;
    --check-external)
      CHECK_EXTERNAL=true
      shift
      ;;
    --timeout)
      TIMEOUT="$2"
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

# Get file directory for resolving relative paths
FILE_DIR="$(cd "$(dirname "$FILE_PATH")" && pwd)"

# Initialize results
ISSUES="[]"
TOTAL_LINKS=0
BROKEN_LINKS=0
INTERNAL_LINKS=0
EXTERNAL_LINKS=0
REFERENCE_LINKS="{}"

add_issue() {
  local severity=$1
  local line=$2
  local link=$3
  local message=$4

  ISSUES=$(echo "$ISSUES" | jq \
    --arg severity "$severity" \
    --arg line "$line" \
    --arg link "$link" \
    --arg msg "$message" \
    '. += [{"severity": $severity, "line": ($line|tonumber), "link": $link, "message": $msg}]')

  ((BROKEN_LINKS++))
}

check_internal_link() {
  local link=$1
  local line_num=$2

  # Remove anchor (#section)
  local file_path="${link%%#*}"

  # Skip empty paths (just anchors like #section)
  if [[ -z "$file_path" ]]; then
    return 0
  fi

  # Resolve relative path
  local full_path
  if [[ "$file_path" == /* ]]; then
    # Absolute path
    full_path="$file_path"
  else
    # Relative path
    full_path="$FILE_DIR/$file_path"
  fi

  # Normalize path (remove ./ and ../)
  full_path=$(realpath -m "$full_path" 2>/dev/null || echo "$full_path")

  # Check if file exists
  if [[ ! -f "$full_path" && ! -d "$full_path" ]]; then
    add_issue "error" "$line_num" "$link" "Broken internal link: file not found"
    return 1
  fi

  return 0
}

check_external_link() {
  local link=$1
  local line_num=$2

  # Skip if not checking external links
  if [[ "$CHECK_EXTERNAL" == "false" ]]; then
    return 0
  fi

  # Use curl to check if URL is accessible
  if command -v curl &> /dev/null; then
    if ! curl -s -f -L --max-time "$TIMEOUT" --head "$link" > /dev/null 2>&1; then
      add_issue "warning" "$line_num" "$link" "External link may be broken (HTTP check failed)"
      return 1
    fi
  else
    # Can't check without curl
    return 0
  fi

  return 0
}

# Parse document for links
line_num=0
in_code_block=false

while IFS= read -r line; do
  ((line_num++))

  # Skip code blocks (don't check links in code)
  if [[ "$line" =~ ^``` ]]; then
    if [[ "$in_code_block" == "false" ]]; then
      in_code_block=true
    else
      in_code_block=false
    fi
    continue
  fi

  if [[ "$in_code_block" == "true" ]]; then
    continue
  fi

  # Extract inline links: [text](url)
  while [[ "$line" =~ \[([^\]]+)\]\(([^\)]+)\) ]]; do
    link_text="${BASH_REMATCH[1]}"
    link_url="${BASH_REMATCH[2]}"
    ((TOTAL_LINKS++))

    # Check if internal or external
    if [[ "$link_url" =~ ^https?:// ]]; then
      # External link
      ((EXTERNAL_LINKS++))
      check_external_link "$link_url" "$line_num"
    elif [[ "$link_url" =~ ^mailto: ]]; then
      # Email link - skip
      :
    else
      # Internal link
      ((INTERNAL_LINKS++))
      check_internal_link "$link_url" "$line_num"
    fi

    # Remove this link from line to find next one
    line="${line#*\](*\)}"
  done

  # Extract reference-style links: [text][ref]
  while [[ "$line" =~ \[([^\]]+)\]\[([^\]]+)\] ]]; do
    link_text="${BASH_REMATCH[1]}"
    link_ref="${BASH_REMATCH[2]}"

    # Store reference for later resolution
    REFERENCE_LINKS=$(echo "$REFERENCE_LINKS" | jq \
      --arg ref "$link_ref" \
      --arg line "$line_num" \
      --arg text "$link_text" \
      '.[$ref] += [{"line": ($line|tonumber), "text": $text}]')

    # Remove this reference from line
    line="${line#*\]\[*\]}"
  done

  # Extract reference definitions: [ref]: url
  if [[ "$line" =~ ^\[([^\]]+)\]:[[:space:]]*(.+)$ ]]; then
    ref_id="${BASH_REMATCH[1]}"
    ref_url="${BASH_REMATCH[2]}"

    # Mark reference as defined
    REFERENCE_LINKS=$(echo "$REFERENCE_LINKS" | jq \
      --arg ref "$ref_id" \
      --arg url "$ref_url" \
      '.[$ref].url = $url')
  fi

done < "$FILE_PATH"

# Check reference-style links
# For each reference used, verify it's defined and check the URL
if [[ $(echo "$REFERENCE_LINKS" | jq 'keys | length') -gt 0 ]]; then
  for ref in $(echo "$REFERENCE_LINKS" | jq -r 'keys[]'); do
    ref_data=$(echo "$REFERENCE_LINKS" | jq -r --arg ref "$ref" '.[$ref]')
    ref_url=$(echo "$ref_data" | jq -r '.url // empty')

    if [[ -z "$ref_url" ]]; then
      # Reference used but not defined
      uses=$(echo "$ref_data" | jq -r '.[].line')
      for line in $uses; do
        add_issue "error" "$line" "[$ref]" "Undefined reference link: [$ref]"
        ((TOTAL_LINKS++))
      done
    else
      # Reference defined, check URL
      ((TOTAL_LINKS++))

      if [[ "$ref_url" =~ ^https?:// ]]; then
        ((EXTERNAL_LINKS++))
        # Check external link from first use line
        first_line=$(echo "$ref_data" | jq -r '.[0].line // 0')
        check_external_link "$ref_url" "$first_line"
      elif [[ "$ref_url" =~ ^mailto: ]]; then
        # Email link - skip
        :
      else
        ((INTERNAL_LINKS++))
        # Check internal link from first use line
        first_line=$(echo "$ref_data" | jq -r '.[0].line // 0')
        check_internal_link "$ref_url" "$first_line"
      fi
    fi
  done
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
  "check": "links",
  "total_links": $TOTAL_LINKS,
  "internal_links": $INTERNAL_LINKS,
  "external_links": $EXTERNAL_LINKS,
  "broken_links": $BROKEN_LINKS,
  "external_check_enabled": $CHECK_EXTERNAL,
  "total_issues": $ISSUE_COUNT,
  "errors": $ERROR_COUNT,
  "warnings": $WARNING_COUNT,
  "info": $INFO_COUNT,
  "issues": $ISSUES
}
EOF
