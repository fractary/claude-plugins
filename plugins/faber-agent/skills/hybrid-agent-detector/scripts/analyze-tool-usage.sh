#!/bin/bash
set -euo pipefail

# analyze-tool-usage.sh
# Analyze tool usage patterns to categorize agents

PROJECT_PATH="${1:-.}"
HYBRID_AGENTS_JSON="${2:-{}}"

# Validate inputs
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "{\"status\": \"error\", \"error\": \"jq_required\"}"
  exit 1
fi

# Parse hybrid agents
total_hybrid=$(echo "$HYBRID_AGENTS_JSON" | jq '.total_hybrid_agents // 0')

if [[ $total_hybrid -eq 0 ]]; then
  echo "{\"status\": \"success\", \"tool_analysis\": [], \"patterns\": {\"pure_orchestrators\": 0, \"hybrid_agents\": 0}}"
  exit 0
fi

# Tool categories
ORCHESTRATION_TOOLS=("Skill" "AskUserQuestion" "Task")
EXECUTION_TOOLS=("Read" "Write" "Edit" "Bash" "Grep" "Glob" "WebFetch")

TOOL_ANALYSIS="["
first_analysis=true

for i in $(seq 0 $((total_hybrid - 1))); do
  agent_data=$(echo "$HYBRID_AGENTS_JSON" | jq ".agents[$i]")

  agent_name=$(echo "$agent_data" | jq -r '.agent_name')
  agent_file=$(echo "$agent_data" | jq -r '.file')
  hybrid_score=$(echo "$agent_data" | jq '.hybrid_score')

  # Analyze tool usage in this agent
  tools_used=()
  orchestration_tools=()
  execution_tools=()

  # Check each orchestration tool
  for tool in "${ORCHESTRATION_TOOLS[@]}"; do
    if grep -qi "$tool" "$agent_file" 2>/dev/null; then
      tools_used+=("$tool")
      orchestration_tools+=("$tool")
    fi
  done

  # Check each execution tool
  for tool in "${EXECUTION_TOOLS[@]}"; do
    if grep -qi "$tool" "$agent_file" 2>/dev/null; then
      tools_used+=("$tool")
      execution_tools+=("$tool")
    fi
  done

  # Calculate percentages
  total_tools=${#tools_used[@]}
  orch_count=${#orchestration_tools[@]}
  exec_count=${#execution_tools[@]}

  orch_percentage=0
  exec_percentage=0

  if [[ $total_tools -gt 0 ]]; then
    orch_percentage=$(awk "BEGIN {printf \"%.2f\", $orch_count / $total_tools}")
    exec_percentage=$(awk "BEGIN {printf \"%.2f\", $exec_count / $total_tools}")
  fi

  # Determine verdict
  verdict="Unknown"
  if (( $(awk "BEGIN {print ($exec_percentage >= 0.8)}") )); then
    verdict="Pure Executor (Anti-pattern)"
  elif (( $(awk "BEGIN {print ($exec_percentage >= 0.5)}") )); then
    verdict="Hybrid - primarily execution"
  elif (( $(awk "BEGIN {print ($exec_percentage >= 0.2)}") )); then
    verdict="Hybrid - some execution"
  else
    verdict="Mostly orchestrator"
  fi

  # Build JSON arrays
  tools_json="["
  first_tool=true
  for tool in "${tools_used[@]}"; do
    if [[ "$first_tool" == "true" ]]; then
      tools_json+="\"$tool\""
      first_tool=false
    else
      tools_json+=",\"$tool\""
    fi
  done
  tools_json+="]"

  orch_json="["
  first_orch=true
  for tool in "${orchestration_tools[@]}"; do
    if [[ "$first_orch" == "true" ]]; then
      orch_json+="\"$tool\""
      first_orch=false
    else
      orch_json+=",\"$tool\""
    fi
  done
  orch_json+="]"

  exec_json="["
  first_exec=true
  for tool in "${execution_tools[@]}"; do
    if [[ "$first_exec" == "true" ]]; then
      exec_json+="\"$tool\""
      first_exec=false
    else
      exec_json+=",\"$tool\""
    fi
  done
  exec_json+="]"

  # Build analysis entry
  analysis_entry=$(cat <<ANALYSIS
{
  "agent_name": "$agent_name",
  "tools_used": $tools_json,
  "orchestration_tools": $orch_json,
  "execution_tools": $exec_json,
  "hybrid_score": $hybrid_score,
  "tool_usage_breakdown": {
    "orchestration_percentage": $orch_percentage,
    "execution_percentage": $exec_percentage
  },
  "verdict": "$verdict"
}
ANALYSIS
)

  if [[ "$first_analysis" == "true" ]]; then
    TOOL_ANALYSIS+="$analysis_entry"
    first_analysis=false
  else
    TOOL_ANALYSIS+=",$analysis_entry"
  fi
done

TOOL_ANALYSIS+="]"

# Count patterns (scan all agents, not just hybrid)
pure_orchestrators=0
hybrid_agents=$total_hybrid
pure_executors=0

if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  total_agents=$(find "$PROJECT_PATH/.claude/agents" -name "*.md" 2>/dev/null | wc -l || echo "0")
  pure_orchestrators=$((total_agents - hybrid_agents))

  # Check if any are pure executors (hybrid_score >= 0.8)
  for i in $(seq 0 $((total_hybrid - 1))); do
    score=$(echo "$HYBRID_AGENTS_JSON" | jq ".agents[$i].hybrid_score")
    if (( $(awk "BEGIN {print ($score >= 0.8)}") )); then
      pure_executors=$((pure_executors + 1))
      hybrid_agents=$((hybrid_agents - 1))
    fi
  done
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "tool_analysis": $TOOL_ANALYSIS,
  "patterns": {
    "pure_orchestrators": $pure_orchestrators,
    "hybrid_agents": $hybrid_agents,
    "pure_executors": $pure_executors
  }
}
EOF
