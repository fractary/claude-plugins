#!/bin/bash
set -euo pipefail

# calculate-script-benefits.sh
# Calculate context reduction benefits from script extraction

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
  echo "{\"status\": \"success\", \"benefits\": {\"tokens_saved\": 0, \"reduction_percentage\": 0}}"
  exit 0
fi

# Token estimation
# Inline logic: ~25 tokens per line of code
# Script reference: ~10 tokens ("Execute: scripts/foo.sh")

# Calculate total tokens saved across all candidates
current_inline_tokens=0
projected_inline_tokens=0

declare -A file_current_tokens
declare -A file_projected_tokens

for i in $(seq 0 $((total_candidates - 1))); do
  candidate=$(echo "$CANDIDATES_JSON" | jq ".extraction_candidates[$i]")

  code_size=$(echo "$candidate" | jq '.code_size')
  file_path=$(echo "$candidate" | jq -r '.file')

  # Current: code_size lines × 25 tokens per line
  inline_tokens=$((code_size * 25))

  # Projected: script reference = 10 tokens
  script_ref_tokens=10

  # Savings for this candidate
  savings=$((inline_tokens - script_ref_tokens))

  current_inline_tokens=$((current_inline_tokens + inline_tokens))
  projected_inline_tokens=$((projected_inline_tokens + script_ref_tokens))

  # Track by file
  if [[ ! -v "file_current_tokens[$file_path]" ]]; then
    file_current_tokens["$file_path"]=0
    file_projected_tokens["$file_path"]=0
  fi

  file_current_tokens["$file_path"]=$((${file_current_tokens[$file_path]} + inline_tokens))
  file_projected_tokens["$file_path"]=$((${file_projected_tokens[$file_path]} + script_ref_tokens))
done

# Calculate total reduction
tokens_saved=$((current_inline_tokens - projected_inline_tokens))

reduction_percentage=0
if [[ $current_inline_tokens -gt 0 ]]; then
  reduction_percentage=$(awk "BEGIN {printf \"%.2f\", $tokens_saved / $current_inline_tokens}")
fi

reduction_pct_display=$(awk "BEGIN {printf \"%d\", $reduction_percentage * 100}")

# Build per-file impact
PER_FILE_IMPACT="["
first_file=true

for file_path in "${!file_current_tokens[@]}"; do
  current_size=${file_current_tokens[$file_path]}
  projected_size=${file_projected_tokens[$file_path]}
  file_reduction=$((current_size - projected_size))
  file_percentage=$(awk "BEGIN {printf \"%.2f\", $file_reduction / $current_size}")

  # Estimate full file size (current size is just inline logic portion)
  # Assume inline logic is ~30% of total file
  estimated_full_current=$((current_size * 10 / 3))
  estimated_full_projected=$((estimated_full_current - file_reduction))

  file_impact=$(cat <<IMPACT
{
  "file": "$file_path",
  "current_size": $estimated_full_current,
  "projected_size": $estimated_full_projected,
  "reduction": $file_reduction,
  "percentage": $file_percentage
}
IMPACT
)

  if [[ "$first_file" == "true" ]]; then
    PER_FILE_IMPACT+="$file_impact"
    first_file=false
  else
    PER_FILE_IMPACT+=",$file_impact"
  fi
done

PER_FILE_IMPACT+="]"

# Calculate ROI
# Assume: average agent invoked 100 times per month
# Extraction effort from previous calculation
extraction_days=$(echo "$CANDIDATES_JSON" | jq -r '.total_effort.total_days // 4.5')

# Invocations to break even = extraction cost / tokens saved per invocation
# Simplified: assume extraction_days × 8 hours × cost vs tokens_saved × value
# For simplicity: invocations_to_break_even ≈ (extraction_days × 3)
invocations_to_break_even=$(awk "BEGIN {printf \"%.0f\", $extraction_days * 3}")

# Description
current_k=$(awk "BEGIN {printf \"%.0fK\", $current_inline_tokens / 1000}")
projected_k=$(awk "BEGIN {printf \"%.0fK\", $projected_inline_tokens / 1000}")

# Output JSON
cat <<EOF
{
  "status": "success",
  "benefits": {
    "current_inline_tokens": $current_inline_tokens,
    "projected_inline_tokens": $projected_inline_tokens,
    "tokens_saved": $tokens_saved,
    "reduction_percentage": $reduction_percentage,
    "description": "${reduction_pct_display}% reduction in inline logic tokens ($current_k → $projected_k)"
  },
  "per_file_impact": $PER_FILE_IMPACT,
  "roi": {
    "extraction_days": $extraction_days,
    "tokens_saved_per_invocation": $tokens_saved,
    "invocations_to_break_even": $invocations_to_break_even,
    "description": "Pays off after ~$invocations_to_break_even invocations"
  }
}
EOF
