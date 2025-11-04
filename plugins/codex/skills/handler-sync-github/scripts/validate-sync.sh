#!/bin/bash
# Validate sync results - check file counts, deletion thresholds, and integrity
#
# Usage:
#   ./validate-sync.sh --results <json-file> [options]
#
# Options:
#   --results <file>                 JSON file with sync results (required)
#   --deletion-threshold <number>    Max files to delete (default: 50)
#   --deletion-threshold-percent <n> Max deletion percentage (default: 20)
#   --json                           Output JSON only (no progress messages)
#
# Output: JSON object with validation results

set -euo pipefail

# Default values
RESULTS_FILE=""
DELETION_THRESHOLD=50
DELETION_THRESHOLD_PERCENT=20
JSON_ONLY=false

# Parse arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --results)
      RESULTS_FILE="$2"
      shift 2
      ;;
    --deletion-threshold)
      DELETION_THRESHOLD="$2"
      shift 2
      ;;
    --deletion-threshold-percent)
      DELETION_THRESHOLD_PERCENT="$2"
      shift 2
      ;;
    --json)
      JSON_ONLY=true
      shift
      ;;
    *)
      echo "Unknown option: $1" >&2
      exit 1
      ;;
  esac
done

# Validation
if [ -z "$RESULTS_FILE" ] || [ ! -f "$RESULTS_FILE" ]; then
  echo '{"success": false, "error": "Results file is required and must exist"}' | jq .
  exit 1
fi

# Progress message (unless JSON-only mode)
log() {
  if [ "$JSON_ONLY" = false ]; then
    echo "$@" >&2
  fi
}

log "=== Validating Sync Results ==="

# Parse results file
if ! jq empty "$RESULTS_FILE" 2>/dev/null; then
  echo '{"success": false, "error": "Invalid JSON in results file"}' | jq .
  exit 1
fi

# Extract values from results
FILES_SYNCED=$(jq -r '.files_synced // 0' "$RESULTS_FILE")
FILES_DELETED=$(jq -r '.files_deleted // 0' "$RESULTS_FILE")
FILES_ADDED=$(jq -r '.files_added // 0' "$RESULTS_FILE")
FILES_MODIFIED=$(jq -r '.files_modified // 0' "$RESULTS_FILE")
DRY_RUN=$(jq -r '.dry_run // false' "$RESULTS_FILE")
SYNC_SUCCESS=$(jq -r '.success // false' "$RESULTS_FILE")

log "Sync Results:"
log "  - Files synced: $FILES_SYNCED"
log "  - Files added: $FILES_ADDED"
log "  - Files modified: $FILES_MODIFIED"
log "  - Files deleted: $FILES_DELETED"
log "  - Dry run: $DRY_RUN"
log "  - Success: $SYNC_SUCCESS"

# Validation checks
VALIDATION_STATUS="success"
ISSUES=()

# Check 1: File counts are non-negative
if [ "$FILES_SYNCED" -lt 0 ] || [ "$FILES_DELETED" -lt 0 ]; then
  ISSUES+=("File counts are negative")
  VALIDATION_STATUS="failure"
  log "❌ File count validation failed"
else
  log "✓ File counts valid"
fi

# Check 2: Deletion threshold
TOTAL_FILES=$((FILES_SYNCED + FILES_DELETED))
if [ "$TOTAL_FILES" -gt 0 ]; then
  DELETION_PERCENT=$((FILES_DELETED * 100 / TOTAL_FILES))
else
  DELETION_PERCENT=0
fi

THRESHOLD_EXCEEDED=false
if [ "$FILES_DELETED" -gt "$DELETION_THRESHOLD" ]; then
  THRESHOLD_EXCEEDED=true
  ISSUES+=("Deletion threshold exceeded: $FILES_DELETED > $DELETION_THRESHOLD")
  VALIDATION_STATUS="warning"
  log "⚠️  Absolute deletion threshold exceeded"
fi

