#!/bin/bash
# validate-merge.sh - Validate workflow merge produced complete results
#
# This script acts as a guard to catch incomplete merges before execution.
# It verifies that if an inheritance chain has ancestors, the merged result
# contains steps from those ancestors.
#
# Usage: validate-merge.sh <merged_workflow_json>
#
# Input: JSON of merged workflow (from merge-workflows.sh or LLM merge)
#
# Output: JSON validation result
#
# Exit codes:
#   0 - Validation passed
#   1 - Validation failed (empty steps from non-empty ancestors)
#   2 - Invalid input

set -e

# Read merged workflow JSON from argument or stdin
if [[ -n "$1" ]] && [[ -f "$1" ]]; then
    MERGED_JSON=$(cat "$1")
elif [[ -n "$1" ]]; then
    MERGED_JSON="$1"
else
    MERGED_JSON=$(cat)
fi

# Validate JSON
if ! echo "$MERGED_JSON" | jq empty 2>/dev/null; then
    echo '{"status": "failure", "valid": false, "message": "Invalid JSON input", "errors": ["Could not parse merged workflow JSON"]}' >&2
    exit 2
fi

# Extract inheritance chain
CHAIN=$(echo "$MERGED_JSON" | jq -r '.workflow.inheritance_chain // .inheritance_chain // []')
CHAIN_LENGTH=$(echo "$CHAIN" | jq 'length')

# If no inheritance (single workflow), skip validation
if [[ "$CHAIN_LENGTH" -le 1 ]]; then
    echo '{"status": "success", "valid": true, "message": "No inheritance - validation skipped", "details": {"inheritance_chain_length": '"$CHAIN_LENGTH"'}}'
    exit 0
fi

# Count steps per source workflow
get_workflow_key() {
    # Handle both nested (.workflow.phases) and flat (.phases) structure
    if echo "$MERGED_JSON" | jq -e '.workflow.phases' >/dev/null 2>&1; then
        echo ".workflow.phases"
    else
        echo ".phases"
    fi
}

PHASES_KEY=$(get_workflow_key)

# Count total steps
TOTAL_STEPS=$(echo "$MERGED_JSON" | jq "$PHASES_KEY | [.frame.steps, .architect.steps, .build.steps, .evaluate.steps, .release.steps] | flatten | length")

# Count steps per source
STEPS_BY_SOURCE=$(echo "$MERGED_JSON" | jq "$PHASES_KEY | [.frame.steps, .architect.steps, .build.steps, .evaluate.steps, .release.steps] | flatten | group_by(.source) | map({source: .[0].source, count: length})")

# Validate: each ancestor in chain should have at least one step
# (unless it intentionally has no steps defined)
MISSING_SOURCES="[]"
WARNINGS="[]"

# Get workflow IDs from chain (skip first which is the child)
for ((i=1; i<CHAIN_LENGTH; i++)); do
    ANCESTOR_ID=$(echo "$CHAIN" | jq -r ".[$i]")

    # Check if this ancestor has any steps in the merged result
    ANCESTOR_STEP_COUNT=$(echo "$STEPS_BY_SOURCE" | jq --arg src "$ANCESTOR_ID" '[.[] | select(.source == $src)] | .[0].count // 0')

    if [[ "$ANCESTOR_STEP_COUNT" -eq 0 ]]; then
        # This ancestor contributed no steps - potential merge failure
        MISSING_SOURCES=$(echo "$MISSING_SOURCES" | jq --arg src "$ANCESTOR_ID" '. + [$src]')
        WARNINGS=$(echo "$WARNINGS" | jq --arg src "$ANCESTOR_ID" '. + ["Ancestor '\''$src'\'' contributed 0 steps to merged workflow"]')
    fi
done

MISSING_COUNT=$(echo "$MISSING_SOURCES" | jq 'length')

if [[ "$MISSING_COUNT" -gt 0 ]]; then
    # Check if this is a critical failure or just a warning
    # Critical: inheritance chain has >1 items but total steps is suspiciously low
    if [[ "$TOTAL_STEPS" -eq 0 ]]; then
        echo '{
            "status": "failure",
            "valid": false,
            "message": "Workflow merge incomplete - no steps from any ancestor",
            "errors": '"$WARNINGS"',
            "details": {
                "inheritance_chain_length": '"$CHAIN_LENGTH"',
                "total_steps": '"$TOTAL_STEPS"',
                "missing_sources": '"$MISSING_SOURCES"',
                "steps_by_source": '"$STEPS_BY_SOURCE"'
            },
            "error_analysis": "The workflow inheritance chain has '"$CHAIN_LENGTH"' workflows but the merged result contains 0 steps. This indicates the merge algorithm did not execute correctly.",
            "suggested_fixes": [
                "Run merge-workflows.sh script directly instead of LLM-based merge",
                "Check that ancestor workflow files exist and contain steps",
                "Verify pre_steps and post_steps are defined in ancestor workflows"
            ]
        }' >&2
        exit 1
    fi

    # Some ancestors missing but not critical
    echo '{
        "status": "warning",
        "valid": true,
        "message": "Workflow merge may be incomplete - some ancestors contributed no steps",
        "warnings": '"$WARNINGS"',
        "details": {
            "inheritance_chain_length": '"$CHAIN_LENGTH"',
            "total_steps": '"$TOTAL_STEPS"',
            "missing_sources": '"$MISSING_SOURCES"',
            "steps_by_source": '"$STEPS_BY_SOURCE"'
        },
        "warning_analysis": "'"$MISSING_COUNT"' ancestor workflow(s) contributed no steps. This may be intentional (ancestors with empty steps) or indicate a merge issue."
    }'
    exit 0
fi

# All ancestors contributed steps - validation passed
echo '{
    "status": "success",
    "valid": true,
    "message": "Workflow merge validation passed",
    "details": {
        "inheritance_chain_length": '"$CHAIN_LENGTH"',
        "total_steps": '"$TOTAL_STEPS"',
        "steps_by_source": '"$STEPS_BY_SOURCE"'
    }
}'
exit 0
