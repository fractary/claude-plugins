#!/usr/bin/env bash
# Format context injection blocks for context and prompt hooks
# Generates consistent, well-formatted context blocks

set -euo pipefail

# Usage: format-context-injection.sh <hook-type> <hook-json> <content-file>
# hook-type: "context" or "prompt"
# hook-json: JSON object with hook configuration
# content-file: File containing the content to inject (for context hooks)

HOOK_TYPE="${1:-}"
HOOK_JSON="${2:-}"
CONTENT_FILE="${3:-}"

if [[ -z "$HOOK_TYPE" ]] || [[ -z "$HOOK_JSON" ]]; then
    echo "Error: Hook type and JSON required" >&2
    echo "Usage: $0 <hook-type> <hook-json> [content-file]" >&2
    exit 1
fi

# Parse hook configuration
HOOK_NAME=$(echo "$HOOK_JSON" | jq -r '.name')
HOOK_WEIGHT=$(echo "$HOOK_JSON" | jq -r '.weight // "medium"')
HOOK_PROMPT=$(echo "$HOOK_JSON" | jq -r '.prompt // ""')
HOOK_CONTENT=$(echo "$HOOK_JSON" | jq -r '.content // ""')

# Get current phase and timing if available from environment
PHASE="${FABER_PHASE:-unknown}"
HOOK_TIMING="${FABER_HOOK_TYPE:-unknown}"

# ============================================================================
# CONTEXT HOOK FORMATTING
# ============================================================================

if [[ "$HOOK_TYPE" == "context" ]]; then
    cat <<EOF
═══════════════════════════════════════════════════════════
📋 PROJECT CONTEXT: $HOOK_NAME
Priority: $HOOK_WEIGHT
Phase: $PHASE ($HOOK_TIMING)
═══════════════════════════════════════════════════════════

EOF

    # Add prompt if provided
    if [[ -n "$HOOK_PROMPT" ]]; then
        echo "$HOOK_PROMPT"
        echo ""
    fi

    # Add referenced documentation
    if [[ -n "$CONTENT_FILE" ]] && [[ -f "$CONTENT_FILE" ]]; then
        echo "## Referenced Documentation"
        echo ""
        cat "$CONTENT_FILE"
        echo ""
    fi

    cat <<EOF
═══════════════════════════════════════════════════════════

EOF

# ============================================================================
# PROMPT HOOK FORMATTING
# ============================================================================

elif [[ "$HOOK_TYPE" == "prompt" ]]; then
    # Select icon based on weight
    ICON="📌"
    case "$HOOK_WEIGHT" in
        critical)
            ICON="⚠️  CRITICAL"
            ;;
        high)
            ICON="⚡"
            ;;
        medium)
            ICON="📌"
            ;;
        low)
            ICON="💡"
            ;;
    esac

    cat <<EOF
─────────────────────────────────────────────────────────
$ICON PROMPT: $HOOK_NAME
Priority: $HOOK_WEIGHT
Phase: $PHASE ($HOOK_TIMING)
─────────────────────────────────────────────────────────

$HOOK_CONTENT

─────────────────────────────────────────────────────────

EOF

else
    echo "Error: Invalid hook type '$HOOK_TYPE' (must be 'context' or 'prompt')" >&2
    exit 1
fi
