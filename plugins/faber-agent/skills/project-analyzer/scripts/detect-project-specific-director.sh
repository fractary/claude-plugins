#!/bin/bash
set -euo pipefail

# detect-project-specific-director.sh
# Detect Project-Specific Director anti-pattern (ARC-006 - ERROR severity)
#
# Projects MUST NOT create their own director skills.
# All orchestration should use core faber-director with workflow configs.
#
# Detection criteria:
# 1. Skills matching *-director/SKILL.md (excluding faber-director)
# 2. Commands with -direct suffix (excluding faber commands)
# 3. Skills containing pattern expansion/orchestration logic
#
# Usage: ./detect-project-specific-director.sh <project_path>
# Output: JSON with detection results

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo '{"status": "error", "error": "invalid_project", "message": ".claude/ directory not found"}'
  exit 1
fi

VIOLATIONS=()
VIOLATION_COUNT=0

# Detection 1: Project-specific director skills
# Look for *-director/SKILL.md excluding faber-director
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")

    # Check if it's a director skill (ends with -director)
    if [[ "$skill_name" == *-director ]]; then
      # Exclude faber-director (the core one is allowed)
      if [[ "$skill_name" != "faber-director" ]]; then
        # Get relative path
        rel_path="${skill_file#$PROJECT_PATH/}"

        violation=$(cat <<VIOLATION
{
  "file": "$rel_path",
  "line": null,
  "rule_id": "ARC-006",
  "severity": "error",
  "description": "Project-specific director skill detected: $skill_name",
  "evidence": "Skill name matches *-director pattern",
  "migration_proposal": {
    "action": "delete",
    "replacement": "Use core faber-director with workflow config",
    "workflow_config_path": ".fractary/plugins/faber/workflows/${skill_name%-director}.json",
    "invocation": "/faber run <id> --workflow ${skill_name%-director}"
  }
}
VIOLATION
)
        VIOLATIONS+=("$violation")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

# Also check plugins directory if it exists (for plugin development)
if [[ -d "$PROJECT_PATH/plugins" ]]; then
  while IFS= read -r -d '' skill_file; do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")

    if [[ "$skill_name" == *-director ]]; then
      if [[ "$skill_name" != "faber-director" ]]; then
        rel_path="${skill_file#$PROJECT_PATH/}"

        violation=$(cat <<VIOLATION
{
  "file": "$rel_path",
  "line": null,
  "rule_id": "ARC-006",
  "severity": "error",
  "description": "Project-specific director skill detected: $skill_name",
  "evidence": "Skill name matches *-director pattern in plugins directory",
  "migration_proposal": {
    "action": "delete",
    "replacement": "Use core faber-director with workflow config",
    "workflow_config_path": ".fractary/plugins/faber/workflows/${skill_name%-director}.json",
    "invocation": "/faber run <id> --workflow ${skill_name%-director}"
  }
}
VIOLATION
)
        VIOLATIONS+=("$violation")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/plugins" -path "*/skills/*-director/SKILL.md" -type f -print0 2>/dev/null || true)
fi

# Detection 2: Commands with -direct suffix (custom direct commands)
if [[ -d "$PROJECT_PATH/.claude/commands" ]]; then
  while IFS= read -r -d '' cmd_file; do
    cmd_name=$(basename "$cmd_file" .md)

    # Check for -direct suffix (excluding faber-direct which is core)
    if [[ "$cmd_name" == *-direct ]]; then
      if [[ "$cmd_name" != "faber-direct" ]]; then
        rel_path="${cmd_file#$PROJECT_PATH/}"

        violation=$(cat <<VIOLATION
{
  "file": "$rel_path",
  "line": null,
  "rule_id": "ARC-006",
  "severity": "error",
  "description": "Project-specific direct command detected: $cmd_name",
  "evidence": "Command name matches *-direct pattern",
  "migration_proposal": {
    "action": "delete",
    "replacement": "Use /faber run <id> --workflow <workflow-name>",
    "workflow_config_path": ".fractary/plugins/faber/workflows/${cmd_name%-direct}.json"
  }
}
VIOLATION
)
        VIOLATIONS+=("$violation")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/.claude/commands" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Build violations JSON array
VIOLATIONS_JSON="["
if [[ ${#VIOLATIONS[@]} -gt 0 ]]; then
  first=true
  for violation in "${VIOLATIONS[@]}"; do
    if [[ "$first" == "true" ]]; then
      VIOLATIONS_JSON+="$violation"
      first=false
    else
      VIOLATIONS_JSON+=",$violation"
    fi
  done
fi
VIOLATIONS_JSON+="]"

# Determine status based on violations found
if [[ $VIOLATION_COUNT -gt 0 ]]; then
  STATUS="error"
  MESSAGE="Project-specific director detected - use core faber-director instead"
else
  STATUS="clean"
  MESSAGE="No project-specific directors found"
fi

# Output JSON result
cat <<EOF
{
  "status": "$STATUS",
  "rule_id": "ARC-006",
  "severity": "error",
  "pattern": "project_specific_director",
  "message": "$MESSAGE",
  "detected": $([ $VIOLATION_COUNT -gt 0 ] && echo "true" || echo "false"),
  "instances": $VIOLATION_COUNT,
  "violations": $VIOLATIONS_JSON
}
EOF
