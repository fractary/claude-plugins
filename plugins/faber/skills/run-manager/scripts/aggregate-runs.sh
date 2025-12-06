#!/usr/bin/env bash
#
# aggregate-runs.sh - Aggregate status of multiple FABER runs
#
# Usage:
#   aggregate-runs.sh --run-ids <id1,id2,id3> [--format <json|markdown>]
#
# Output: Aggregated status of all runs
#
# Exit Codes:
#   0 - Success
#   1 - Validation or input error

set -euo pipefail

# Parse arguments
RUN_IDS=""
OUTPUT_FORMAT="json"
BASE_PATH=".fractary/plugins/faber/runs"

print_usage() {
    cat <<EOF
Usage: aggregate-runs.sh --run-ids <id1,id2,id3> [options]

Aggregates the status of multiple FABER runs for parallel coordination.

Required:
  --run-ids <ids>         Comma-separated list of run IDs

Optional:
  --format <format>       Output format: json (default) or markdown
  --base-path <path>      Base path for runs (default: .fractary/plugins/faber/runs)

Output:
  Aggregated status including:
  - Summary counts by status
  - Details for each run
  - Pending feedback requests

Exit Codes:
  0 - Success
  1 - Validation or input error
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        --run-ids)
            RUN_IDS="$2"
            shift 2
            ;;
        --format)
            OUTPUT_FORMAT="$2"
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
if [[ -z "$RUN_IDS" ]]; then
    echo '{"status": "error", "error": {"code": "MISSING_RUN_IDS", "message": "--run-ids is required"}}' >&2
    exit 1
fi

# Validate format
if [[ "$OUTPUT_FORMAT" != "json" && "$OUTPUT_FORMAT" != "markdown" ]]; then
    echo '{"status": "error", "error": {"code": "INVALID_FORMAT", "message": "format must be json or markdown"}}' >&2
    exit 1
fi

# Split run IDs into array
IFS=',' read -ra RUN_ID_ARRAY <<< "$RUN_IDS"

# Initialize counters
TOTAL=0
COMPLETED=0
AWAITING_FEEDBACK=0
IN_PROGRESS=0
ERROR_COUNT=0
CANCELLED=0
UNKNOWN=0

# Build runs array
RUNS_JSON="[]"
FEEDBACK_REQUESTS="[]"

for run_id in "${RUN_ID_ARRAY[@]}"; do
    TOTAL=$((TOTAL + 1))

    # Trim whitespace
    run_id=$(echo "$run_id" | xargs)

    STATE_FILE="${BASE_PATH}/${run_id}/state.json"
    METADATA_FILE="${BASE_PATH}/${run_id}/metadata.json"

    if [[ ! -f "$STATE_FILE" ]]; then
        UNKNOWN=$((UNKNOWN + 1))
        RUNS_JSON=$(echo "$RUNS_JSON" | jq \
            --arg run_id "$run_id" \
            '. + [{
                run_id: $run_id,
                status: "unknown",
                error: "State file not found"
            }]')
        continue
    fi

    # Read state
    STATE=$(cat "$STATE_FILE")
    STATUS=$(echo "$STATE" | jq -r '.status // "unknown"')
    WORK_ID=$(echo "$STATE" | jq -r '.work_id // ""')
    PHASE=$(echo "$STATE" | jq -r '.current_phase // ""')
    STEP=$(echo "$STATE" | jq -r '.current_step // ""')

    # Count by status
    case "$STATUS" in
        completed)
            COMPLETED=$((COMPLETED + 1))
            ;;
        awaiting_feedback)
            AWAITING_FEEDBACK=$((AWAITING_FEEDBACK + 1))
            # Extract feedback request
            FEEDBACK_REQUEST=$(echo "$STATE" | jq '.feedback_request // null')
            if [[ "$FEEDBACK_REQUEST" != "null" ]]; then
                FEEDBACK_REQUESTS=$(echo "$FEEDBACK_REQUESTS" | jq \
                    --arg run_id "$run_id" \
                    --arg work_id "$WORK_ID" \
                    --argjson request "$FEEDBACK_REQUEST" \
                    '. + [{
                        run_id: $run_id,
                        work_id: $work_id,
                        request: $request
                    }]')
            fi
            ;;
        in_progress)
            IN_PROGRESS=$((IN_PROGRESS + 1))
            ;;
        failed|error)
            ERROR_COUNT=$((ERROR_COUNT + 1))
            ;;
        cancelled)
            CANCELLED=$((CANCELLED + 1))
            ;;
        *)
            UNKNOWN=$((UNKNOWN + 1))
            ;;
    esac

    # Build run entry
    RUN_ENTRY=$(echo "$STATE" | jq \
        --arg run_id "$run_id" \
        '{
            run_id: $run_id,
            work_id: .work_id,
            status: .status,
            current_phase: .current_phase,
            current_step: .current_step,
            feedback_request: .feedback_request,
            artifacts: .artifacts
        }')

    RUNS_JSON=$(echo "$RUNS_JSON" | jq --argjson run "$RUN_ENTRY" '. + [$run]')
