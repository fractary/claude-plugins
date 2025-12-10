#!/bin/bash
#
# execute-workflow.sh - Deterministic FABER Workflow Executor (Prototype)
#
# This script owns the workflow iteration loop, ensuring steps cannot be skipped.
# Claude is invoked per-step via --resume to maintain context, but bash controls
# the progression.
#
# Usage:
#   ./execute-workflow.sh --plan <plan.json> --run-id <run-id> [--resume-from <step-index>]
#
# Example:
#   ./execute-workflow.sh --plan logs/fractary/plugins/faber/plans/my-plan.json \
#     --run-id "fractary/claude-plugins/abc123"
#

# Note: Not using set -e because we need fine-grained control over error handling
# in the main workflow loop. Errors are handled explicitly.
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Default values
PLAN_FILE=""
RUN_ID=""
RESUME_FROM=0
DRY_RUN=false
VERBOSE=false
SESSION_ID=""
SERIALIZED_INPUT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --plan)
            PLAN_FILE="$2"
            shift 2
            ;;
        --run-id)
            RUN_ID="$2"
            shift 2
            ;;
        --resume-from)
            RESUME_FROM="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        --session-id)
            SESSION_ID="$2"
            shift 2
            ;;
        --serialized-input)
            SERIALIZED_INPUT=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 --plan <plan.json> --run-id <run-id> [options]"
            echo ""
            echo "Options:"
            echo "  --plan <file>         Path to workflow plan JSON"
            echo "  --run-id <id>         Run identifier (e.g., fractary/project/uuid)"
            echo "  --resume-from <n>     Resume from step index N (0-based)"
            echo "  --session-id <id>     Resume existing Claude session"
            echo "  --dry-run             Show what would be executed without running"
            echo "  --verbose             Enable verbose output"
            echo "  --serialized-input    Send all steps as single message (reduces API calls)"
            echo "  -h, --help            Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$PLAN_FILE" ]]; then
    echo -e "${RED}Error: --plan is required${NC}"
    exit 1
fi

if [[ ! -f "$PLAN_FILE" ]]; then
    echo -e "${RED}Error: Plan file not found: $PLAN_FILE${NC}"
    exit 1
fi

if [[ -z "$RUN_ID" ]]; then
    echo -e "${RED}Error: --run-id is required${NC}"
    exit 1
fi

# Setup paths
RUNS_DIR="$PROJECT_ROOT/.fractary/plugins/faber/runs/$RUN_ID"
EVENTS_DIR="$RUNS_DIR/events"
STATE_FILE="$RUNS_DIR/state.json"
LOG_FILE="$RUNS_DIR/executor.log"

# Ensure run directory exists
mkdir -p "$EVENTS_DIR"

# Logging function
log() {
    local level="$1"
    shift
    local message="$*"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    echo "[$timestamp] [$level] $message" >> "$LOG_FILE"

    case "$level" in
        INFO)  echo -e "${BLUE}ℹ${NC} $message" ;;
        OK)    echo -e "${GREEN}✓${NC} $message" ;;
        WARN)  echo -e "${YELLOW}⚠${NC} $message" ;;
        ERROR) echo -e "${RED}✗${NC} $message" ;;
        STEP)  echo -e "${CYAN}→${NC} $message" ;;
    esac
}

