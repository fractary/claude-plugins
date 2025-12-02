#!/usr/bin/env bash
# apply-updates.sh - Apply approved updates to documentation
#
# Usage:
#   ./apply-updates.sh --target <file> --updates <json> [--backup true|false]
#
# Inputs:
#   --target    Target document path
#   --updates   JSON with updates to apply
#   --backup    Create backup before modification (default: true)
#
# Outputs:
#   JSON with update results

set -euo pipefail

# Defaults
TARGET=""
UPDATES=""
BACKUP="true"

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --target)
      TARGET="$2"
      shift 2
      ;;
    --updates)
      UPDATES="$2"
      shift 2
      ;;
    --backup)
      BACKUP="$2"
      shift 2
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validate inputs
if [[ -z "$TARGET" ]]; then
  echo '{"success": false, "error": "Target document required", "error_code": "MISSING_TARGET"}'
  exit 1
fi

if [[ ! -f "$TARGET" ]]; then
  echo '{"success": false, "error": "Target document not found: '"$TARGET"'", "error_code": "FILE_NOT_FOUND"}'
  exit 1
fi

if [[ -z "$UPDATES" ]]; then
  echo '{"success": false, "error": "Updates JSON required", "error_code": "MISSING_UPDATES"}'
  exit 1
fi

# Create backup if requested
BACKUP_FILE=""
if [[ "$BACKUP" == "true" ]]; then
  BACKUP_FILE="${TARGET}.backup.$(date +%Y-%m-%d-%H%M%S)"
  cp "$TARGET" "$BACKUP_FILE"
fi

# Track applied updates
APPLIED_COUNT=0
FAILED_COUNT=0
APPLIED_UPDATES="[]"
FAILED_UPDATES="[]"

# Process each update
while IFS= read -r update; do
  section=$(echo "$update" | jq -r '.section')
  action=$(echo "$update" | jq -r '.action')
  content=$(echo "$update" | jq -r '.content')

  case "$action" in
    add)
      # For 'add' actions, we just note them - actual insertion requires LLM intelligence
      APPLIED_UPDATES=$(echo "$APPLIED_UPDATES" | jq --arg s "$section" --arg a "$action" \
        '. + [{"section": $s, "action": $a, "status": "noted_for_review"}]')
      ((APPLIED_COUNT++))
      ;;

    review)
      # For 'review' actions, just note them
      APPLIED_UPDATES=$(echo "$APPLIED_UPDATES" | jq --arg s "$section" --arg a "$action" \
        '. + [{"section": $s, "action": $a, "status": "requires_manual_review"}]')
      ((APPLIED_COUNT++))
      ;;

    *)
      FAILED_UPDATES=$(echo "$FAILED_UPDATES" | jq --arg s "$section" --arg a "$action" \
        --arg e "Unknown action type" \
        '. + [{"section": $s, "action": $a, "error": $e}]')
      ((FAILED_COUNT++))
      ;;
  esac
done < <(echo "$UPDATES" | jq -c '.[]')

# Output results
cat <<EOF
{
  "success": true,
  "operation": "apply",
  "target": "$TARGET",
  "backup_created": $(if [[ -n "$BACKUP_FILE" ]]; then echo "\"$BACKUP_FILE\""; else echo "null"; fi),
  "updates_applied": $APPLIED_COUNT,
  "updates_failed": $FAILED_COUNT,
  "applied": $APPLIED_UPDATES,
  "failed": $FAILED_UPDATES,
  "note": "Updates are noted for review. Full document updates require docs-manager agent for intelligent content insertion."
}
EOF