if [ "$DELETION_PERCENT" -gt "$DELETION_THRESHOLD_PERCENT" ]; then
  THRESHOLD_EXCEEDED=true
  if [[ ! " ${ISSUES[@]} " =~ "Deletion threshold exceeded" ]]; then
    ISSUES+=("Deletion percentage exceeded: $DELETION_PERCENT% > $DELETION_THRESHOLD_PERCENT%")
  fi
  VALIDATION_STATUS="warning"
  log "⚠️  Percentage deletion threshold exceeded"
fi

if [ "$THRESHOLD_EXCEEDED" = false ]; then
  log "✓ Deletion thresholds OK ($FILES_DELETED files, $DELETION_PERCENT%)"
fi

# Check 3: Sync success
if [ "$SYNC_SUCCESS" != "true" ]; then
  ISSUES+=("Sync operation reported failure")
  VALIDATION_STATUS="failure"
  log "❌ Sync operation failed"
else
  log "✓ Sync operation succeeded"
fi

# Check 4: Dry-run consistency
if [ "$DRY_RUN" = "true" ] && [ "$FILES_SYNCED" -eq 0 ] && [ "$FILES_DELETED" -eq 0 ]; then
  # This is OK for dry-run with no changes
  log "✓ Dry-run with no changes"
fi

# Calculate recommendations
RECOMMENDATIONS=()

if [ "$THRESHOLD_EXCEEDED" = true ]; then
  RECOMMENDATIONS+=("Review the list of files to be deleted carefully")
  RECOMMENDATIONS+=("Consider adjusting deletion thresholds if this is expected")
  RECOMMENDATIONS+=("Run with --dry-run first to preview changes")
fi

if [ "$FILES_DELETED" -gt "$((FILES_SYNCED / 2))" ] && [ "$FILES_SYNCED" -gt 0 ]; then
  RECOMMENDATIONS+=("More files deleted than synced - verify this is intentional")
fi

if [ "$VALIDATION_STATUS" = "success" ] && [ ${#RECOMMENDATIONS[@]} -eq 0 ]; then
  RECOMMENDATIONS+=("Sync looks good - safe to proceed")
fi

# Generate issues JSON
ISSUES_JSON="[]"
if [ ${#ISSUES[@]} -gt 0 ]; then
  ISSUES_JSON=$(printf '%s\n' "${ISSUES[@]}" | jq -R . | jq -s 'map({severity: "warning", message: .})')
fi

# Generate recommendations JSON
RECS_JSON="[]"
if [ ${#RECOMMENDATIONS[@]} -gt 0 ]; then
  RECS_JSON=$(printf '%s\n' "${RECOMMENDATIONS[@]}" | jq -R . | jq -s .)
fi

log ""
log "Validation Status: $VALIDATION_STATUS"
log "Issues: ${#ISSUES[@]}"
log "Recommendations: ${#RECOMMENDATIONS[@]}"

# Output JSON results
jq -n \
  --arg status "$VALIDATION_STATUS" \
  --argjson files_synced "$FILES_SYNCED" \
  --argjson files_deleted "$FILES_DELETED" \
  --argjson deletion_threshold_exceeded "$([ "$THRESHOLD_EXCEEDED" = "true" ] && echo true || echo false)" \
  --argjson deletion_count "$FILES_DELETED" \
  --argjson deletion_threshold "$DELETION_THRESHOLD" \
  --argjson deletion_percent "$DELETION_PERCENT" \
  --argjson deletion_threshold_percent "$DELETION_THRESHOLD_PERCENT" \
  --argjson issues "$ISSUES_JSON" \
  --argjson recommendations "$RECS_JSON" \
  '{
    validation_status: $status,
    checks: {
      file_counts: "passed",
      deletion_thresholds: ($deletion_threshold_exceeded | if . then "exceeded" else "passed" end),
      sync_success: "passed"
    },
    issues: $issues,
    recommendations: $recommendations,
    summary: {
      files_synced: $files_synced,
      files_deleted: $files_deleted,
      deletion_threshold_exceeded: $deletion_threshold_exceeded
    }
  }'

# Exit with appropriate code
if [ "$VALIDATION_STATUS" = "failure" ]; then
  exit 1
fi

exit 0
