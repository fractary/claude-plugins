#!/bin/bash
set -euo pipefail

# identify-extraction-candidates.sh
# Identify specific code blocks that should be extracted to scripts

PROJECT_PATH="${1:-.}"
INLINE_LOGIC_JSON="${2:-{}}"

# Validate inputs
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

if ! command -v jq &> /dev/null; then
  echo "{\"status\": \"error\", \"error\": \"jq_required\"}"
  exit 1
fi

# Parse inline logic data
inline_detected=$(echo "$INLINE_LOGIC_JSON" | jq -r '.inline_logic_detected // false')

if [[ "$inline_detected" == "false" ]]; then
  echo "{\"status\": \"success\", \"extraction_candidates\": [], \"total_candidates\": 0}"
  exit 0
fi

total_instances=$(echo "$INLINE_LOGIC_JSON" | jq '.total_instances // 0')

# Build extraction candidates
CANDIDATES="["
first_candidate=true
candidate_count=0
high_value_count=0
medium_value_count=0
low_value_count=0

# Process each file with inline logic
file_count=$(echo "$INLINE_LOGIC_JSON" | jq '.by_file | length')

for i in $(seq 0 $((file_count - 1))); do
  file_data=$(echo "$INLINE_LOGIC_JSON" | jq ".by_file[$i]")

  file_path=$(echo "$file_data" | jq -r '.file')
  patterns=$(echo "$file_data" | jq '.patterns')
  pattern_count=$(echo "$patterns" | jq 'length')

  # Group similar patterns (if multiple patterns in same file, they might be extractable together)
  for j in $(seq 0 $((pattern_count - 1))); do
    pattern=$(echo "$patterns" | jq ".[$j]")

    pattern_type=$(echo "$pattern" | jq -r '.pattern_type')
    line_number=$(echo "$pattern" | jq '.line_number')
    code_snippet=$(echo "$pattern" | jq -r '.code_snippet')
    severity=$(echo "$pattern" | jq -r '.severity')

    # Estimate code size (number of lines this logic might span)
    # For bash commands: usually 1-3 lines
    # For algorithms: could be 5-20 lines
    code_size=1
    if [[ "$pattern_type" == "algorithm" ]]; then
      code_size=10
    elif [[ "$pattern_type" == "data_processing" ]]; then
      code_size=5
    fi

    # Determine extraction value
    extraction_value="medium"
    reason="Standard extraction candidate"

    if [[ "$pattern_type" == "bash_command" && "$severity" == "high" ]]; then
      extraction_value="high"
      reason="Bash command easily extractable to script"
    elif [[ "$pattern_type" == "algorithm" ]]; then
      extraction_value="high"
      reason="Deterministic algorithm - ideal for script"
    elif [[ "$pattern_type" == "data_processing" ]]; then
      extraction_value="medium"
      reason="Data processing logic"
    elif [[ "$pattern_type" == "validation" ]]; then
      extraction_value="high"
      reason="Validation logic - deterministic and reusable"
    fi

    # Generate suggested script name
    file_name=$(basename "$file_path" .md)
    script_name=$(echo "$pattern_type" | tr '_' '-')
    suggested_script="scripts/${script_name}-${file_name}.sh"

    # Estimate context savings (tokens)
    # Inline logic: ~25 tokens per line
    # Script reference: ~10 tokens
    # Savings = (code_size * 25) - 10
    context_savings=$(( (code_size * 25) - 10 ))

    # Build candidate JSON
    candidate_id="${file_name}-${pattern_type}-${line_number}"

    candidate=$(cat <<CANDIDATE
{
  "candidate_id": "$candidate_id",
  "file": "$file_path",
  "location": "line $line_number",
  "pattern_type": "$pattern_type",
  "code_size": $code_size,
  "extraction_value": "$extraction_value",
  "reason": "$reason",
  "suggested_script": "$suggested_script",
  "context_savings": $context_savings
}
CANDIDATE
)

    if [[ "$first_candidate" == "true" ]]; then
      CANDIDATES+="$candidate"
      first_candidate=false
    else
      CANDIDATES+=",$candidate"
    fi

    candidate_count=$((candidate_count + 1))

    # Count by value
    if [[ "$extraction_value" == "high" ]]; then
      high_value_count=$((high_value_count + 1))
    elif [[ "$extraction_value" == "medium" ]]; then
      medium_value_count=$((medium_value_count + 1))
    else
      low_value_count=$((low_value_count + 1))
    fi
  done
done

CANDIDATES+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "extraction_candidates": $CANDIDATES,
  "total_candidates": $candidate_count,
  "high_value_count": $high_value_count,
  "medium_value_count": $medium_value_count,
  "low_value_count": $low_value_count
}
EOF
