#!/bin/bash
set -euo pipefail

# inspect-structure.sh
# Scan Claude Code project and collect structural information

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH" ]]; then
  echo "{\"status\": \"error\", \"error\": \"project_not_found\", \"message\": \"Directory does not exist: $PROJECT_PATH\"}"
  exit 1
fi

if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\", \"message\": \".claude/ directory not found\", \"resolution\": \"Ensure this is a valid Claude Code project root\"}"
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

# Build JSON arrays
AGENT_FILES_JSON=$(printf ',"%s"' "${AGENT_FILES[@]}" 2>/dev/null || echo "")
AGENT_FILES_JSON="[${AGENT_FILES_JSON:1}]"
AGENT_NAMES_JSON=$(printf ',"%s"' "${AGENT_NAMES[@]}" 2>/dev/null || echo "")
AGENT_NAMES_JSON="[${AGENT_NAMES_JSON:1}]"

SKILL_FILES_JSON=$(printf ',"%s"' "${SKILL_FILES[@]}" 2>/dev/null || echo "")
SKILL_FILES_JSON="[${SKILL_FILES_JSON:1}]"
SKILL_NAMES_JSON=$(printf ',"%s"' "${SKILL_NAMES[@]}" 2>/dev/null || echo "")
SKILL_NAMES_JSON="[${SKILL_NAMES_JSON:1}]"

COMMAND_FILES_JSON=$(printf ',"%s"' "${COMMAND_FILES[@]}" 2>/dev/null || echo "")
COMMAND_FILES_JSON="[${COMMAND_FILES_JSON:1}]"
COMMAND_NAMES_JSON=$(printf ',"%s"' "${COMMAND_NAMES[@]}" 2>/dev/null || echo "")
COMMAND_NAMES_JSON="[${COMMAND_NAMES_JSON:1}]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "project_path": "$PROJECT_PATH",
  "agents": {
    "count": ${#AGENT_FILES[@]},
    "files": $AGENT_FILES_JSON,
    "names": $AGENT_NAMES_JSON
  },
  "skills": {
    "count": ${#SKILL_FILES[@]},
    "files": $SKILL_FILES_JSON,
    "names": $SKILL_NAMES_JSON
  },
  "commands": {
    "count": ${#COMMAND_FILES[@]},
    "files": $COMMAND_FILES_JSON,
    "names": $COMMAND_NAMES_JSON
  },
  "project_type": "$PROJECT_TYPE"
}
EOF
