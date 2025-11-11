#!/bin/bash
set -euo pipefail

# detect-director-as-agent.sh
# Detect Director-as-Agent anti-pattern
# Director MUST be Skill (simple pattern expansion only)
# If an Agent only does pattern expansion and no orchestration, it's an anti-pattern

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Director characteristics (simple responsibilities)
DIRECTOR_KEYWORDS=(
  "pattern.*expan"
  "wildcard"
  "expand.*pattern"
  "parse.*pattern"
  "\*\*\/\*"
  "comma.*separated"
  "glob"
  "entity.*list"
  "parallelism.*recommendation"
)

# Anti-indicators (if present, NOT a director anti-pattern)
ORCHESTRATION_KEYWORDS=(
  "workflow"
  "orchestrate"
  "Phase 1:"
  "state management"
  "AskUserQuestion"
  "coordinate"
  "user.*approval"
)

INSTANCES=()
DETAILS=()

# Scan all agent files
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    agent_name=$(basename "$agent_file" .md)

    # Count director pattern keywords
    director_match_count=0
    matched_keywords=()

    for keyword in "${DIRECTOR_KEYWORDS[@]}"; do
      if grep -qi "$keyword" "$agent_file" 2>/dev/null; then
        director_match_count=$((director_match_count + 1))
        matched_keywords+=("$keyword")
      fi
    done

    # Count orchestration keywords (should be absent for director)
    orchestration_count=0
    for keyword in "${ORCHESTRATION_KEYWORDS[@]}"; do
      if grep -qi "$keyword" "$agent_file" 2>/dev/null; then
        orchestration_count=$((orchestration_count + 1))
      fi
    done

    # If looks like director (3+ pattern keywords) AND no orchestration (< 2 keywords)
    # Then it's a Director-as-Agent anti-pattern
    if [[ $director_match_count -ge 3 && $orchestration_count -lt 2 ]]; then
      INSTANCES+=("$agent_name")

      # Build evidence keywords JSON array
      keywords_json=$(printf ',"%s"' "${matched_keywords[@]}")
      keywords_json="[${keywords_json:1}]"

      # Check if name contains "director" or "expander"
      simple_name=false
      if [[ "$agent_name" =~ director|expander|router ]]; then
        simple_name=true
      fi

      confidence=$(awk "BEGIN {print ($director_match_count / ${#DIRECTOR_KEYWORDS[@]}) * (1 - $orchestration_count / ${#ORCHESTRATION_KEYWORDS[@]})}")

      detail=$(cat <<DETAIL
{
  "name": "$agent_name",
  "location": "$agent_file",
  "evidence": "Agent only expands patterns ($director_match_count pattern keywords, $orchestration_count orchestration keywords)",
  "evidence_keywords": $keywords_json,
  "simple_responsibility": true,
  "simple_name": $simple_name,
  "confidence": $confidence,
  "migration_days": 2,
  "priority": "medium"
}
DETAIL
)
      DETAILS+=("$detail")
    fi
  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Build output
DETECTED=false
if [[ ${#INSTANCES[@]} -gt 0 ]]; then
  DETECTED=true
fi

# Build details JSON array
DETAILS_JSON="["
if [[ ${#DETAILS[@]} -gt 0 ]]; then
  first=true
  for detail in "${DETAILS[@]}"; do
    if [[ "$first" == "true" ]]; then
      DETAILS_JSON+="$detail"
      first=false
    else
      DETAILS_JSON+=",$detail"
    fi
  done
fi
DETAILS_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "pattern": "director_as_agent",
  "detected": $DETECTED,
  "instances": ${#INSTANCES[@]},
  "details": $DETAILS_JSON
}
EOF
