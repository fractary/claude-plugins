#!/usr/bin/env bash
#
# hooks-execute-all.sh - Execute all hooks for a phase boundary
#
# Usage:
#   hooks-execute-all.sh <boundary> [context_json] [config_path]
#
# Arguments:
#   boundary      - Hook boundary (pre_frame, post_frame, pre_architect, etc.)
#   context_json  - Optional JSON context to pass to hooks
#   config_path   - Optional path to config file
#
# Examples:
#   hooks-execute-all.sh pre_frame
#   hooks-execute-all.sh post_build '{"work_id": "123", "phase": "build"}'
#
# Output:
#   JSON object with execution results and any actions required

set -euo pipefail

# Arguments
BOUNDARY="${1:?Boundary required}"
CONTEXT_JSON="${2:-{}}"
CONFIG_PATH="${3:-.fractary/plugins/faber/config.json}"

# Resolve paths robustly (works regardless of execution context)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
FABER_ROOT="$(cd "$SKILL_ROOT/../.." && pwd)"
CORE_SCRIPTS="$FABER_ROOT/skills/core/scripts"

# Verify core scripts exist
if [ ! -d "$CORE_SCRIPTS" ]; then
    echo "Error: Core scripts not found at: $CORE_SCRIPTS" >&2
    exit 1
fi

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Validate boundary
case "$BOUNDARY" in
    pre_frame|post_frame|pre_architect|post_architect|pre_build|post_build|pre_evaluate|post_evaluate|pre_release|post_release) ;;
    *)
        echo "Error: Invalid boundary: $BOUNDARY" >&2
        echo "Valid boundaries: pre_frame, post_frame, pre_architect, post_architect, pre_build, post_build, pre_evaluate, post_evaluate, pre_release, post_release" >&2
        exit 1
        ;;
esac

# Check config exists
if [ ! -f "$CONFIG_PATH" ]; then
    echo -e "${YELLOW}⚠ No config file found, skipping hooks${NC}" >&2
    echo '{"status": "success", "boundary": "'"$BOUNDARY"'", "hooks_executed": 0, "message": "No config file"}'
    exit 0
fi

# Get hooks for this boundary from config
HOOKS=$(jq -r --arg boundary "$BOUNDARY" '
    .workflows[0].hooks[$boundary] // []
' "$CONFIG_PATH" 2>/dev/null || echo "[]")

HOOK_COUNT=$(echo "$HOOKS" | jq 'length')

if [ "$HOOK_COUNT" -eq 0 ]; then
    echo -e "${BLUE}ℹ No hooks configured for boundary: $BOUNDARY${NC}" >&2
    echo '{"status": "success", "boundary": "'"$BOUNDARY"'", "hooks_executed": 0, "message": "No hooks configured"}'
    exit 0
fi

echo -e "${BLUE}▶${NC} Executing $HOOK_COUNT hook(s) for boundary: $BOUNDARY" >&2

# Track results
RESULTS="[]"
ACTIONS_REQUIRED="[]"
HOOKS_SUCCEEDED=0
HOOKS_FAILED=0

# Execute each hook
for ((i=0; i<HOOK_COUNT; i++)); do
    HOOK=$(echo "$HOOKS" | jq ".[$i]")
    HOOK_TYPE=$(echo "$HOOK" | jq -r '.type')
    HOOK_DESC=$(echo "$HOOK" | jq -r '.description // "Hook '"$((i+1))"'"')

    echo -e "  ${BLUE}→${NC} $HOOK_DESC ($HOOK_TYPE)" >&2

    # Execute the hook
    set +e
    HOOK_RESULT=$("$CORE_SCRIPTS/hook-execute.sh" "$HOOK" "$CONTEXT_JSON" 2>&1)
    HOOK_EXIT=$?
    set -e

    if [ $HOOK_EXIT -eq 0 ]; then
        echo -e "    ${GREEN}✓${NC} Success" >&2
        HOOKS_SUCCEEDED=$((HOOKS_SUCCEEDED + 1))

        # Add to results
        RESULTS=$(echo "$RESULTS" | jq --argjson hook "$HOOK" \
            '. += [{"hook": $hook, "status": "success", "exit_code": 0}]')

        # Check for actions required (document or skill hooks)
        case "$HOOK_TYPE" in
            document)
                HOOK_PATH=$(echo "$HOOK" | jq -r '.path')
                ACTIONS_REQUIRED=$(echo "$ACTIONS_REQUIRED" | jq \
                    --arg type "read_document" \
                    --arg path "$HOOK_PATH" \
                    --arg desc "$HOOK_DESC" \
                    '. += [{"type": $type, "path": $path, "description": $desc}]')
                ;;
            skill)
                SKILL_NAME=$(echo "$HOOK" | jq -r '.skill')
                SKILL_PARAMS=$(echo "$HOOK" | jq '.parameters // {}')
                ACTIONS_REQUIRED=$(echo "$ACTIONS_REQUIRED" | jq \
                    --arg type "invoke_skill" \
                    --arg skill "$SKILL_NAME" \
                    --argjson params "$SKILL_PARAMS" \
                    --arg desc "$HOOK_DESC" \
                    '. += [{"type": $type, "skill": $skill, "parameters": $params, "description": $desc}]')
                ;;
        esac
    else
        echo -e "    ${RED}✗${NC} Failed (exit $HOOK_EXIT)" >&2
        HOOKS_FAILED=$((HOOKS_FAILED + 1))

        # Add to results
        RESULTS=$(echo "$RESULTS" | jq --argjson hook "$HOOK" --arg output "$HOOK_RESULT" \
            '. += [{"hook": $hook, "status": "failed", "exit_code": '"$HOOK_EXIT"', "output": $output}]')
    fi
done

echo "" >&2

# Summary
if [ $HOOKS_FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ All $HOOK_COUNT hook(s) executed successfully${NC}" >&2
    STATUS="success"
else
    echo -e "${RED}✗ $HOOKS_FAILED of $HOOK_COUNT hook(s) failed${NC}" >&2
    STATUS="partial_failure"
fi

# Output JSON result
jq -n \
    --arg status "$STATUS" \
    --arg boundary "$BOUNDARY" \
    --argjson hooks_executed "$HOOK_COUNT" \
    --argjson hooks_succeeded "$HOOKS_SUCCEEDED" \
    --argjson hooks_failed "$HOOKS_FAILED" \
    --argjson results "$RESULTS" \
    --argjson actions_required "$ACTIONS_REQUIRED" \
    '{
        "status": $status,
        "boundary": $boundary,
        "hooks_executed": $hooks_executed,
        "hooks_succeeded": $hooks_succeeded,
        "hooks_failed": $hooks_failed,
        "results": $results,
        "actions_required": $actions_required
    }'

exit 0
