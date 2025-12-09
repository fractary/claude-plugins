#!/usr/bin/env bash
#
# generate-command.sh - Generate /fractary-faber:run continuation command
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
# Output: The formatted /fractary-faber:run command
#
# Security:
#   - All inputs are validated for format and suspicious patterns
#   - Prompt text is safely escaped using printf '%q' to prevent injection
#   - Shell metacharacters are properly handled

set -euo pipefail

# =============================================================================
# Input Validation Functions
# =============================================================================

# Validate work ID format (alphanumeric, hyphens, underscores, or numeric)
validate_work_id() {
    local id="$1"
    if [[ ! "$id" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid work-id format: $id" >&2
        echo "Work ID must contain only alphanumeric characters, hyphens, or underscores" >&2
        exit 1
    fi
}

# Validate phase name
validate_phase() {
    local phase="$1"
    case "$phase" in
        frame|architect|build|evaluate|release)
            return 0
            ;;
        *)
            echo "Error: Invalid phase: $phase" >&2
            echo "Valid phases: frame, architect, build, evaluate, release" >&2
            exit 1
            ;;
    esac
}

# Validate step name (alphanumeric, hyphens, underscores)
validate_step() {
    local step="$1"
    if [[ ! "$step" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid step format: $step" >&2
        echo "Step must contain only alphanumeric characters, hyphens, or underscores" >&2
        exit 1
    fi
}

# Validate workflow ID (alphanumeric, hyphens, underscores)
validate_workflow() {
    local workflow="$1"
    if [[ ! "$workflow" =~ ^[a-zA-Z0-9_-]+$ ]]; then
        echo "Error: Invalid workflow format: $workflow" >&2
        echo "Workflow must contain only alphanumeric characters, hyphens, or underscores" >&2
        exit 1
    fi
}

# Check for suspicious patterns that could indicate injection attempts
check_suspicious_patterns() {
    local value="$1"
    local name="$2"

    # Check for common shell injection patterns
    if [[ "$value" =~ [\$\`] ]] || \
       [[ "$value" =~ \$\( ]] || \
       [[ "$value" =~ \>\> ]] || \
       [[ "$value" =~ \|\| ]] || \
       [[ "$value" =~ \&\& ]] || \
       [[ "$value" =~ \; ]]; then
        echo "Error: Suspicious pattern detected in $name" >&2
        echo "Shell metacharacters like \$, \`, ;, |, & are not allowed in identifiers" >&2
        exit 1
    fi
}

# Safely escape a string for shell usage using printf %q
# This is the most robust method for shell escaping
safe_escape() {
    printf '%q' "$1"
}

# =============================================================================
# Main Script
# =============================================================================

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

# Validate all inputs for format and suspicious patterns
validate_work_id "$WORK_ID"
check_suspicious_patterns "$WORK_ID" "work-id"

validate_phase "$PHASE"

validate_step "$STEP"
check_suspicious_patterns "$STEP" "step"

validate_workflow "$WORKFLOW"
check_suspicious_patterns "$WORKFLOW" "workflow"

# Note: PROMPT is allowed to contain special characters but will be safely escaped
# FLAGS are passed through but validated for suspicious injection patterns
if [ -n "$FLAGS" ]; then
    check_suspicious_patterns "$FLAGS" "flags"
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
CMD="/fractary-faber:run --work-id $WORK_ID"

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
    # Use printf '%q' for robust shell escaping - this is the safest method
    # It handles all shell metacharacters including $, `, ", ', \, etc.
    ESCAPED_PROMPT=$(safe_escape "$PROMPT")
    CMD="$CMD --prompt $ESCAPED_PROMPT"
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
