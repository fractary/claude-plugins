#!/usr/bin/env bash
# Analyze validation errors and categorize by fix strategy
# Usage: analyze-fixes.sh {validation_errors_json}
# Returns: Fix recommendations JSON

set -euo pipefail

ERRORS_JSON="${1:-[]}"

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 1
fi

# Categorize errors by fix strategy
AUTO_FIXABLE=$(echo "$ERRORS_JSON" | jq '[.[] | select(.severity == "warning" and (.check | contains("optional") or contains("format")))]')
SEMI_AUTO=$(echo "$ERRORS_JSON" | jq '[.[] | select(.check | contains("redaction"))]')
MANUAL=$(echo "$ERRORS_JSON" | jq '[.[] | select(.severity == "critical" and (.check | contains("required") or contains("schema")))]')

AUTO_COUNT=$(echo "$AUTO_FIXABLE" | jq 'length')
SEMI_COUNT=$(echo "$SEMI_AUTO" | jq 'length')
MANUAL_COUNT=$(echo "$MANUAL" | jq 'length')

cat <<EOF
{
  "auto_fixable": $AUTO_FIXABLE,
  "semi_auto": $SEMI_AUTO,
  "manual": $MANUAL,
  "summary": {
    "auto_fixable_count": $AUTO_COUNT,
    "semi_auto_count": $SEMI_COUNT,
    "manual_count": $MANUAL_COUNT,
    "total": $((AUTO_COUNT + SEMI_COUNT + MANUAL_COUNT))
  },
  "recommendation": "$(if [[ $MANUAL_COUNT -gt 0 ]]; then echo "Manual intervention required"; elif [[ $SEMI_COUNT -gt 0 ]]; then echo "User confirmation needed"; else echo "Can auto-fix"; fi)"
}
EOF
