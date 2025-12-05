#!/bin/bash
# Repo Manager: Poll GitHub CI Workflows Until Complete
# Polls GitHub API for workflow/CI check completion before allowing PR review
#
# Exit codes:
#   0 - All CI checks completed successfully
#   1 - General error
#   2 - Invalid arguments
#   3 - Configuration error (gh CLI missing, not in git repo)
#   4 - CI checks failed
#   5 - Timeout reached (CI still pending after max wait)
#   6 - No CI checks configured (neutral - not a failure)
#  11 - Authentication error

set -euo pipefail

# =============================================================================
# Configuration Defaults
# =============================================================================
DEFAULT_POLL_INTERVAL=60        # seconds between polls
DEFAULT_TIMEOUT=900             # 15 minutes max wait
DEFAULT_INITIAL_DELAY=10        # Wait before first check (CI often not immediately available)

# =============================================================================
# Parse Arguments
# =============================================================================
usage() {
    cat <<EOF
Usage: $0 <pr_number> [options]

Poll GitHub CI workflows until they complete or timeout.

Arguments:
  pr_number           PR number to check

Options:
  --interval SECONDS  Polling interval (default: $DEFAULT_POLL_INTERVAL)
  --timeout SECONDS   Maximum wait time (default: $DEFAULT_TIMEOUT)
  --initial-delay SEC Initial delay before first check (default: $DEFAULT_INITIAL_DELAY)
  --quiet             Suppress progress output (only show final result)
  --json              Output results as JSON

Exit Codes:
  0  - All CI checks passed
  4  - CI checks failed
  5  - Timeout (CI still pending)
  6  - No CI checks configured

Examples:
  $0 456
  $0 456 --interval 30 --timeout 600
  $0 456 --quiet --json
EOF
    exit 2
}

# Defaults
PR_NUMBER=""
POLL_INTERVAL=$DEFAULT_POLL_INTERVAL
TIMEOUT=$DEFAULT_TIMEOUT
INITIAL_DELAY=$DEFAULT_INITIAL_DELAY
QUIET=false
JSON_OUTPUT=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case "$1" in
        --interval)
            POLL_INTERVAL="$2"
            shift 2
            ;;
        --timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        --initial-delay)
            INITIAL_DELAY="$2"
            shift 2
            ;;
        --quiet)
            QUIET=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --help|-h)
            usage
            ;;
        -*)
            echo "Error: Unknown option: $1" >&2
            usage
            ;;
        *)
            if [[ -z "$PR_NUMBER" ]]; then
                PR_NUMBER="$1"
            else
                echo "Error: Unexpected argument: $1" >&2
                usage
            fi
            shift
            ;;
    esac
done

# Validate PR number
if [[ -z "$PR_NUMBER" ]]; then
    echo "Error: PR number is required" >&2
    usage
fi

