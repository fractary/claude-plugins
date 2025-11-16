#!/usr/bin/env bash
# Render mustache template with JSON data
# Usage: render-template.sh {template_path} {data_json}
# Returns: Rendered markdown to stdout

set -euo pipefail

TEMPLATE_PATH="${1:-}"
DATA_JSON="${2:-}"

# Validate inputs
if [[ -z "$TEMPLATE_PATH" ]] || [[ -z "$DATA_JSON" ]]; then
  echo "ERROR: Missing required arguments" >&2
  echo "Usage: render-template.sh {template_path} {data_json}" >&2
  exit 1
fi

if [[ ! -f "$TEMPLATE_PATH" ]]; then
  echo "ERROR: Template file not found: $TEMPLATE_PATH" >&2
  exit 1
fi

# Check if mustache CLI is available
if command -v mustache >/dev/null 2>&1; then
  # Use mustache CLI for proper template rendering
  echo "$DATA_JSON" | mustache - "$TEMPLATE_PATH"
  exit 0
fi

# Check if mo (mustache in bash) is available
if command -v mo >/dev/null 2>&1; then
  # Use mo for mustache rendering
  echo "$DATA_JSON" | mo "$TEMPLATE_PATH"
  exit 0
fi

# Fallback: Simple variable substitution using sed/jq
if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: No mustache renderer available (tried: mustache, mo, jq)" >&2
  echo "Install mustache: npm install -g mustache" >&2
  echo "Or install mo: brew install mo (macOS) or download from https://github.com/tests-always-included/mo" >&2
  exit 1
fi

# Simple fallback: Replace {{variable}} patterns with jq values
RENDERED="$(cat "$TEMPLATE_PATH")"

# Extract all {{variable}} patterns
VARIABLES=$(echo "$RENDERED" | grep -oE '\{\{[^}]+\}\}' | sed 's/[{}]//g' | sort -u)

for var in $VARIABLES; do
  # Skip mustache conditionals and loops (start with # or ^)
  if [[ "$var" =~ ^[#^/] ]]; then
    continue
  fi

  # Get value from JSON
  VALUE=$(echo "$DATA_JSON" | jq -r ".$var // \"\"")

  # Replace in template
  RENDERED=$(echo "$RENDERED" | sed "s|{{$var}}|$VALUE|g")
done

# Note: This fallback doesn't handle conditionals or loops properly
# For full mustache support, install mustache or mo
echo "$RENDERED"

# Warning about limited fallback
if echo "$RENDERED" | grep -qE '\{\{[#^]'; then
  echo "WARNING: Template contains conditionals/loops that require full mustache support" >&2
  echo "Install mustache: npm install -g mustache" >&2
fi
