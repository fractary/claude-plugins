#!/usr/bin/env bash
# Aggregate results from parallel execution
# Usage: aggregate-results.sh {results_dir}
# Returns: Aggregated statistics JSON

set -euo pipefail

RESULTS_DIR="${1:-}"

if [[ -z "$RESULTS_DIR" ]] || [[ ! -d "$RESULTS_DIR" ]]; then
  echo "ERROR: Valid results directory required" >&2
  exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required for aggregation" >&2
  exit 1
fi

# Collect all results
RESULT_FILES=("$RESULTS_DIR"/job-*.json)

if [[ ${#RESULT_FILES[@]} -eq 0 ]] || [[ ! -f "${RESULT_FILES[0]}" ]]; then
  cat <<EOF
{
  "total": 0,
  "status": "no_results",
  "summary": {}
}
EOF
  exit 0
fi

# Aggregate using jq
ALL_RESULTS=$(cat "${RESULT_FILES[@]}" | jq -s '.')

TOTAL=$(echo "$ALL_RESULTS" | jq 'length')
PASSED=$(echo "$ALL_RESULTS" | jq '[.[] | select(.status == "success" or .status == "passed")] | length')
FAILED=$(echo "$ALL_RESULTS" | jq '[.[] | select(.status == "failed" or .status == "error")] | length')
PENDING=$(echo "$ALL_RESULTS" | jq '[.[] | select(.status == "pending")] | length')

cat <<EOF
{
  "total": $TOTAL,
  "passed": $PASSED,
  "failed": $FAILED,
  "pending": $PENDING,
  "results": $ALL_RESULTS,
  "summary": {
    "success_rate": $(if [[ $TOTAL -gt 0 ]]; then echo "scale=2; $PASSED * 100 / $TOTAL" | bc; else echo 0; fi)
  }
}
EOF
