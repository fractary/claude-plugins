#!/bin/bash
set -euo pipefail

# detect-hybrid-agents.sh
# Detect agents performing execution work directly (Hybrid Agent anti-pattern)

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Tool categorization
# Orchestration tools (correct for agents)
ORCHESTRATION_TOOLS=("Skill" "AskUserQuestion" "Task")

# Execution tools (should be in skills, not agents)
EXECUTION_TOOLS=("Read" "Write" "Edit" "Bash" "Grep" "Glob" "WebFetch")

# Execution patterns
FILE_OP_PATTERNS=("Read\s*tool" "Write\s*tool" "Edit\s*tool" "Read(" "Write(" "Edit(")
DATA_PROC_PATTERNS=("parse.*json" "jq\s*" "transform.*data" "calculate" "aggregate")
API_PATTERNS=("curl\s+" "http\s+request" "api\s+call" "WebFetch")
SYSTEM_PATTERNS=("grep\s+" "awk\s+" "sed\s+" "find\s+" "Bash\s*tool")

AGENTS_JSON="["
first_agent=true
total_hybrid=0

# Scan all agents
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    # Count tool usage
    orchestration_count=0
    execution_count=0

    for tool in "${ORCHESTRATION_TOOLS[@]}"; do
      count=$(grep -ci "$tool" "$agent_file" 2>/dev/null || echo "0")
      orchestration_count=$((orchestration_count + count))
    done

    for tool in "${EXECUTION_TOOLS[@]}"; do
      count=$(grep -ci "$tool" "$agent_file" 2>/dev/null || echo "0")
      execution_count=$((execution_count + count))
    done

    # If agent uses execution tools, analyze patterns
    if [[ $execution_count -gt 0 ]]; then
      execution_patterns=()

      # Check file operations
      file_op_count=0
      file_op_evidence=()
      for pattern in "${FILE_OP_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$agent_file" 2>/dev/null; then
          file_op_count=$((file_op_count + 1))
          matched_tool=$(echo "$pattern" | sed 's/\\s\*.*//;s/($//')
          file_op_evidence+=("$matched_tool")
        fi
      done

      if [[ $file_op_count -gt 0 ]]; then
        # Build evidence JSON array
        evidence_json="["
        first_evidence=true
        for evidence in "${file_op_evidence[@]}"; do
          if [[ "$first_evidence" == "true" ]]; then
            evidence_json+="\"$evidence\""
            first_evidence=false
          else
            evidence_json+=",\"$evidence\""
          fi
        done
        evidence_json+="]"

        pattern_entry=$(cat <<PATTERN
{
  "pattern_type": "file_operations",
  "instances": $file_op_count,
  "evidence": $evidence_json,
  "severity": "high"
}
PATTERN
)
        execution_patterns+=("$pattern_entry")
      fi

      # Check data processing
      data_proc_count=0
      data_proc_evidence=()
      for pattern in "${DATA_PROC_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$agent_file" 2>/dev/null; then
          data_proc_count=$((data_proc_count + 1))
          data_proc_evidence+=("Data processing logic")
        fi
      done

      if [[ $data_proc_count -gt 0 ]]; then
        evidence_json='["Direct data processing"]'

        pattern_entry=$(cat <<PATTERN
{
  "pattern_type": "data_processing",
  "instances": $data_proc_count,
  "evidence": $evidence_json,
  "severity": "medium"
}
PATTERN
)
        execution_patterns+=("$pattern_entry")
      fi

      # Check API calls
      api_count=0
      for pattern in "${API_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$agent_file" 2>/dev/null; then
          api_count=$((api_count + 1))
        fi
      done

      if [[ $api_count -gt 0 ]]; then
        pattern_entry=$(cat <<PATTERN
{
  "pattern_type": "api_calls",
  "instances": $api_count,
  "evidence": ["Direct API calls"],
  "severity": "high"
}
PATTERN
)
        execution_patterns+=("$pattern_entry")
      fi

      # Check system operations
      system_count=0
      for pattern in "${SYSTEM_PATTERNS[@]}"; do
        if grep -qi "$pattern" "$agent_file" 2>/dev/null; then
          system_count=$((system_count + 1))
        fi
      done

      if [[ $system_count -gt 0 ]]; then
        pattern_entry=$(cat <<PATTERN
{
  "pattern_type": "system_operations",
  "instances": $system_count,
  "evidence": ["Direct system commands"],
  "severity": "high"
}
PATTERN
)
        execution_patterns+=("$pattern_entry")
      fi

      # Calculate hybrid score (0.0 - 1.0)
      total_tool_usage=$((orchestration_count + execution_count))
      hybrid_score=0
      if [[ $total_tool_usage -gt 0 ]]; then
        hybrid_score=$(awk "BEGIN {printf \"%.2f\", $execution_count / $total_tool_usage}")
      fi

      # Only flag as hybrid if score >= 0.2 (20% execution)
      if (( $(awk "BEGIN {print ($hybrid_score >= 0.2)}") )); then
        # Build patterns JSON
        patterns_json="["
        first_pattern=true
        for pattern_entry in "${execution_patterns[@]}"; do
          if [[ "$first_pattern" == "true" ]]; then
            patterns_json+="$pattern_entry"
            first_pattern=false
          else
            patterns_json+=",$pattern_entry"
          fi
        done
        patterns_json+="]"

        # Check if orchestration is also present (true hybrid)
        orchestration_present=false
        if [[ $orchestration_count -gt 0 ]]; then
          orchestration_present=true
        fi

        # Build agent entry
        agent_entry=$(cat <<AGENT
{
  "agent_name": "$agent_name",
  "file": "$agent_file",
  "hybrid_score": $hybrid_score,
  "execution_patterns": $patterns_json,
  "orchestration_present": $orchestration_present,
  "recommendation": "Extract execution to skills"
}
AGENT
)

        if [[ "$first_agent" == "true" ]]; then
          AGENTS_JSON+="$agent_entry"
          first_agent=false
        else
          AGENTS_JSON+=",$agent_entry"
        fi

        total_hybrid=$((total_hybrid + 1))
      fi
    fi

  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

AGENTS_JSON+="]"

# Determine if hybrid agents detected
HYBRID_DETECTED=false
if [[ $total_hybrid -gt 0 ]]; then
  HYBRID_DETECTED=true
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "hybrid_agents_detected": $HYBRID_DETECTED,
  "total_hybrid_agents": $total_hybrid,
  "agents": $AGENTS_JSON
}
EOF
