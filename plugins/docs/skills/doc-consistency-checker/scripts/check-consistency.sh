#!/usr/bin/env bash
# check-consistency.sh - Analyze git diff and detect documentation-relevant changes
#
# Usage:
#   ./check-consistency.sh --base <ref> --head <ref> [--targets <files>] [--output-format json|text]
#
# Inputs:
#   --base          Base git reference (default: main)
#   --head          Head git reference (default: HEAD)
#   --targets       Comma-separated target docs (default: CLAUDE.md,README.md,docs/README.md,CONTRIBUTING.md)
#   --output-format Output format: json or text (default: json)
#
# Outputs:
#   JSON with categorized changes and affected documentation sections

set -euo pipefail

# Defaults
BASE_REF="main"
HEAD_REF="HEAD"
TARGETS="CLAUDE.md,README.md,docs/README.md,CONTRIBUTING.md"
OUTPUT_FORMAT="json"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --base)
      BASE_REF="$2"
      shift 2
      ;;
    --head)
      HEAD_REF="$2"
      shift 2
      ;;
    --targets)
      TARGETS="$2"
      shift 2
      ;;
    --output-format)
      OUTPUT_FORMAT="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
  echo '{"success": false, "error": "Not a git repository", "error_code": "NOT_GIT_REPO"}'
  exit 1
fi

# Get the diff
DIFF_OUTPUT=$(git diff --name-status "$BASE_REF"..."$HEAD_REF" 2>/dev/null || echo "")

if [[ -z "$DIFF_OUTPUT" ]]; then
  echo '{"success": true, "status": "current", "message": "No changes detected between refs", "changes": {}}'
  exit 0
fi

# Initialize counters
declare -A API_CHANGES=()
declare -A FEATURE_CHANGES=()
declare -A ARCHITECTURE_CHANGES=()
declare -A CONFIG_CHANGES=()
declare -A DOC_CHANGES=()

