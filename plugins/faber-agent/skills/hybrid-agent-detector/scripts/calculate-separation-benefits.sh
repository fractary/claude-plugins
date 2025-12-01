#!/bin/bash
set -euo pipefail

# calculate-separation-benefits.sh
# Calculate benefits of separating execution into skills

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
  echo "{\"status\": \"success\", \"separation_benefits\": [], \"total_context_savings\": 0}"
  exit 0
fi

# Token estimation constants
AVG_AGENT_TOKENS=45000
AVG_SKILL_TOKENS=5000

SEPARATION_BENEFITS="["
first_benefit=true
total_context_savings=0
total_new_skills=0

for i in $(seq 0 $((total_hybrid - 1))); do
  agent_data=$(echo "$HYBRID_AGENTS_JSON" | jq ".agents[$i]")

  agent_name=$(echo "$agent_data" | jq -r '.agent_name')
  agent_file=$(echo "$agent_data" | jq -r '.file')
  hybrid_score=$(echo "$agent_data" | jq '.hybrid_score')

  # Estimate current agent size (default to average)
  current_agent_size=$AVG_AGENT_TOKENS

  # If file exists, estimate based on line count
  if [[ -f "$agent_file" ]]; then
    line_count=$(wc -l < "$agent_file" 2>/dev/null || echo "1000")
    # Rough estimate: 10 tokens per line
    current_agent_size=$((line_count * 10))
  fi

  # Estimate execution logic size based on hybrid score
  # hybrid_score = execution% of agent
  execution_logic_size=$(awk "BEGIN {printf \"%.0f\", $current_agent_size * $hybrid_score}")

  # After separation:
  # - Agent keeps orchestration logic only
  # - Execution logic moves to skills

  projected_agent_size=$((current_agent_size - execution_logic_size))

  # Estimate number of new skills based on execution patterns
  execution_patterns=$(echo "$agent_data" | jq '.execution_patterns | length')
  new_skills_created=$execution_patterns

  # Each skill will be smaller than the extracted logic (scripts are more efficient)
  # Assume 30% compression from moving to scripts
  skills_total_size=$(awk "BEGIN {printf \"%.0f\", $execution_logic_size * 0.30}")

  # Context reduction = execution_logic_size - skills_total_size
  # (because execution logic was in agent, now compressed in skills)
  context_reduction=$((execution_logic_size - skills_total_size))

  reduction_percentage=0
  if [[ $current_agent_size -gt 0 ]]; then
    reduction_percentage=$(awk "BEGIN {printf \"%.2f\", $context_reduction / $current_agent_size}")
  fi

  # Reusability score (higher hybrid score = more reusable logic)
  reusability_score=$(awk "BEGIN {printf \"%.2f\", $hybrid_score * 0.9}")

  # Benefits list
  benefits_json='[
    "'"$(awk "BEGIN {printf \"%d%%\", $reduction_percentage * 100}")"' context reduction in agent",
    "'"$new_skills_created"' reusable skills created",
    "Execution testable independently"
  ]'

  # Build benefit entry
  benefit_entry=$(cat <<BENEFIT
{
  "agent_name": "$agent_name",
  "current_agent_size": $current_agent_size,
  "execution_logic_size": $execution_logic_size,
  "projected_agent_size": $projected_agent_size,
  "new_skills_created": $new_skills_created,
  "skills_total_size": $skills_total_size,
  "context_reduction": $context_reduction,
  "reduction_percentage": $reduction_percentage,
  "reusability_score": $reusability_score,
  "benefits": $benefits_json
}
BENEFIT
)

  if [[ "$first_benefit" == "true" ]]; then
    SEPARATION_BENEFITS+="$benefit_entry"
    first_benefit=false
  else
    SEPARATION_BENEFITS+=",$benefit_entry"
  fi

  total_context_savings=$((total_context_savings + context_reduction))
  total_new_skills=$((total_new_skills + new_skills_created))
done

SEPARATION_BENEFITS+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "separation_benefits": $SEPARATION_BENEFITS,
  "total_context_savings": $total_context_savings,
  "total_new_skills": $total_new_skills
}
EOF
