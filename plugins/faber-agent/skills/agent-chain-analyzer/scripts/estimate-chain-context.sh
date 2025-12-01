#!/bin/bash
set -euo pipefail

# estimate-chain-context.sh
# Calculate context load impact for agent chains

PROJECT_PATH="${1:-.}"
CHAINS_JSON="${2:-{}}"

# Context estimation constants
AVG_AGENT_TOKENS=45000
AVG_SKILL_TOKENS=5000
AGENT_OVERHEAD=10000
SKILL_OVERHEAD=2000
MANAGER_TOKENS=45000

# Validate inputs
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

if [[ "$CHAINS_JSON" == "{}" ]]; then
  echo "{\"status\": \"error\", \"error\": \"no_chains_provided\"}"
  exit 1
fi

# Parse chains using jq
if ! command -v jq &> /dev/null; then
  echo "{\"status\": \"error\", \"error\": \"jq_required\"}"
  exit 1
fi

CHAIN_COUNT=$(echo "$CHAINS_JSON" | jq '.chain_count // 0')

if [[ $CHAIN_COUNT -eq 0 ]]; then
  echo "{\"status\": \"success\", \"context_estimates\": [], \"total_current_context\": 0, \"total_projected_context\": 0, \"total_reduction\": 0}"
  exit 0
fi

# Analyze each chain
CONTEXT_ESTIMATES="["
first_estimate=true
total_current_context=0
total_projected_context=0

for i in $(seq 0 $((CHAIN_COUNT - 1))); do
  chain=$(echo "$CHAINS_JSON" | jq ".chains[$i]")

  chain_id=$(echo "$chain" | jq -r '.chain_id')
  depth=$(echo "$chain" | jq '.depth')

  # Current context calculation
  agents_count=$depth
  tokens_per_agent=$AVG_AGENT_TOKENS
  agent_tokens=$((agents_count * tokens_per_agent))
  overhead_tokens=$((agents_count * AGENT_OVERHEAD))
  current_total=$((agent_tokens + overhead_tokens))

  # Projected context (after converting to Manager + Skills)
  # 1 Manager agent + N skills (one per original agent step)
  manager_tokens=$MANAGER_TOKENS
  skills_count=$agents_count
  skill_tokens=$((skills_count * AVG_SKILL_TOKENS))
  projected_overhead=$((skills_count * SKILL_OVERHEAD))
  projected_total=$((manager_tokens + skill_tokens + projected_overhead))

  # Calculate reduction
  tokens_saved=$((current_total - projected_total))
  reduction_percentage=$(awk "BEGIN {printf \"%.2f\", $tokens_saved / $current_total}")

  # Build context estimate JSON
  estimate_json=$(cat <<ESTIMATE
{
  "chain_id": "$chain_id",
  "current_context": {
    "agents": $agents_count,
    "tokens_per_agent": $tokens_per_agent,
    "total_tokens": $agent_tokens,
    "overhead_tokens": $overhead_tokens,
    "grand_total": $current_total
  },
  "projected_context": {
    "manager_agent": $manager_tokens,
    "skills": $skills_count,
    "tokens_per_skill": $AVG_SKILL_TOKENS,
    "skills_total": $skill_tokens,
    "overhead_tokens": $projected_overhead,
    "grand_total": $projected_total
  },
  "reduction": {
    "tokens_saved": $tokens_saved,
    "percentage": $reduction_percentage,
    "description": "$(awk "BEGIN {printf \"%d%%\", $reduction_percentage * 100}") context reduction ($(awk "BEGIN {printf \"%.0fK\", $current_total / 1000}") → $(awk "BEGIN {printf \"%.0fK\", $projected_total / 1000}"))"
  }
}
ESTIMATE
)

  if [[ "$first_estimate" == "true" ]]; then
    CONTEXT_ESTIMATES+="$estimate_json"
    first_estimate=false
  else
    CONTEXT_ESTIMATES+=",$estimate_json"
  fi

  total_current_context=$((total_current_context + current_total))
  total_projected_context=$((total_projected_context + projected_total))
done

CONTEXT_ESTIMATES+="]"

# Calculate overall reduction
if [[ $total_current_context -gt 0 ]]; then
  total_reduction=$(awk "BEGIN {printf \"%.2f\", ($total_current_context - $total_projected_context) / $total_current_context}")
else
  total_reduction=0
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "context_estimates": $CONTEXT_ESTIMATES,
  "total_current_context": $total_current_context,
  "total_projected_context": $total_projected_context,
  "total_reduction": $total_reduction
}
EOF
