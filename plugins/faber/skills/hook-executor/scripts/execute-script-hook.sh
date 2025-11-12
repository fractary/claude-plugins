#!/usr/bin/env bash
# Execute a script hook with proper environment and timeout
# Used by hook executor to run script hooks

set -euo pipefail

# Usage: execute-script-hook.sh <script-path> <timeout> <workflow-context-json>

SCRIPT_PATH="${1:-}"
TIMEOUT="${2:-300}"
WORKFLOW_CONTEXT="${3:-}"

if [[ -z "$SCRIPT_PATH" ]]; then
    echo "Error: Script path required" >&2
    echo "Usage: $0 <script-path> <timeout> <workflow-context-json>" >&2
    exit 1
fi

if [[ -z "$WORKFLOW_CONTEXT" ]]; then
    echo "Error: Workflow context JSON required" >&2
    exit 1
fi

# Parse workflow context
PHASE=$(echo "$WORKFLOW_CONTEXT" | jq -r '.phase')
HOOK_TYPE=$(echo "$WORKFLOW_CONTEXT" | jq -r '.hookType')
ENVIRONMENT=$(echo "$WORKFLOW_CONTEXT" | jq -r '.environment')
WORK_ITEM_ID=$(echo "$WORKFLOW_CONTEXT" | jq -r '.workItem.id // ""')
WORK_ITEM_TYPE=$(echo "$WORKFLOW_CONTEXT" | jq -r '.workItem.type // ""')
PROJECT_ROOT=$(echo "$WORKFLOW_CONTEXT" | jq -r '.projectRoot')
CONFIG_PATH=$(echo "$WORKFLOW_CONTEXT" | jq -r '.configPath // ""')
AUTONOMY_LEVEL=$(echo "$WORKFLOW_CONTEXT" | jq -r '.autonomyLevel // ""')
DRY_RUN=$(echo "$WORKFLOW_CONTEXT" | jq -r '.flags.dryRun // false')

# Resolve script path (support template variables)
RESOLVED_PATH="$SCRIPT_PATH"
RESOLVED_PATH="${RESOLVED_PATH//\{\{environment\}\}/$ENVIRONMENT}"
RESOLVED_PATH="${RESOLVED_PATH//\{\{phase\}\}/$PHASE}"
RESOLVED_PATH="${RESOLVED_PATH//\{\{project_root\}\}/$PROJECT_ROOT}"

# Make path absolute if relative
if [[ ! "$RESOLVED_PATH" = /* ]]; then
    RESOLVED_PATH="$PROJECT_ROOT/$RESOLVED_PATH"
fi

# Check script exists
if [[ ! -f "$RESOLVED_PATH" ]]; then
    echo "Error: Script not found: $SCRIPT_PATH (resolved to: $RESOLVED_PATH)" >&2
    exit 1
fi

# Check script is executable (make executable if not)
if [[ ! -x "$RESOLVED_PATH" ]]; then
    echo "Warning: Script not executable, making executable: $RESOLVED_PATH" >&2
    chmod +x "$RESOLVED_PATH" || {
        echo "Error: Cannot make script executable: $RESOLVED_PATH" >&2
        exit 1
    }
fi

# Set FABER environment variables
export FABER_PHASE="$PHASE"
export FABER_HOOK_TYPE="$HOOK_TYPE"
export FABER_ENVIRONMENT="$ENVIRONMENT"
export FABER_WORK_ITEM_ID="$WORK_ITEM_ID"
export FABER_WORK_ITEM_TYPE="$WORK_ITEM_TYPE"
export FABER_PROJECT_ROOT="$PROJECT_ROOT"
export FABER_CONFIG_PATH="$CONFIG_PATH"
export FABER_AUTONOMY_LEVEL="$AUTONOMY_LEVEL"
export FABER_DRY_RUN="$DRY_RUN"

# Output execution info to stderr
echo "Executing script hook: $SCRIPT_PATH" >&2
echo "Resolved path: $RESOLVED_PATH" >&2
echo "Timeout: ${TIMEOUT}s" >&2
echo "Environment: $ENVIRONMENT" >&2
echo "Phase: $PHASE ($HOOK_TYPE)" >&2

# Create temporary files for output
STDOUT_FILE=$(mktemp)
STDERR_FILE=$(mktemp)
EXIT_CODE_FILE=$(mktemp)

# Cleanup temp files on exit
cleanup() {
    rm -f "$STDOUT_FILE" "$STDERR_FILE" "$EXIT_CODE_FILE"
}
trap cleanup EXIT

# Execute script with timeout
START_TIME=$(date +%s)

(
    # Execute script in subshell
    cd "$PROJECT_ROOT" || exit 1

    if command -v timeout >/dev/null 2>&1; then
        # GNU timeout command available
        timeout "${TIMEOUT}s" bash "$RESOLVED_PATH" >"$STDOUT_FILE" 2>"$STDERR_FILE"
    else
        # Fallback: background execution with manual timeout
        bash "$RESOLVED_PATH" >"$STDOUT_FILE" 2>"$STDERR_FILE" &
        SCRIPT_PID=$!

        # Wait for timeout or completion
        for ((i=0; i<TIMEOUT; i++)); do
            if ! kill -0 "$SCRIPT_PID" 2>/dev/null; then
                # Process completed
                wait "$SCRIPT_PID"
                exit $?
            fi
            sleep 1
        done

        # Timeout reached, kill process
        echo "Error: Script execution timeout (${TIMEOUT}s)" >&2
        kill -TERM "$SCRIPT_PID" 2>/dev/null || true
        sleep 2
        kill -KILL "$SCRIPT_PID" 2>/dev/null || true
        exit 124  # Standard timeout exit code
    fi
)

SCRIPT_EXIT_CODE=$?
echo "$SCRIPT_EXIT_CODE" > "$EXIT_CODE_FILE"

END_TIME=$(date +%s)
DURATION=$((END_TIME - START_TIME))

# Output metadata as JSON to stderr
cat >&2 <<EOF
{
  "exitCode": $SCRIPT_EXIT_CODE,
  "duration": $DURATION,
  "timeout": $TIMEOUT,
  "timedOut": $([ $SCRIPT_EXIT_CODE -eq 124 ] && echo "true" || echo "false")
}
EOF

# Output script stdout to stdout
cat "$STDOUT_FILE"

# Output script stderr to stderr (after metadata)
if [[ -s "$STDERR_FILE" ]]; then
    echo "=== Script stderr ===" >&2
    cat "$STDERR_FILE" >&2
fi

# Exit with script's exit code
exit "$SCRIPT_EXIT_CODE"
