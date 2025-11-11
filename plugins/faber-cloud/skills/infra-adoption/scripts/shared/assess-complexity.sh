#!/bin/bash
# assess-complexity.sh - Shared complexity assessment logic
#
# Assesses infrastructure complexity based on Terraform structure, resources,
# environments, and custom scripts.
#
# Returns: "complexity_level|complexity_score|estimated_hours"

set -euo pipefail

# Function: Assess infrastructure complexity
assess_complexity() {
  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"

  local complexity="simple"
  local complexity_score=0

  # Terraform complexity factors
  local structure=$(jq -r '.summary.primary_structure // "flat"' "$tf_report")
  local resource_count=$(jq -r '.summary.total_resources // 0' "$tf_report")
  local module_count=$(jq -r '.terraform_directories[0].modules | length // 0' "$tf_report")
  local backend_type=$(jq -r '.terraform_directories[0].backend.type // "local"' "$tf_report")

  # Structure complexity
  case "$structure" in
    flat)
      complexity_score=$((complexity_score + 1))
      ;;
    modular)
      complexity_score=$((complexity_score + 3))
      ;;
    multi-environment)
      complexity_score=$((complexity_score + 5))
      ;;
  esac

  # Resource count complexity
  if [ "$resource_count" -gt 50 ]; then
    complexity_score=$((complexity_score + 3))
  elif [ "$resource_count" -gt 20 ]; then
    complexity_score=$((complexity_score + 2))
  elif [ "$resource_count" -gt 10 ]; then
    complexity_score=$((complexity_score + 1))
  fi

  # Module complexity
  if [ "$module_count" -gt 5 ]; then
    complexity_score=$((complexity_score + 2))
  elif [ "$module_count" -gt 0 ]; then
    complexity_score=$((complexity_score + 1))
  fi

  # Backend complexity
  if [ "$backend_type" != "local" ]; then
    complexity_score=$((complexity_score + 1))
  fi

  # AWS complexity
  local env_count=$(jq -r '.summary.project_related_profiles // 0' "$aws_report")
  if [ "$env_count" -gt 3 ]; then
    complexity_score=$((complexity_score + 2))
  elif [ "$env_count" -gt 1 ]; then
    complexity_score=$((complexity_score + 1))
  fi

  # Custom agents complexity
  local agent_count=$(jq -r '.summary.total_files // 0' "$agents_report")
  if [ "$agent_count" -gt 10 ]; then
    complexity_score=$((complexity_score + 3))
  elif [ "$agent_count" -gt 5 ]; then
    complexity_score=$((complexity_score + 2))
  elif [ "$agent_count" -gt 0 ]; then
    complexity_score=$((complexity_score + 1))
  fi

  # Determine complexity level and estimated hours
  local estimated_hours=4
  if [ "$complexity_score" -le 3 ]; then
    complexity="simple"
    estimated_hours=4
  elif [ "$complexity_score" -le 7 ]; then
    complexity="moderate"
    estimated_hours=12
  else
    complexity="complex"
    estimated_hours=24
  fi

  echo "${complexity}|${complexity_score}|${estimated_hours}"
}

# If called directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
  if [ $# -lt 3 ]; then
    echo "Usage: assess-complexity.sh <tf_report> <aws_report> <agents_report>" >&2
    echo "Returns: complexity_level|complexity_score|estimated_hours" >&2
    exit 2
  fi

  assess_complexity "$1" "$2" "$3"
fi
