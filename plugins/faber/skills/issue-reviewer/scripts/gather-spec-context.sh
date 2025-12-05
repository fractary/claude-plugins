#!/bin/bash
#
# gather-spec-context.sh
# Finds and reads specification files for a work item
#
# Usage: gather-spec-context.sh <work_id>
#
# Output: JSON with spec path and content (if found)
#

set -euo pipefail

WORK_ID="${1:-}"

if [[ -z "$WORK_ID" ]]; then
  echo '{"error": "work_id is required"}' >&2
  exit 1
fi

# Pad work ID to 5 digits for standard naming
WORK_ID_PADDED=$(printf "%05d" "$WORK_ID" 2>/dev/null || echo "$WORK_ID")

# Search locations for specs
SEARCH_PATTERNS=(
  "specs/WORK-${WORK_ID_PADDED}-*.md"
  "specs/WORK-${WORK_ID}-*.md"
  "docs/specs/*${WORK_ID}*.md"
  ".fractary/specs/*${WORK_ID}*.md"
)

# Find spec file safely using find command only (no glob expansion)
find_spec() {
  for pattern in "${SEARCH_PATTERNS[@]}"; do
    # Use find to handle glob patterns safely - avoids command injection
    local matches
    matches=$(find . -path "./$pattern" -type f 2>/dev/null | head -1)
    if [[ -n "$matches" ]]; then
      echo "$matches"
      return 0
    fi
  done

  return 1
}

# Extract requirements from spec content
extract_requirements() {
  local content="$1"

  # Extract FR-* requirements
  echo "$content" | grep -E "^#### FR-|^- FR-|^\*\*FR-" | head -20 || true
}

# Extract acceptance criteria from spec content
extract_acceptance_criteria() {
  local content="$1"

  # Extract AC-* items
  echo "$content" | grep -E "^### AC-|^- \[ \]|^- \[x\]" | head -30 || true
}

# Main execution
SPEC_PATH=$(find_spec) || SPEC_PATH=""

if [[ -z "$SPEC_PATH" ]]; then
  # Use jq --arg to safely escape WORK_ID and avoid JSON injection
  jq -n --arg work_id "$WORK_ID" '{
    "found": false,
    "spec_path": null,
    "spec_content": null,
    "requirements": [],
    "acceptance_criteria": [],
    "message": ("No specification found for work ID " + $work_id)
  }'
  exit 0
fi

# Read spec content with error handling
SPEC_CONTENT=$(cat "$SPEC_PATH" 2>/dev/null) || {
  jq -n --arg work_id "$WORK_ID" --arg path "$SPEC_PATH" '{
    "found": false,
    "spec_path": $path,
    "spec_content": null,
    "requirements": [],
    "acceptance_criteria": [],
    "error": ("Failed to read specification file: " + $path),
    "message": ("Specification found but unreadable for work ID " + $work_id)
  }'
  exit 1
}

# Extract structured data
REQUIREMENTS=$(extract_requirements "$SPEC_CONTENT")
ACCEPTANCE_CRITERIA=$(extract_acceptance_criteria "$SPEC_CONTENT")

# Build output JSON
jq -n \
  --arg path "$SPEC_PATH" \
  --arg content "$SPEC_CONTENT" \
  --arg requirements "$REQUIREMENTS" \
  --arg criteria "$ACCEPTANCE_CRITERIA" \
  '{
    "found": true,
    "spec_path": $path,
    "spec_content": $content,
    "spec_size": ($content | length),
    "requirements_raw": $requirements,
    "acceptance_criteria_raw": $criteria,
    "fetched_at": (now | strftime("%Y-%m-%dT%H:%M:%SZ"))
  }'
