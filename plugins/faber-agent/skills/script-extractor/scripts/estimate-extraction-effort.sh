#!/bin/bash
set -euo pipefail

# estimate-extraction-effort.sh
# Estimate effort required to extract inline logic to scripts

PROJECT_PATH="${1:-.}"
CANDIDATES_JSON="${2:-{}}"

# Validate inputs
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "{\"status\": \"error\", \"error\": \"jq_required\"}"
  exit 1
fi

# Parse candidates
total_candidates=$(echo "$CANDIDATES_JSON" | jq '.total_candidates // 0')

if [[ $total_candidates -eq 0 ]]; then
  echo "{\"status\": \"success\", \"effort_estimates\": [], \"total_effort\": {\"total_hours\": 0, \"total_days\": 0}}"
  exit 0
fi

# Effort estimation constants (hours)
# Based on: extract code, parameterize, test, update references
SIMPLE_EXTRACTION=0.5    # Simple bash command
MEDIUM_EXTRACTION=2.0    # Algorithm or data processing
COMPLEX_EXTRACTION=4.0   # Complex logic with dependencies

TESTING_MULTIPLIER=0.5   # Testing = 50% of extraction time

# Estimate effort for each candidate
EFFORT_ESTIMATES="["
first_estimate=true

total_extraction_hours=0
total_testing_hours=0

for i in $(seq 0 $((total_candidates - 1))); do
  candidate=$(echo "$CANDIDATES_JSON" | jq ".extraction_candidates[$i]")

  candidate_id=$(echo "$candidate" | jq -r '.candidate_id')
  pattern_type=$(echo "$candidate" | jq -r '.pattern_type')
  code_size=$(echo "$candidate" | jq '.code_size')

  # Determine complexity based on pattern type and code size
  complexity="simple"
  extraction_hours=$SIMPLE_EXTRACTION

  if [[ "$pattern_type" == "bash_command" ]]; then
    if [[ $code_size -le 3 ]]; then
      complexity="simple"
      extraction_hours=$SIMPLE_EXTRACTION
    else
      complexity="medium"
      extraction_hours=$MEDIUM_EXTRACTION
    fi
  elif [[ "$pattern_type" == "algorithm" ]]; then
    complexity="medium"
    extraction_hours=$MEDIUM_EXTRACTION
    if [[ $code_size -gt 15 ]]; then
      complexity="complex"
      extraction_hours=$COMPLEX_EXTRACTION
    fi
  elif [[ "$pattern_type" == "data_processing" ]]; then
    complexity="medium"
    extraction_hours=$MEDIUM_EXTRACTION
  elif [[ "$pattern_type" == "validation" ]]; then
    complexity="simple"
    extraction_hours=$SIMPLE_EXTRACTION
  fi

  # Calculate testing hours
  testing_hours=$(awk "BEGIN {printf \"%.1f\", $extraction_hours * $TESTING_MULTIPLIER}")

  # Total hours for this candidate
  total_hours=$(awk "BEGIN {printf \"%.1f\", $extraction_hours + $testing_hours}")

  # Check for dependencies (existing scripts that might be reused)
  dependencies=[]
  file_path=$(echo "$candidate" | jq -r '.file')
  skill_dir=$(dirname "$(dirname "$file_path")")

  if [[ -d "$skill_dir/scripts" ]]; then
    script_count=$(find "$skill_dir/scripts" -name "*.sh" 2>/dev/null | wc -l || echo "0")
    if [[ $script_count -gt 0 ]]; then
      dependencies='["existing validation scripts"]'
    fi
  fi

  # Build effort estimate JSON
  estimate=$(cat <<ESTIMATE
{
  "candidate_id": "$candidate_id",
  "complexity": "$complexity",
  "extraction_hours": $extraction_hours,
  "testing_hours": $testing_hours,
  "total_hours": $total_hours,
  "dependencies": $dependencies
}
ESTIMATE
)

  if [[ "$first_estimate" == "true" ]]; then
    EFFORT_ESTIMATES+="$estimate"
    first_estimate=false
  else
    EFFORT_ESTIMATES+=",$estimate"
  fi

  # Accumulate totals
  total_extraction_hours=$(awk "BEGIN {print $total_extraction_hours + $extraction_hours}")
  total_testing_hours=$(awk "BEGIN {print $total_testing_hours + $testing_hours}")
done

EFFORT_ESTIMATES+="]"

# Calculate total effort
total_hours=$(awk "BEGIN {print $total_extraction_hours + $total_testing_hours}")
total_days=$(awk "BEGIN {printf \"%.1f\", $total_hours / 8}")  # 8-hour workday

# Output JSON
cat <<EOF
{
  "status": "success",
  "effort_estimates": $EFFORT_ESTIMATES,
  "total_effort": {
    "extraction_hours": $total_extraction_hours,
    "testing_hours": $total_testing_hours,
    "total_hours": $total_hours,
    "total_days": $total_days
  }
}
EOF
