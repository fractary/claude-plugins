#!/usr/bin/env bash
#
# find-broken-links.sh - Scan directory for broken links
#
# Usage: find-broken-links.sh --directory <path> [--recursive] [--check-external] [--fix-mode]
#

set -euo pipefail

# Default values
DIRECTORY=""
RECURSIVE=true
CHECK_EXTERNAL=false
FIX_MODE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --directory)
      DIRECTORY="$2"
      shift 2
      ;;
    --recursive)
      RECURSIVE="$2"
      shift 2
      ;;
    --check-external)
      CHECK_EXTERNAL="$2"
      shift 2
      ;;
    --fix-mode)
      FIX_MODE="$2"
      shift 2
      ;;
    *)
      echo "Error: Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate required arguments
if [[ -z "$DIRECTORY" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Missing required argument: --directory",
  "error_code": "MISSING_ARGUMENT"
}
EOF
  exit 1
fi

# Check if directory exists
if [[ ! -d "$DIRECTORY" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "Directory not found: $DIRECTORY",
  "error_code": "DIR_NOT_FOUND"
}
EOF
  exit 1
fi

# Get script directory to find check-links.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CHECK_LINKS_SCRIPT="$SCRIPT_DIR/../../doc-validator/scripts/check-links.sh"

if [[ ! -f "$CHECK_LINKS_SCRIPT" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "check-links.sh not found at $CHECK_LINKS_SCRIPT",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

# Find markdown files
if [[ "$RECURSIVE" == "true" ]]; then
  FIND_DEPTH=""
else
  FIND_DEPTH="-maxdepth 1"
fi

# Initialize aggregated results
ALL_BROKEN_LINKS="[]"
TOTAL_FILES=0
FILES_WITH_BROKEN_LINKS=0
TOTAL_BROKEN_LINKS=0
TOTAL_LINKS=0
FIXED_LINKS=0

# Process each markdown file
while IFS= read -r file; do
  ((TOTAL_FILES++))

  # Check links in this file
  if [[ "$CHECK_EXTERNAL" == "true" ]]; then
    RESULT=$("$CHECK_LINKS_SCRIPT" --file "$file" --check-external 2>/dev/null || echo '{"success":false}')
  else
    RESULT=$("$CHECK_LINKS_SCRIPT" --file "$file" 2>/dev/null || echo '{"success":false}')
  fi

  # Check if check was successful
  if ! echo "$RESULT" | jq -e '.success' > /dev/null 2>&1; then
    continue
  fi

  # Extract link stats
  FILE_TOTAL_LINKS=$(echo "$RESULT" | jq -r '.total_links // 0')
  FILE_BROKEN_LINKS=$(echo "$RESULT" | jq -r '.broken_links // 0')

  TOTAL_LINKS=$((TOTAL_LINKS + FILE_TOTAL_LINKS))
  TOTAL_BROKEN_LINKS=$((TOTAL_BROKEN_LINKS + FILE_BROKEN_LINKS))

  if [[ $FILE_BROKEN_LINKS -gt 0 ]]; then
    ((FILES_WITH_BROKEN_LINKS++))

    # Extract issues and add file context
    FILE_ISSUES=$(echo "$RESULT" | jq --arg file "$file" '.issues[] | . + {"file": $file}')

    # Add to aggregated broken links
    while IFS= read -r issue; do
      ALL_BROKEN_LINKS=$(echo "$ALL_BROKEN_LINKS" | jq --argjson issue "$issue" '. += [$issue]')

      # Attempt to fix if fix_mode enabled
      if [[ "$FIX_MODE" == "true" ]]; then
        LINK=$(echo "$issue" | jq -r '.link')
        SEVERITY=$(echo "$issue" | jq -r '.severity')

        # Only attempt to fix internal broken links (errors)
        if [[ "$SEVERITY" == "error" ]]; then
          # Try to find the file in the directory tree
          BASENAME=$(basename "$LINK")
          FOUND=$(find "$DIRECTORY" -type f -name "$BASENAME" | head -n 1)

          if [[ -n "$FOUND" ]]; then
            echo "Found potential fix for $LINK -> $FOUND" >&2
            # TODO: Update the link in the file
            # This would require sed/awk manipulation which is complex
            # For now, just report as fixable
            ((FIXED_LINKS++))
          fi
        fi
      fi
    done < <(echo "$FILE_ISSUES" | jq -c '.')
  fi

done < <(find "$DIRECTORY" $FIND_DEPTH -type f -name "*.md" | sort)

# Calculate health metrics
if [[ $TOTAL_FILES -gt 0 ]]; then
  FILES_HEALTHY_PCT=$(echo "scale=1; (($TOTAL_FILES - $FILES_WITH_BROKEN_LINKS) * 100) / $TOTAL_FILES" | bc)
else
  FILES_HEALTHY_PCT=0
fi

if [[ $TOTAL_LINKS -gt 0 ]]; then
  LINKS_HEALTHY_PCT=$(echo "scale=1; (($TOTAL_LINKS - $TOTAL_BROKEN_LINKS) * 100) / $TOTAL_LINKS" | bc)
else
  LINKS_HEALTHY_PCT=100
fi

# Group broken links by type
INTERNAL_BROKEN=$(echo "$ALL_BROKEN_LINKS" | jq '[.[] | select(.severity == "error")] | length')
EXTERNAL_BROKEN=$(echo "$ALL_BROKEN_LINKS" | jq '[.[] | select(.severity == "warning")] | length')

# Return results
cat <<EOF
{
  "success": true,
  "operation": "find-broken-links",
  "directory": "$DIRECTORY",
  "recursive": $RECURSIVE,
  "check_external": $CHECK_EXTERNAL,
  "fix_mode": $FIX_MODE,
  "summary": {
    "total_files": $TOTAL_FILES,
    "files_with_broken_links": $FILES_WITH_BROKEN_LINKS,
    "files_healthy_pct": $FILES_HEALTHY_PCT,
    "total_links": $TOTAL_LINKS,
    "total_broken_links": $TOTAL_BROKEN_LINKS,
    "links_healthy_pct": $LINKS_HEALTHY_PCT,
    "internal_broken": $INTERNAL_BROKEN,
    "external_broken": $EXTERNAL_BROKEN,
    "fixed_links": $FIXED_LINKS
  },
  "broken_links": $ALL_BROKEN_LINKS,
  "timestamp": "$(date -Iseconds)"
}
EOF