# Emit event (deterministic - bash, not LLM)
emit_event() {
    local event_type="$1"
    local phase="${2:-}"
    local step="${3:-}"
    local message="${4:-}"

    # Get next event ID
    local next_id_file="$EVENTS_DIR/.next-id"
    local event_id=1
    if [[ -f "$next_id_file" ]]; then
        event_id=$(cat "$next_id_file")
    fi

    # Create event JSON
    local event_file="$EVENTS_DIR/$(printf "%03d" $event_id)-${event_type}.json"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%S.%3NZ")

    local event_json=$(jq -n \
        --argjson id "$event_id" \
        --arg type "$event_type" \
        --arg ts "$timestamp" \
        --arg run_id "$RUN_ID" \
        --arg phase "$phase" \
        --arg step "$step" \
        --arg msg "$message" \
        --arg source "deterministic-executor" \
        '{
            event_id: $id,
            type: $type,
            timestamp: $ts,
            run_id: $run_id,
            phase: (if $phase == "" then null else $phase end),
            step: (if $step == "" then null else $step end),
            message: $msg,
            source: $source
        }')

    echo "$event_json" > "$event_file"

    # Increment next ID
    echo $((event_id + 1)) > "$next_id_file"

    if [[ "$VERBOSE" == "true" ]]; then
        log INFO "Emitted event: $event_type (ID: $event_id)"
    fi
}

# Update state (deterministic - bash, not LLM)
update_state() {
    local operation="$1"
    shift

    case "$operation" in
        init)
            # Initialize state file if it doesn't exist
            if [[ ! -f "$STATE_FILE" ]]; then
                jq -n \
                    --arg run_id "$RUN_ID" \
                    --arg status "in_progress" \
                    '{
                        run_id: $run_id,
                        executor: "deterministic",
                        status: $status,
                        started_at: (now | todate),
                        current_phase: null,
                        current_step: null,
                        current_step_index: 0,
                        phases: {
                            frame: {status: "pending", steps: []},
                            architect: {status: "pending", steps: []},
                            build: {status: "pending", steps: []},
                            evaluate: {status: "pending", steps: []},
                            release: {status: "pending", steps: []}
                        },
                        session_id: null,
                        artifacts: {},
                        errors: []
                    }' > "$STATE_FILE"
            fi
            ;;

        set-session)
            local session_id="$1"
            jq --arg sid "$session_id" '.session_id = $sid' "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;

        step-start)
            local phase="$1"
            local step="$2"
            local step_index="$3"
            jq --arg phase "$phase" --arg step "$step" --argjson idx "$step_index" \
                '.current_phase = $phase | .current_step = $step | .current_step_index = $idx | .phases[$phase].status = "in_progress"' \
                "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;

        step-complete)
            local phase="$1"
            local step="$2"
            jq --arg phase "$phase" --arg step "$step" \
                '.phases[$phase].steps += [$step]' \
                "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;

        step-failed)
            local phase="$1"
            local step="$2"
            local error="$3"
            jq --arg phase "$phase" --arg step "$step" --arg err "$error" \
                '.status = "failed" | .phases[$phase].status = "failed" | .errors += [{step: $step, error: $err}]' \
                "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;

        phase-complete)
            local phase="$1"
            jq --arg phase "$phase" \
                '.phases[$phase].status = "completed"' \
                "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;

        workflow-complete)
            jq '.status = "completed" | .completed_at = (now | todate)' \
                "$STATE_FILE" > "${STATE_FILE}.tmp"
            mv "${STATE_FILE}.tmp" "$STATE_FILE"
            ;;
    esac
}