# Categorize changes
while IFS=$'\t' read -r status file; do
  # Skip empty lines
  [[ -z "$file" ]] && continue

  # Determine change type based on file patterns
  case "$file" in
    # API changes
    */routes/*|*/api/*|*/endpoints/*|*Controller.ts|*Controller.js|*.openapi.*)
      API_CHANGES["$file"]="$status"
      ;;

    # Feature changes (commands, skills, agents)
    */commands/*.md|*/skills/*/SKILL.md|*/agents/*.md|*/commands/*.ts|*/skills/*.ts)
      FEATURE_CHANGES["$file"]="$status"
      ;;

    # Architecture changes
    */agents/*|*/plugins/*/.claude-plugin/*|package.json|tsconfig.json|*/workflows/*.json)
      ARCHITECTURE_CHANGES["$file"]="$status"
      ;;

    # Configuration changes
    *.config.*|*.toml|.env*|*/config/*.json|*/config/*.yaml|*/config/*.yml)
      CONFIG_CHANGES["$file"]="$status"
      ;;

    # Documentation changes in subdirectories
    docs/*|*.md)
      DOC_CHANGES["$file"]="$status"
      ;;
  esac
done <<< "$DIFF_OUTPUT"

# Count total changes
TOTAL_FILES=$(echo "$DIFF_OUTPUT" | wc -l)
LINES_ADDED=$(git diff --stat "$BASE_REF"..."$HEAD_REF" 2>/dev/null | tail -1 | grep -oP '\d+(?= insertion)' || echo "0")
LINES_REMOVED=$(git diff --stat "$BASE_REF"..."$HEAD_REF" 2>/dev/null | tail -1 | grep -oP '\d+(?= deletion)' || echo "0")

# Check which target docs exist
IFS=',' read -ra TARGET_ARRAY <<< "$TARGETS"
EXISTING_TARGETS=()
MISSING_TARGETS=()

for target in "${TARGET_ARRAY[@]}"; do
  if [[ -f "$target" ]]; then
    EXISTING_TARGETS+=("$target")
  else
    MISSING_TARGETS+=("$target")
  fi
done

# Determine if docs are stale
STALE_DOCS=()
CURRENT_DOCS=()

# Check if changes warrant doc updates
HAS_SIGNIFICANT_CHANGES=false

if [[ ${#API_CHANGES[@]} -gt 0 ]] || [[ ${#FEATURE_CHANGES[@]} -gt 0 ]] || [[ ${#ARCHITECTURE_CHANGES[@]} -gt 0 ]]; then
  HAS_SIGNIFICANT_CHANGES=true
fi

# For each existing target, determine if it's stale
for target in "${EXISTING_TARGETS[@]}"; do
  IS_STALE=false
  AFFECTED_SECTIONS=()

  case "$target" in
    *CLAUDE.md*)
      # CLAUDE.md needs updates for architecture and feature changes
      if [[ ${#ARCHITECTURE_CHANGES[@]} -gt 0 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("Directory Structure" "Architecture")
      fi
      if [[ ${#FEATURE_CHANGES[@]} -gt 0 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("Common Development Tasks" "Key Files to Reference")
      fi
      if [[ ${#CONFIG_CHANGES[@]} -gt 0 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("Configuration Files")
      fi
      ;;

    *README.md)
      # README needs updates for API and feature changes
      if [[ ${#API_CHANGES[@]} -gt 0 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("API" "Usage")
      fi
      if [[ ${#FEATURE_CHANGES[@]} -gt 0 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("Features" "Getting Started")
      fi
      ;;

    *CONTRIBUTING.md)
      # CONTRIBUTING needs updates for significant architecture changes
      if [[ ${#ARCHITECTURE_CHANGES[@]} -gt 3 ]]; then
        IS_STALE=true
        AFFECTED_SECTIONS+=("Development Setup" "Project Structure")
      fi
      ;;
  esac

  if [[ "$IS_STALE" == "true" ]]; then
    STALE_DOCS+=("$target")
  else
    CURRENT_DOCS+=("$target")
  fi
done

# Build JSON output
if [[ "$OUTPUT_FORMAT" == "json" ]]; then
  # Build API changes array
  API_JSON="[]"
  for file in "${!API_CHANGES[@]}"; do
    status="${API_CHANGES[$file]}"
    API_JSON=$(echo "$API_JSON" | jq --arg f "$file" --arg s "$status" '. + [{"file": $f, "status": $s}]')
  done

  # Build feature changes array
  FEATURE_JSON="[]"
  for file in "${!FEATURE_CHANGES[@]}"; do
    status="${FEATURE_CHANGES[$file]}"
    FEATURE_JSON=$(echo "$FEATURE_JSON" | jq --arg f "$file" --arg s "$status" '. + [{"file": $f, "status": $s}]')
  done

  # Build architecture changes array
  ARCH_JSON="[]"
  for file in "${!ARCHITECTURE_CHANGES[@]}"; do
    status="${ARCHITECTURE_CHANGES[$file]}"
    ARCH_JSON=$(echo "$ARCH_JSON" | jq --arg f "$file" --arg s "$status" '. + [{"file": $f, "status": $s}]')
  done

  # Build config changes array
  CONFIG_JSON="[]"
  for file in "${!CONFIG_CHANGES[@]}"; do
    status="${CONFIG_CHANGES[$file]}"
    CONFIG_JSON=$(echo "$CONFIG_JSON" | jq --arg f "$file" --arg s "$status" '. + [{"file": $f, "status": $s}]')
  done

  # Determine overall status
  if [[ ${#STALE_DOCS[@]} -gt 0 ]]; then
    STATUS="stale"
  else
    STATUS="current"
  fi

  # Output JSON
  cat <<EOF
{
  "success": true,
  "operation": "check",
  "status": "$STATUS",
  "base_ref": "$BASE_REF",
  "head_ref": "$HEAD_REF",
  "targets_checked": ${#EXISTING_TARGETS[@]},
  "targets_stale": ${#STALE_DOCS[@]},
  "stale_documents": $(printf '%s\n' "${STALE_DOCS[@]:-}" | jq -R . | jq -s .),
  "current_documents": $(printf '%s\n' "${CURRENT_DOCS[@]:-}" | jq -R . | jq -s .),
  "missing_targets": $(printf '%s\n' "${MISSING_TARGETS[@]:-}" | jq -R . | jq -s .),
  "changes": {
    "api": $API_JSON,
    "features": $FEATURE_JSON,
    "architecture": $ARCH_JSON,
    "configuration": $CONFIG_JSON
  },
  "summary": {
    "files_changed": $TOTAL_FILES,
    "lines_added": ${LINES_ADDED:-0},
    "lines_removed": ${LINES_REMOVED:-0},
    "has_significant_changes": $HAS_SIGNIFICANT_CHANGES
  }
}
EOF
else
  # Text output
  echo "Documentation Consistency Check"
  echo "================================"
  echo ""
  echo "Base: $BASE_REF"
  echo "Head: $HEAD_REF"
  echo ""
  echo "Changes Detected:"
  echo "  API: ${#API_CHANGES[@]}"
  echo "  Features: ${#FEATURE_CHANGES[@]}"
  echo "  Architecture: ${#ARCHITECTURE_CHANGES[@]}"
  echo "  Configuration: ${#CONFIG_CHANGES[@]}"
  echo ""
  echo "Documents:"
  echo "  Stale: ${STALE_DOCS[*]:-none}"
  echo "  Current: ${CURRENT_DOCS[*]:-none}"
  echo "  Missing: ${MISSING_TARGETS[*]:-none}"
fi
