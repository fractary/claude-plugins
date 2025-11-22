#!/bin/bash
# Aggregate and rank search results from multiple sources
set -euo pipefail

RESULTS_JSON="${1:?Results JSON required}"
MAX_RESULTS="${2:-100}"

# Parse results JSON (expecting array of result objects)
# Each result has: source, file, issue, match_line, context

# For now, simple aggregation: deduplicate and limit
AGGREGATED=$(echo "$RESULTS_JSON" | jq -c \
    --argjson max "$MAX_RESULTS" \
    'unique_by(.file) | .[:$max]')

echo "$AGGREGATED" | jq .
