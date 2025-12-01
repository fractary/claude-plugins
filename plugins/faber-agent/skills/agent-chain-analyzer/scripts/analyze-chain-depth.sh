#!/bin/bash
set -euo pipefail

# analyze-chain-depth.sh
# Analyze chain depth and complexity for agent chains

PROJECT_PATH="${1:-.}"
CHAINS_JSON="${2:-{}}"

# Validate inputs
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

if [[ "$CHAINS_JSON" == "{}" ]]; then
  echo "{\"status\": \"error\", \"error\": \"no_chains_provided\", \"message\": \"Chains data required\"}"
  exit 1
fi

# Parse chains using jq if available, otherwise simple parsing
if command -v jq &> /dev/null; then
  CHAIN_COUNT=$(echo "$CHAINS_JSON" | jq '.chain_count // 0')

  if [[ $CHAIN_COUNT -eq 0 ]]; then
    echo "{\"status\": \"success\", \"depth_analysis\": [], \"average_depth\": 0}"
    exit 0
  fi

  # Analyze each chain
  DEPTH_ANALYSIS="["
  first_chain=true
  total_depth=0

  for i in $(seq 0 $((CHAIN_COUNT - 1))); do
    chain=$(echo "$CHAINS_JSON" | jq ".chains[$i]")

    chain_id=$(echo "$chain" | jq -r '.chain_id')
    depth=$(echo "$chain" | jq '.depth')
    entry_point=$(echo "$chain" | jq -r '.entry_point')
    agents=$(echo "$chain" | jq -r '.agents[]')

    # Calculate complexity score (0.0 - 1.0)
    # Factors: depth (40%), error handling (30%), state (30%)
    complexity_score=0

    # Depth factor: longer chains = higher complexity
    if [[ $depth -eq 2 ]]; then
      depth_factor=0.3
    elif [[ $depth -eq 3 ]]; then
      depth_factor=0.6
    elif [[ $depth -eq 4 ]]; then
      depth_factor=0.8
    else
      depth_factor=1.0
    fi

    complexity_score=$(awk "BEGIN {print $depth_factor * 0.4}")

    # Check for error handling in chain agents
    error_handling_found=false
    for agent_name in $agents; do
      agent_file="$PROJECT_PATH/.claude/agents/${agent_name}.md"
      if [[ -f "$agent_file" ]]; then
        if grep -qi "error\|ERROR_HANDLING\|try.*catch\|exception" "$agent_file" 2>/dev/null; then
          error_handling_found=true
          break
        fi
      fi
    done

    if [[ "$error_handling_found" == "false" ]]; then
      # No error handling = +30% complexity
      complexity_score=$(awk "BEGIN {print $complexity_score + 0.3}")
    fi

    # Check for state management attempts (indicates need for Manager)
    state_management_found=false
    for agent_name in $agents; do
      agent_file="$PROJECT_PATH/.claude/agents/${agent_name}.md"
      if [[ -f "$agent_file" ]]; then
        if grep -qi "state\|workflow_phase\|STATE_MANAGEMENT" "$agent_file" 2>/dev/null; then
          state_management_found=true
          break
        fi
      fi
    done

    if [[ "$state_management_found" == "false" ]]; then
      # No state management = +30% complexity (harder to refactor)
      complexity_score=$(awk "BEGIN {print $complexity_score + 0.3}")
    fi

    # Ensure complexity score doesn't exceed 1.0
    if (( $(awk "BEGIN {print ($complexity_score > 1.0)}") )); then
      complexity_score=1.0
    fi

    # Identify complexity factors
    COMPLEXITY_FACTORS=()
    if [[ $depth -ge 4 ]]; then
      COMPLEXITY_FACTORS+=("Deep chain ($depth agents)")
    elif [[ $depth -eq 3 ]]; then
      COMPLEXITY_FACTORS+=("Medium chain ($depth agents)")
    else
      COMPLEXITY_FACTORS+=("Short chain ($depth agents)")
    fi

    if [[ "$error_handling_found" == "false" ]]; then
      COMPLEXITY_FACTORS+=("No error handling between agents")
    fi

    if [[ "$state_management_found" == "false" ]]; then
      COMPLEXITY_FACTORS+=("No state persistence")
    fi

    COMPLEXITY_FACTORS+=("Sequential only (no parallelism)")

    # Build complexity factors JSON
    factors_json="["
    first_factor=true
    for factor in "${COMPLEXITY_FACTORS[@]}"; do
      if [[ "$first_factor" == "true" ]]; then
        factors_json+="\"$factor\""
        first_factor=false
      else
        factors_json+=",\"$factor\""
      fi
    done
    factors_json+="]"

    # Determine migration complexity
    migration_complexity="medium"
    if (( $(awk "BEGIN {print ($complexity_score >= 0.8)}") )); then
      migration_complexity="high"
    elif (( $(awk "BEGIN {print ($complexity_score <= 0.4)}") )); then
      migration_complexity="low"
    fi

    # Estimate refactor days (base: 10 days, +2 per additional agent beyond 3)
    estimated_days=10
    if [[ $depth -gt 3 ]]; then
      additional_days=$(( (depth - 3) * 2 ))
      estimated_days=$((estimated_days + additional_days))
    fi

    # Build depth analysis JSON
    analysis_json=$(cat <<ANALYSIS
{
  "chain_id": "$chain_id",
  "depth": $depth,
  "complexity_score": $complexity_score,
  "complexity_factors": $factors_json,
  "migration_complexity": "$migration_complexity",
  "estimated_refactor_days": $estimated_days
}
ANALYSIS
)

    if [[ "$first_chain" == "true" ]]; then
      DEPTH_ANALYSIS+="$analysis_json"
      first_chain=false
    else
      DEPTH_ANALYSIS+=",$analysis_json"
    fi

    total_depth=$((total_depth + depth))
  done

  DEPTH_ANALYSIS+="]"

  # Calculate average depth
  average_depth=$(awk "BEGIN {print $total_depth / $CHAIN_COUNT}")

  # Find deepest chain
  deepest_chain_id=$(echo "$CHAINS_JSON" | jq -r '[.chains[] | {chain_id: .chain_id, depth: .depth}] | max_by(.depth) | .chain_id')
  deepest_chain_depth=$(echo "$CHAINS_JSON" | jq '[.chains[] | .depth] | max')

  # Output JSON
  cat <<EOF
{
  "status": "success",
  "depth_analysis": $DEPTH_ANALYSIS,
  "average_depth": $average_depth,
  "deepest_chain": {
    "chain_id": "$deepest_chain_id",
    "depth": $deepest_chain_depth
  }
}
EOF

else
  # Fallback if jq not available - simplified analysis
  echo "{\"status\": \"error\", \"error\": \"jq_required\", \"message\": \"jq command required for chain analysis\"}"
  exit 1
fi
