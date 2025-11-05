#!/usr/bin/env bash
#
# validate-structure.sh - Validate document has required sections
#
# Usage: validate-structure.sh --file <path> --doc-type <type>
#

set -euo pipefail

# Default values
FILE_PATH=""
DOC_TYPE=""

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

if [[ -z "$DOC_TYPE" ]]; then
  echo "Error: Missing required argument: --doc-type" >&2
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

# Get script directory to find parse-document.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse document structure using parse-document.sh
if [[ ! -f "$SCRIPT_DIR/../../doc-updater/scripts/parse-document.sh" ]]; then
  cat <<EOF
{
  "success": false,
  "error": "parse-document.sh not found",
  "error_code": "MISSING_DEPENDENCY"
}
EOF
  exit 1
fi

PARSED=$("$SCRIPT_DIR/../../doc-updater/scripts/parse-document.sh" --file "$FILE_PATH")

if ! echo "$PARSED" | jq -e '.success' > /dev/null 2>&1; then
  cat <<EOF
{
  "success": false,
  "error": "Failed to parse document structure",
  "error_code": "PARSE_FAILED"
}
EOF
  exit 1
fi

# Extract section headings (case-insensitive matching)
SECTIONS_JSON=$(echo "$PARSED" | jq -r '.sections')
SECTION_HEADINGS=$(echo "$SECTIONS_JSON" | jq -r '.[].heading')

# Initialize issues array
ISSUES="[]"

add_issue() {
  local severity=$1
  local section=$2
  local message=$3

  ISSUES=$(echo "$ISSUES" | jq \
    --arg severity "$severity" \
    --arg section "$section" \
    --arg msg "$message" \
    '. += [{"severity": $severity, "section": $section, "message": $msg}]')
}

check_section_exists() {
  local required_section=$1
  local severity=${2:-error}  # Default to error if not specified

  # Case-insensitive check
  if ! echo "$SECTION_HEADINGS" | grep -qi "^${required_section}$"; then
    add_issue "$severity" "$required_section" "Missing required section: $required_section"
    return 1
  fi
  return 0
}

# Define required sections by document type
case "$DOC_TYPE" in
  adr)
    # ADR required sections
    check_section_exists "Status"
    check_section_exists "Context"
    check_section_exists "Decision"
    check_section_exists "Consequences"

    # Optional but recommended
    check_section_exists "Alternatives" "info"
    ;;

  design)
    # Design document required sections
    check_section_exists "Overview"
    check_section_exists "Architecture"

    # Recommended sections
    check_section_exists "Requirements" "info"
    check_section_exists "Implementation" "info"
    ;;

  runbook)
    # Runbook required sections
    check_section_exists "Purpose"
    check_section_exists "Steps"

    # Recommended sections
    check_section_exists "Prerequisites" "info"
    check_section_exists "Troubleshooting" "info"
    check_section_exists "Rollback" "warning"
    ;;

  api-spec)
    # API spec required sections
    check_section_exists "Overview"
    check_section_exists "Authentication"
    check_section_exists "Endpoints"

    # Recommended sections
    check_section_exists "Models" "info"
    check_section_exists "Errors" "info"
    ;;

  test-report)
    # Test report required sections
    check_section_exists "Summary"
    check_section_exists "Results"

    # Recommended sections
    check_section_exists "Test Cases" "info"
    check_section_exists "Coverage" "info"
    check_section_exists "Issues" "warning"
    ;;

  deployment)
    # Deployment document required sections
    check_section_exists "Overview"
    check_section_exists "Deployment Steps"

    # Recommended sections
    check_section_exists "Infrastructure" "info"
    check_section_exists "Configuration" "info"
    check_section_exists "Verification" "warning"
    check_section_exists "Rollback" "warning"
    ;;

  changelog)
    # Changelog structure (flexible, but should have version sections)
    # Check for at least one version heading (contains digits)
    VERSION_FOUND=false
    while IFS= read -r heading; do
      if [[ "$heading" =~ [0-9] ]]; then
        VERSION_FOUND=true
        break
      fi
    done <<< "$SECTION_HEADINGS"

    if [[ "$VERSION_FOUND" == "false" ]]; then
      add_issue "warning" "Versions" "No version sections found (expected sections like '## [1.0.0]')"
    fi
    ;;

  architecture)
    # Architecture document required sections
    check_section_exists "Overview"
    check_section_exists "Components"

    # Recommended sections
    check_section_exists "Data Flow" "info"
    check_section_exists "Technology Stack" "info"
    check_section_exists "Deployment" "info"
    ;;

  troubleshooting)
    # Troubleshooting guide required sections
    check_section_exists "Problem"
    check_section_exists "Diagnosis"
    check_section_exists "Solution"

    # Recommended sections
    check_section_exists "Prevention" "info"
    ;;

  postmortem)
    # Postmortem required sections
    check_section_exists "Incident Summary"
    check_section_exists "Timeline"
    check_section_exists "Root Cause"
    check_section_exists "Action Items"

    # Recommended sections
    check_section_exists "Impact" "info"
    check_section_exists "Lessons Learned" "info"
    ;;

  *)
    # Unknown document type - just check for basic structure
    if [[ $(echo "$SECTIONS_JSON" | jq 'length') -eq 0 ]]; then
      add_issue "warning" "Structure" "Document has no sections"
    fi
    ;;
esac

# Check for common structural issues

# 1. Check if document is too short (less than 100 characters)
FILE_SIZE=$(stat -f%z "$FILE_PATH" 2>/dev/null || stat -c%s "$FILE_PATH" 2>/dev/null)
if [[ $FILE_SIZE -lt 100 ]]; then
  add_issue "warning" "Content" "Document appears too short (less than 100 bytes)"
fi

# 2. Check if document has at least one section
SECTION_COUNT=$(echo "$SECTIONS_JSON" | jq 'length')
if [[ $SECTION_COUNT -eq 0 ]]; then
  add_issue "error" "Structure" "Document has no sections (no markdown headings found)"
fi

# 3. Check for deeply nested sections (more than 4 levels)
MAX_LEVEL=$(echo "$SECTIONS_JSON" | jq '[.[].level] | max // 0')
if [[ $MAX_LEVEL -gt 4 ]]; then
  add_issue "info" "Structure" "Document has deeply nested sections (level $MAX_LEVEL). Consider flattening."
fi

# 4. Check for code blocks without language tags
CODE_BLOCKS=$(echo "$PARSED" | jq -r '.code_blocks')
CODE_BLOCKS_WITHOUT_LANG=$(echo "$CODE_BLOCKS" | jq '[.[] | select(.language == "")] | length')
if [[ $CODE_BLOCKS_WITHOUT_LANG -gt 0 ]]; then
  add_issue "info" "Code Blocks" "$CODE_BLOCKS_WITHOUT_LANG code block(s) missing language identifier"
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
  "check": "structure",
  "doc_type": "$DOC_TYPE",
  "section_count": $SECTION_COUNT,
  "max_heading_level": $MAX_LEVEL,
  "total_issues": $ISSUE_COUNT,
  "errors": $ERROR_COUNT,
  "warnings": $WARNING_COUNT,
  "info": $INFO_COUNT,
  "issues": $ISSUES,
  "sections_found": $(echo "$SECTIONS_JSON" | jq '[.[].heading]')
}
EOF
