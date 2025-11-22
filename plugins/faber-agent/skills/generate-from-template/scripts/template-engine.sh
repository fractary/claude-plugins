#!/bin/bash
# Template Substitution Engine
# Replaces {{VARIABLE}} placeholders in templates with actual values

set -euo pipefail

# Usage: template-engine.sh <template-file> <output-file> <variables-json>
TEMPLATE_FILE="$1"
OUTPUT_FILE="$2"
VARIABLES_JSON="$3"

if [ ! -f "$TEMPLATE_FILE" ]; then
    echo "Error: Template file not found: $TEMPLATE_FILE" >&2
    exit 1
fi

echo "🔧 Template Engine"
echo "   Template: $TEMPLATE_FILE"
echo "   Output: $OUTPUT_FILE"
echo ""

# Read template content
TEMPLATE_CONTENT=$(<"$TEMPLATE_FILE")

# Parse variables from JSON and perform substitutions
echo "Applying substitutions..."

# Extract all variables from JSON and substitute
while IFS= read -r line; do
    VAR_NAME=$(echo "$line" | jq -r '.key')
    VAR_VALUE=$(echo "$line" | jq -r '.value')

    if [ "$VAR_NAME" != "null" ] && [ "$VAR_VALUE" != "null" ]; then
        echo "  • {{$VAR_NAME}} → ${VAR_VALUE:0:50}$([ ${#VAR_VALUE} -gt 50 ] && echo '...')"
        # Escape special characters for sed
        ESCAPED_VALUE=$(printf '%s\n' "$VAR_VALUE" | sed -e 's/[\/&]/\\&/g')
        TEMPLATE_CONTENT=$(echo "$TEMPLATE_CONTENT" | sed "s/{{${VAR_NAME}}}/${ESCAPED_VALUE}/g")
    fi
done < <(echo "$VARIABLES_JSON" | jq -r 'to_entries[] | @json | fromjson | {key: .key, value: .value} | @json')

echo ""

# Check for unreplaced variables
UNREPLACED=$(echo "$TEMPLATE_CONTENT" | grep -o '{{[A-Z_]*}}' | sort -u || true)
if [ -n "$UNREPLACED" ]; then
    echo "⚠️  Warning: Unreplaced variables found:"
    echo "$UNREPLACED" | sed 's/^/     /'
    echo ""
fi

# Write output
echo "$TEMPLATE_CONTENT" > "$OUTPUT_FILE"

echo "✅ Template generated: $OUTPUT_FILE"
exit 0
