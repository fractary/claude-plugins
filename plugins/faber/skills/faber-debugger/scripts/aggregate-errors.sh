#!/usr/bin/env bash
#
# aggregate-errors.sh - Aggregate errors and warnings from workflow execution
#
# Usage:
#   aggregate-errors.sh --run-id <run-id>
#
# Description:
#   Parses the workflow state and event log to extract all errors and warnings
#   from step executions. Groups and deduplicates for analysis.
#
# Output: JSON object with aggregated errors, warnings, and analysis metadata
#
# Security:
#   - Run ID is validated to prevent path traversal
#   - All file operations use validated paths

set -euo pipefail

# Path resolution
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FABER_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
CORE_SCRIPTS="$FABER_ROOT/skills/core/scripts"

# =============================================================================
# Input Validation Functions
# =============================================================================

# Validate run ID format (prevent path traversal and shell injection)
# Format: org/repo/runid or just runid
validate_run_id() {
    local id="$1"

    # Check for path traversal attempts
    if [[ "$id" =~ \.\. ]]; then
        echo '{"status": "error", "message": "Invalid run-id: path traversal not allowed"}' >&2
        exit 1
    fi

    # Only allow safe characters: alphanumeric, forward slash, hyphen, underscore
    if [[ ! "$id" =~ ^[a-zA-Z0-9/_-]+$ ]]; then
        echo '{"status": "error", "message": "Invalid run-id: contains invalid characters"}' >&2
        exit 1
    fi

    # Length limit
    if [[ ${#id} -gt 256 ]]; then
        echo '{"status": "error", "message": "Invalid run-id: too long (max 256 chars)"}' >&2
        exit 1
    fi
}

# Parse arguments
RUN_ID=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --run-id)
            RUN_ID="${2:?Run ID required}"
            shift 2
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

if [ -z "$RUN_ID" ]; then
    echo "Error: --run-id is required" >&2
    exit 1
fi

# Validate run ID before using in file paths
validate_run_id "$RUN_ID"

# Paths
RUN_DIR=".fractary/plugins/faber/runs/$RUN_ID"
STATE_FILE="$RUN_DIR/state.json"
EVENTS_FILE="$RUN_DIR/events.jsonl"

# Check if state file exists
if [ ! -f "$STATE_FILE" ]; then
    echo '{"error": "State file not found", "errors": [], "warnings": [], "summary": {"total_errors": 0, "total_warnings": 0}}'
    exit 0
fi

# Initialize arrays
errors_json="[]"
warnings_json="[]"
analyses_json="[]"

# Read state and extract step responses
state_content=$(cat "$STATE_FILE")

# Process each phase
phases=$(echo "$state_content" | jq -r '.phases | keys[]' 2>/dev/null || echo "")

for phase in $phases; do
    # Get steps for this phase
    steps=$(echo "$state_content" | jq -r ".phases.\"$phase\".steps // []" 2>/dev/null)
    step_count=$(echo "$steps" | jq 'length')

    for i in $(seq 0 $((step_count - 1))); do
        step=$(echo "$steps" | jq ".[$i]")
        step_id=$(echo "$step" | jq -r '.id // .name // "unknown"')
        step_status=$(echo "$step" | jq -r '.status // "unknown"')

        # Extract errors from step response
        step_errors=$(echo "$step" | jq -r '.response.errors // []' 2>/dev/null || echo "[]")
        if [ "$step_errors" != "[]" ] && [ "$step_errors" != "null" ]; then
            # Add phase/step context to each error
            error_count=$(echo "$step_errors" | jq 'length')
            for j in $(seq 0 $((error_count - 1))); do
                error_msg=$(echo "$step_errors" | jq -r ".[$j]")
                timestamp=$(echo "$step" | jq -r '.completed_at // .started_at // ""')

                # Try to extract location from error message
                location=""
                if echo "$error_msg" | grep -qE '[a-zA-Z0-9_/.-]+:[0-9]+'; then
                    location=$(echo "$error_msg" | grep -oE '[a-zA-Z0-9_/.-]+:[0-9]+' | head -1)
                fi

                error_obj=$(jq -n \
                    --arg phase "$phase" \
                    --arg step "$step_id" \
                    --arg message "$error_msg" \
                    --arg location "$location" \
                    --arg timestamp "$timestamp" \
                    '{
                        phase: $phase,
                        step: $step,
                        message: $message,
                        location: $location,
                        timestamp: $timestamp
                    }')

                errors_json=$(echo "$errors_json" | jq ". + [$error_obj]")
            done
        fi

        # Extract warnings from step response
        step_warnings=$(echo "$step" | jq -r '.response.warnings // []' 2>/dev/null || echo "[]")
        if [ "$step_warnings" != "[]" ] && [ "$step_warnings" != "null" ]; then
            warning_count=$(echo "$step_warnings" | jq 'length')
            for j in $(seq 0 $((warning_count - 1))); do
                warning_msg=$(echo "$step_warnings" | jq -r ".[$j]")
                timestamp=$(echo "$step" | jq -r '.completed_at // .started_at // ""')

                warning_obj=$(jq -n \
                    --arg phase "$phase" \
                    --arg step "$step_id" \
                    --arg message "$warning_msg" \
                    --arg timestamp "$timestamp" \
                    '{
                        phase: $phase,
                        step: $step,
                        message: $message,
                        timestamp: $timestamp
                    }')

                warnings_json=$(echo "$warnings_json" | jq ". + [$warning_obj]")
            done
        fi

        # Extract error analysis from step response
        error_analysis=$(echo "$step" | jq -r '.response.error_analysis // ""' 2>/dev/null)
        if [ -n "$error_analysis" ] && [ "$error_analysis" != "null" ]; then
            analysis_obj=$(jq -n \
                --arg phase "$phase" \
                --arg step "$step_id" \
                --arg analysis "$error_analysis" \
                '{
                    phase: $phase,
                    step: $step,
                    analysis: $analysis
                }')

            analyses_json=$(echo "$analyses_json" | jq ". + [$analysis_obj]")
        fi
    done
done

# Also check events file for error events
if [ -f "$EVENTS_FILE" ]; then
    while IFS= read -r event; do
        event_type=$(echo "$event" | jq -r '.type // ""')

        if [ "$event_type" = "step_error" ] || [ "$event_type" = "phase_error" ]; then
            phase=$(echo "$event" | jq -r '.phase // "unknown"')
            step=$(echo "$event" | jq -r '.step // "unknown"')
            error_msg=$(echo "$event" | jq -r '.data.error // .data.message // ""')
            timestamp=$(echo "$event" | jq -r '.timestamp // ""')

            if [ -n "$error_msg" ]; then
                # Check if we already have this error (avoid duplicates)
                exists=$(echo "$errors_json" | jq --arg msg "$error_msg" 'any(.[]; .message == $msg)')
                if [ "$exists" = "false" ]; then
                    error_obj=$(jq -n \
                        --arg phase "$phase" \
                        --arg step "$step" \
                        --arg message "$error_msg" \
                        --arg location "" \
                        --arg timestamp "$timestamp" \
                        '{
                            phase: $phase,
                            step: $step,
                            message: $message,
                            location: $location,
                            timestamp: $timestamp,
                            source: "event"
                        }')

                    errors_json=$(echo "$errors_json" | jq ". + [$error_obj]")
                fi
            fi
        fi
    done < "$EVENTS_FILE"
fi

# Calculate summary statistics
total_errors=$(echo "$errors_json" | jq 'length')
total_warnings=$(echo "$warnings_json" | jq 'length')

# Get unique affected phases and steps
affected_phases=$(echo "$errors_json" | jq '[.[].phase] | unique')
affected_steps=$(echo "$errors_json" | jq '[.[].step] | unique')

# Group errors by pattern (for identifying common issues)
# Simple grouping by first few words of the message
group_by_pattern() {
    local items="$1"
    echo "$items" | jq '
        group_by(.message | split(" ")[0:3] | join(" "))
        | map({
            pattern: .[0].message | split(" ")[0:3] | join(" "),
            count: length,
            examples: [.[0:3][].message]
        })
        | sort_by(.count) | reverse
    '
}

error_patterns=$(group_by_pattern "$errors_json")

# Build final output
jq -n \
    --argjson errors "$errors_json" \
    --argjson warnings "$warnings_json" \
    --argjson error_analyses "$analyses_json" \
    --argjson error_patterns "$error_patterns" \
    --argjson affected_phases "$affected_phases" \
    --argjson affected_steps "$affected_steps" \
    --argjson total_errors "$total_errors" \
    --argjson total_warnings "$total_warnings" \
    '{
        errors: $errors,
        warnings: $warnings,
        error_analyses: $error_analyses,
        error_patterns: $error_patterns,
        summary: {
            total_errors: $total_errors,
            total_warnings: $total_warnings,
            affected_phases: $affected_phases,
            affected_steps: $affected_steps
        }
    }'
