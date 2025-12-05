#!/usr/bin/env bash
#
# generate-command.sh - Generate /faber:run continuation command
#
# Usage:
#   generate-command.sh --work-id <id> --phase <phase> --step <step> [options]
#
# Options:
#   --work-id <id>       Work item ID (required)
#   --phase <phase>      Phase to resume from (required)
#   --step <step>        Step to resume from (required)
#   --prompt <text>      Prompt text for the command
#   --workflow <id>      Workflow ID (default: default)
#   --flags <flags>      Additional flags (e.g., --retry)
#   --escape             Escape output for shell usage
#
# Examples:
#   generate-command.sh --work-id 244 --phase build --step implement --prompt "Fix type errors"
#
# Output: The formatted /faber:run command

set -euo pipefail

# Defaults
WORK_ID=""
PHASE=""
STEP=""
PROMPT=""
WORKFLOW="default"
FLAGS=""
ESCAPE=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --work-id)
            WORK_ID="${2:?Work ID required}"
            shift 2
            ;;
        --phase)
            PHASE="${2:?Phase required}"
            shift 2
            ;;
        --step)
            STEP="${2:?Step required}"
            shift 2
            ;;
        --prompt)
            PROMPT="$2"
            shift 2
            ;;
        --workflow)
            WORKFLOW="$2"
            shift 2
            ;;
        --flags)
            FLAGS="$2"
            shift 2
            ;;
        --escape)
            ESCAPE=true
            shift
            ;;
        *)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
    esac
done

# Validate required arguments
if [ -z "$WORK_ID" ]; then
    echo "Error: --work-id is required" >&2
    exit 1
fi

if [ -z "$PHASE" ]; then
    echo "Error: --phase is required" >&2
    exit 1
fi

if [ -z "$STEP" ]; then
    echo "Error: --step is required" >&2
    exit 1
fi

# Map phase to FABER step names
# The --step argument expects the builder/tester/etc. not the phase name
map_phase_to_step() {
    local phase="$1"
    local step="$2"

    case "$phase" in
        frame)
            echo "framer"
            ;;
        architect)
            echo "architect"
            ;;
        build)
            # Build phase might have different steps
            if [ "$step" = "implement" ]; then
                echo "builder"
            elif [ "$step" = "commit" ]; then
                echo "builder"  # Commit is part of build
            else
                echo "builder"
            fi
            ;;
        evaluate)
            if [ "$step" = "test" ]; then
                echo "tester"
            elif [ "$step" = "review" ]; then
                echo "reviewer"
            else
                echo "evaluator"
            fi
            ;;
        release)
            echo "releaser"
            ;;
        *)
            echo "$step"
            ;;
    esac
}

# Get the appropriate step name
STEP_NAME=$(map_phase_to_step "$PHASE" "$STEP")

# Build the command
CMD="/faber:run --work-id $WORK_ID"

# Add workflow if not default
if [ "$WORKFLOW" != "default" ]; then
    CMD="$CMD --workflow $WORKFLOW"
fi

# Add step
CMD="$CMD --step $STEP_NAME"

# Add any additional flags
if [ -n "$FLAGS" ]; then
    CMD="$CMD $FLAGS"
fi

# Add prompt if provided
if [ -n "$PROMPT" ]; then
    # Escape special characters in prompt for shell safety
    if [ "$ESCAPE" = true ]; then
        # Escape single quotes
        ESCAPED_PROMPT=$(printf '%s' "$PROMPT" | sed "s/'/'\\\\''/g")
        CMD="$CMD --prompt '$ESCAPED_PROMPT'"
    else
        CMD="$CMD --prompt \"$PROMPT\""
    fi
fi

# Output the command
echo "$CMD"

# Also output as JSON for programmatic use
jq -n \
    --arg command "$CMD" \
    --arg work_id "$WORK_ID" \
    --arg workflow "$WORKFLOW" \
    --arg phase "$PHASE" \
    --arg step "$STEP_NAME" \
    --arg prompt "$PROMPT" \
    '{
        command: $command,
        parsed: {
            work_id: $work_id,
            workflow: $workflow,
            phase: $phase,
            step: $step,
            prompt_length: ($prompt | length)
        }
    }' >&2
