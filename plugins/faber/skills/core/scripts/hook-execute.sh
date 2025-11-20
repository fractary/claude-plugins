#!/usr/bin/env bash
#
# hook-execute.sh - Execute a FABER hook
#
# Usage:
#   hook-execute.sh <hook-json> [context-json]
#
# Hook Types:
#   - document: Returns path for LLM to read
#   - script: Executes script with timeout
#   - skill: Returns skill invocation instruction
#
# Example:
#   hook-execute.sh '{"type":"script","path":"./hook.sh"}' '{"work_id":"123","phase":"frame"}'

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ $# -eq 0 ]; then
    echo "Usage: hook-execute.sh <hook-json> [context-json]" >&2
    exit 1
fi

HOOK_JSON="$1"
CONTEXT_JSON="${2:-{}}"

# Default timeout (30 seconds)
DEFAULT_TIMEOUT=30

# Validate hook first
if ! "$SCRIPT_DIR/hook-validate.sh" "$HOOK_JSON" > /dev/null 2>&1; then
    echo -e "${RED}✗ Hook validation failed${NC}" >&2
    "$SCRIPT_DIR/error-report.sh" FABER-302
    exit 1
fi

# Parse hook configuration
HOOK_TYPE=$(echo "$HOOK_JSON" | jq -r '.type')
HOOK_TIMEOUT=$(echo "$HOOK_JSON" | jq -r ".timeout // $DEFAULT_TIMEOUT")
HOOK_DESC=$(echo "$HOOK_JSON" | jq -r '.description // "Hook"')

echo -e "${BLUE}▶${NC} Executing hook: $HOOK_DESC"
echo "   Type: $HOOK_TYPE"

# Execute based on type
case "$HOOK_TYPE" in
    document)
        HOOK_PATH=$(echo "$HOOK_JSON" | jq -r '.path')

        if [ ! -f "$HOOK_PATH" ]; then
            echo -e "${RED}✗ Document not found: $HOOK_PATH${NC}" >&2
            "$SCRIPT_DIR/error-report.sh" FABER-303
            exit 1
        fi

        echo ""
        echo -e "${GREEN}✓ Document hook ready${NC}"
        echo ""
        echo "════════════════════════════════════════"
        echo "HOOK DOCUMENT: $HOOK_PATH"
        echo "════════════════════════════════════════"
        echo ""
        echo "ACTION REQUIRED: Read and process the document at:"
        echo "  $HOOK_PATH"
        echo ""
        echo "Context:"
        echo "$CONTEXT_JSON" | jq '.'
        echo ""
        ;;

    script)
        HOOK_PATH=$(echo "$HOOK_JSON" | jq -r '.path')

        if [ ! -f "$HOOK_PATH" ]; then
            echo -e "${RED}✗ Script not found: $HOOK_PATH${NC}" >&2
            "$SCRIPT_DIR/error-report.sh" FABER-303
            exit 1
        fi

        if [ ! -x "$HOOK_PATH" ]; then
            echo -e "${RED}✗ Script is not executable: $HOOK_PATH${NC}" >&2
            echo "Run: chmod +x $HOOK_PATH" >&2
            exit 1
        fi

        echo "   Timeout: ${HOOK_TIMEOUT}s"
        echo ""

        # Create temp file for context
        CONTEXT_FILE=$(mktemp)
        echo "$CONTEXT_JSON" > "$CONTEXT_FILE"

        # Execute script with timeout
        set +e
        if timeout "${HOOK_TIMEOUT}s" "$HOOK_PATH" "$CONTEXT_FILE" 2>&1; then
            EXIT_CODE=$?
        else
            EXIT_CODE=$?
        fi
        set -e

        # Clean up temp file
        rm -f "$CONTEXT_FILE"

        echo ""

        if [ $EXIT_CODE -eq 124 ]; then
            # Timeout exit code
            echo -e "${RED}✗ Hook timeout exceeded${NC}" >&2
            "$SCRIPT_DIR/error-report.sh" FABER-301
            exit 1
        elif [ $EXIT_CODE -ne 0 ]; then
            echo -e "${RED}✗ Hook execution failed (exit code: $EXIT_CODE)${NC}" >&2
            "$SCRIPT_DIR/error-report.sh" FABER-300
            exit 1
        else
            echo -e "${GREEN}✓ Hook completed successfully${NC}"
        fi
        ;;

    skill)
        SKILL_ID=$(echo "$HOOK_JSON" | jq -r '.skill')
        SKILL_PARAMS=$(echo "$HOOK_JSON" | jq -r '.parameters // {}')

        echo ""
        echo -e "${GREEN}✓ Skill hook ready${NC}"
        echo ""
        echo "════════════════════════════════════════"
        echo "HOOK SKILL: $SKILL_ID"
        echo "════════════════════════════════════════"
        echo ""
        echo "ACTION REQUIRED: Invoke the skill using the Skill tool:"
        echo ""
        echo "Skill: $SKILL_ID"
        echo ""
        echo "Context:"
        echo "$CONTEXT_JSON" | jq '.'
        echo ""
        if [ "$SKILL_PARAMS" != "{}" ]; then
            echo "Parameters:"
            echo "$SKILL_PARAMS" | jq '.'
            echo ""
        fi
        ;;

    *)
        echo -e "${RED}✗ Unknown hook type: $HOOK_TYPE${NC}" >&2
        exit 1
        ;;
esac

exit 0
