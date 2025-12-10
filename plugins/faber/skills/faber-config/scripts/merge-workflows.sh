#!/bin/bash
# merge-workflows.sh - Deterministic workflow inheritance merger
#
# This script performs the critical workflow merge operation deterministically,
# removing LLM variability from this critical path.
#
# Usage: merge-workflows.sh <workflow_id> [--plugin-root <path>] [--project-root <path>]
#
# Arguments:
#   workflow_id    - ID of workflow to resolve (e.g., "fractary-faber:default", "project:my-workflow")
#   --plugin-root  - Plugin installation root (default: ~/.claude/plugins/marketplaces/fractary)
#   --project-root - Project root directory (default: current working directory)
#
# Output: JSON with merged workflow and inheritance chain
#
# Exit codes:
#   0 - Success
#   1 - Workflow not found
#   2 - Invalid namespace
#   3 - Circular inheritance detected
#   4 - Duplicate step ID
#   5 - Invalid JSON

set -e

# Default paths
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$HOME/.claude/plugins/marketplaces/fractary}"
PROJECT_ROOT="$(pwd)"

# Parse arguments
WORKFLOW_ID=""
while [[ $# -gt 0 ]]; do
    case $1 in
        --plugin-root)
            PLUGIN_ROOT="$2"
            shift 2
            ;;
        --project-root)
            PROJECT_ROOT="$2"
            shift 2
            ;;
        *)
            if [[ -z "$WORKFLOW_ID" ]]; then
                WORKFLOW_ID="$1"
            fi
            shift
            ;;
    esac
done

if [[ -z "$WORKFLOW_ID" ]]; then
    echo '{"status": "failure", "message": "workflow_id is required", "errors": ["Missing workflow_id argument"]}' >&2
    exit 1
fi

# Function to resolve namespace to file path
resolve_workflow_path() {
    local workflow_id="$1"
    local namespace=""
    local workflow_name=""

    # Parse namespace from workflow_id
    if [[ "$workflow_id" == *":"* ]]; then
        namespace="${workflow_id%%:*}"
        workflow_name="${workflow_id#*:}"
    else
        namespace="project"
        workflow_name="$workflow_id"
    fi

    # Map namespace to path
    case "$namespace" in
        "fractary-faber")
            echo "${PLUGIN_ROOT}/plugins/faber/config/workflows/${workflow_name}.json"
            ;;
        "fractary-faber-cloud")
            echo "${PLUGIN_ROOT}/plugins/faber-cloud/config/workflows/${workflow_name}.json"
            ;;
        "project"|"")
            echo "${PROJECT_ROOT}/.fractary/plugins/faber/workflows/${workflow_name}.json"
            ;;
        *)
            echo '{"status": "failure", "message": "Invalid namespace: '"$namespace"'", "errors": ["Unknown namespace: '"$namespace"'"]}' >&2
            exit 2
            ;;
    esac
}

# Function to load a workflow JSON file
# Implements fallback: if workflow_id has no namespace (implicitly "project") and file doesn't exist
# in project location, try the plugin's default workflows location
load_workflow() {
    local workflow_id="$1"
    local path
    path=$(resolve_workflow_path "$workflow_id")

    # Check if file exists at resolved path
    if [[ ! -f "$path" ]]; then
        # Fallback logic: if no explicit namespace was provided (no colon in workflow_id),
        # try the plugin's default workflow location before failing
        if [[ "$workflow_id" != *":"* ]]; then
            local fallback_path="${PLUGIN_ROOT}/plugins/faber/config/workflows/${workflow_id}.json"
            if [[ -f "$fallback_path" ]]; then
                # Found in plugin defaults - use this path
                path="$fallback_path"
            else
                # Not found in either location
                echo '{"status": "failure", "message": "Workflow not found: '"$workflow_id"'", "errors": ["File not found in project ('"$path"') or plugin defaults ('"$fallback_path"')"]}' >&2
                exit 1
            fi
        else
            # Explicit namespace was provided, don't fallback
            echo '{"status": "failure", "message": "Workflow not found: '"$workflow_id"'", "errors": ["File not found: '"$path"'"]}' >&2
            exit 1
        fi
    fi

    # Validate JSON
    if ! jq empty "$path" 2>/dev/null; then
        echo '{"status": "failure", "message": "Invalid JSON in workflow: '"$workflow_id"'", "errors": ["JSON parse error in '"$path"'"]}' >&2
        exit 5
    fi

    cat "$path"
}