if ! [[ "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "Error: PR number must be a positive integer" >&2
    exit 2
fi

# =============================================================================
# Environment Checks
# =============================================================================

# Check if gh CLI is available
if ! command -v gh &> /dev/null; then
    echo "Error: gh CLI not found. Install it from https://cli.github.com" >&2
    exit 3
fi

# Check if jq is available
if ! command -v jq &> /dev/null; then
    echo "Error: jq not found. Install it for JSON processing." >&2
    exit 3
fi

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository" >&2
    exit 3
fi

# =============================================================================
# Helper Functions
# =============================================================================

log() {
    if [[ "$QUIET" != "true" ]]; then
        echo "$@"
    fi
}

log_progress() {
    if [[ "$QUIET" != "true" ]]; then
        echo -e "\r$@"
    fi
}

output_json() {
    local status="$1"
    local message="$2"
    local total_checks="${3:-0}"
    local passed="${4:-0}"
    local failed="${5:-0}"
    local pending="${6:-0}"
    local elapsed="${7:-0}"
    local details="${8:-[]}"

    jq -n \
        --arg status "$status" \
        --arg message "$message" \
        --argjson total_checks "$total_checks" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson pending "$pending" \
        --argjson elapsed "$elapsed" \
        --argjson details "$details" \
        '{
            status: $status,
            message: $message,
            pr_number: '"$PR_NUMBER"',
            ci_summary: {
                total_checks: $total_checks,
                passed: $passed,
                failed: $failed,
                pending: $pending
            },
            elapsed_seconds: $elapsed,
            check_details: $details
        }'
}

# =============================================================================
# Main Polling Logic
# =============================================================================

get_ci_status() {
    # Fetch PR status checks using gh CLI
    # Returns JSON with check status

    local pr_data
    pr_data=$(gh pr view "$PR_NUMBER" --json statusCheckRollup,headRefName 2>&1)

    if [[ $? -ne 0 ]]; then
        if echo "$pr_data" | grep -qi "authentication"; then
            echo '{"error": "authentication", "message": "GitHub authentication failed"}'
            return 11
        elif echo "$pr_data" | grep -qi "not found"; then
            echo '{"error": "not_found", "message": "PR not found"}'
            return 1
        else
            echo '{"error": "unknown", "message": "Failed to fetch PR data"}'
            return 1
        fi
    fi

    echo "$pr_data"
    return 0
}

analyze_checks() {
    local pr_data="$1"

    # Extract statusCheckRollup array
    local checks
    checks=$(echo "$pr_data" | jq -r '.statusCheckRollup // []')

    local total=0
    local passed=0
    local failed=0
    local pending=0
    local details="[]"

    # Count statuses
    # GitHub status check states: SUCCESS, FAILURE, PENDING, ERROR, NEUTRAL, etc.
    # Also handle conclusion field for check runs

    total=$(echo "$checks" | jq 'length')

    if [[ "$total" -eq 0 ]]; then
        echo '{"total": 0, "passed": 0, "failed": 0, "pending": 0, "complete": true, "success": true, "no_ci": true, "details": []}'
        return 0
    fi

    # Process each check
    # statusCheckRollup contains both status checks and check runs
    # Check runs have: status (queued, in_progress, completed) and conclusion (success, failure, etc.)
    # Status checks have: state (pending, success, failure, error)

    details=$(echo "$checks" | jq '[.[] | {
        name: (.name // .context // "unknown"),
        status: (.status // .state // "unknown"),
        conclusion: (.conclusion // null),
        is_complete: (
            (.status == "completed" or .status == "COMPLETED") or
            (.state == "success" or .state == "SUCCESS" or .state == "failure" or .state == "FAILURE" or .state == "error" or .state == "ERROR")
        ),
        is_success: (
            (.conclusion == "success" or .conclusion == "SUCCESS" or .conclusion == "neutral" or .conclusion == "NEUTRAL" or .conclusion == "skipped" or .conclusion == "SKIPPED") or
            (.state == "success" or .state == "SUCCESS")
        ),
        is_failure: (
            (.conclusion == "failure" or .conclusion == "FAILURE" or .conclusion == "cancelled" or .conclusion == "CANCELLED" or .conclusion == "timed_out" or .conclusion == "TIMED_OUT" or .conclusion == "action_required" or .conclusion == "ACTION_REQUIRED") or
            (.state == "failure" or .state == "FAILURE" or .state == "error" or .state == "ERROR")
        )
    }]')

    passed=$(echo "$details" | jq '[.[] | select(.is_success == true)] | length')
    failed=$(echo "$details" | jq '[.[] | select(.is_failure == true)] | length')
    pending=$(echo "$details" | jq '[.[] | select(.is_complete == false)] | length')

    local complete="false"
    local success="false"

    if [[ "$pending" -eq 0 ]]; then
        complete="true"
        if [[ "$failed" -eq 0 ]]; then
            success="true"
        fi
    fi

    jq -n \
        --argjson total "$total" \
        --argjson passed "$passed" \
        --argjson failed "$failed" \
        --argjson pending "$pending" \
        --argjson complete "$complete" \
        --argjson success "$success" \
        --argjson details "$details" \
        '{
            total: $total,
            passed: $passed,
            failed: $failed,
            pending: $pending,
            complete: $complete,
            success: $success,
            no_ci: false,
            details: $details
        }'
}

# =============================================================================
# Main Execution
# =============================================================================

log "Polling CI workflows for PR #$PR_NUMBER..."
log "Poll interval: ${POLL_INTERVAL}s, Timeout: ${TIMEOUT}s"
log ""

# Initial delay to allow CI to start
if [[ "$INITIAL_DELAY" -gt 0 ]]; then
    log "Waiting ${INITIAL_DELAY}s for CI to initialize..."
    sleep "$INITIAL_DELAY"
fi

START_TIME=$(date +%s)
POLL_COUNT=0

while true; do
    POLL_COUNT=$((POLL_COUNT + 1))
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))

    # Check timeout
    if [[ "$ELAPSED" -ge "$TIMEOUT" ]]; then
        log ""
        log "Timeout reached after ${ELAPSED}s (${POLL_COUNT} polls)"

        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "timeout" "CI checks still pending after ${TIMEOUT}s timeout" \
                0 0 0 0 "$ELAPSED" "[]"
        fi
        exit 5
    fi

    # Fetch and analyze CI status
    PR_DATA=$(get_ci_status)
    FETCH_EXIT=$?

    if [[ $FETCH_EXIT -ne 0 ]]; then
        if echo "$PR_DATA" | jq -e '.error == "authentication"' > /dev/null 2>&1; then
            log "Error: GitHub authentication failed"
            if [[ "$JSON_OUTPUT" == "true" ]]; then
                output_json "error" "GitHub authentication failed" 0 0 0 0 "$ELAPSED" "[]"
            fi
            exit 11
        else
            log "Error: Failed to fetch PR data"
            if [[ "$JSON_OUTPUT" == "true" ]]; then
                output_json "error" "Failed to fetch PR data" 0 0 0 0 "$ELAPSED" "[]"
            fi
            exit 1
        fi
    fi

    # Analyze check status
    CHECK_STATUS=$(analyze_checks "$PR_DATA")

    TOTAL=$(echo "$CHECK_STATUS" | jq -r '.total')
    PASSED=$(echo "$CHECK_STATUS" | jq -r '.passed')
    FAILED=$(echo "$CHECK_STATUS" | jq -r '.failed')
    PENDING=$(echo "$CHECK_STATUS" | jq -r '.pending')
    COMPLETE=$(echo "$CHECK_STATUS" | jq -r '.complete')
    SUCCESS=$(echo "$CHECK_STATUS" | jq -r '.success')
    NO_CI=$(echo "$CHECK_STATUS" | jq -r '.no_ci')
    DETAILS=$(echo "$CHECK_STATUS" | jq -r '.details')

    # Log progress
    log_progress "[Poll #$POLL_COUNT | ${ELAPSED}s] Checks: $PASSED passed, $FAILED failed, $PENDING pending (total: $TOTAL)"

    # Handle no CI configured
    if [[ "$NO_CI" == "true" ]]; then
        log ""
        log "No CI checks configured for this PR"

        if [[ "$JSON_OUTPUT" == "true" ]]; then
            output_json "no_ci" "No CI checks configured" 0 0 0 0 "$ELAPSED" "[]"
        fi
        exit 6
    fi

    # Check if complete
    if [[ "$COMPLETE" == "true" ]]; then
        log ""

        if [[ "$SUCCESS" == "true" ]]; then
            log "All CI checks passed! ($PASSED/$TOTAL)"

            if [[ "$JSON_OUTPUT" == "true" ]]; then
                output_json "success" "All CI checks passed" "$TOTAL" "$PASSED" "$FAILED" "$PENDING" "$ELAPSED" "$DETAILS"
            fi
            exit 0
        else
            log "CI checks failed! ($FAILED failures)"

            # Show failed checks
            FAILED_NAMES=$(echo "$DETAILS" | jq -r '[.[] | select(.is_failure == true) | .name] | join(", ")')
            log "Failed checks: $FAILED_NAMES"

            if [[ "$JSON_OUTPUT" == "true" ]]; then
                output_json "failed" "CI checks failed: $FAILED_NAMES" "$TOTAL" "$PASSED" "$FAILED" "$PENDING" "$ELAPSED" "$DETAILS"
            fi
            exit 4
        fi
    fi

    # Still pending, wait and poll again
    REMAINING=$((TIMEOUT - ELAPSED))
    log_progress "[Poll #$POLL_COUNT | ${ELAPSED}s] Waiting ${POLL_INTERVAL}s... (${REMAINING}s remaining until timeout)"
    sleep "$POLL_INTERVAL"
done
