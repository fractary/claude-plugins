#!/bin/bash
set -euo pipefail

# detect-director-patterns.sh
# Detect missing director command patterns (ARC-004, ARC-005)
# Director commands should support:
# - Multi-step action arguments (comma-separated)
# - Standard --agent <workflow_steps> format

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

# Patterns that indicate multi-step action support
MULTI_STEP_PATTERNS=(
  'comma.separated'
  'comma-separated'
  'multiple.steps'
  'multi-step'
  'action.*,.*action'
  'step1,step2'
  'split.*,'
  'parse.*,'
  '--action.*<.*,.*>'
)

# Patterns that indicate standard --agent format
AGENT_FORMAT_PATTERNS=(
  '--agent'
  'agent.*<.*steps'
  'workflow_steps'
  '--steps'
)

# Patterns that indicate --action is supported
ACTION_PATTERNS=(
  '--action'
  '-a\s'
  'action.*parameter'
  'action.*argument'
)

FINDINGS=()
COMPLIANT_DIRECTORS=()
NON_COMPLIANT_DIRECTORS=()

# Find all director-related files (commands and skills)
find_director_files() {
  local search_path="$1"
  local pattern="$2"

  if [[ -d "$search_path" ]]; then
    find "$search_path" -type f -name "*director*" -name "*.md" -print0 2>/dev/null || true
    find "$search_path" -type f -name "*direct*" -name "*.md" -print0 2>/dev/null || true
  fi
}

