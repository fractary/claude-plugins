#!/bin/bash
set -euo pipefail

# detect-response-format-compliance.sh
# Detect skills that don't follow FABER response format standards (RESP-001)
#
# WRAPPER APPROACH: This script wraps scripts/validate-skill-responses.sh with --json
# and transforms its output to match the project-analyzer detection format.
# This maintains a single source of truth for validation logic.
#
# Usage: ./detect-response-format-compliance.sh <project_path> [--fix]
#
# Output: JSON matching project-analyzer detection format with non_compliant_count at root
#
# Compliance criteria (strict - all required for "compliant"):
#   - Has <OUTPUTS> section
#   - Documents status field (success/warning/failure)
#   - Documents message field
#   - Documents details object
#   - References RESPONSE-FORMAT.md or "standard FABER response format"
#   - Documents errors/warnings arrays

PROJECT_PATH="${1:-.}"
FIX_MODE=false

# Parse optional --fix flag
shift || true
for arg in "$@"; do
  case $arg in
    --fix)
      FIX_MODE=true
      ;;
  esac
done

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required but not installed"}'
  exit 1
fi

# Find the validation script
# Script location: plugins/faber-agent/skills/project-analyzer/scripts/
# Validator location: scripts/validate-skill-responses.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$SCRIPT_DIR/../../../../.."
VALIDATOR_SCRIPT="$REPO_ROOT/scripts/validate-skill-responses.sh"

# Try alternative paths for different execution contexts
if [[ ! -x "$VALIDATOR_SCRIPT" ]]; then
  VALIDATOR_SCRIPT="$PROJECT_PATH/scripts/validate-skill-responses.sh"
fi

if [[ ! -x "$VALIDATOR_SCRIPT" ]]; then
  echo '{"status": "error", "error": "missing_validator", "message": "validate-skill-responses.sh not found or not executable"}'
  exit 1
fi

# Check if plugins directory exists
PLUGINS_DIR="$PROJECT_PATH/plugins"
if [[ ! -d "$PLUGINS_DIR" ]]; then
  jq -n '{
    status: "success",
    detection: "response-format-compliance",
    code: "RESP-001",
    severity: "warning",
    non_compliant_count: 0,
    summary: {
      skills_checked: 0,
      compliant: 0,
      partial: 0,
      non_compliant: 0
    },
    violations: [],
    recommendation: "See docs/MIGRATE-SKILL-RESPONSES.md for migration guide"
  }'
  exit 0
fi

# Run the validation script with --json flag (WRAPPER APPROACH)
# The validator uses PLUGINS_DIR env var to locate plugins
VALIDATION_OUTPUT=$(PLUGINS_DIR="$PLUGINS_DIR" "$VALIDATOR_SCRIPT" --json 2>/dev/null || true)

# Validate JSON output
if ! echo "$VALIDATION_OUTPUT" | jq -e . >/dev/null 2>&1; then
  echo '{"status": "error", "error": "invalid_validator_output", "message": "validate-skill-responses.sh returned invalid JSON"}'
  exit 1
fi

# Extract counts from validation output
SKILLS_CHECKED=$(echo "$VALIDATION_OUTPUT" | jq -r '.summary.total // 0')
COMPLIANT_COUNT=$(echo "$VALIDATION_OUTPUT" | jq -r '.summary.compliant // 0')
PARTIAL_COUNT=$(echo "$VALIDATION_OUTPUT" | jq -r '.summary.partial // 0')
NON_COMPLIANT_COUNT=$(echo "$VALIDATION_OUTPUT" | jq -r '.summary.non_compliant // 0')

# Transform results to violations format with DYNAMIC missing fields
# Filter to only partial and non_compliant, derive missing fields from compliance message
VIOLATIONS=$(echo "$VALIDATION_OUTPUT" | jq '
  [.results[]
   | select(.compliance != "compliant" and .compliance != "skip")
   | {
       skill: "\(.plugin)/\(.skill)",
       compliance: .compliance,
       missing: (
         # Dynamic missing fields based on actual compliance status
         if .compliance == "non_compliant" then
           if .message | contains("Missing <OUTPUTS>") then
             ["<OUTPUTS> section"]
           else
             ["status field", "message field", "details object", "RESPONSE-FORMAT.md reference", "errors/warnings arrays"]
           end
         elif .compliance == "partial" then
           if .message | contains("missing_some_fields") then
             ["RESPONSE-FORMAT.md reference", "errors/warnings arrays"]
           elif .message | contains("missing_message_and_more") then
             ["message field", "details object", "RESPONSE-FORMAT.md reference", "errors/warnings arrays"]
           else
             ["some fields missing"]
           end
         else
           []
         end
       ),
       message: .message
     }
  ]
')

# Build output in project-analyzer format with non_compliant_count at root
jq -n \
  --arg detection "response-format-compliance" \
  --arg code "RESP-001" \
  --arg severity "warning" \
  --argjson non_compliant_count "$NON_COMPLIANT_COUNT" \
  --argjson skills_checked "$SKILLS_CHECKED" \
  --argjson compliant "$COMPLIANT_COUNT" \
  --argjson partial "$PARTIAL_COUNT" \
  --argjson non_compliant "$NON_COMPLIANT_COUNT" \
  --argjson violations "$VIOLATIONS" \
  '{
    status: "success",
    detection: $detection,
    code: $code,
    severity: $severity,
    non_compliant_count: $non_compliant_count,
    summary: {
      skills_checked: $skills_checked,
      compliant: $compliant,
      partial: $partial,
      non_compliant: $non_compliant
    },
    violations: $violations,
    recommendation: "See docs/MIGRATE-SKILL-RESPONSES.md for migration guide"
  }'

# Optional fix mode - invoke validator's fix capability
if [[ "$FIX_MODE" == "true" ]] && [[ "$NON_COMPLIANT_COUNT" -gt 0 ]]; then
  echo "" >&2
  echo "Running fix mode..." >&2
  PLUGINS_DIR="$PLUGINS_DIR" "$VALIDATOR_SCRIPT" --fix >/dev/null 2>&1 || true
  echo "Fix mode complete. Re-run detection to verify changes." >&2
fi
