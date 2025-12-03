#!/bin/bash
set -euo pipefail

# inspect-structure.sh
# Scan Claude Code project and collect structural information
# Uses jq for safe JSON construction with proper escaping

PROJECT_PATH="${1:-.}"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required but not installed", "resolution": "Install jq: apt install jq / brew install jq"}'
  exit 1
fi

# Validate project path
if [[ ! -d "$PROJECT_PATH" ]]; then
  jq -n --arg path "$PROJECT_PATH" '{status: "error", error: "project_not_found", message: ("Directory does not exist: " + $path)}'
  exit 1
fi

if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  jq -n '{status: "error", error: "invalid_project", message: ".claude/ directory not found", resolution: "Ensure this is a valid Claude Code project root"}'
  exit 1
fi

# Find agents
AGENT_FILES=()
AGENT_NAMES=()
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' file; do
    AGENT_FILES+=("$file")
    # Extract agent name from file path
    basename_file=$(basename "$file" .md)
    AGENT_NAMES+=("$basename_file")
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Find skills
SKILL_FILES=()
SKILL_NAMES=()
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' file; do
    SKILL_FILES+=("$file")
    # Extract skill name from directory path
    skill_dir=$(dirname "$file")
    skill_name=$(basename "$skill_dir")
    SKILL_NAMES+=("$skill_name")
  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

# Find commands
COMMAND_FILES=()
COMMAND_NAMES=()
if [[ -d "$PROJECT_PATH/.claude/commands" ]]; then
  while IFS= read -r -d '' file; do
    COMMAND_FILES+=("$file")
    # Extract command name from file path
    basename_file=$(basename "$file" .md)
    COMMAND_NAMES+=("$basename_file")
  done < <(find "$PROJECT_PATH/.claude/commands" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Determine project type
PROJECT_TYPE="unknown"
if [[ ${#SKILL_FILES[@]} -gt 0 && ${#AGENT_FILES[@]} -eq 0 ]]; then
  PROJECT_TYPE="skills-based"
elif [[ ${#SKILL_FILES[@]} -eq 0 && ${#AGENT_FILES[@]} -gt 0 ]]; then
  PROJECT_TYPE="pre-skills"
elif [[ ${#SKILL_FILES[@]} -gt 0 && ${#AGENT_FILES[@]} -gt 0 ]]; then
  # Check if agents use Task tool to invoke other agents (pre-skills pattern)
  AGENT_CHAINS_FOUND=false
  for agent_file in "${AGENT_FILES[@]}"; do
    if grep -q "Task tool" "$agent_file" 2>/dev/null || \
       grep -q "Task(" "$agent_file" 2>/dev/null || \
       grep -q "@agent-" "$agent_file" 2>/dev/null; then
      # Check if it's invoking another agent (not a skill)
      if grep -E "agent-[a-z-]+:" "$agent_file" | grep -v "@skill-" > /dev/null 2>&1; then
        AGENT_CHAINS_FOUND=true
        break
      fi
    fi
  done

  if [[ "$AGENT_CHAINS_FOUND" == "true" ]]; then
    PROJECT_TYPE="hybrid"  # Has both skills and agent chains
  else
    PROJECT_TYPE="skills-based"  # Modern architecture
  fi
fi

# Build JSON arrays using jq for proper escaping
# Convert bash arrays to JSON arrays safely
array_to_json() {
  local arr=("$@")
  if [[ ${#arr[@]} -eq 0 ]]; then
    echo "[]"
  else
    printf '%s\n' "${arr[@]}" | jq -R . | jq -s .
  fi
}

AGENT_FILES_JSON=$(array_to_json "${AGENT_FILES[@]}")
AGENT_NAMES_JSON=$(array_to_json "${AGENT_NAMES[@]}")
SKILL_FILES_JSON=$(array_to_json "${SKILL_FILES[@]}")
SKILL_NAMES_JSON=$(array_to_json "${SKILL_NAMES[@]}")
COMMAND_FILES_JSON=$(array_to_json "${COMMAND_FILES[@]}")
COMMAND_NAMES_JSON=$(array_to_json "${COMMAND_NAMES[@]}")

# Output JSON using jq for proper escaping
jq -n \
  --arg project_path "$PROJECT_PATH" \
  --arg project_type "$PROJECT_TYPE" \
  --argjson agent_count "${#AGENT_FILES[@]}" \
  --argjson agent_files "$AGENT_FILES_JSON" \
  --argjson agent_names "$AGENT_NAMES_JSON" \
  --argjson skill_count "${#SKILL_FILES[@]}" \
  --argjson skill_files "$SKILL_FILES_JSON" \
  --argjson skill_names "$SKILL_NAMES_JSON" \
  --argjson command_count "${#COMMAND_FILES[@]}" \
  --argjson command_files "$COMMAND_FILES_JSON" \
  --argjson command_names "$COMMAND_NAMES_JSON" \
  '{
    status: "success",
    project_path: $project_path,
    agents: {
      count: $agent_count,
      files: $agent_files,
      names: $agent_names
    },
    skills: {
      count: $skill_count,
      files: $skill_files,
      names: $skill_names
    },
    commands: {
      count: $command_count,
      files: $command_files,
      names: $command_names
    },
    project_type: $project_type
  }'
