#!/bin/bash
set -euo pipefail

# manager-agent-validator.sh
# Validates Manager agent follows Manager-as-Agent pattern

AGENT_FILE="${1:?Error: Agent file path required}"

# Validate file exists
if [[ ! -f "$AGENT_FILE" ]]; then
  echo '{"status": "error", "error": "file_not_found", "file": "'"$AGENT_FILE"'"}'
  exit 1
fi

# Initialize results
IS_AGENT=false
LOCATION_CORRECT=false
HAS_BASH=false
HAS_SKILL=false
HAS_READ=false
HAS_WRITE=false
HAS_GLOB=false
HAS_GREP=false
HAS_ASK_USER=false
HAS_FRONTMATTER=false
HAS_CONTEXT=false
HAS_CRITICAL_RULES=false
HAS_WORKFLOW=false
HAS_PHASES=false
ISSUES=()
WARNINGS=()

# Check location (should be in agents/ directory)
if [[ "$AGENT_FILE" == *"/agents/"* ]]; then
  LOCATION_CORRECT=true
  IS_AGENT=true
else
  LOCATION_CORRECT=false
  ISSUES+=('{"type": "wrong_location", "severity": "critical", "message": "Manager not in agents/ directory", "fix": "Move to agents/ directory"}')
fi

# Extract frontmatter tools
if grep -q "^---$" "$AGENT_FILE"; then
  HAS_FRONTMATTER=true

  # Extract tools line from frontmatter
  TOOLS_LINE=$(awk '/^---$/,/^---$/ {if ($1 == "tools:") print}' "$AGENT_FILE" | head -1)

  # Check for required tools
  if echo "$TOOLS_LINE" | grep -qi "bash"; then HAS_BASH=true; fi
  if echo "$TOOLS_LINE" | grep -qi "skill"; then HAS_SKILL=true; fi
  if echo "$TOOLS_LINE" | grep -qi "read"; then HAS_READ=true; fi
  if echo "$TOOLS_LINE" | grep -qi "write"; then HAS_WRITE=true; fi
  if echo "$TOOLS_LINE" | grep -qi "glob"; then HAS_GLOB=true; fi
  if echo "$TOOLS_LINE" | grep -qi "grep"; then HAS_GREP=true; fi
  if echo "$TOOLS_LINE" | grep -qi "askuserquestion"; then HAS_ASK_USER=true; fi
fi

# Build missing tools list
MISSING_TOOLS=()
if [[ "$HAS_BASH" == "false" ]]; then MISSING_TOOLS+=("Bash"); fi
if [[ "$HAS_SKILL" == "false" ]]; then MISSING_TOOLS+=("Skill"); fi
if [[ "$HAS_READ" == "false" ]]; then MISSING_TOOLS+=("Read"); fi
if [[ "$HAS_WRITE" == "false" ]]; then MISSING_TOOLS+=("Write"); fi
if [[ "$HAS_GLOB" == "false" ]]; then MISSING_TOOLS+=("Glob"); fi
if [[ "$HAS_GREP" == "false" ]]; then MISSING_TOOLS+=("Grep"); fi
if [[ "$HAS_ASK_USER" == "false" ]]; then MISSING_TOOLS+=("AskUserQuestion"); fi

ALL_TOOLS_PRESENT=true
if [[ ${#MISSING_TOOLS[@]} -gt 0 ]]; then
  ALL_TOOLS_PRESENT=false
  MISSING_TOOLS_STR=$(IFS=, ; echo "${MISSING_TOOLS[*]}")
  ISSUES+=('{"type": "missing_tool_access", "severity": "critical", "message": "Manager missing critical tools: '"$MISSING_TOOLS_STR"'", "fix": "Add missing tools to frontmatter"}')
fi

# Check XML markup
if grep -q "<CONTEXT>" "$AGENT_FILE"; then HAS_CONTEXT=true; fi
if grep -q "<CRITICAL_RULES>" "$AGENT_FILE"; then HAS_CRITICAL_RULES=true; fi
if grep -q "<WORKFLOW>" "$AGENT_FILE"; then HAS_WORKFLOW=true; fi

# Check for phases
if grep -q "Phase [0-9]:" "$AGENT_FILE"; then HAS_PHASES=true; fi

# Check for Manager-as-Skill anti-pattern (Manager in skills/ directory)
if [[ "$AGENT_FILE" == *"/skills/"* ]]; then
  IS_AGENT=false
  ISSUES+=('{"type": "manager_as_skill", "severity": "critical", "message": "Manager implemented as Skill (anti-pattern)", "fix": "Move to agents/ directory and ensure full tool access"}')
fi

# Build issues JSON array
ISSUES_JSON="["
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  FIRST=true
  for issue in "${ISSUES[@]}"; do
    if [[ "$FIRST" == "true" ]]; then
      ISSUES_JSON+="$issue"
      FIRST=false
    else
      ISSUES_JSON+=",

$issue"
    fi
  done
fi
ISSUES_JSON+="]"

# Build warnings JSON array
WARNINGS_JSON="["
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  FIRST=true
  for warning in "${WARNINGS[@]}"; do
    if [[ "$FIRST" == "true" ]]; then
      WARNINGS_JSON+="$warning"
      FIRST=false
    else
      WARNINGS_JSON+=",$warning"
    fi
  done
fi
WARNINGS_JSON+="]"

# Determine pass/fail
PASSED=true
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  PASSED=false
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "file": "$AGENT_FILE",
  "validation": {
    "is_agent": $IS_AGENT,
    "location_correct": $LOCATION_CORRECT,
    "tool_access": {
      "has_bash": $HAS_BASH,
      "has_skill": $HAS_SKILL,
      "has_read": $HAS_READ,
      "has_write": $HAS_WRITE,
      "has_glob": $HAS_GLOB,
      "has_grep": $HAS_GREP,
      "has_ask_user": $HAS_ASK_USER,
      "all_tools_present": $ALL_TOOLS_PRESENT
    },
    "structure": {
      "has_frontmatter": $HAS_FRONTMATTER,
      "has_context": $HAS_CONTEXT,
      "has_critical_rules": $HAS_CRITICAL_RULES,
      "has_workflow": $HAS_WORKFLOW,
      "has_phases": $HAS_PHASES
    },
    "xml_markup": {
      "has_context": $HAS_CONTEXT,
      "has_critical_rules": $HAS_CRITICAL_RULES,
      "has_workflow": $HAS_WORKFLOW,
      "all_markup_present": $([ "$HAS_CONTEXT" == "true" ] && [ "$HAS_CRITICAL_RULES" == "true" ] && [ "$HAS_WORKFLOW" == "true" ] && echo "true" || echo "false")
    },
    "pattern_compliance": {
      "manager_pattern": $([ "$IS_AGENT" == "true" ] && [ "$ALL_TOOLS_PRESENT" == "true" ] && echo "true" || echo "false")
    }
  },
  "issues": $ISSUES_JSON,
  "warnings": $WARNINGS_JSON,
  "passed": $PASSED
}
EOF
