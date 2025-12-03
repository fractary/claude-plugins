#!/bin/bash
set -euo pipefail

# detect-workflow-logging.sh
# Detect missing workflow event logging in manager agents (AGT-005)
# Manager agents MUST emit structured workflow events for cross-project visibility

PROJECT_PATH="${1:-.}"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required but not installed"}'
  exit 1
fi

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  jq -n '{status: "error", error: "invalid_project", message: ".claude/ directory not found"}'
  exit 1
fi

# Workflow logging indicators to detect in manager files
# These patterns indicate the agent implements workflow event emission per AGT-005
LOGGING_PATTERNS=(
  "workflow-event-emitter"
  "emit_workflow_event"
  "emit_event"
  "EVENT_EMISSION"
  "workflow_start"
  "workflow_complete"
  "artifact_create"
  "fractary-logs"
  "log-manager"
  "<LOGGING>"
  "WORKFLOW_EVENT"
)

# THRESHOLD RATIONALE:
# We require at least 2 logging-related patterns to consider an agent compliant.
# Why 2? A compliant manager should have:
#   1. A reference to the logging mechanism (e.g., "workflow-event-emitter", "fractary-logs")
#   2. At least one event type (e.g., "workflow_start", "workflow_complete")
# A single match could be incidental (e.g., documentation mentioning logging).
# Two matches indicate intentional implementation.
COMPLIANCE_THRESHOLD=2

COMPLIANT_MANAGERS=()
NON_COMPLIANT_MANAGERS=()
DETAILS=()

# Find all manager agents
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    # Check if this is a manager agent
    # Detection criteria:
    #   1. Name contains "manager" (most reliable)
    #   2. File explicitly mentions "Manager-as-Agent" pattern or "manager agent"
    # Note: Avoided broad patterns like "orchestrat*" which could match documentation
    is_manager=false
    if [[ "$agent_name" == *"-manager"* ]] || [[ "$agent_name" == *"manager-"* ]]; then
      is_manager=true
    elif grep -qiE "Manager-as-Agent|manager[[:space:]]+agent" "$agent_file" 2>/dev/null; then
      is_manager=true
    fi

    if [[ "$is_manager" == "true" ]]; then
      # Check for workflow logging patterns
      match_count=0
      matched_patterns=()

      for pattern in "${LOGGING_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$agent_file" 2>/dev/null; then
          match_count=$((match_count + 1))
          matched_patterns+=("$pattern")
        fi
      done

      # Check against compliance threshold (see THRESHOLD RATIONALE above)
      if [[ $match_count -ge $COMPLIANCE_THRESHOLD ]]; then
        COMPLIANT_MANAGERS+=("$agent_name")
      else
        NON_COMPLIANT_MANAGERS+=("$agent_name")

        # Build matched patterns JSON array
        if [[ ${#matched_patterns[@]} -gt 0 ]]; then
          patterns_json=$(printf ',"%s"' "${matched_patterns[@]}")
          patterns_json="[${patterns_json:1}]"
        else
          patterns_json="[]"
        fi

        detail=$(cat <<DETAIL
{
  "name": "$agent_name",
  "location": "$agent_file",
  "rule_id": "AGT-005",
  "rule_name": "Manager emits workflow events",
  "severity": "warning",
  "evidence": "Manager agent lacks workflow event emission (found $match_count of ${#LOGGING_PATTERNS[@]} logging patterns)",
  "found_patterns": $patterns_json,
  "required_patterns": ["workflow-event-emitter OR <EVENT_EMISSION>", "workflow_start", "workflow_complete"],
  "remediation": [
    "Add <EVENT_EMISSION> section to manager agent",
    "Emit workflow_start at workflow initialization",
    "Emit artifact_create when outputs created",
    "Emit workflow_complete at workflow end",
    "Reference fractary-logs:workflow-event-emitter skill"
  ]
}
DETAIL
)
        DETAILS+=("$detail")
      fi
    fi
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Also check skills that might be acting as managers (they shouldn't, but check anyway)
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")

    # Check if this skill has manager-like characteristics (should be an agent)
    if [[ "$skill_name" == *"-manager"* ]] || [[ "$skill_name" == *"manager-"* ]]; then
      NON_COMPLIANT_MANAGERS+=("$skill_name (skill)")

      detail=$(cat <<DETAIL
{
  "name": "$skill_name",
  "location": "$skill_file",
  "rule_id": "AGT-005",
  "rule_name": "Manager emits workflow events",
  "severity": "critical",
  "evidence": "Manager is implemented as a Skill instead of an Agent - cannot emit workflow events properly",
  "found_patterns": [],
  "required_patterns": ["Must be Agent, not Skill"],
  "remediation": [
    "CRITICAL: Convert skill to agent first",
    "Move from skills/ to agents/",
    "Then add workflow event emission"
  ]
}
DETAIL
)
      DETAILS+=("$detail")
    fi
  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

# Build output
TOTAL_MANAGERS=$((${#COMPLIANT_MANAGERS[@]} + ${#NON_COMPLIANT_MANAGERS[@]}))
VIOLATIONS_FOUND=false
if [[ ${#NON_COMPLIANT_MANAGERS[@]} -gt 0 ]]; then
  VIOLATIONS_FOUND=true
fi

# Build details JSON array
DETAILS_JSON="["
if [[ ${#DETAILS[@]} -gt 0 ]]; then
  first=true
  for detail in "${DETAILS[@]}"; do
    if [[ "$first" == "true" ]]; then
      DETAILS_JSON+="$detail"
      first=false
    else
      DETAILS_JSON+=",$detail"
    fi
  done
fi
DETAILS_JSON+="]"

# Build compliant list
COMPLIANT_JSON="["
if [[ ${#COMPLIANT_MANAGERS[@]} -gt 0 ]]; then
  first=true
  for manager in "${COMPLIANT_MANAGERS[@]}"; do
    if [[ "$first" == "true" ]]; then
      COMPLIANT_JSON+="\"$manager\""
      first=false
    else
      COMPLIANT_JSON+=",\"$manager\""
    fi
  done
fi
COMPLIANT_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "rule_id": "AGT-005",
  "rule_name": "Manager emits workflow events",
  "total_managers": $TOTAL_MANAGERS,
  "compliant_count": ${#COMPLIANT_MANAGERS[@]},
  "non_compliant_count": ${#NON_COMPLIANT_MANAGERS[@]},
  "violations_found": $VIOLATIONS_FOUND,
  "compliant_managers": $COMPLIANT_JSON,
  "details": $DETAILS_JSON
}
EOF