# Build inheritance chain (child first, then ancestors)
build_inheritance_chain() {
    local workflow_id="$1"
    local chain="[]"
    local visited="{}"
    local current_id="$workflow_id"

    while [[ -n "$current_id" ]]; do
        # Check for circular inheritance
        if echo "$visited" | jq -e --arg id "$current_id" '.[$id] == true' >/dev/null 2>&1; then
            echo '{"status": "failure", "message": "Circular inheritance detected", "errors": ["Workflow '"$current_id"' creates inheritance cycle"]}' >&2
            exit 3
        fi

        # Mark as visited
        visited=$(echo "$visited" | jq --arg id "$current_id" '. + {($id): true}')

        # Add to chain
        chain=$(echo "$chain" | jq --arg id "$current_id" '. + [$id]')

        # Load workflow and get extends
        local workflow_json
        workflow_json=$(load_workflow "$current_id")
        current_id=$(echo "$workflow_json" | jq -r '.extends // empty')
    done

    echo "$chain"
}

# Merge steps for a single phase according to inheritance rules
# Pre-steps: root ancestor first (reversed chain)
# Main steps: only from child (first in chain)
# Post-steps: child first (chain order)
merge_phase_steps() {
    local chain_json="$1"
    local phase="$2"
    local merged_steps="[]"
    local chain_length
    chain_length=$(echo "$chain_json" | jq 'length')

    # Pre-steps: iterate from root (last) to child (first) = reversed
    for ((i=chain_length-1; i>=0; i--)); do
        local workflow_id
        workflow_id=$(echo "$chain_json" | jq -r ".[$i]")
        local workflow_json
        workflow_json=$(load_workflow "$workflow_id")

        # Get pre_steps for this phase
        local pre_steps
        pre_steps=$(echo "$workflow_json" | jq --arg phase "$phase" '.phases[$phase].pre_steps // []')

        # Add source metadata and position to each step
        pre_steps=$(echo "$pre_steps" | jq --arg src "$workflow_id" '[.[] | . + {"source": $src, "position": "pre_step"}]')

        # Append to merged
        merged_steps=$(echo "$merged_steps" "$pre_steps" | jq -s '.[0] + .[1]')
    done

    # Main steps: only from child (index 0)
    local child_id
    child_id=$(echo "$chain_json" | jq -r '.[0]')
    local child_workflow
    child_workflow=$(load_workflow "$child_id")
    local main_steps
    main_steps=$(echo "$child_workflow" | jq --arg phase "$phase" '.phases[$phase].steps // []')
    main_steps=$(echo "$main_steps" | jq --arg src "$child_id" '[.[] | . + {"source": $src, "position": "step"}]')
    merged_steps=$(echo "$merged_steps" "$main_steps" | jq -s '.[0] + .[1]')

    # Post-steps: iterate from child (first) to root (last) = chain order
    for ((i=0; i<chain_length; i++)); do
        local workflow_id
        workflow_id=$(echo "$chain_json" | jq -r ".[$i]")
        local workflow_json
        workflow_json=$(load_workflow "$workflow_id")

        # Get post_steps for this phase
        local post_steps
        post_steps=$(echo "$workflow_json" | jq --arg phase "$phase" '.phases[$phase].post_steps // []')

        # Add source metadata and position to each step
        post_steps=$(echo "$post_steps" | jq --arg src "$workflow_id" '[.[] | . + {"source": $src, "position": "post_step"}]')

        # Append to merged
        merged_steps=$(echo "$merged_steps" "$post_steps" | jq -s '.[0] + .[1]')
    done

    echo "$merged_steps"
}

