#!/bin/bash
set -euo pipefail

# detect-agent-chains.sh
# Detect agent chain anti-patterns (Agent1 → Agent2 → Agent3)
# Agent chains occur when agents invoke other agents via Task tool

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Data structures
declare -A AGENT_INVOCATIONS  # Maps agent → list of agents it invokes
declare -A AGENT_FILES        # Maps agent name → file path
declare -a ALL_AGENTS
declare -a CHAINS_FOUND
CHAIN_COUNT=0

# Find all agent files
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)
    AGENT_FILES["$agent_name"]="$agent_file"
    ALL_AGENTS+=("$agent_name")
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# No agents found
if [[ ${#ALL_AGENTS[@]} -eq 0 ]]; then
  echo "{\"status\": \"success\", \"chains_detected\": false, \"chain_count\": 0, \"chains\": [], \"message\": \"No agents found in project\"}"
  exit 0
fi

# Detect agent invocations in each agent file
for agent_name in "${ALL_AGENTS[@]}"; do
  agent_file="${AGENT_FILES[$agent_name]}"
  invoked_agents=()

  # Pattern 1: @agent-{plugin}:{agent-name}
  while IFS= read -r line; do
    # Extract agent name from @agent- pattern
    if [[ "$line" =~ @agent-[a-zA-Z0-9_-]+:([a-zA-Z0-9_-]+) ]]; then
      invoked_agent="${BASH_REMATCH[1]}"
      # Verify it's an actual agent in the project
      if [[ " ${ALL_AGENTS[*]} " =~ " ${invoked_agent} " ]]; then
        invoked_agents+=("$invoked_agent")
      fi
    fi
  done < <(grep -i "@agent-" "$agent_file" 2>/dev/null || true)

  # Pattern 2: Task tool invocation with agent reference
  while IFS= read -r line; do
    # Look for Task tool followed by agent name
    if [[ "$line" =~ Task.*tool.*([a-zA-Z0-9_-]+) ]]; then
      potential_agent="${BASH_REMATCH[1]}"
      if [[ " ${ALL_AGENTS[*]} " =~ " ${potential_agent} " ]]; then
        invoked_agents+=("$potential_agent")
      fi
    fi
  done < <(grep -i "Task tool\|Task(" "$agent_file" 2>/dev/null || true)

  # Store unique invocations
  if [[ ${#invoked_agents[@]} -gt 0 ]]; then
    unique_invocations=$(printf '%s\n' "${invoked_agents[@]}" | sort -u)
    AGENT_INVOCATIONS["$agent_name"]="$unique_invocations"
  fi
done

# Build chains by following invocations recursively
function find_chain() {
  local start_agent="$1"
  local current_path="$2"
  local -n visited_ref=$3

  # Add current agent to path
  local new_path="$current_path"
  if [[ -n "$new_path" ]]; then
    new_path="$new_path,$start_agent"
  else
    new_path="$start_agent"
  fi

  # Check if this agent has invocations
  if [[ -v "AGENT_INVOCATIONS[$start_agent]" ]]; then
    local invocations="${AGENT_INVOCATIONS[$start_agent]}"

    while IFS= read -r invoked_agent; do
      # Avoid cycles
      if [[ ! " ${visited_ref[*]} " =~ " ${invoked_agent} " ]]; then
        visited_ref+=("$invoked_agent")

        # Recursively follow the chain
        find_chain "$invoked_agent" "$new_path" visited_ref
      else
        # Cycle detected, still record the chain found so far
        if [[ $(echo "$new_path" | tr ',' '\n' | wc -l) -ge 2 ]]; then
          CHAINS_FOUND+=("$new_path")
        fi
      fi
    done <<< "$invocations"
  else
    # Terminal agent - record chain if length >= 2
    if [[ $(echo "$new_path" | tr ',' '\n' | wc -l) -ge 2 ]]; then
      CHAINS_FOUND+=("$new_path")
    fi
  fi
}

# Find all chains starting from each agent
for agent_name in "${ALL_AGENTS[@]}"; do
  # Only start chains from agents that have invocations
  if [[ -v "AGENT_INVOCATIONS[$agent_name]" ]]; then
    visited_agents=("$agent_name")
    find_chain "$agent_name" "" visited_agents
  fi
done

# Deduplicate chains (same chain found multiple times)
if [[ ${#CHAINS_FOUND[@]} -gt 0 ]]; then
  UNIQUE_CHAINS=($(printf '%s\n' "${CHAINS_FOUND[@]}" | sort -u))
else
  UNIQUE_CHAINS=()
fi

# No chains detected
if [[ ${#UNIQUE_CHAINS[@]} -eq 0 ]]; then
  echo "{\"status\": \"success\", \"chains_detected\": false, \"chain_count\": 0, \"chains\": [], \"message\": \"No agent chains found - project uses modern architecture\"}"
  exit 0
fi

# Build JSON output for each chain
CHAINS_JSON="["
first_chain=true

for chain_path in "${UNIQUE_CHAINS[@]}"; do
  # Parse chain path
  IFS=',' read -ra CHAIN_AGENTS <<< "$chain_path"

  entry_point="${CHAIN_AGENTS[0]}"
  chain_depth=${#CHAIN_AGENTS[@]}
  chain_id="${entry_point}-chain"

  # Build agents array JSON
  agents_json="["
  first_agent=true
  for agent in "${CHAIN_AGENTS[@]}"; do
    if [[ "$first_agent" == "true" ]]; then
      agents_json+="\"$agent\""
      first_agent=false
    else
      agents_json+=",\"$agent\""
    fi
  done
  agents_json+="]"

  # Build locations array JSON
  locations_json="["
  first_location=true
  for agent in "${CHAIN_AGENTS[@]}"; do
    location="${AGENT_FILES[$agent]}"
    if [[ "$first_location" == "true" ]]; then
      locations_json+="\"$location\""
      first_location=false
    else
      locations_json+=",\"$location\""
    fi
  done
  locations_json+="]"

  # Estimate context (45K per agent)
  context_estimate=$((chain_depth * 45000))

  # Build chain JSON object
  chain_json=$(cat <<CHAIN
{
  "chain_id": "$chain_id",
  "entry_point": "$entry_point",
  "agents": $agents_json,
  "depth": $chain_depth,
  "locations": $locations_json,
  "invocation_pattern": "Task tool",
  "context_estimate": $context_estimate
}
CHAIN
)

  if [[ "$first_chain" == "true" ]]; then
    CHAINS_JSON+="$chain_json"
    first_chain=false
  else
    CHAINS_JSON+=",$chain_json"
  fi

  CHAIN_COUNT=$((CHAIN_COUNT + 1))
done

CHAINS_JSON+="]"

# Calculate total agents in chains (unique)
AGENTS_IN_CHAINS=()
for chain_path in "${UNIQUE_CHAINS[@]}"; do
  IFS=',' read -ra CHAIN_AGENTS <<< "$chain_path"
  for agent in "${CHAIN_AGENTS[@]}"; do
    AGENTS_IN_CHAINS+=("$agent")
  done
done
UNIQUE_AGENTS_IN_CHAINS=($(printf '%s\n' "${AGENTS_IN_CHAINS[@]}" | sort -u))
TOTAL_AGENTS_IN_CHAINS=${#UNIQUE_AGENTS_IN_CHAINS[@]}

# Find max chain depth
MAX_DEPTH=0
for chain_path in "${UNIQUE_CHAINS[@]}"; do
  IFS=',' read -ra CHAIN_AGENTS <<< "$chain_path"
  depth=${#CHAIN_AGENTS[@]}
  if [[ $depth -gt $MAX_DEPTH ]]; then
    MAX_DEPTH=$depth
  fi
done

# Output final JSON
cat <<EOF
{
  "status": "success",
  "chains_detected": true,
  "chain_count": $CHAIN_COUNT,
  "chains": $CHAINS_JSON,
  "total_agents_in_chains": $TOTAL_AGENTS_IN_CHAINS,
  "max_chain_depth": $MAX_DEPTH
}
EOF
