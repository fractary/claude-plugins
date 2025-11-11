#!/bin/bash
set -euo pipefail

# map-chain-dependencies.sh
# Map complete dependency graph for agent chains

PROJECT_PATH="${1:-.}"
CHAINS_JSON="${2:-{}}"

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
  echo "{\"status\": \"error\", \"error\": \"jq_required\", \"message\": \"jq command required for dependency mapping\"}"
  exit 1
fi

CHAIN_COUNT=$(echo "$CHAINS_JSON" | jq '.chain_count // 0')

if [[ $CHAIN_COUNT -eq 0 ]]; then
  echo "{\"status\": \"success\", \"dependency_graph\": {\"nodes\": [], \"edges\": []}, \"data_flow\": []}"
  exit 0
fi

# Build nodes and edges for dependency graph
NODES="["
EDGES="["
DATA_FLOW=()
PARALLELIZATION_OPPORTUNITIES=()

first_node=true
first_edge=true

# Process all chains
for i in $(seq 0 $((CHAIN_COUNT - 1))); do
  chain=$(echo "$CHAINS_JSON" | jq ".chains[$i]")

  agents=$(echo "$chain" | jq -r '.agents[]')
  agents_array=($agents)

  # Create nodes for each agent
  for j in "${!agents_array[@]}"; do
    agent="${agents_array[$j]}"

    # Determine node type
    node_type="intermediate"
    if [[ $j -eq 0 ]]; then
      node_type="entry_point"
    elif [[ $j -eq $((${#agents_array[@]} - 1)) ]]; then
      node_type="terminal"
    fi

    # Check if node already exists (agent might be in multiple chains)
    node_exists=$(echo "$NODES" | grep -c "\"id\": \"$agent\"" || echo "0")

    if [[ $node_exists -eq 0 ]]; then
      node_json="{\"id\": \"$agent\", \"type\": \"$node_type\"}"

      if [[ "$first_node" == "true" ]]; then
        NODES+="$node_json"
        first_node=false
      else
        NODES+=",$node_json"
      fi
    fi
  done

  # Create edges between consecutive agents in chain
  for j in $(seq 0 $((${#agents_array[@]} - 2))); do
    from_agent="${agents_array[$j]}"
    to_agent="${agents_array[$((j + 1))]}"

    # Analyze data passed between agents
    from_agent_file="$PROJECT_PATH/.claude/agents/${from_agent}.md"
    data_passed=()

    if [[ -f "$from_agent_file" ]]; then
      # Look for data structures being passed
      # Common patterns: JSON objects, result variables, etc.
      if grep -qi "results\|data\|output" "$from_agent_file" 2>/dev/null; then
        # Extract variable names that might be passed
        while IFS= read -r line; do
          if [[ "$line" =~ (results|data|output|response|payload) ]]; then
            data_passed+=("${BASH_REMATCH[0]}")
          fi
        done < <(grep -oi '\b\w*\(results\|data\|output\|response\|payload\)\w*\b' "$from_agent_file" 2>/dev/null | head -n 3 || true)
      fi
    fi

    # Default if no specific data found
    if [[ ${#data_passed[@]} -eq 0 ]]; then
      data_passed=("task_results")
    fi

    # Build data_passed JSON array
    data_passed_json="["
    first_data=true
    for data in "${data_passed[@]}"; do
      if [[ "$first_data" == "true" ]]; then
        data_passed_json+="\"$data\""
        first_data=false
      else
        data_passed_json+=",\"$data\""
      fi
    done
    data_passed_json+="]"

    # Create edge
    edge_json=$(cat <<EDGE
{
  "from": "$from_agent",
  "to": "$to_agent",
  "data_passed": $data_passed_json,
  "invocation_method": "Task tool"
}
EDGE
)

    if [[ "$first_edge" == "true" ]]; then
      EDGES+="$edge_json"
      first_edge=false
    else
      EDGES+=",$edge_json"
    fi

    # Track data flow
    for data in "${data_passed[@]}"; do
      DATA_FLOW+=("$data ($from_agent → $to_agent)")
    done
  done

  # Analyze parallelization opportunities
  if [[ ${#agents_array[@]} -ge 3 ]]; then
    # Check if intermediate agents are independent
    # If agents 2 and 3 don't depend on each other's output, they could run in parallel
    if [[ ${#agents_array[@]} -ge 4 ]]; then
      agent2="${agents_array[1]}"
      agent3="${agents_array[2]}"

      # Simple heuristic: if different domains (e.g., analyzer vs validator)
      if [[ "$agent2" != "$agent3" ]]; then
        PARALLELIZATION_OPPORTUNITIES+=("$agent2 and $agent3 could potentially run in parallel if refactored")
      fi
    fi
  fi
done

NODES+="]"
EDGES+="]"

# Build data_flow JSON array
DATA_FLOW_JSON="["
first_flow=true
# Deduplicate data flow entries
UNIQUE_DATA_FLOW=($(printf '%s\n' "${DATA_FLOW[@]}" | sort -u))
for flow in "${UNIQUE_DATA_FLOW[@]}"; do
  if [[ "$first_flow" == "true" ]]; then
    DATA_FLOW_JSON+="\"$flow\""
    first_flow=false
  else
    DATA_FLOW_JSON+=",\"$flow\""
  fi
done
DATA_FLOW_JSON+="]"

# Build parallelization opportunities JSON array
PARALLEL_JSON="["
if [[ ${#PARALLELIZATION_OPPORTUNITIES[@]} -gt 0 ]]; then
  first_parallel=true
  for opp in "${PARALLELIZATION_OPPORTUNITIES[@]}"; do
    if [[ "$first_parallel" == "true" ]]; then
      PARALLEL_JSON+="\"$opp\""
      first_parallel=false
    else
      PARALLEL_JSON+=",\"$opp\""
    fi
  done
fi
PARALLEL_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "dependency_graph": {
    "nodes": $NODES,
    "edges": $EDGES
  },
  "data_flow": $DATA_FLOW_JSON,
  "parallelization_opportunities": $PARALLEL_JSON
}
EOF
