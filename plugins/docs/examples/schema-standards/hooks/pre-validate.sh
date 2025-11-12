#!/usr/bin/env bash
#
# Pre-Validate Hook - Example
#
# This hook runs BEFORE standard fractary-docs validation.
# Use it to enforce project-specific validation rules.
#
# Environment variables available:
#   FILE_PATH  - Path to the document being validated
#   DOC_TYPE   - Document type (from front matter)
#   PLUGIN_DIR - Path to plugin directory
#
# Exit codes:
#   0 - Continue with validation
#   Non-zero - Block validation (treat as validation failure)
#

set -euo pipefail

# Only run custom validation for schema documents
if [[ "$DOC_TYPE" != "schema" ]]; then
  echo "Skipping project-specific schema validation (doc type: $DOC_TYPE)"
  exit 0
fi

echo "Running project-specific schema validation..."

# Run custom validation script
SCRIPT_PATH="./.fractary/plugins/docs/scripts/validate-schema-docs.sh"

if [[ ! -f "$SCRIPT_PATH" ]]; then
  echo "Warning: Custom validation script not found: $SCRIPT_PATH"
  exit 0
fi

# Run validation and capture output
VALIDATION_RESULT=$("$SCRIPT_PATH" "$FILE_PATH")

# Parse result
ERRORS=$(echo "$VALIDATION_RESULT" | jq -r '.errors // 0')
WARNINGS=$(echo "$VALIDATION_RESULT" | jq -r '.warnings // 0')
INFO=$(echo "$VALIDATION_RESULT" | jq -r '.info // 0')

# Display results
if [[ $ERRORS -gt 0 ]]; then
  echo "❌ Custom validation failed with $ERRORS errors, $WARNINGS warnings, $INFO info"
  echo "$VALIDATION_RESULT" | jq -r '.issues[] | "  [\(.severity | ascii_upcase)] \(.check): \(.message)"'
  exit 1
elif [[ $WARNINGS -gt 0 || $INFO -gt 0 ]]; then
  echo "⚠️  Custom validation passed with $WARNINGS warnings, $INFO info"
  echo "$VALIDATION_RESULT" | jq -r '.issues[] | "  [\(.severity | ascii_upcase)] \(.check): \(.message)"'
else
  echo "✅ Custom validation passed"
fi

exit 0
