#!/bin/bash
set -euo pipefail

# calculate-context-load.sh
# Calculate context load (token estimates) for project architecture

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Token estimation constants (approximate)
# Based on: 1 token ≈ 4 characters for English text
AVG_AGENT_TOKENS=45000    # Typical agent file size
AVG_SKILL_TOKENS=5000     # Typical skill file size
AVG_COMMAND_TOKENS=2000   # Typical command file size
OVERHEAD_PER_AGENT=10000  # State management, invocation overhead

# Count components
AGENT_COUNT=0
SKILL_COUNT=0
COMMAND_COUNT=0

if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  AGENT_COUNT=$(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" 2>/dev/null | wc -l)
fi

if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  SKILL_COUNT=$(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" 2>/dev/null | wc -l)
fi

if [[ -d "$PROJECT_PATH/.claude/commands" ]]; then
  COMMAND_COUNT=$(find "$PROJECT_PATH/.claude/commands" -type f -name "*.md" 2>/dev/null | wc -l)
fi

# Calculate current load
AGENTS_TOKENS=$((AGENT_COUNT * AVG_AGENT_TOKENS))
SKILLS_TOKENS=$((SKILL_COUNT * AVG_SKILL_TOKENS))
COMMANDS_TOKENS=$((COMMAND_COUNT * AVG_COMMAND_TOKENS))
OVERHEAD_TOKENS=$((AGENT_COUNT * OVERHEAD_PER_AGENT))

CURRENT_LOAD=$((AGENTS_TOKENS + SKILLS_TOKENS + COMMANDS_TOKENS + OVERHEAD_TOKENS))

# Projected load estimation (after optimizations)
# Assumptions:
# - Agent chains converted to Manager + Skills: 53% reduction
# - Manager-as-Skill converted to Agent: minimal increase (state management overhead)
# - Director-as-Agent converted to Skill: 89% reduction (45K → 5K)
# - Script extraction: 20% reduction in skill tokens

# Detect anti-patterns to estimate optimization
MANAGER_AS_SKILL_COUNT=0
DIRECTOR_AS_AGENT_COUNT=0
AGENT_CHAIN_DEPTH=0

# Count Manager-as-Skill instances (skills with orchestration keywords)
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    # Check for manager characteristics
    manager_keywords_found=0
    if grep -qi "workflow_phase\|phases_completed\|user_approval\|orchestrate" "$skill_file" 2>/dev/null; then
      manager_keywords_found=$((manager_keywords_found + 1))
    fi

    if [[ $manager_keywords_found -ge 1 ]]; then
      MANAGER_AS_SKILL_COUNT=$((MANAGER_AS_SKILL_COUNT + 1))
    fi
  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

# Count Director-as-Agent instances (agents with simple pattern expansion)
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    # Check for director characteristics
    if grep -qi "pattern.*expan\|wildcard\|glob" "$agent_file" 2>/dev/null; then
      # Check orchestration is absent
      if ! grep -qi "Phase 1:\|orchestrate\|workflow" "$agent_file" 2>/dev/null; then
        DIRECTOR_AS_AGENT_COUNT=$((DIRECTOR_AS_AGENT_COUNT + 1))
      fi
    fi
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Estimate agent chain depth (look for Task tool invocations)
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    # Count Task tool or agent invocations
    chain_count=$(grep -ci "Task tool\|Task(\|@agent-" "$agent_file" 2>/dev/null || echo "0")
    if [[ $chain_count -gt $AGENT_CHAIN_DEPTH ]]; then
      AGENT_CHAIN_DEPTH=$chain_count
    fi
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Calculate projected load
# Start with current load
PROJECTED_LOAD=$CURRENT_LOAD

# Manager-as-Skill → Agent: +5K overhead each
MANAGER_AS_SKILL_ADJUSTMENT=$((MANAGER_AS_SKILL_COUNT * 5000))
PROJECTED_LOAD=$((PROJECTED_LOAD + MANAGER_AS_SKILL_ADJUSTMENT))

# Director-as-Agent → Skill: Save 40K each (45K → 5K)
DIRECTOR_AS_AGENT_REDUCTION=$((DIRECTOR_AS_AGENT_COUNT * 40000))
PROJECTED_LOAD=$((PROJECTED_LOAD - DIRECTOR_AS_AGENT_REDUCTION))

# Agent chains: 53% reduction if chains detected
if [[ $AGENT_CHAIN_DEPTH -ge 2 ]]; then
  # Estimate chain context: AGENT_CHAIN_DEPTH agents × 45K
  CHAIN_CONTEXT=$((AGENT_CHAIN_DEPTH * AVG_AGENT_TOKENS))
  # After conversion: 1 Manager + AGENT_CHAIN_DEPTH skills
  CONVERTED_CONTEXT=$((AVG_AGENT_TOKENS + AGENT_CHAIN_DEPTH * AVG_SKILL_TOKENS))
  CHAIN_REDUCTION=$((CHAIN_CONTEXT - CONVERTED_CONTEXT))
  PROJECTED_LOAD=$((PROJECTED_LOAD - CHAIN_REDUCTION))
fi

# Script extraction: 20% reduction in skills
SCRIPT_EXTRACTION_REDUCTION=$((SKILLS_TOKENS / 5))
PROJECTED_LOAD=$((PROJECTED_LOAD - SCRIPT_EXTRACTION_REDUCTION))

# Ensure projected load is not negative or unrealistic
if [[ $PROJECTED_LOAD -lt 10000 ]]; then
  PROJECTED_LOAD=10000  # Minimum realistic load
fi

# Calculate reduction
REDUCTION_TOKENS=$((CURRENT_LOAD - PROJECTED_LOAD))
if [[ $CURRENT_LOAD -gt 0 ]]; then
  REDUCTION_PERCENTAGE=$(awk "BEGIN {printf \"%.2f\", $REDUCTION_TOKENS / $CURRENT_LOAD}")
else
  REDUCTION_PERCENTAGE="0.00"
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "current_load_tokens": $CURRENT_LOAD,
  "projected_load_tokens": $PROJECTED_LOAD,
  "reduction_tokens": $REDUCTION_TOKENS,
  "reduction_percentage": $REDUCTION_PERCENTAGE,
  "breakdown": {
    "agents": $AGENTS_TOKENS,
    "skills": $SKILLS_TOKENS,
    "commands": $COMMANDS_TOKENS,
    "overhead": $OVERHEAD_TOKENS
  },
  "optimization_factors": {
    "manager_as_skill_count": $MANAGER_AS_SKILL_COUNT,
    "director_as_agent_count": $DIRECTOR_AS_AGENT_COUNT,
    "agent_chain_depth": $AGENT_CHAIN_DEPTH,
    "script_extraction_potential": true
  }
}
EOF
