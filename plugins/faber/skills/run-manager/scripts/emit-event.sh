#!/usr/bin/env bash
#
# emit-event.sh - Emit a FABER workflow event
#
# Usage:
#   emit-event.sh --run-id <id> --type <type> [options]
#
# Writes event to the run's events directory with sequential ID.
# Events are immutable once written.
#

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Parse arguments
RUN_ID=""
EVENT_TYPE=""
PHASE=""
STEP=""
STATUS=""
MESSAGE=""
METADATA="{}"
ARTIFACTS="[]"
DURATION_MS=""
ERROR_JSON=""
BASE_PATH=".fractary/plugins/faber/runs"

print_usage() {
    cat <<EOF
Usage: emit-event.sh --run-id <id> --type <type> [options]

Emits a workflow event to the run's event log.

Required:
  --run-id <id>         Full run identifier (org/project/uuid)
  --type <type>         Event type (workflow_start, phase_start, etc.)

Optional:
  --phase <phase>       Current phase (frame, architect, build, evaluate, release)
  --step <step>         Current step within phase
  --status <status>     Event status (started, completed, failed, skipped)
  --message <text>      Human-readable event description
  --metadata <json>     Event-specific metadata (JSON object)
  --artifacts <json>    Artifacts array (JSON array)
  --duration-ms <ms>    Duration in milliseconds
  --error <json>        Error information (JSON object)
  --base-path <path>    Base path for runs (default: .fractary/plugins/faber/runs)

Event Types:
  Workflow: workflow_start, workflow_complete, workflow_error, workflow_cancelled,
            workflow_resumed, workflow_rerun
  Phase:    phase_start, phase_skip, phase_complete, phase_error
  Step:     step_start, step_complete, step_error, step_retry
  Artifact: artifact_create, artifact_modify
  Git:      commit_create, branch_create, pr_create, pr_merge
  Other:    checkpoint, skill_invoke, agent_invoke, decision_point,
            retry_loop_enter, retry_loop_exit, approval_request,
            approval_granted, approval_denied, hook_execute

Output:
  JSON object with event details and file path
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --type)
            EVENT_TYPE="$2"
            shift 2
            ;;
        --phase)
            PHASE="$2"
            shift 2
            ;;
        --step)
            STEP="$2"
            shift 2
            ;;
        --status)
            STATUS="$2"
            shift 2
            ;;
        --message)
            MESSAGE="$2"
            shift 2
            ;;
        --metadata)
            METADATA="$2"
            shift 2
            ;;
        --artifacts)
            ARTIFACTS="$2"
            shift 2
            ;;
        --duration-ms)
            DURATION_MS="$2"
            shift 2
            ;;
        --error)
            ERROR_JSON="$2"
            shift 2
            ;;
        --base-path)
            BASE_PATH="$2"
            shift 2
            ;;
        --help|-h)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$RUN_ID" ]]; then
    echo '{"status": "error", "error": {"code": "MISSING_RUN_ID", "message": "--run-id is required"}}' >&2
    exit 1
fi

if [[ -z "$EVENT_TYPE" ]]; then
    echo '{"status": "error", "error": {"code": "MISSING_EVENT_TYPE", "message": "--type is required"}}' >&2
    exit 1
fi

# Validate run_id format
if [[ ! "$RUN_ID" =~ ^[a-z0-9_-]+/[a-z0-9_-]+/[a-f0-9-]{36}$ ]]; then
    echo '{"status": "error", "error": {"code": "INVALID_RUN_ID", "message": "Invalid run_id format"}}' >&2
    exit 1
fi

# Validate event type
VALID_TYPES=(
    "workflow_start" "workflow_complete" "workflow_error" "workflow_cancelled"
    "workflow_resumed" "workflow_rerun"
    "phase_start" "phase_skip" "phase_complete" "phase_error"
    "step_start" "step_complete" "step_error" "step_retry"
    "artifact_create" "artifact_modify"
    "commit_create" "branch_create" "pr_create" "pr_merge"
    "spec_generate" "spec_validate" "test_run" "docs_update"
    "checkpoint" "skill_invoke" "agent_invoke" "decision_point"
    "retry_loop_enter" "retry_loop_exit"
    "approval_request" "approval_granted" "approval_denied" "hook_execute"
)