# Apply skip_steps from child workflow
apply_skip_steps() {
    local merged_steps="$1"
    local skip_steps="$2"

    if [[ "$skip_steps" == "null" ]] || [[ "$skip_steps" == "[]" ]]; then
        echo "$merged_steps"
        return
    fi

    # Filter out steps whose id is in skip_steps
    echo "$merged_steps" | jq --argjson skip "$skip_steps" '[.[] | select(.id as $id | $skip | index($id) | not)]'
}

# Validate no duplicate step IDs
validate_unique_step_ids() {
    local all_steps="$1"

    # Get all step IDs
    local ids
    ids=$(echo "$all_steps" | jq -r '.[].id // empty')

    # Check for duplicates
    local duplicates
    duplicates=$(echo "$ids" | sort | uniq -d)

    if [[ -n "$duplicates" ]]; then
        echo '{"status": "failure", "message": "Duplicate step IDs found", "errors": ["Duplicate step IDs: '"$(echo "$duplicates" | tr '\n' ', ')"'"]}' >&2
        exit 4
    fi
}

# Main execution
main() {
    # Build inheritance chain
    local chain
    chain=$(build_inheritance_chain "$WORKFLOW_ID")

    # Load child workflow for base metadata
    local child_workflow
    child_workflow=$(load_workflow "$(echo "$chain" | jq -r '.[0]')")

    # Get skip_steps from child
    local skip_steps
    skip_steps=$(echo "$child_workflow" | jq '.skip_steps // []')

    # Initialize merged workflow with child's metadata
    local merged
    merged=$(echo "$child_workflow" | jq '{
        id: .id,
        description: .description,
        autonomy: .autonomy,
        integrations: .integrations
    }')

    # Add inheritance chain metadata
    merged=$(echo "$merged" | jq --argjson chain "$chain" '. + {inheritance_chain: $chain}')

    # Add skipped_steps if any
    if [[ "$skip_steps" != "[]" ]]; then
        merged=$(echo "$merged" | jq --argjson skip "$skip_steps" '. + {skipped_steps: $skip}')
    fi

    # Merge phases
    local phases="{}"
    local all_steps="[]"

    for phase in frame architect build evaluate release; do
        local phase_steps
        phase_steps=$(merge_phase_steps "$chain" "$phase")

        # Apply skip_steps
        phase_steps=$(apply_skip_steps "$phase_steps" "$skip_steps")

        # Accumulate all steps for validation
        all_steps=$(echo "$all_steps" "$phase_steps" | jq -s '.[0] + .[1]')

        # Get enabled status from child (or default true)
        local enabled
        enabled=$(echo "$child_workflow" | jq --arg phase "$phase" '.phases[$phase].enabled // true')

        # Get max_retries for evaluate phase
        local max_retries=""
        if [[ "$phase" == "evaluate" ]]; then
            max_retries=$(echo "$child_workflow" | jq '.phases.evaluate.max_retries // 3')
        fi

        # Build phase object
        if [[ "$phase" == "evaluate" ]]; then
            phases=$(echo "$phases" | jq --arg phase "$phase" \
                --argjson steps "$phase_steps" \
                --argjson enabled "$enabled" \
                --argjson max_retries "$max_retries" \
                '. + {($phase): {enabled: $enabled, steps: $steps, max_retries: $max_retries}}')
        else
            phases=$(echo "$phases" | jq --arg phase "$phase" \
                --argjson steps "$phase_steps" \
                --argjson enabled "$enabled" \
                '. + {($phase): {enabled: $enabled, steps: $steps}}')
        fi
    done

    # Validate unique step IDs
    validate_unique_step_ids "$all_steps"

    # Add phases to merged workflow
    merged=$(echo "$merged" | jq --argjson phases "$phases" '. + {phases: $phases}')

    # Return success response
    echo "{\"status\": \"success\", \"message\": \"Workflow merged successfully\", \"workflow\": $merged}"
}

# Run main
main
