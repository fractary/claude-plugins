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
# Exit Codes:
#   0 - Success
#   1 - Validation or input error
#   2 - State update failure (CRITICAL - requires intervention)
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

Exit Codes:
  0 - Success
  1 - Validation or input error
  2 - State update failure (CRITICAL)
EOF
}

# Sanitize string for safe JSON output - removes control characters
sanitize_string() {
    local input="$1"
    # Remove control characters except newline/tab, escape backslashes and quotes
    printf '%s' "$input" | tr -d '\000-\010\013\014\016-\037' | sed 's/\\/\\\\/g; s/"/\\"/g'
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
            # Validate metadata is valid JSON object
            if ! echo "$2" | jq -e 'type == "object"' > /dev/null 2>&1; then
                echo '{"status": "error", "error": {"code": "INVALID_METADATA", "message": "--metadata must be a valid JSON object"}}' >&2
                exit 1
            fi
            METADATA="$2"
            shift 2
            ;;
        --artifacts)
            # Validate artifacts is valid JSON array
            if ! echo "$2" | jq -e 'type == "array"' > /dev/null 2>&1; then
                echo '{"status": "error", "error": {"code": "INVALID_ARTIFACTS", "message": "--artifacts must be a valid JSON array"}}' >&2
                exit 1
            fi
            ARTIFACTS="$2"
            shift 2
            ;;
        --duration-ms)
            # Validate duration is a number
            if ! [[ "$2" =~ ^[0-9]+$ ]]; then
                echo '{"status": "error", "error": {"code": "INVALID_DURATION", "message": "--duration-ms must be a positive integer"}}' >&2
                exit 1
            fi
            DURATION_MS="$2"
            shift 2
            ;;
        --error)
            # Validate error is valid JSON object
            if ! echo "$2" | jq -e 'type == "object"' > /dev/null 2>&1; then
                echo '{"status": "error", "error": {"code": "INVALID_ERROR", "message": "--error must be a valid JSON object"}}' >&2
                exit 1
            fi
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

# Validate run_id format - stricter regex (no leading/trailing special chars in org/project)
if [[ ! "$RUN_ID" =~ ^[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] && \
   [[ ! "$RUN_ID" =~ ^[a-z0-9]/[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
    echo '{"status": "error", "error": {"code": "INVALID_RUN_ID", "message": "Invalid run_id format"}}' >&2
    exit 1
fi

# Path traversal protection - ensure run_id doesn't contain .. or absolute paths
if [[ "$RUN_ID" == *".."* ]] || [[ "$RUN_ID" == /* ]]; then
    echo '{"status": "error", "error": {"code": "PATH_TRAVERSAL", "message": "Path traversal attempt detected"}}' >&2
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
    # Use jq for safe JSON output
    jq -n --arg type "$EVENT_TYPE" \
        '{"status": "error", "error": {"code": "INVALID_EVENT_TYPE", "message": ("Unknown event type: " + $type)}}' >&2
    exit 1
fi

# Build paths
RUN_DIR="${BASE_PATH}/${RUN_ID}"
EVENTS_DIR="${RUN_DIR}/events"
NEXT_ID_FILE="${EVENTS_DIR}/.next-id"
LOCK_FILE="${NEXT_ID_FILE}.lock"
STATE_FILE="${RUN_DIR}/state.json"

# Verify run directory exists
if [[ ! -d "$RUN_DIR" ]]; then
    jq -n --arg dir "$RUN_DIR" \
        '{"status": "error", "error": {"code": "RUN_NOT_FOUND", "message": ("Run directory not found: " + $dir)}}' >&2
    exit 1
fi

# Get and increment event ID (atomic using flock with cleanup)
get_next_event_id() {
    local lockfile="$LOCK_FILE"

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

    # Release lock
    exec 200>&-

    # Clean up lock file
    rm -f "$lockfile" 2>/dev/null || true

    echo "$current_id"
}

EVENT_ID=$(get_next_event_id)

# Generate timestamp with milliseconds
# Use date with nanoseconds if available, fall back to seconds
if date +%N &>/dev/null; then
    # GNU date supports nanoseconds
    TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.%3NZ)
else
    # macOS/BSD date - use perl for milliseconds
    if command -v perl &>/dev/null; then
        TIMESTAMP=$(perl -MTime::HiRes=time -MPOSIX=strftime -e 'my $t = time; my $ms = sprintf("%03d", ($t - int($t)) * 1000); print strftime("%Y-%m-%dT%H:%M:%S", gmtime(int($t))) . "." . $ms . "Z"')
    else
        # Fallback to seconds with .000
        TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%S.000Z)
    fi
fi

# Build event JSON using jq for safe escaping of all values
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

# Update state.json with last_event_id - CRITICAL operation
# Failure here means state is inconsistent and requires intervention
if [[ -f "$STATE_FILE" ]]; then
    TEMP_STATE="${STATE_FILE}.tmp.$$"

    if ! jq --argjson eid "$EVENT_ID" --arg ts "$TIMESTAMP" \
        '.last_event_id = $eid | .updated_at = $ts' \
        "$STATE_FILE" > "$TEMP_STATE" 2>/dev/null; then
        rm -f "$TEMP_STATE" 2>/dev/null || true
        jq -n --arg eid "$EVENT_ID" --arg path "$EVENT_PATH" \
            '{"status": "error", "error": {"code": "STATE_UPDATE_FAILED", "message": "Failed to update state.json - event was written but state is inconsistent", "event_id": ($eid | tonumber), "event_path": $path}}' >&2
        exit 2
    fi

    if ! mv "$TEMP_STATE" "$STATE_FILE" 2>/dev/null; then
        rm -f "$TEMP_STATE" 2>/dev/null || true
        jq -n --arg eid "$EVENT_ID" --arg path "$EVENT_PATH" \
            '{"status": "error", "error": {"code": "STATE_WRITE_FAILED", "message": "Failed to write state.json - event was written but state is inconsistent", "event_id": ($eid | tonumber), "event_path": $path}}' >&2
        exit 2
    fi
fi

# Output result using jq for safe JSON
jq -n \
    --argjson event_id "$EVENT_ID" \
    --arg type "$EVENT_TYPE" \
    --arg run_id "$RUN_ID" \
    --arg timestamp "$TIMESTAMP" \
    --arg event_path "$EVENT_PATH" \
    '{
        status: "success",
        operation: "emit-event",
        event_id: $event_id,
        type: $type,
        run_id: $run_id,
        timestamp: $timestamp,
        event_path: $event_path
    }'

exit 0
