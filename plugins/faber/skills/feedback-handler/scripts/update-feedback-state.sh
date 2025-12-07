#!/usr/bin/env bash
#
# update-feedback-state.sh - Update run state with feedback request/response
#
# Usage:
#   update-feedback-state.sh --run-id <id> --operation <op> [options]
#
# Operations:
#   set-awaiting    Set status to awaiting_feedback with request details
#   clear-awaiting  Clear feedback request, set status to in_progress
#   add-history     Add entry to feedback_history array
#
# Exit Codes:
#   0 - Success
#   1 - Validation or input error
#   2 - State update failure

set -euo pipefail

# Parse arguments
RUN_ID=""
OPERATION=""
REQUEST_ID=""
FEEDBACK_TYPE=""
PROMPT=""
OPTIONS_JSON="[]"
CONTEXT_JSON="{}"
PHASE=""
STEP=""
STEP_INDEX=""
RESPONSE=""
USER=""
SOURCE=""
COMMENT_URL=""
BASE_PATH=".fractary/plugins/faber/runs"

print_usage() {
    cat <<EOF
Usage: update-feedback-state.sh --run-id <id> --operation <op> [options]

Operations:
  set-awaiting    Set status to awaiting_feedback
  clear-awaiting  Clear feedback request, resume workflow
  add-history     Add feedback to history

Options for set-awaiting:
  --request-id <id>       Feedback request ID
  --type <type>           Feedback type (approval, review, etc.)
  --prompt <text>         Prompt message
  --options <json>        Valid response options (JSON array)
  --context <json>        Additional context (JSON object)
  --phase <phase>         Current phase
  --step <step>           Current step
  --step-index <n>        Step index within phase
  --comment-url <url>     URL of issue comment (if posted)

Options for clear-awaiting:
  --phase <phase>         Resume phase
  --step <step>           Resume step

Options for add-history:
  --request-id <id>       Request ID being responded to
  --type <type>           Feedback type
  --response <response>   User's response
  --user <user>           User who provided feedback
  --source <source>       Feedback source (cli, issue_comment)

Common:
  --base-path <path>      Base path for runs (default: .fractary/plugins/faber/runs)
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --operation)
            OPERATION="$2"
            shift 2
            ;;
        --request-id)
            REQUEST_ID="$2"
            shift 2
            ;;
        --type)
            FEEDBACK_TYPE="$2"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --options)
            OPTIONS_JSON="$2"
            shift 2
            ;;
        --context)
            CONTEXT_JSON="$2"
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
        --step-index)
            STEP_INDEX="$2"
            shift 2
            ;;
        --response)
            RESPONSE="$2"
            shift 2
            ;;
        --user)
            USER="$2"
            shift 2
            ;;
        --source)
            SOURCE="$2"
            shift 2
            ;;
        --comment-url)
            COMMENT_URL="$2"
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

if [[ -z "$OPERATION" ]]; then
    echo '{"status": "error", "error": {"code": "MISSING_OPERATION", "message": "--operation is required"}}' >&2
    exit 1
fi

