#!/usr/bin/env bash
# Validate log against type-specific rules and standards
# Usage: validate-rules.sh {log_path} {rules_path} {standards_path}
# Returns: JSON validation results

set -euo pipefail

LOG_PATH="${1:-}"
RULES_PATH="${2:-}"
STANDARDS_PATH="${3:-}"

# Validate inputs
if [[ -z "$LOG_PATH" ]] || [[ -z "$RULES_PATH" ]] || [[ -z "$STANDARDS_PATH" ]]; then
  echo "ERROR: Missing required arguments" >&2
  echo "Usage: validate-rules.sh {log_path} {rules_path} {standards_path}" >&2
  exit 1
fi

if [[ ! -f "$LOG_PATH" ]]; then
  echo "ERROR: Log file not found: $LOG_PATH" >&2
  exit 1
fi

if [[ ! -f "$RULES_PATH" ]]; then
  echo "ERROR: Rules file not found: $RULES_PATH" >&2
  exit 1
fi

if [[ ! -f "$STANDARDS_PATH" ]]; then
  echo "ERROR: Standards file not found: $STANDARDS_PATH" >&2
  exit 1
fi

# Initialize results
declare -a ERRORS=()
declare -a WARNINGS=()
declare -a INFO=()

# Read log content
LOG_CONTENT=$(cat "$LOG_PATH")

# Extract frontmatter (between first two --- markers)
FRONTMATTER=$(awk '/^---$/{if(++n==2)exit;next}n==1' "$LOG_PATH")

# Extract body (after second --- marker)
BODY=$(awk '/^---$/{n++}n==2' "$LOG_PATH")

# Check for MUST have requirements (✅) in rules
MUST_RULES=$(grep -E '^✅.*\*\*MUST' "$RULES_PATH" || true)

while IFS= read -r rule; do
  if [[ -z "$rule" ]]; then continue; fi

  # Extract requirement description
  REQUIREMENT=$(echo "$rule" | sed -E 's/^✅[[:space:]]*\*\*MUST[^*]*\*\*[[:space:]]*//')

  # Check for section requirements (e.g., "MUST have Test Results section")
  if echo "$REQUIREMENT" | grep -qi "section"; then
    SECTION_NAME=$(echo "$REQUIREMENT" | grep -oE '[A-Z][a-z]+( [A-Z][a-z]+)*' | head -1)
    if [[ -n "$SECTION_NAME" ]] && ! echo "$BODY" | grep -qi "^##.*$SECTION_NAME"; then
      ERRORS+=("{\"severity\":\"critical\",\"check\":\"rules.required_sections\",\"message\":\"Missing required section: $SECTION_NAME\",\"location\":\"body\"}")
    fi
  fi

  # Check for redaction requirements
  if echo "$REQUIREMENT" | grep -qi "redact"; then
    # Check for common secret patterns that should be redacted
    if echo "$LOG_CONTENT" | grep -qiE '(api[_-]?key|password|secret|token)[[:space:]]*[:=][[:space:]]*[^[]'; then
      # Check if they're actually redacted
      if ! echo "$LOG_CONTENT" | grep -q '\[REDACTED'; then
        ERRORS+=("{\"severity\":\"critical\",\"check\":\"rules.redaction\",\"message\":\"Unredacted secrets detected - must apply redaction\",\"location\":\"content\"}")
      fi
    fi
  fi
done <<< "$MUST_RULES"

# Check for SHOULD have requirements (⚠️) in rules
SHOULD_RULES=$(grep -E '^⚠️.*\*\*SHOULD' "$RULES_PATH" || true)

while IFS= read -r rule; do
  if [[ -z "$rule" ]]; then continue; fi

  REQUIREMENT=$(echo "$rule" | sed -E 's/^⚠️[[:space:]]*\*\*SHOULD[^*]*\*\*[[:space:]]*//')

  # Check for recommended sections
  if echo "$REQUIREMENT" | grep -qi "section"; then
    SECTION_NAME=$(echo "$REQUIREMENT" | grep -oE '[A-Z][a-z]+( [A-Z][a-z]+)*' | head -1)
    if [[ -n "$SECTION_NAME" ]] && ! echo "$BODY" | grep -qi "^##.*$SECTION_NAME"; then
      WARNINGS+=("{\"severity\":\"warning\",\"check\":\"rules.recommended_sections\",\"message\":\"Missing recommended section: $SECTION_NAME\",\"location\":\"body\"}")
    fi
  fi
done <<< "$SHOULD_RULES"

# Check required sections from standards.md
REQUIRED_SECTIONS=$(grep -E '^-.*\(.*\)$' "$STANDARDS_PATH" | head -10 || true)

while IFS= read -r section_line; do
  if [[ -z "$section_line" ]]; then continue; fi

  # Extract section name (text before parenthesis)
  SECTION=$(echo "$section_line" | sed -E 's/^-[[:space:]]*//' | sed -E 's/[[:space:]]*\(.*//')

  if [[ -n "$SECTION" ]] && ! echo "$BODY" | grep -qi "^##.*$SECTION"; then
    INFO+=("{\"severity\":\"info\",\"check\":\"standards.sections\",\"message\":\"Consider adding section: $SECTION\",\"location\":\"body\"}")
  fi
done <<< "$REQUIRED_SECTIONS"

# Build JSON output
ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -s '.' 2>/dev/null || echo '[]')
WARNINGS_JSON=$(printf '%s\n' "${WARNINGS[@]}" | jq -s '.' 2>/dev/null || echo '[]')
INFO_JSON=$(printf '%s\n' "${INFO[@]}" | jq -s '.' 2>/dev/null || echo '[]')

ERROR_COUNT=$(echo "$ERRORS_JSON" | jq 'length')
WARNING_COUNT=$(echo "$WARNINGS_JSON" | jq 'length')
INFO_COUNT=$(echo "$INFO_JSON" | jq 'length')

if [[ $ERROR_COUNT -gt 0 ]]; then
  STATUS="failed"
elif [[ $WARNING_COUNT -gt 0 ]]; then
  STATUS="warnings"
else
  STATUS="passed"
fi

cat <<EOF
{
  "status": "$STATUS",
  "errors": $ERRORS_JSON,
  "warnings": $WARNINGS_JSON,
  "info": $INFO_JSON,
  "summary": {
    "critical_errors": $ERROR_COUNT,
    "warnings": $WARNING_COUNT,
    "info": $INFO_COUNT
  }
}
EOF

# Exit with appropriate code
if [[ $ERROR_COUNT -gt 0 ]]; then
  exit 1
else
  exit 0
fi