done

# Generate timestamp
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

if [[ "$OUTPUT_FORMAT" == "json" ]]; then
    # JSON output
    jq -n \
        --arg timestamp "$TIMESTAMP" \
        --argjson total "$TOTAL" \
        --argjson completed "$COMPLETED" \
        --argjson awaiting_feedback "$AWAITING_FEEDBACK" \
        --argjson in_progress "$IN_PROGRESS" \
        --argjson error "$ERROR_COUNT" \
        --argjson cancelled "$CANCELLED" \
        --argjson unknown "$UNKNOWN" \
        --argjson runs "$RUNS_JSON" \
        --argjson feedback_requests "$FEEDBACK_REQUESTS" \
        '{
            status: "success",
            aggregated_at: $timestamp,
            summary: {
                total: $total,
                completed: $completed,
                awaiting_feedback: $awaiting_feedback,
                in_progress: $in_progress,
                error: $error,
                cancelled: $cancelled,
                unknown: $unknown
            },
            all_stopped: ($in_progress == 0),
            needs_feedback: ($awaiting_feedback > 0 or $error > 0),
            runs: $runs,
            feedback_requests: $feedback_requests
        }'
else
    # Markdown output
    echo "## Parallel Workflow Status"
    echo ""
    echo "**Aggregated at**: ${TIMESTAMP}"
    echo ""
    echo "${TOTAL} workflow runs:"
    [[ $COMPLETED -gt 0 ]] && echo "- **${COMPLETED}** completed successfully"
    [[ $AWAITING_FEEDBACK -gt 0 ]] && echo "- **${AWAITING_FEEDBACK}** awaiting feedback"
    [[ $IN_PROGRESS -gt 0 ]] && echo "- **${IN_PROGRESS}** still running"
    [[ $ERROR_COUNT -gt 0 ]] && echo "- **${ERROR_COUNT}** failed with errors"
    [[ $CANCELLED -gt 0 ]] && echo "- **${CANCELLED}** cancelled"
    [[ $UNKNOWN -gt 0 ]] && echo "- **${UNKNOWN}** unknown/not found"
    echo ""

    # Completed runs
    COMPLETED_RUNS=$(echo "$RUNS_JSON" | jq -r '.[] | select(.status == "completed")')
    if [[ -n "$COMPLETED_RUNS" && "$COMPLETED_RUNS" != "null" ]]; then
        echo "### Completed Runs"
        echo ""
        echo "| Work ID | Phase | Artifacts |"
        echo "|---------|-------|-----------|"
        echo "$RUNS_JSON" | jq -r '.[] | select(.status == "completed") | "| #\(.work_id // "N/A") | \(.current_phase // "done") | \(.artifacts.pr_url // "—") |"'
        echo ""
    fi

    # Awaiting feedback
    if [[ $AWAITING_FEEDBACK -gt 0 ]]; then
        echo "### Feedback Needed"
        echo ""
        echo "$FEEDBACK_REQUESTS" | jq -r '.[] | "**Run #\(.work_id)** (\(.run_id)):\n- Type: \(.request.type)\n- Phase: \(.request.phase // "unknown") → \(.request.step // "unknown")\n- Question: \(.request.prompt)\n- Options: \(.request.options | join(", "))\n"'
    fi

    # Errors
    ERROR_RUNS=$(echo "$RUNS_JSON" | jq -r '.[] | select(.status == "failed" or .status == "error")')
    if [[ -n "$ERROR_RUNS" && "$ERROR_RUNS" != "null" ]]; then
        echo "### Failed Runs"
        echo ""
        echo "$RUNS_JSON" | jq -r '.[] | select(.status == "failed" or .status == "error") | "**Run #\(.work_id)** (\(.run_id)):\n- Phase: \(.current_phase // "unknown") → \(.current_step // "unknown")\n- Status: \(.status)\n"'
    fi

    # In progress
    if [[ $IN_PROGRESS -gt 0 ]]; then
        echo "### Still Running"
        echo ""
        echo "$RUNS_JSON" | jq -r '.[] | select(.status == "in_progress") | "- **#\(.work_id)**: \(.current_phase // "unknown") → \(.current_step // "unknown")"'
        echo ""
    fi
fi

exit 0
