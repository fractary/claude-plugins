#!/usr/bin/env bash
#
# state-update-step.sh - Update a specific step within a phase
#
# Usage:
#   state-update-step.sh <phase> <step_name> <status> [data_json]
#
# Arguments:
#   phase       - Phase name (frame, architect, build, evaluate, release)
#   step_name   - Name of the step to update
#   status      - Step status (pending, in_progress, completed, failed, skipped)
#   data_json   - Optional JSON data to store with step (default: {})
#
# Examples:
#   state-update-step.sh build implement in_progress
#   state-update-step.sh build implement completed '{"files_changed": 5}'
#   state-update-step.sh evaluate test failed '{"test_count": 10, "failures": 2}'

set -euo pipefail

# Arguments
PHASE="${1:?Phase name required}"
STEP_NAME="${2:?Step name required}"
STATUS="${3:?Status required}"
DATA_JSON="${4:-{}}"

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

# Validate phase
case "$PHASE" in
    frame|architect|build|evaluate|release) ;;
    *)
        echo "Error: Invalid phase: $PHASE" >&2
        exit 1
        ;;
esac

# Validate status
case "$STATUS" in
    pending|in_progress|completed|failed|skipped) ;;
    *)
        echo "Error: Invalid status: $STATUS" >&2
        exit 1
        ;;
esac

# Validate data JSON
if ! echo "$DATA_JSON" | jq empty 2>/dev/null; then
    echo "Error: Invalid JSON in data parameter" >&2
    exit 1
fi

# Check state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo "Error: State file not found: $STATE_FILE" >&2
    exit 1
fi

# Read current state
CURRENT_STATE=$("$CORE_SCRIPTS/state-read.sh" "$STATE_FILE")

# Current timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Update step in the phase
# First, ensure the phase has a steps array
# Then find or create the step entry and update it
UPDATED_STATE=$(echo "$CURRENT_STATE" | jq \
    --arg phase "$PHASE" \
    --arg step_name "$STEP_NAME" \
    --arg status "$STATUS" \
    --arg timestamp "$TIMESTAMP" \
    --argjson data "$DATA_JSON" \
    '
    # Ensure steps array exists for the phase
    if .phases[$phase].steps == null then
        .phases[$phase].steps = []
    else . end |

    # Find step index
    (.phases[$phase].steps | map(.name == $step_name) | index(true)) as $idx |

    if $idx != null then
        # Update existing step
        .phases[$phase].steps[$idx].status = $status |
        .phases[$phase].steps[$idx].updated_at = $timestamp |
        if $status == "in_progress" then
            .phases[$phase].steps[$idx].started_at = $timestamp
        elif $status == "completed" then
            .phases[$phase].steps[$idx].completed_at = $timestamp
        elif $status == "failed" then
            .phases[$phase].steps[$idx].failed_at = $timestamp
        else . end |
        if $data != {} then
            .phases[$phase].steps[$idx].data = $data
        else . end
    else
        # Create new step entry
        .phases[$phase].steps += [{
            "name": $step_name,
            "status": $status,
            "started_at": (if $status == "in_progress" then $timestamp else null end),
            "completed_at": (if $status == "completed" then $timestamp else null end),
            "data": (if $data != {} then $data else null end)
        } | with_entries(select(.value != null))]
    end
    ')

# Write updated state
echo "$UPDATED_STATE" | "$CORE_SCRIPTS/state-write.sh" "$STATE_FILE"

echo "Step '$STEP_NAME' in phase '$PHASE' updated to '$STATUS'"
exit 0