# Verify step completion (check external evidence)
verify_step() {
    local step_id="$1"
    local phase="$2"

    case "$step_id" in
        core-create-pr)
            # Verify PR actually exists on GitHub
            local branch=$(jq -r '.artifacts.branch_name // empty' "$STATE_FILE")
            if [[ -n "$branch" ]]; then
                local pr_number=$(gh pr list --head "$branch" --json number --jq '.[0].number' 2>/dev/null || echo "")
                if [[ -z "$pr_number" ]]; then
                    log ERROR "Verification failed: No PR found for branch $branch"
                    return 1
                fi
                log OK "Verified: PR #$pr_number exists for branch $branch"
                # Store PR number in state
                jq --arg pr "$pr_number" '.artifacts.pr_number = $pr' "$STATE_FILE" > "${STATE_FILE}.tmp"
                mv "${STATE_FILE}.tmp" "$STATE_FILE"
            fi
            ;;

        core-commit-and-push*)
            # Verify commits exist on remote
            local branch=$(git rev-parse --abbrev-ref HEAD 2>/dev/null || echo "")
            if [[ -n "$branch" && "$branch" != "HEAD" ]]; then
                git fetch origin "$branch" 2>/dev/null || true
                local local_sha=$(git rev-parse HEAD 2>/dev/null || echo "")
                local remote_sha=$(git rev-parse "origin/$branch" 2>/dev/null || echo "")
                if [[ "$local_sha" != "$remote_sha" ]]; then
                    log WARN "Local and remote may be out of sync (local: ${local_sha:0:7}, remote: ${remote_sha:0:7})"
                fi
            fi
            ;;

        core-merge-pr)
            # Verify PR was merged
            local pr_number=$(jq -r '.artifacts.pr_number // empty' "$STATE_FILE")
            if [[ -n "$pr_number" ]]; then
                local pr_state=$(gh pr view "$pr_number" --json state --jq '.state' 2>/dev/null || echo "")
                if [[ "$pr_state" != "MERGED" ]]; then
                    log ERROR "Verification failed: PR #$pr_number is not merged (state: $pr_state)"
                    return 1
                fi
                log OK "Verified: PR #$pr_number is merged"
            fi
            ;;

        *)
            # No specific verification for this step
            if [[ "$VERBOSE" == "true" ]]; then
                log INFO "No external verification defined for step: $step_id"
            fi
            ;;
    esac

    return 0
}

