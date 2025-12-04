#!/usr/bin/env bash
#
# resume-run.sh - Prepare context for resuming a FABER run
#
# Usage:
#   resume-run.sh --run-id <run-id> [--step <step-id>]
#
# Description:
#   Loads state from an existing run and determines the next step to execute.
#   Returns a resume context object for the faber-manager agent.
#
# Arguments:
#   --run-id <run-id>  Run identifier (format: org/project/uuid)
#   --step <step-id>   Optional: Start from specific step (format: phase:step-name)
#
# Returns:
#   JSON object with resume context
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_PATH=".fractary/plugins/faber/runs"

# Parse arguments
RUN_ID=""
STEP_ID=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --step)
            STEP_ID="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate run_id
if [ -z "$RUN_ID" ]; then
    echo "Error: --run-id is required" >&2
    exit 1
fi

# Validate run_id format
if ! echo "$RUN_ID" | grep -qE '^[a-z0-9_-]+/[a-z0-9_-]+/[a-f0-9-]{36}$'; then
    echo "Error: Invalid run_id format. Expected: org/project/uuid" >&2
    exit 1
fi

# Check if run directory exists
RUN_DIR="$BASE_PATH/$RUN_ID"
if [ ! -d "$RUN_DIR" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "error": "Run directory not found: $RUN_DIR"
}
EOF
    exit 1
fi

# Load state
STATE_FILE="$RUN_DIR/state.json"
if [ ! -f "$STATE_FILE" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "error": "State file not found: $STATE_FILE"
}
EOF
    exit 1
fi

STATE=$(cat "$STATE_FILE")

# Check run status - can only resume pending, in_progress, or failed runs
RUN_STATUS=$(echo "$STATE" | jq -r '.status')
if [ "$RUN_STATUS" = "completed" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "error": "Cannot resume a completed run. Use --rerun to start a new run."
}
EOF
    exit 1
fi

if [ "$RUN_STATUS" = "cancelled" ]; then
    cat <<EOF
{
  "status": "error",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "error": "Cannot resume a cancelled run. Use --rerun to start a new run."
}
EOF
    exit 1
fi

# Load metadata
METADATA_FILE="$RUN_DIR/metadata.json"
METADATA="{}"
if [ -f "$METADATA_FILE" ]; then
    METADATA=$(cat "$METADATA_FILE")
fi

# Extract key state values
CURRENT_PHASE=$(echo "$STATE" | jq -r '.current_phase // "frame"')
WORK_ID=$(echo "$STATE" | jq -r '.work_id')
ARTIFACTS=$(echo "$STATE" | jq -c '.artifacts // {}')
PHASES=$(echo "$STATE" | jq -c '.phases')

# Determine completed phases
COMPLETED_PHASES=$(echo "$PHASES" | jq -c '[to_entries[] | select(.value.status == "completed") | .key]')

# Determine current step (if specified, validate it; otherwise find next incomplete step)
RESUME_PHASE="$CURRENT_PHASE"
RESUME_STEP=""

if [ -n "$STEP_ID" ]; then
    # User specified a step - validate and use it
    STEP_PHASE=$(echo "$STEP_ID" | cut -d':' -f1)
    STEP_NAME=$(echo "$STEP_ID" | cut -d':' -f2)

    # Validate phase exists
    case "$STEP_PHASE" in
        frame|architect|build|evaluate|release)
            RESUME_PHASE="$STEP_PHASE"
            RESUME_STEP="$STEP_NAME"
            ;;
        *)
            cat <<EOF
{
  "status": "error",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "error": "Invalid phase in step_id: $STEP_PHASE"
}
EOF
            exit 1
            ;;
    esac
else
    # Find the first incomplete step in the current phase
    PHASE_STEPS=$(echo "$PHASES" | jq -r --arg p "$CURRENT_PHASE" '.[$p].steps // []')
    RESUME_STEP=$(echo "$PHASE_STEPS" | jq -r '[.[] | select(.status != "completed")] | .[0].name // ""')

    # If no incomplete step found, start the phase fresh
    if [ -z "$RESUME_STEP" ]; then
        RESUME_STEP=""
    fi
fi

# Count events
EVENTS_DIR="$RUN_DIR/events"
EVENT_COUNT=0
if [ -d "$EVENTS_DIR" ]; then
    EVENT_COUNT=$(find "$EVENTS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')
fi

# Build resume context
cat <<EOF
{
  "status": "success",
  "operation": "resume-run",
  "run_id": "$RUN_ID",
  "work_id": "$WORK_ID",
  "run_status": "$RUN_STATUS",
  "resume_context": {
    "completed_phases": $COMPLETED_PHASES,
    "current_phase": "$RESUME_PHASE",
    "current_step": "$RESUME_STEP",
    "artifacts": $ARTIFACTS,
    "event_count": $EVENT_COUNT
  },
  "metadata": $METADATA
}
EOF
exit 0
