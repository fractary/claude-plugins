#!/bin/bash
set -euo pipefail

# detect-manager-as-skill.sh
# Detect Manager-as-Skill anti-pattern
# Manager MUST be Agent (has state management, user interaction, orchestration)
# If these characteristics appear in a SKILL.md file, it's an anti-pattern

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Manager characteristics to detect in skill files
MANAGER_KEYWORDS=(
  "workflow_phase"
  "phases_completed"
  "user_approval"
  "AskUserQuestion"
  "state management"
  "workflow state"
  "Phase 1:"
  "Phase 2:"
  "Phase 3:"
  "orchestrate"
  "coordinate"
  "7-phase"
  "INSPECT.*ANALYZE.*PRESENT"
)

INSTANCES=()
DETAILS=()

# Scan all skill files
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    skill_dir=$(dirname "$skill_file")
    skill_name=$(basename "$skill_dir")

    # Count matching keywords
    match_count=0
    matched_keywords=()
    matched_lines=()

    for keyword in "${MANAGER_KEYWORDS[@]}"; do
      if grep -qi "$keyword" "$skill_file" 2>/dev/null; then
        match_count=$((match_count + 1))
        matched_keywords+=("$keyword")

        # Get line numbers where keyword appears
        while IFS= read -r line_num; do
          matched_lines+=("$line_num")
        done < <(grep -ni "$keyword" "$skill_file" 2>/dev/null | cut -d: -f1 || true)
      fi
    done

    # If 3+ manager characteristics found, flag as anti-pattern
    if [[ $match_count -ge 3 ]]; then
      INSTANCES+=("$skill_name")

      # Build evidence keywords JSON array
      keywords_json=$(printf ',"%s"' "${matched_keywords[@]}")
      keywords_json="[${keywords_json:1}]"

      # Build evidence lines JSON array (unique and sorted)
      unique_lines=$(printf '%s\n' "${matched_lines[@]}" | sort -nu | head -n 10)
      lines_json="["
      first=true
      while IFS= read -r line; do
        if [[ "$first" == "true" ]]; then
          lines_json+="$line"
          first=false
        else
          lines_json+=",$line"
        fi
      done <<< "$unique_lines"
      lines_json+="]"

      confidence=$(awk "BEGIN {print $match_count / ${#MANAGER_KEYWORDS[@]}}")

      detail=$(cat <<DETAIL
{
  "name": "$skill_name",
  "location": "$skill_file",
  "evidence": "File contains $match_count manager characteristics (state management, orchestration, multi-phase workflow)",
  "evidence_keywords": $keywords_json,
  "evidence_lines": $lines_json,
  "confidence": $confidence,
  "migration_days": 7,
  "priority": "high"
}
DETAIL
)
      DETAILS+=("$detail")
    fi
  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
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
  "pattern": "manager_as_skill",
  "detected": $DETECTED,
  "instances": ${#INSTANCES[@]},
  "details": $DETAILS_JSON
}
EOF
