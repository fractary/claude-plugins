#!/usr/bin/env bash
# Generate classification recommendation from scores
# Usage: generate-recommendation.sh {scores_json}
# Returns: JSON recommendation

set -euo pipefail

SCORES_JSON="${1:-}"

if [[ -z "$SCORES_JSON" ]]; then
  echo "ERROR: scores_json required" >&2
  exit 1
fi

# Validate JSON
if ! echo "$SCORES_JSON" | jq empty 2>/dev/null; then
  echo "ERROR: Invalid JSON scores" >&2
  exit 1
fi

# Find highest score
HIGHEST_TYPE=$(echo "$SCORES_JSON" | jq -r 'to_entries | max_by(.value) | .key')
HIGHEST_SCORE=$(echo "$SCORES_JSON" | jq -r ".$HIGHEST_TYPE")

# Find second highest (alternative)
ALTERNATIVE_TYPE=$(echo "$SCORES_JSON" | jq -r "to_entries | sort_by(-.value) | .[1].key")
ALTERNATIVE_SCORE=$(echo "$SCORES_JSON" | jq -r ".$ALTERNATIVE_TYPE")

# Determine confidence level
if [[ $HIGHEST_SCORE -ge 90 ]]; then
  CONFIDENCE="high"
  REVIEW="false"
elif [[ $HIGHEST_SCORE -ge 70 ]]; then
  CONFIDENCE="medium"
  REVIEW="true"
else
  CONFIDENCE="low"
  REVIEW="true"
  HIGHEST_TYPE="_untyped"
fi

# Generate reasoning based on type
case $HIGHEST_TYPE in
  session)
    REASONING="Session indicators detected: conversation patterns, session ID, or Claude context"
    ;;
  build)
    REASONING="Build indicators detected: build commands, exit codes, or compilation output"
    ;;
  deployment)
    REASONING="Deployment indicators detected: environment fields, version numbers, or deploy commands"
    ;;
  debug)
    REASONING="Debug indicators detected: error messages, stack traces, or troubleshooting content"
    ;;
  test)
    REASONING="Test indicators detected: test framework, pass/fail counts, or coverage metrics"
    ;;
  audit)
    REASONING="Audit indicators detected: user actions, access events, or compliance keywords"
    ;;
  operational)
    REASONING="Operational indicators detected: maintenance tasks, backups, or system operations"
    ;;
  _untyped)
    REASONING="No strong type indicators found - classification uncertain"
    ;;
esac

# Build output
cat <<EOF
{
  "recommended_type": "$HIGHEST_TYPE",
  "confidence": $HIGHEST_SCORE,
  "confidence_level": "$CONFIDENCE",
  "reasoning": "$REASONING",
  "review_recommended": $REVIEW,
  "alternative_type": "$ALTERNATIVE_TYPE",
  "alternative_score": $ALTERNATIVE_SCORE,
  "all_scores": $SCORES_JSON
}
EOF