# Validate run_id format - must match: org/project/uuid (prevents path traversal)
if [[ ! "$RUN_ID" =~ ^[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-z0-9][a-z0-9_-]*[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]] && \
   [[ ! "$RUN_ID" =~ ^[a-z0-9]/[a-z0-9]/[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$ ]]; then
    echo '{"status": "error", "error": {"code": "INVALID_RUN_ID", "message": "Invalid run_id format. Must be: org/project/uuid"}}' >&2
    exit 1
fi

# Path traversal protection - ensure run_id doesn't contain .. or absolute paths
if [[ "$RUN_ID" == *".."* ]] || [[ "$RUN_ID" == /* ]]; then
    echo '{"status": "error", "error": {"code": "PATH_TRAVERSAL", "message": "Path traversal attempt detected"}}' >&2
    exit 1
fi

# Build paths
STATE_FILE="${BASE_PATH}/${RUN_ID}/state.json"
LOCK_FILE="${STATE_FILE}.lock"

# Cleanup function to release lock on exit
cleanup() {
    if [[ -n "${LOCK_FD:-}" ]]; then
        exec {LOCK_FD}>&- 2>/dev/null || true
    fi
    rm -f "$LOCK_FILE" 2>/dev/null || true
}
trap cleanup EXIT

# Acquire exclusive lock for state file operations
acquire_lock() {
    exec {LOCK_FD}>"$LOCK_FILE"
    if ! flock -x -w 30 "$LOCK_FD" 2>/dev/null; then
        echo '{"status": "error", "error": {"code": "LOCK_TIMEOUT", "message": "Could not acquire state file lock within 30 seconds"}}' >&2
        exit 2
    fi
}

# Verify state file exists
if [[ ! -f "$STATE_FILE" ]]; then
    jq -n --arg path "$STATE_FILE" \
        '{"status": "error", "error": {"code": "STATE_NOT_FOUND", "message": ("State file not found: " + $path)}}' >&2
    exit 1
fi

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

case "$OPERATION" in
    set-awaiting)
        # Validate required fields
        if [[ -z "$REQUEST_ID" || -z "$FEEDBACK_TYPE" || -z "$PROMPT" || -z "$PHASE" || -z "$STEP" ]]; then
            echo '{"status": "error", "error": {"code": "MISSING_FIELDS", "message": "set-awaiting requires: --request-id, --type, --prompt, --phase, --step"}}' >&2
            exit 1
        fi

        # Acquire exclusive lock before modifying state
        acquire_lock

        # Build feedback request object
        FEEDBACK_REQUEST=$(jq -n \
            --arg request_id "$REQUEST_ID" \
            --arg type "$FEEDBACK_TYPE" \
            --arg prompt "$PROMPT" \
            --argjson options "$OPTIONS_JSON" \
            --argjson context "$CONTEXT_JSON" \
            --arg timestamp "$TIMESTAMP" \
            --arg comment_url "$COMMENT_URL" \
            '{
                request_id: $request_id,
                type: $type,
                prompt: $prompt,
                options: $options,
                context: $context,
                requested_at: $timestamp,
                notification_sent: {
                    cli: true,
                    issue_comment: ($comment_url != ""),
                    comment_url: (if $comment_url != "" then $comment_url else null end)
                }
            }')

        # Build resume point
        RESUME_POINT=$(jq -n \
            --arg phase "$PHASE" \
            --arg step "$STEP" \
            --arg step_index "$STEP_INDEX" \
            '{
                phase: $phase,
                step: $step,
                step_index: (if $step_index != "" then ($step_index | tonumber) else null end)
            }')

        # Update state
        TEMP_STATE="${STATE_FILE}.tmp.$$"
        if ! jq \
            --arg status "awaiting_feedback" \
            --arg phase "$PHASE" \
            --arg step "$STEP" \
            --arg timestamp "$TIMESTAMP" \
            --argjson feedback_request "$FEEDBACK_REQUEST" \
            --argjson resume_point "$RESUME_POINT" \
            '.status = $status |
             .current_phase = $phase |
             .current_step = $step |
             .updated_at = $timestamp |
             .feedback_request = $feedback_request |
             .resume_point = $resume_point' \
            "$STATE_FILE" > "$TEMP_STATE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_UPDATE_FAILED", "message": "Failed to update state file"}}' >&2
            exit 2
        fi

        if ! mv "$TEMP_STATE" "$STATE_FILE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_WRITE_FAILED", "message": "Failed to write state file"}}' >&2
            exit 2
        fi

        jq -n \
            --arg request_id "$REQUEST_ID" \
            --arg phase "$PHASE" \
            --arg step "$STEP" \
            '{
                status: "success",
                operation: "set-awaiting",
                request_id: $request_id,
                resume_point: {phase: $phase, step: $step}
            }'
        ;;

    clear-awaiting)
        # Validate phase and step for resume
        if [[ -z "$PHASE" || -z "$STEP" ]]; then
            echo '{"status": "error", "error": {"code": "MISSING_FIELDS", "message": "clear-awaiting requires: --phase, --step"}}' >&2
            exit 1
        fi

        # Acquire exclusive lock before modifying state
        acquire_lock

        # Update state - clear feedback request and set in_progress
        TEMP_STATE="${STATE_FILE}.tmp.$$"
        if ! jq \
            --arg status "in_progress" \
            --arg phase "$PHASE" \
            --arg step "$STEP" \
            --arg timestamp "$TIMESTAMP" \
            '.status = $status |
             .current_phase = $phase |
             .current_step = $step |
             .updated_at = $timestamp |
             del(.feedback_request) |
             del(.resume_point)' \
            "$STATE_FILE" > "$TEMP_STATE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_UPDATE_FAILED", "message": "Failed to update state file"}}' >&2
            exit 2
        fi

        if ! mv "$TEMP_STATE" "$STATE_FILE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_WRITE_FAILED", "message": "Failed to write state file"}}' >&2
            exit 2
        fi

        jq -n \
            --arg phase "$PHASE" \
            --arg step "$STEP" \
            '{
                status: "success",
                operation: "clear-awaiting",
                resume_point: {phase: $phase, step: $step}
            }'
        ;;

    add-history)
        # Validate required fields
        if [[ -z "$REQUEST_ID" || -z "$FEEDBACK_TYPE" || -z "$RESPONSE" ]]; then
            echo '{"status": "error", "error": {"code": "MISSING_FIELDS", "message": "add-history requires: --request-id, --type, --response"}}' >&2
            exit 1
        fi

        # Acquire exclusive lock before modifying state
        acquire_lock

        # Build history entry
        HISTORY_ENTRY=$(jq -n \
            --arg request_id "$REQUEST_ID" \
            --arg type "$FEEDBACK_TYPE" \
            --arg response "$RESPONSE" \
            --arg user "${USER:-unknown}" \
            --arg source "${SOURCE:-cli}" \
            --arg timestamp "$TIMESTAMP" \
            '{
                request_id: $request_id,
                request_type: $type,
                response: $response,
                provided_by: {
                    user: $user,
                    source: $source
                },
                received_at: $timestamp
            }')

        # Update state - add to feedback_history
        TEMP_STATE="${STATE_FILE}.tmp.$$"
        if ! jq \
            --argjson entry "$HISTORY_ENTRY" \
            --arg timestamp "$TIMESTAMP" \
            '.updated_at = $timestamp |
             .feedback_history = ((.feedback_history // []) + [$entry])' \
            "$STATE_FILE" > "$TEMP_STATE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_UPDATE_FAILED", "message": "Failed to update state file"}}' >&2
            exit 2
        fi

        if ! mv "$TEMP_STATE" "$STATE_FILE" 2>/dev/null; then
            rm -f "$TEMP_STATE" 2>/dev/null || true
            echo '{"status": "error", "error": {"code": "STATE_WRITE_FAILED", "message": "Failed to write state file"}}' >&2
            exit 2
        fi

        jq -n \
            --arg request_id "$REQUEST_ID" \
            --arg response "$RESPONSE" \
            '{
                status: "success",
                operation: "add-history",
                request_id: $request_id,
                response: $response
            }'
        ;;

    *)
        jq -n --arg op "$OPERATION" \
            '{"status": "error", "error": {"code": "INVALID_OPERATION", "message": ("Unknown operation: " + $op)}}' >&2
        exit 1
        ;;
esac

exit 0
