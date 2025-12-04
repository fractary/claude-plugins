#!/usr/bin/env bash
#
# state-mark-complete.sh - Mark workflow as completed or failed
#
# Usage:
#   state-mark-complete.sh <final_status> [summary_or_error]
#
# Arguments:
#   final_status      - Final status (completed, failed, cancelled)
#   summary_or_error  - Optional summary (for completed) or error message (for failed)
#
# Examples:
#   state-mark-complete.sh completed "All phases executed successfully"
#   state-mark-complete.sh failed "Evaluate phase failed after 3 retries"
#   state-mark-complete.sh cancelled "User cancelled workflow"

set -euo pipefail

# Arguments
FINAL_STATUS="${1:?Final status required (completed, failed, cancelled)}"
SUMMARY_OR_ERROR="${2:-}"

# Resolve paths robustly (works regardless of execution context)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FABER_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
CORE_SCRIPTS="$FABER_ROOT/skills/core/scripts"
STATE_FILE=".fractary/plugins/faber/state.json"

# Verify core scripts exist
if [ ! -d "$CORE_SCRIPTS" ]; then
    echo "Error: Core scripts not found at: $CORE_SCRIPTS" >&2
    exit 1
fi

# Validate status
case "$FINAL_STATUS" in
    completed|failed|cancelled) ;;
    *)
        echo "Error: Invalid final status: $FINAL_STATUS" >&2
        echo "Valid statuses: completed, failed, cancelled" >&2
        exit 1
        ;;
esac

# Check state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

# Read current state
CURRENT_STATE=$("$CORE_SCRIPTS/state-read.sh" "$STATE_FILE")

# Current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build update based on status
case "$FINAL_STATUS" in
    completed)
        UPDATED_STATE=$(echo "$CURRENT_STATE" | jq \
            --arg status "$FINAL_STATUS" \
            --arg timestamp "$TIMESTAMP" \
            --arg summary "$SUMMARY_OR_ERROR" \
            '
            .status = $status |
            .completed_at = $timestamp |
            if $summary != "" then .summary = $summary else . end
            ')
        ;;
    failed)
        UPDATED_STATE=$(echo "$CURRENT_STATE" | jq \
            --arg status "$FINAL_STATUS" \
            --arg timestamp "$TIMESTAMP" \
            --arg error "$SUMMARY_OR_ERROR" \
            '
            .status = $status |
            .completed_at = $timestamp |
            if $error != "" then
                if .errors == null then .errors = [] else . end |
                .errors += [{
                    "message": $error,
                    "timestamp": $timestamp,
                    "type": "workflow_failure"
                }]
            else . end
            ')
        ;;
    cancelled)
        UPDATED_STATE=$(echo "$CURRENT_STATE" | jq \
            --arg status "$FINAL_STATUS" \
            --arg timestamp "$TIMESTAMP" \
            --arg reason "$SUMMARY_OR_ERROR" \
            '
            .status = $status |
            .completed_at = $timestamp |
            if $reason != "" then .cancellation_reason = $reason else . end
            ')
        ;;
esac

# Write updated state
echo "$UPDATED_STATE" | "$CORE_SCRIPTS/state-write.sh" "$STATE_FILE"

echo "Workflow marked as: $FINAL_STATUS"
exit 0