# Check both commands and skills directories
for dir in "$PROJECT_PATH/.claude/commands" "$PROJECT_PATH/.claude/skills"; do
  if [[ ! -d "$dir" ]]; then
    continue
  fi

  while IFS= read -r -d '' file; do
    if [[ -z "$file" ]]; then
      continue
    fi

    file_name=$(basename "$file" .md)

    # Check for multi-step action support
    has_multi_step=false
    for pattern in "${MULTI_STEP_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$file" 2>/dev/null; then
        has_multi_step=true
        break
      fi
    done

    # Check for --agent format support
    has_agent_format=false
    for pattern in "${AGENT_FORMAT_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$file" 2>/dev/null; then
        has_agent_format=true
        break
      fi
    done

    # Check if --action is documented
    has_action=false
    for pattern in "${ACTION_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$file" 2>/dev/null; then
        has_action=true
        break
      fi
    done

    # Determine compliance
    issues=()
    if [[ "$has_action" == "false" ]]; then
      issues+=("Missing --action argument documentation")
    fi
    if [[ "$has_action" == "true" && "$has_multi_step" == "false" ]]; then
      issues+=("--action does not support comma-separated multi-step values")
    fi
    if [[ "$has_agent_format" == "false" ]]; then
      issues+=("Missing --agent <workflow_steps> format (recommended)")
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
      COMPLIANT_DIRECTORS+=("$file_name")
    elif [[ ${#issues[@]} -lt 3 ]]; then
      # Partial compliance - warning level
      NON_COMPLIANT_DIRECTORS+=("$file_name")

      issues_json=$(printf ',"%s"' "${issues[@]}")
      issues_json="[${issues_json:1}]"

      detail=$(cat <<DETAIL
{
  "name": "$file_name",
  "location": "$file",
  "rule_id": "ARC-004",
  "rule_name": "Director argument patterns",
  "severity": "info",
  "has_action": $has_action,
  "has_multi_step": $has_multi_step,
  "has_agent_format": $has_agent_format,
  "issues": $issues_json,
  "remediation": [
    "Add --action argument that accepts comma-separated step names",
    "Document multi-step support: --action step1,step2,step3",
    "Consider adding --agent <workflow_steps> format for clarity"
  ],
  "example": "--action frame,architect,build OR --agent frame,architect"
}
DETAIL
)
      FINDINGS+=("$detail")
    else
      # Major non-compliance - warning level
      NON_COMPLIANT_DIRECTORS+=("$file_name")

      issues_json=$(printf ',"%s"' "${issues[@]}")
      issues_json="[${issues_json:1}]"

      detail=$(cat <<DETAIL
{
  "name": "$file_name",
  "location": "$file",
  "rule_id": "ARC-004",
  "rule_name": "Director argument patterns",
  "severity": "warning",
  "has_action": $has_action,
  "has_multi_step": $has_multi_step,
  "has_agent_format": $has_agent_format,
  "issues": $issues_json,
  "remediation": [
    "Add --action argument that accepts comma-separated step names",
    "Document multi-step support: --action step1,step2,step3",
    "Consider adding --agent <workflow_steps> format for clarity"
  ],
  "example": "--action frame,architect,build OR --agent frame,architect"
}
DETAIL
)
      FINDINGS+=("$detail")
    fi
  done < <(find "$dir" -type f \( -name "*director*" -o -name "*direct*" \) -name "*.md" -print0 2>/dev/null || true)
done

# Also check for SKILL.md files in director skill directories
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_dir; do
    if [[ -z "$skill_dir" ]]; then
      continue
    fi

    skill_name=$(basename "$skill_dir")
    skill_file="$skill_dir/SKILL.md"

    if [[ ! -f "$skill_file" ]]; then
      continue
    fi

    # Check for multi-step action support
    has_multi_step=false
    for pattern in "${MULTI_STEP_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$skill_file" 2>/dev/null; then
        has_multi_step=true
        break
      fi
    done

    # Check for --agent format support
    has_agent_format=false
    for pattern in "${AGENT_FORMAT_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$skill_file" 2>/dev/null; then
        has_agent_format=true
        break
      fi
    done

    # Check if --action is documented
    has_action=false
    for pattern in "${ACTION_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$skill_file" 2>/dev/null; then
        has_action=true
        break
      fi
    done

    # Determine compliance
    issues=()
    if [[ "$has_action" == "false" ]]; then
      issues+=("Missing --action argument documentation")
    fi
    if [[ "$has_action" == "true" && "$has_multi_step" == "false" ]]; then
      issues+=("--action does not support comma-separated multi-step values")
    fi

    if [[ ${#issues[@]} -eq 0 ]]; then
      COMPLIANT_DIRECTORS+=("$skill_name")
    elif [[ ${#issues[@]} -gt 0 ]]; then
      NON_COMPLIANT_DIRECTORS+=("$skill_name")

      issues_json=$(printf ',"%s"' "${issues[@]}")
      issues_json="[${issues_json:1}]"

      detail=$(cat <<DETAIL
{
  "name": "$skill_name",
  "location": "$skill_file",
  "rule_id": "ARC-004",
  "rule_name": "Director argument patterns",
  "severity": "info",
  "has_action": $has_action,
  "has_multi_step": $has_multi_step,
  "has_agent_format": $has_agent_format,
  "issues": $issues_json,
  "remediation": [
    "Add --action argument that accepts comma-separated step names",
    "Document multi-step support: --action step1,step2,step3"
  ],
  "example": "--action frame,architect,build"
}
DETAIL
)
      FINDINGS+=("$detail")
    fi
  done < <(find "$PROJECT_PATH/.claude/skills" -maxdepth 1 -type d \( -name "*director*" -o -name "*direct*" \) -print0 2>/dev/null || true)
fi

# Build output
TOTAL_DIRECTORS=$((${#COMPLIANT_DIRECTORS[@]} + ${#NON_COMPLIANT_DIRECTORS[@]}))
VIOLATIONS_FOUND=false
if [[ ${#NON_COMPLIANT_DIRECTORS[@]} -gt 0 ]]; then
  VIOLATIONS_FOUND=true
fi

# Build details JSON array
DETAILS_JSON="["
if [[ ${#FINDINGS[@]} -gt 0 ]]; then
  first=true
  for detail in "${FINDINGS[@]}"; do
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
if [[ ${#COMPLIANT_DIRECTORS[@]} -gt 0 ]]; then
  first=true
  for dir in "${COMPLIANT_DIRECTORS[@]}"; do
    if [[ "$first" == "true" ]]; then
      COMPLIANT_JSON+="\"$dir\""
      first=false
    else
      COMPLIANT_JSON+=",\"$dir\""
    fi
  done
fi
COMPLIANT_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "rule_id": "ARC-004",
  "rule_name": "Director argument patterns",
  "description": "Director commands should support multi-step actions and standard argument formats",
  "total_directors": $TOTAL_DIRECTORS,
  "compliant_count": ${#COMPLIANT_DIRECTORS[@]},
  "non_compliant_count": ${#NON_COMPLIANT_DIRECTORS[@]},
  "violations_found": $VIOLATIONS_FOUND,
  "compliant_directors": $COMPLIANT_JSON,
  "details": $DETAILS_JSON
}
EOF
