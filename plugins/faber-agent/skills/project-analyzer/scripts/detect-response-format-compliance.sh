#!/bin/bash
set -euo pipefail

# detect-response-format-compliance.sh
# Detect skills that don't follow FABER response format standards (RESP-001)
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

# Check skill compliance
check_skill_outputs() {
  local skill_md="$1"

  if [[ ! -f "$skill_md" ]]; then
    echo "no_skill_md"
    return
  fi

  local content
  content=$(cat "$skill_md")

  # Check for <OUTPUTS> section
  if ! grep -q '<OUTPUTS>' <<< "$content"; then
    echo "no_outputs_section"
    return
  fi

  # Check for standard response format reference
  local has_format_ref=false
  if grep -q 'RESPONSE-FORMAT.md' <<< "$content" || \
     grep -qi 'standard FABER response format' <<< "$content"; then
    has_format_ref=true
  fi

  # Check for status field in examples
  local has_status=false
  if grep -qE '"status"[[:space:]]*:[[:space:]]*"(success|warning|failure)"' <<< "$content"; then
    has_status=true
  fi

  # Check for message field
  local has_message=false
  if grep -q '"message":' <<< "$content"; then
    has_message=true
  fi

  # Check for details field
  local has_details=false
  if grep -q '"details":' <<< "$content"; then
    has_details=true
  fi

  # Check for errors/warnings arrays
  local has_error_handling=false
  if grep -q '"errors":' <<< "$content" || grep -q '"warnings":' <<< "$content"; then
    has_error_handling=true
  fi

  # Determine compliance level (strict criteria)
  if [[ "$has_format_ref" == "true" ]] && \
     [[ "$has_status" == "true" ]] && \
     [[ "$has_message" == "true" ]] && \
     [[ "$has_details" == "true" ]] && \
     [[ "$has_error_handling" == "true" ]]; then
    echo "compliant"
  elif [[ "$has_status" == "true" ]] && [[ "$has_message" == "true" ]]; then
    echo "partial"
  elif [[ "$has_status" == "true" ]]; then
    echo "partial"
  else
    echo "non_compliant"
  fi
}

# Initialize counters
TOTAL_SKILLS=0
COMPLIANT_SKILLS=0
PARTIAL_SKILLS=0
NON_COMPLIANT_SKILLS=0

# Initialize violations array
declare -a VIOLATIONS_JSON=()

# Scan all skills
for plugin_dir in "$PLUGINS_DIR"/*/; do
  [[ -d "$plugin_dir" ]] || continue

  plugin_name=$(basename "$plugin_dir")
  skills_dir="${plugin_dir}skills"

  [[ -d "$skills_dir" ]] || continue

  for skill_dir in "$skills_dir"/*/; do
    [[ -d "$skill_dir" ]] || continue

    skill_name=$(basename "$skill_dir")
    skill_md="${skill_dir}SKILL.md"

    # Skip if no SKILL.md
    [[ -f "$skill_md" ]] || continue

    ((TOTAL_SKILLS++)) || true

    result=$(check_skill_outputs "$skill_md")

    case "$result" in
      "compliant")
        ((COMPLIANT_SKILLS++)) || true
        ;;
      "partial")
        ((PARTIAL_SKILLS++)) || true
        # Add to violations with partial missing fields
        VIOLATIONS_JSON+=("{\"skill\":\"${plugin_name}/${skill_name}\",\"compliance\":\"partial\",\"missing\":[\"errors array example\",\"warnings array example\"],\"message\":\"Partially compliant\"}")
        ;;
      "non_compliant"|"no_outputs_section")
        ((NON_COMPLIANT_SKILLS++)) || true
        # Add to violations with full missing fields
        VIOLATIONS_JSON+=("{\"skill\":\"${plugin_name}/${skill_name}\",\"compliance\":\"non_compliant\",\"missing\":[\"status field\",\"message field\",\"details object\",\"RESPONSE-FORMAT.md reference\",\"errors/warnings arrays\"],\"message\":\"Missing standard format\"}")
        ;;
    esac
  done
done

# Build violations JSON array
if [[ ${#VIOLATIONS_JSON[@]} -gt 0 ]]; then
  VIOLATIONS_ARRAY=$(printf '%s\n' "${VIOLATIONS_JSON[@]}" | jq -s '.')
else
  VIOLATIONS_ARRAY="[]"
fi

# Output JSON result
jq -n \
  --arg detection "response-format-compliance" \
  --arg code "RESP-001" \
  --arg severity "warning" \
  --argjson non_compliant_count "$NON_COMPLIANT_SKILLS" \
  --argjson skills_checked "$TOTAL_SKILLS" \
  --argjson compliant "$COMPLIANT_SKILLS" \
  --argjson partial "$PARTIAL_SKILLS" \
  --argjson non_compliant "$NON_COMPLIANT_SKILLS" \
  --argjson violations "$VIOLATIONS_ARRAY" \
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

# Optional fix mode
if [[ "$FIX_MODE" == "true" ]] && [[ "$NON_COMPLIANT_SKILLS" -gt 0 ]]; then
  VALIDATOR_SCRIPT="$PROJECT_PATH/scripts/validate-skill-responses.sh"
  if [[ -x "$VALIDATOR_SCRIPT" ]]; then
    echo "" >&2
    echo "Running fix mode..." >&2
    PLUGINS_DIR="$PLUGINS_DIR" "$VALIDATOR_SCRIPT" --fix >/dev/null 2>&1 || true
    echo "Fix mode complete. Re-run detection to verify changes." >&2
  fi
fi