# Initialize Claude session
init_claude_session() {
    local plan_context="$1"

    # Log to stderr to avoid capturing in session_id variable
    echo -e "${BLUE}ℹ${NC} Initializing Claude session..." >&2

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "DRY_RUN_SESSION_ID"
        return 0
    fi

    # Extract workflow context safely (handle special characters in issue titles)
    local workflow_context
    workflow_context=$(echo "$plan_context" | jq -c '{
        plan_id: .id,
        work_id: .source.work_id,
        issue: .items[0].issue,
        workflow_id: .workflow.id
    }' 2>/dev/null || echo '{"error": "failed to parse plan context"}')

    local init_prompt="You are executing a FABER workflow using the deterministic executor.

IMPORTANT RULES:
1. I will send you steps ONE AT A TIME
2. For each step, execute ONLY that step using appropriate tools
3. After completing a step, return a JSON result: {\"status\": \"success|failure\", \"message\": \"...\", \"artifacts\": {...}}
4. Do NOT proceed to the next step on your own - wait for me to send it
5. You have full access to tools: Bash, Read, Write, Edit, Glob, Grep, Task, Skill, SlashCommand

WORKFLOW CONTEXT:
$workflow_context

Acknowledge that you understand and are ready to receive steps."

    # Use --dangerously-skip-permissions for non-interactive execution
    # This is necessary because sub-Claude instances can't get interactive approval
    local result=$(claude -p "$init_prompt" --output-format json --dangerously-skip-permissions </dev/null 2>/dev/null || echo '{"error": "failed"}')

    local session_id=$(echo "$result" | jq -r '.session_id // empty')

    if [[ -z "$session_id" ]]; then
        log ERROR "Failed to initialize Claude session"
        echo "$result" >> "$LOG_FILE"
        exit 1
    fi

    echo "$session_id"
}

# Execute a single step via Claude
execute_step_via_claude() {
    local session_id="$1"
    local phase="$2"
    local step_id="$3"
    local step_name="$4"
    local step_command="$5"
    local step_args="$6"

    if [[ "$DRY_RUN" == "true" ]]; then
        # Log to stderr so it doesn't mix with JSON output
        echo "[DRY RUN] Would execute: $step_command" >&2
        echo '{"status": "success", "message": "dry run", "artifacts": {}}'
        return 0
    fi

    local step_prompt="EXECUTE THIS STEP NOW:

Phase: $phase
Step ID: $step_id
Step Name: $step_name
Command: $step_command
Arguments: $step_args

Instructions:
1. Execute the command using the appropriate tool (SlashCommand for /fractary-* commands, or Skill tool)
2. If the command fails, report the failure
3. When done, return JSON:
   {\"status\": \"success|failure\", \"message\": \"summary of what was done\", \"artifacts\": {\"key\": \"value\"}}

Execute now:"

    # Note: Redirect stdin from /dev/null to prevent claude from consuming
    # the while loop's stdin (from STEPS_FILE)
    # Use --dangerously-skip-permissions for non-interactive execution
    local result=$(claude --resume "$session_id" -p "$step_prompt" --output-format json --dangerously-skip-permissions </dev/null 2>/dev/null || echo '{"error": "claude invocation failed"}')

    # Extract Claude's response text (which should contain our JSON)
    local claude_response=$(echo "$result" | jq -r '.result // empty')

    # Try to extract JSON from the response
    # Claude might wrap it in markdown code blocks or include extra text
    local step_result=""

    # First, try to parse the whole response as JSON
    if echo "$claude_response" | jq -e . >/dev/null 2>&1; then
        step_result="$claude_response"
    else
        # Try to extract JSON from markdown code blocks (```json ... ```)
        # Use sed to extract content between ```json and ```
        local extracted=$(echo "$claude_response" | sed -n '/```json/,/```/p' | sed '1d;$d' | tr -d '\n')
        if [[ -n "$extracted" ]] && echo "$extracted" | jq -e . >/dev/null 2>&1; then
            step_result="$extracted"
        else
            # Try to find any JSON object with "status" field using Python for proper parsing
            step_result=$(echo "$claude_response" | python3 -c '
import sys, re, json
text = sys.stdin.read()
# Find JSON objects in the text
pattern = r"\{[^{}]*(?:\{[^{}]*\}[^{}]*)*\}"
matches = re.findall(pattern, text)
for m in matches:
    try:
        obj = json.loads(m)
        if "status" in obj:
            print(json.dumps(obj))
            sys.exit(0)
    except:
        pass
' 2>/dev/null || echo "")
        fi
    fi

    if [[ -z "$step_result" ]]; then
        # If we can't parse JSON, create a failure response
        step_result='{"status": "unknown", "message": "Could not parse step result", "raw_response": "'"$(echo "$claude_response" | head -c 500 | tr -d '\n' | sed 's/"/\\"/g')"'"}'
    fi

    echo "$step_result"
}

# Execute all steps via Claude with serialized input (single message)
# This reduces API calls by sending all steps at once
execute_steps_serialized() {
    local session_id="$1"
    local steps_file="$2"
    local start_index="$3"

    if [[ "$DRY_RUN" == "true" ]]; then
        echo "[DRY RUN] Would execute all steps in serialized mode" >&2
        # Return success for each step
        local idx=0
        while IFS= read -r step_json; do
            if [[ $idx -ge $start_index ]]; then
                local step_id=$(echo "$step_json" | jq -r '.step.id')
                echo "{\"step_id\": \"$step_id\", \"status\": \"success\", \"message\": \"dry run\", \"artifacts\": {}}"
            fi
            ((idx++))
        done < "$steps_file"
        return 0
    fi

    # Build serialized steps JSON array
    local steps_array="["
    local first=true
    local idx=0
    while IFS= read -r step_json; do
        if [[ $idx -ge $start_index ]]; then
            if [[ "$first" == "true" ]]; then
                first=false
            else
                steps_array+=","
            fi
            # Add step with phase info and prompt
            local phase=$(echo "$step_json" | jq -r '.phase')
            local step=$(echo "$step_json" | jq -c '.step')
            local step_with_prompt=$(echo "$step" | jq -c --arg phase "$phase" '. + {phase: $phase, prompt: ("Execute step: " + .name + " (" + .id + ")")}')
            steps_array+="$step_with_prompt"
        fi
        ((idx++))
    done < "$steps_file"
    steps_array+="]"

    # Create the serialized input prompt
    local serialized_prompt="EXECUTE WORKFLOW STEPS (Serialized Input Mode)

You have been given ALL workflow steps in a single message. Execute them ONE BY ONE in order.

STEPS TO EXECUTE:
$steps_array

CRITICAL INSTRUCTIONS:
1. Execute steps IN ORDER - do not skip any step
2. After EACH step, output a JSON result line:
   {\"step_id\": \"...\", \"status\": \"success|failure\", \"message\": \"...\", \"artifacts\": {...}}
3. If a step fails, STOP and report the failure
4. Use appropriate tools for each step (SlashCommand for /fractary-* commands, Skill tool for skills)
5. Each step result MUST be on its own line for parsing

BEGIN EXECUTION:"

    # Execute with Claude (redirect stdin to prevent consuming loop's input)
    # Use --dangerously-skip-permissions for non-interactive execution
    local result=$(claude --resume "$session_id" -p "$serialized_prompt" --output-format json --dangerously-skip-permissions </dev/null 2>/dev/null || echo '{"error": "claude invocation failed"}')

    # Extract Claude's response
    local claude_response=$(echo "$result" | jq -r '.result // empty')

    # Return the full response - caller will parse step results
    echo "$claude_response"
}

# Extract steps from plan into a flat array
extract_steps() {
    local plan_file="$1"

    # Extract all steps from all phases in order
    # Note: Using '// true' to default enabled to true, then checking for true
    jq -c '
        .workflow.phases | to_entries |
        map(select((.value.enabled // true) == true)) |
        map({phase: .key, steps: .value.steps}) |
        map(.steps[] as $step | {phase: .phase, step: $step}) |
        .[]
    ' "$plan_file"
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

echo ""
echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     FABER Deterministic Executor (Prototype)                 ║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""

log INFO "Plan file: $PLAN_FILE"
log INFO "Run ID: $RUN_ID"
log INFO "Resume from step: $RESUME_FROM"

# Load plan
PLAN_CONTENT=$(cat "$PLAN_FILE")
PLAN_ID=$(echo "$PLAN_CONTENT" | jq -r '.id')
WORK_ID=$(echo "$PLAN_CONTENT" | jq -r '.source.work_id // .items[0].work_id // "unknown"')

log INFO "Plan ID: $PLAN_ID"
log INFO "Work ID: #$WORK_ID"

# Initialize state
update_state init

# Initialize or resume Claude session
if [[ -n "$SESSION_ID" ]]; then
    log INFO "Resuming Claude session: $SESSION_ID"
else
    SESSION_ID=$(init_claude_session "$PLAN_CONTENT")
    log OK "Claude session initialized: $SESSION_ID"
    update_state set-session "$SESSION_ID"
fi

# Emit workflow start event
emit_event "workflow_start" "" "" "Starting FABER workflow (deterministic executor)"

# Extract all steps to a temp file to avoid subshell issues with while loop
STEPS_FILE=$(mktemp)
trap "rm -f $STEPS_FILE" EXIT
extract_steps "$PLAN_FILE" > "$STEPS_FILE"
TOTAL_STEPS=$(wc -l < "$STEPS_FILE")

log INFO "Total steps to execute: $TOTAL_STEPS"

# ============================================================================
# EXECUTION MODE SELECTION
# ============================================================================

if [[ "$SERIALIZED_INPUT" == "true" ]]; then
    # ========================================================================
    # SERIALIZED INPUT MODE
    # ========================================================================
    # All steps sent in a single message to Claude
    # Reduces API calls but relies on Claude to execute sequentially

    log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log INFO "MODE: Serialized Input (single message)"
    log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    # Execute all steps via single Claude call
    log INFO "Sending all steps to Claude in single message..."
    serialized_response=$(execute_steps_serialized "$SESSION_ID" "$STEPS_FILE" "$RESUME_FROM")

    # Parse the response line by line for step results
    # Each line should be a JSON object with step_id and status
    STEP_INDEX=$RESUME_FROM
    CURRENT_PHASE=""

    while IFS= read -r step_json; do
        if [[ $STEP_INDEX -lt $RESUME_FROM ]]; then
            ((STEP_INDEX++))
            continue
        fi

        phase=$(echo "$step_json" | jq -r '.phase')
        step_id=$(echo "$step_json" | jq -r '.step.id')
        step_name=$(echo "$step_json" | jq -r '.step.name')

        # Phase transition handling
        if [[ "$phase" != "$CURRENT_PHASE" ]]; then
            if [[ -n "$CURRENT_PHASE" ]]; then
                emit_event "phase_complete" "$CURRENT_PHASE" "" "Completed $CURRENT_PHASE phase"
                update_state phase-complete "$CURRENT_PHASE"
            fi
            CURRENT_PHASE="$phase"
            emit_event "phase_start" "$phase" "" "Starting $phase phase"
        fi

        # Emit events and update state (deterministic)
        emit_event "step_start" "$phase" "$step_id" "Starting step: $step_name"
        update_state step-start "$phase" "$step_id" "$STEP_INDEX"

        # Try to extract result for this step from serialized response
        step_result=$(echo "$serialized_response" | grep -o "{[^}]*\"step_id\"[[:space:]]*:[[:space:]]*\"$step_id\"[^}]*}" | head -1 || echo "")

        if [[ -z "$step_result" ]]; then
            # No result found for this step - might have failed before reaching it
            log WARN "No result found for step: $step_id"
            step_status="unknown"
            step_message="No result found in serialized response"
        else
            step_status=$(echo "$step_result" | jq -r '.status // "unknown"')
            step_message=$(echo "$step_result" | jq -r '.message // "no message"')
        fi

        log INFO "Step $step_id: status=$step_status"

        if [[ "$step_status" != "success" ]]; then
            log ERROR "Step failed: $step_id - $step_message"
            update_state step-failed "$phase" "$step_id" "$step_message"
            emit_event "step_failed" "$phase" "$step_id" "Step failed: $step_message"

            echo ""
            echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
            echo -e "${RED}  WORKFLOW HALTED (Serialized Mode)${NC}"
            echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
            echo ""
            echo "Failed at step: $step_id ($step_name)"
            echo "Error: $step_message"
            echo ""
            echo "To resume from this step (standard mode recommended):"
            echo "  $0 --plan $PLAN_FILE --run-id $RUN_ID --resume-from $STEP_INDEX --session-id $SESSION_ID"
            echo ""
            exit 1
        fi

        update_state step-complete "$phase" "$step_id"
        emit_event "step_complete" "$phase" "$step_id" "Completed step: $step_name"
        log OK "Step completed: $step_id"

        ((STEP_INDEX++))
    done < "$STEPS_FILE"

else
    # ========================================================================
    # STANDARD MODE (One message per step)
    # ========================================================================
    # Each step is sent to Claude individually via --resume
    # More API calls but guarantees step-by-step execution

# Execute steps
STEP_INDEX=0
CURRENT_PHASE=""

while IFS= read -r step_json; do
    # Skip if resuming from a later step
    if [[ $STEP_INDEX -lt $RESUME_FROM ]]; then
        log INFO "Skipping step $STEP_INDEX (resuming from $RESUME_FROM)"
        ((STEP_INDEX++))
        continue
    fi

    # Extract step details
    phase=$(echo "$step_json" | jq -r '.phase')
    step_id=$(echo "$step_json" | jq -r '.step.id')
    step_name=$(echo "$step_json" | jq -r '.step.name')
    step_command=$(echo "$step_json" | jq -r '.step.command // empty')
    step_args=$(echo "$step_json" | jq -c '.step.arguments // {}')

    # Phase transition
    if [[ "$phase" != "$CURRENT_PHASE" ]]; then
        if [[ -n "$CURRENT_PHASE" ]]; then
            emit_event "phase_complete" "$CURRENT_PHASE" "" "Completed $CURRENT_PHASE phase"
            update_state phase-complete "$CURRENT_PHASE"
        fi
        CURRENT_PHASE="$phase"
        emit_event "phase_start" "$phase" "" "Starting $phase phase"
        log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
        log INFO "PHASE: $phase"
        log INFO "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    fi

    echo ""
    log STEP "Step $((STEP_INDEX + 1))/$TOTAL_STEPS: $step_name ($step_id)"

    # DETERMINISTIC: Emit step_start
    emit_event "step_start" "$phase" "$step_id" "Starting step: $step_name"

    # DETERMINISTIC: Update state to in_progress
    update_state step-start "$phase" "$step_id" "$STEP_INDEX"

    # CLAUDE: Execute the step
    log INFO "Invoking Claude to execute step..."
    step_result=$(execute_step_via_claude "$SESSION_ID" "$phase" "$step_id" "$step_name" "$step_command" "$step_args")

    # Parse result
    step_status=$(echo "$step_result" | jq -r '.status // "unknown"')
    step_message=$(echo "$step_result" | jq -r '.message // "no message"')

    log INFO "Claude returned: status=$step_status"

    # DETERMINISTIC: Verify step completion (external evidence)
    if [[ "$step_status" == "success" ]]; then
        # verify_step returns: 0=pass, 1=fail, 2=no verification needed
        verify_exit_code=0
        verify_step "$step_id" "$phase" || verify_exit_code=$?
        if [[ $verify_exit_code -eq 1 ]]; then
            step_status="failure"
            step_message="External verification failed"
        fi
        # exit code 2 means no verification defined - that's OK
    fi

    # Handle result
    if [[ "$step_status" != "success" ]]; then
        log ERROR "Step failed: $step_id - $step_message"

        # DETERMINISTIC: Update state to failed
        update_state step-failed "$phase" "$step_id" "$step_message"

        # DETERMINISTIC: Emit step_failed
        emit_event "step_failed" "$phase" "$step_id" "Step failed: $step_message"

        echo ""
        echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
        echo -e "${RED}  WORKFLOW HALTED${NC}"
        echo -e "${RED}═══════════════════════════════════════════════════════════${NC}"
        echo ""
        echo "Failed at step: $step_id ($step_name)"
        echo "Error: $step_message"
        echo ""
        echo "To resume from this step:"
        echo "  $0 --plan $PLAN_FILE --run-id $RUN_ID --resume-from $STEP_INDEX --session-id $SESSION_ID"
        echo ""
        exit 1
    fi

    # DETERMINISTIC: Update state to completed
    update_state step-complete "$phase" "$step_id"

    # DETERMINISTIC: Emit step_complete
    emit_event "step_complete" "$phase" "$step_id" "Completed step: $step_name"

    log OK "Step completed: $step_id"

    ((STEP_INDEX++))
done < "$STEPS_FILE"

fi  # End of execution mode selection (standard vs serialized)

# Complete final phase
if [[ -n "$CURRENT_PHASE" ]]; then
    emit_event "phase_complete" "$CURRENT_PHASE" "" "Completed $CURRENT_PHASE phase"
    update_state phase-complete "$CURRENT_PHASE"
fi

# DETERMINISTIC: Mark workflow complete
update_state workflow-complete
emit_event "workflow_complete" "" "" "FABER workflow completed successfully"

echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     WORKFLOW COMPLETE                                        ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
echo ""
log OK "All $TOTAL_STEPS steps completed successfully"
log INFO "Run ID: $RUN_ID"
log INFO "Session ID: $SESSION_ID"
log INFO "State file: $STATE_FILE"
log INFO "Events: $EVENTS_DIR"
echo ""
