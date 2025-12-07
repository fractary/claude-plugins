#!/bin/bash
set -euo pipefail

# detect-project-specific-manager.sh
# Detect Project-Specific Manager anti-pattern (ARC-007 - ERROR severity)
#
# Projects MUST NOT create their own manager agents.
# All orchestration should use core faber-manager with workflow configs.
#
# Detection criteria:
# 1. Agent files matching *-manager.md (excluding faber-manager and primitive managers)
# 2. Agents containing orchestration/workflow coordination logic
#
# Usage: ./detect-project-specific-manager.sh <project_path>
# Output: JSON with detection results

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo '{"status": "error", "error": "invalid_project", "message": ".claude/ directory not found"}'
  exit 1
fi

# Core managers that are allowed (primitive managers from fractary ecosystem)
ALLOWED_MANAGERS=(
  "faber-manager"
  "repo-manager"
  "work-manager"
  "file-manager"
  "codex-manager"
  "docs-manager"
  "log-manager"
  "spec-manager"
)

# Check if a manager name is in the allowed list
is_allowed_manager() {
  local name="$1"
  for allowed in "${ALLOWED_MANAGERS[@]}"; do
    if [[ "$name" == "$allowed" ]]; then
      return 0
    fi
  done
  return 1
}

VIOLATIONS=()
VIOLATION_COUNT=0

# Manager characteristics (orchestration patterns)
ORCHESTRATION_KEYWORDS=(
  "Phase 1:"
  "Phase 2:"
  "Phase 3:"
  "orchestrate"
  "coordinate"
  "workflow"
  "FABER"
  "Frame.*Architect.*Build"
  "INSPECT.*ANALYZE.*PRESENT"
)

# Detection 1: Agent files matching *-manager.md pattern
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    # Check if it's a manager agent (ends with -manager)
    if [[ "$agent_name" == *-manager ]]; then
      # Check if it's in the allowed list
      if ! is_allowed_manager "$agent_name"; then
        rel_path="${agent_file#$PROJECT_PATH/}"

        # Check for orchestration patterns to confirm it's doing workflow coordination
        orchestration_evidence=""
        match_count=0
        for keyword in "${ORCHESTRATION_KEYWORDS[@]}"; do
          if grep -qi "$keyword" "$agent_file" 2>/dev/null; then
            match_count=$((match_count + 1))
            if [[ -z "$orchestration_evidence" ]]; then
              orchestration_evidence="$keyword"
            else
              orchestration_evidence="$orchestration_evidence, $keyword"
            fi
          fi
        done

        # Extract project name from manager name
        project_name="${agent_name%-manager}"

        violation=$(cat <<VIOLATION
{
  "file": "$rel_path",
  "line": null,
  "rule_id": "ARC-007",
  "severity": "error",
  "description": "Project-specific manager agent detected: $agent_name",
  "evidence": "Agent name matches *-manager pattern${orchestration_evidence:+ with orchestration logic: $orchestration_evidence}",
  "orchestration_indicators": $match_count,
  "migration_proposal": {
    "action": "delete",
    "replacement": "Use core faber-manager with workflow config",
    "workflow_config": {
      "id": "$project_name-workflow",
      "path": ".fractary/plugins/faber/workflows/$project_name.json",
      "phases": {
        "frame": { "enabled": true, "steps": [] },
        "architect": { "enabled": true, "steps": [] },
        "build": { "enabled": true, "steps": [] },
        "evaluate": { "enabled": true, "steps": [] },
        "release": { "enabled": true, "steps": [] }
      }
    },
    "invocation": "/faber run <id> --workflow $project_name"
  }
}
VIOLATION
)
        VIOLATIONS+=("$violation")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*-manager.md" -print0 2>/dev/null || true)
fi

# Also check plugins directory if it exists (for plugin development)
if [[ -d "$PROJECT_PATH/plugins" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    if [[ "$agent_name" == *-manager ]]; then
      if ! is_allowed_manager "$agent_name"; then
        rel_path="${agent_file#$PROJECT_PATH/}"

        # Check for orchestration patterns
        orchestration_evidence=""
        match_count=0
        for keyword in "${ORCHESTRATION_KEYWORDS[@]}"; do
          if grep -qi "$keyword" "$agent_file" 2>/dev/null; then
            match_count=$((match_count + 1))
            if [[ -z "$orchestration_evidence" ]]; then
              orchestration_evidence="$keyword"
            else
              orchestration_evidence="$orchestration_evidence, $keyword"
            fi
          fi
        done

        project_name="${agent_name%-manager}"

        violation=$(cat <<VIOLATION
{
  "file": "$rel_path",
  "line": null,
  "rule_id": "ARC-007",
  "severity": "error",
  "description": "Project-specific manager agent detected: $agent_name",
  "evidence": "Agent name matches *-manager pattern in plugins directory${orchestration_evidence:+ with orchestration logic: $orchestration_evidence}",
  "orchestration_indicators": $match_count,
  "migration_proposal": {
    "action": "delete",
    "replacement": "Use core faber-manager with workflow config",
    "workflow_config": {
      "id": "$project_name-workflow",
      "path": ".fractary/plugins/faber/workflows/$project_name.json"
    },
    "invocation": "/faber run <id> --workflow $project_name"
  }
}
VIOLATION
)
        VIOLATIONS+=("$violation")
        VIOLATION_COUNT=$((VIOLATION_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/plugins" -path "*/agents/*-manager.md" -type f -print0 2>/dev/null || true)
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
  MESSAGE="Project-specific manager detected - use core faber-manager with workflow config"
else
  STATUS="clean"
  MESSAGE="No project-specific managers found"
fi

# Output JSON result
cat <<EOF
{
  "status": "$STATUS",
  "rule_id": "ARC-007",
  "severity": "error",
  "pattern": "project_specific_manager",
  "message": "$MESSAGE",
  "detected": $([ $VIOLATION_COUNT -gt 0 ] && echo "true" || echo "false"),
  "instances": $VIOLATION_COUNT,
  "violations": $VIOLATIONS_JSON
}
EOF
