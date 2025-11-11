#!/bin/bash
set -euo pipefail

# director-skill-validator.sh
# Validates Director skill is simple pattern expansion (no orchestration)

SKILL_FILE="${1:?Error: Skill file path required}"

# Validate file exists
if [[ ! -f "$SKILL_FILE" ]]; then
  echo '{"status": "error", "error": "file_not_found", "file": "'"$SKILL_FILE"'"}'
  exit 1
fi

# Initialize results
IS_SKILL=false
LOCATION_CORRECT=false
SIMPLE_INTERFACE=true
HAS_EXPAND_OPERATION=false
HAS_PARALLELISM_CALC=false
OPERATION_COUNT=0
HAS_ORCHESTRATION=false
HAS_WORKFLOW=false
HAS_STATE_MANAGEMENT=false
INVOKES_SKILLS=false
USES_ASK_USER=false
ISSUES=()
WARNINGS=()

# Check location (should be in skills/ directory)
if [[ "$SKILL_FILE" == *"/skills/"* ]] && [[ "$SKILL_FILE" == *"/SKILL.md" ]]; then
  LOCATION_CORRECT=true
  IS_SKILL=true
else
  LOCATION_CORRECT=false
  ISSUES+=('{"type": "wrong_location", "severity": "critical", "message": "Director not in skills/ directory", "fix": "Move to skills/{name}/SKILL.md"}')
fi

# Check for Director anti-patterns (orchestration logic)
if grep -qi "<WORKFLOW>" "$SKILL_FILE"; then
  HAS_WORKFLOW=true
  HAS_ORCHESTRATION=true
  ISSUES+=('{"type": "director_has_orchestration", "severity": "critical", "message": "Director has <WORKFLOW> section (anti-pattern)", "fix": "Remove orchestration logic. Director should only expand patterns."}')
fi

if grep -qi "Phase [0-9]:" "$SKILL_FILE"; then
  HAS_ORCHESTRATION=true
  ISSUES+=('{"type": "director_has_phases", "severity": "critical", "message": "Director has workflow phases (anti-pattern)", "fix": "Remove phases. Director should only expand patterns."}')
fi

if grep -qi "state_management\|workflow_state\|phases_completed" "$SKILL_FILE"; then
  HAS_STATE_MANAGEMENT=true
  HAS_ORCHESTRATION=true
  ISSUES+=('{"type": "director_has_state", "severity": "critical", "message": "Director manages workflow state (anti-pattern)", "fix": "Remove state management. Director is stateless."}')
fi

if grep -qi "@skill-\|Skill tool" "$SKILL_FILE"; then
  INVOKES_SKILLS=true
  WARNINGS+=('{"type": "director_invokes_skills", "severity": "medium", "message": "Director may be invoking other skills", "note": "Director should only expand patterns, not orchestrate skills"}')
fi

if grep -qi "AskUserQuestion" "$SKILL_FILE"; then
  USES_ASK_USER=true
  ISSUES+=('{"type": "director_uses_ask_user", "severity": "critical", "message": "Director uses AskUserQuestion (anti-pattern)", "fix": "Remove user interaction. Director is not an agent."}')
fi

# Check for required Director operations
if grep -qi "expand-to-batch\|expand.*batch" "$SKILL_FILE"; then
  HAS_EXPAND_OPERATION=true
  ((OPERATION_COUNT++))
fi

if grep -qi "calculate-parallelism\|parallelism" "$SKILL_FILE"; then
  HAS_PARALLELISM_CALC=true
  ((OPERATION_COUNT++))
fi

# Count total operations
TOTAL_OPERATIONS=$(grep -c "^## [a-z-]*$" "$SKILL_FILE" 2>/dev/null || echo "0")

# If has orchestration, not a simple interface
if [[ "$HAS_ORCHESTRATION" == "true" ]]; then
  SIMPLE_INTERFACE=false
fi

# Check if Director is in agents/ (anti-pattern)
if [[ "$SKILL_FILE" == *"/agents/"* ]]; then
  IS_SKILL=false
  ISSUES+=('{"type": "director_as_agent", "severity": "critical", "message": "Director implemented as Agent (anti-pattern)", "fix": "Move to skills/ directory. Director should be a Skill."}')
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
      ISSUES_JSON+=",$issue"
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
  "file": "$SKILL_FILE",
  "validation": {
    "is_skill": $IS_SKILL,
    "location_correct": $LOCATION_CORRECT,
    "simple_interface": $SIMPLE_INTERFACE,
    "operations": {
      "has_expand_operation": $HAS_EXPAND_OPERATION,
      "has_parallelism_calc": $HAS_PARALLELISM_CALC,
      "operation_count": $TOTAL_OPERATIONS
    },
    "anti_patterns": {
      "has_orchestration": $HAS_ORCHESTRATION,
      "has_workflow": $HAS_WORKFLOW,
      "has_state_management": $HAS_STATE_MANAGEMENT,
      "invokes_skills": $INVOKES_SKILLS,
      "uses_ask_user": $USES_ASK_USER
    },
    "pattern_compliance": {
      "director_pattern": $([ "$IS_SKILL" == "true" ] && [ "$SIMPLE_INTERFACE" == "true" ] && [ "$HAS_ORCHESTRATION" == "false" ] && echo "true" || echo "false"),
      "simple_expansion_only": $([ "$HAS_ORCHESTRATION" == "false" ] && echo "true" || echo "false")
    }
  },
  "issues": $ISSUES_JSON,
  "warnings": $WARNINGS_JSON,
  "passed": $PASSED
}
EOF
