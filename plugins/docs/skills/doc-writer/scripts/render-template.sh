#!/bin/bash
# render-template.sh - Render Mustache template with variables
# Usage: render-template.sh <template_file> <variables_json>

set -euo pipefail

TEMPLATE_FILE="$1"
VARIABLES_JSON="$2"

# Check template exists
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    echo "Error: Template not found: $TEMPLATE_FILE" >&2
    exit 1
fi

# Read template
TEMPLATE=$(<"$TEMPLATE_FILE")

# Simple Mustache renderer using jq and sed
# This is a basic implementation - for production, consider using a proper Mustache library

# Extract all {{variables}} from template
VARS=$(echo "$TEMPLATE" | grep -oP '\{\{[^}]+\}\}' | sort -u || true)

RENDERED="$TEMPLATE"

# Replace each variable
for VAR_WITH_BRACES in $VARS; do
    # Remove {{ and }}
    VAR=$(echo "$VAR_WITH_BRACES" | sed 's/{{//; s/}}//')

    # Skip conditionals and loops (start with # or ^)
    if [[ "$VAR" =~ ^[#^/] ]]; then
        continue
    fi

    # Get value from JSON
    VALUE=$(echo "$VARIABLES_JSON" | jq -r --arg var "$VAR" '
        .[$var] //
        (.[$var | split(".")[0]]? | .[$var | split(".")[1]]?) //
        ""
    ')

    # Replace in template
    RENDERED=$(echo "$RENDERED" | sed "s|{{$VAR}}|$VALUE|g")
done

# Output rendered template
echo "$RENDERED"
