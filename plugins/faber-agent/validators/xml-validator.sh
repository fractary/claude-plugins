#!/bin/bash
# XML Markup Validator for Fractary Agents and Skills
# Validates that XML sections follow FRACTARY-PLUGIN-STANDARDS.md

set -euo pipefail

ARTIFACT_PATH="$1"
ARTIFACT_TYPE="${2:-agent}"  # agent, skill, or command

if [ ! -f "$ARTIFACT_PATH" ]; then
    echo "Error: File not found: $ARTIFACT_PATH" >&2
    exit 1
fi

# Define required sections based on artifact type
if [ "$ARTIFACT_TYPE" = "agent" ]; then
    REQUIRED_SECTIONS=(
        "CONTEXT"
        "CRITICAL_RULES"
        "INPUTS"
        "WORKFLOW"
        "COMPLETION_CRITERIA"
        "OUTPUTS"
        "ERROR_HANDLING"
    )
elif [ "$ARTIFACT_TYPE" = "skill" ]; then
    REQUIRED_SECTIONS=(
        "CONTEXT"
        "CRITICAL_RULES"
        "INPUTS"
        "WORKFLOW"
        "COMPLETION_CRITERIA"
        "OUTPUTS"
        "DOCUMENTATION"
        "ERROR_HANDLING"
    )
elif [ "$ARTIFACT_TYPE" = "command" ]; then
    REQUIRED_SECTIONS=(
        "CONTEXT"
        "CRITICAL_RULES"
        "WORKFLOW"
        "ARGUMENT_PARSING"
        "AGENT_INVOCATION"
        "ERROR_HANDLING"
    )
else
    echo "Error: Unknown artifact type: $ARTIFACT_TYPE" >&2
    exit 1
fi

echo "🔍 Validating XML markup for $ARTIFACT_TYPE: $ARTIFACT_PATH"
echo ""

ERRORS=0
WARNINGS=0

# Check for required sections
echo "Checking required sections..."
for SECTION in "${REQUIRED_SECTIONS[@]}"; do
    if grep -q "<${SECTION}>" "$ARTIFACT_PATH" && grep -q "</${SECTION}>" "$ARTIFACT_PATH"; then
        echo "  ✅ $SECTION section present"
    else
        echo "  ❌ Missing required section: $SECTION" >&2
        ((ERRORS++))
    fi
done

echo ""

# Check for proper UPPERCASE naming
echo "Checking tag naming conventions..."
LOWERCASE_TAGS=$(grep -oP '<\K[a-z_-]+(?=>)' "$ARTIFACT_PATH" | grep -v -E '^(example|commentary|system-reminder|antml:)' || true)
if [ -n "$LOWERCASE_TAGS" ]; then
    echo "  ⚠️  Found lowercase XML tags (should be UPPERCASE):" >&2
    echo "$LOWERCASE_TAGS" | sed 's/^/      /' >&2
    ((WARNINGS++))
else
    echo "  ✅ All custom tags use UPPERCASE"
fi

echo ""

# Check for unclosed tags
echo "Checking for unclosed tags..."
UNCLOSED=0
for SECTION in "${REQUIRED_SECTIONS[@]}"; do
    OPEN_COUNT=$(grep -c "<${SECTION}>" "$ARTIFACT_PATH" || true)
    CLOSE_COUNT=$(grep -c "</${SECTION}>" "$ARTIFACT_PATH" || true)

    if [ "$OPEN_COUNT" -ne "$CLOSE_COUNT" ]; then
        echo "  ❌ Unclosed tag: $SECTION (open: $OPEN_COUNT, close: $CLOSE_COUNT)" >&2
        ((ERRORS++))
        UNCLOSED=1
    fi
done

if [ $UNCLOSED -eq 0 ]; then
    echo "  ✅ All tags properly closed"
fi

echo ""

# Summary
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
if [ $ERRORS -eq 0 ] && [ $WARNINGS -eq 0 ]; then
    echo "✅ Validation passed: All XML markup checks successful"
    exit 0
elif [ $ERRORS -eq 0 ]; then
    echo "⚠️  Validation passed with warnings: $WARNINGS warning(s)"
    exit 0
else
    echo "❌ Validation failed: $ERRORS error(s), $WARNINGS warning(s)"
    exit 1
fi