TYPE_VALID=false
for t in "${VALID_TYPES[@]}"; do
    if [[ "$EVENT_TYPE" == "$t" ]]; then
        TYPE_VALID=true
        break
    fi
done

if [[ "$TYPE_VALID" != "true" ]]; then
    echo "{\"status\": \"error\", \"error\": {\"code\": \"INVALID_EVENT_TYPE\", \"message\": \"Unknown event type: $EVENT_TYPE\"}}" >&2
    exit 1
fi

# Build paths
RUN_DIR="${BASE_PATH}/${RUN_ID}"
EVENTS_DIR="${RUN_DIR}/events"
NEXT_ID_FILE="${EVENTS_DIR}/.next-id"
STATE_FILE="${RUN_DIR}/state.json"

# Verify run directory exists
if [[ ! -d "$RUN_DIR" ]]; then
    echo "{\"status\": \"error\", \"error\": {\"code\": \"RUN_NOT_FOUND\", \"message\": \"Run directory not found: $RUN_DIR\"}}" >&2
    exit 1
fi

# Get and increment event ID (atomic using flock)
get_next_event_id() {
    local lockfile="${NEXT_ID_FILE}.lock"

    # Create lock file and acquire exclusive lock
    exec 200>"$lockfile"
    flock -x 200

    # Read current ID
    local current_id
    if [[ -f "$NEXT_ID_FILE" ]]; then
        current_id=$(cat "$NEXT_ID_FILE")
    else
        current_id=1
    fi

    # Write next ID
    echo $((current_id + 1)) > "$NEXT_ID_FILE"

    # Release lock (automatically released when fd closed)
    exec 200>&-

    echo "$current_id"
}

EVENT_ID=$(get_next_event_id)

# Generate timestamp
TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Build event JSON
build_event() {
    local event_json
    event_json=$(jq -n \
        --argjson event_id "$EVENT_ID" \
        --arg type "$EVENT_TYPE" \
        --arg timestamp "$TIMESTAMP" \
        --arg run_id "$RUN_ID" \
        --arg phase "$PHASE" \
        --arg step "$STEP" \
        --arg status "$STATUS" \
        --arg user "${USER:-unknown}" \
        --arg source "emit-event.sh" \
        --arg message "$MESSAGE" \
        --argjson metadata "$METADATA" \
        --argjson artifacts "$ARTIFACTS" \
        '{
            event_id: $event_id,
            type: $type,
            timestamp: $timestamp,
            run_id: $run_id
        }
        + (if $phase != "" then {phase: $phase} else {} end)
        + (if $step != "" then {step: $step} else {} end)
        + (if $status != "" then {status: $status} else {} end)
        + {user: $user, source: $source}
        + (if $message != "" then {message: $message} else {} end)
        + (if $metadata != {} then {metadata: $metadata} else {} end)
        + (if $artifacts != [] then {artifacts: $artifacts} else {} end)
        ')

    # Add duration if provided
    if [[ -n "$DURATION_MS" ]]; then
        event_json=$(echo "$event_json" | jq --argjson dur "$DURATION_MS" '. + {duration_ms: $dur}')
    fi

    # Add error if provided
    if [[ -n "$ERROR_JSON" ]]; then
        event_json=$(echo "$event_json" | jq --argjson err "$ERROR_JSON" '. + {error: $err}')
    fi

    echo "$event_json"
}

EVENT_JSON=$(build_event)

# Write event to file
EVENT_FILENAME=$(printf "%03d-%s.json" "$EVENT_ID" "$EVENT_TYPE")
EVENT_PATH="${EVENTS_DIR}/${EVENT_FILENAME}"

echo "$EVENT_JSON" > "$EVENT_PATH"

# Update state.json with last_event_id
if [[ -f "$STATE_FILE" ]]; then
    # Update last_event_id and updated_at
    jq --argjson eid "$EVENT_ID" --arg ts "$TIMESTAMP" \
        '.last_event_id = $eid | .updated_at = $ts' \
        "$STATE_FILE" > "${STATE_FILE}.tmp" && mv "${STATE_FILE}.tmp" "$STATE_FILE"
fi

# Output result
cat <<EOF
{
  "status": "success",
  "operation": "emit-event",
  "event_id": $EVENT_ID,
  "type": "$EVENT_TYPE",
  "run_id": "$RUN_ID",
  "timestamp": "$TIMESTAMP",
  "event_path": "$EVENT_PATH"
}
EOF

exit 0
