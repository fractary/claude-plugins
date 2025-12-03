#!/bin/bash
set -euo pipefail

# detect-direct-skill-commands.sh
# Detect direct skill command invocations (CMD-004)
# Commands MUST route through manager agent, not invoke skills directly
# Exception: *-direct.md and *director*.md commands are allowed

PROJECT_PATH="${1:-.}"

# Check for jq dependency
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required but not installed"}'
  exit 1
fi

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  jq -n '{status: "error", error: "invalid_project", message: ".claude/ directory not found"}'
  exit 1
fi

# Patterns that indicate direct skill invocation (not through manager)
# Note: Using [[:space:]] for POSIX portability instead of \s
DIRECT_SKILL_PATTERNS=(
  'Skill[[:space:]]*\('
  'Skill[[:space:]]*:'
  '@skill-'
  'invoke[[:space:]]+skill'
  'skill[[:space:]]+invoke'
  'SlashCommand[[:space:]]+skill'
)

# Patterns that indicate proper manager routing (these are OK)
MANAGER_PATTERNS=(
  'manager'
  'Manager'
  'director'
  'Director'
)

COMPLIANT_COMMANDS=()
NON_COMPLIANT_COMMANDS=()
DETAILS=()

# Find all command files
if [[ -d "$PROJECT_PATH/.claude/commands" ]]; then
  while IFS= read -r -d '' cmd_file; do
    cmd_name=$(basename "$cmd_file" .md)

    # Skip exception files
    if [[ "$cmd_name" == *"-direct" ]] || [[ "$cmd_name" == *"direct" ]] || [[ "$cmd_name" == *"director"* ]]; then
      COMPLIANT_COMMANDS+=("$cmd_name (exception)")
      continue
    fi

    # Check if command invokes skills directly
    has_direct_skill=false
    direct_skill_evidence=()
    evidence_lines=()

    for pattern in "${DIRECT_SKILL_PATTERNS[@]}"; do
      if grep -Eqi "$pattern" "$cmd_file" 2>/dev/null; then
        # Found potential direct skill invocation - check if it's to a manager/director
        matching_lines=$(grep -Eni "$pattern" "$cmd_file" 2>/dev/null || true)

        while IFS= read -r match_line; do
          if [[ -z "$match_line" ]]; then
            continue
          fi

          line_num=$(echo "$match_line" | cut -d: -f1)
          line_content=$(echo "$match_line" | cut -d: -f2-)

          # Check if this line also references a manager/director (which is OK)
          is_manager_call=false
          for mgr_pattern in "${MANAGER_PATTERNS[@]}"; do
            if echo "$line_content" | grep -qi "$mgr_pattern"; then
              is_manager_call=true
              break
            fi
          done

          if [[ "$is_manager_call" == "false" ]]; then
            has_direct_skill=true
            direct_skill_evidence+=("$pattern")
            evidence_lines+=("$line_num")
          fi
        done <<< "$matching_lines"
      fi
    done

    if [[ "$has_direct_skill" == "true" ]]; then
      NON_COMPLIANT_COMMANDS+=("$cmd_name")

      # Build evidence JSON arrays (escape special characters for JSON)
      if [[ ${#direct_skill_evidence[@]} -gt 0 ]]; then
        # Escape backslashes and quotes in patterns for valid JSON
        escaped_patterns=()
        for pat in "${direct_skill_evidence[@]}"; do
          escaped=$(echo "$pat" | sed 's/\\/\\\\/g' | sed 's/"/\\"/g')
          escaped_patterns+=("$escaped")
        done
        evidence_json=$(printf ',"%s"' "${escaped_patterns[@]}" | sort -u)
        evidence_json="[${evidence_json:1}]"
      else
        evidence_json="[]"
      fi

      if [[ ${#evidence_lines[@]} -gt 0 ]]; then
        lines_json=$(printf '%s\n' "${evidence_lines[@]}" | sort -nu | head -10 | paste -sd, -)
        lines_json="[$lines_json]"
      else
        lines_json="[]"
      fi

      # Get code snippet from first violation line (properly JSON-escaped)
      first_line="${evidence_lines[0]:-1}"
      raw_snippet=$(sed -n "${first_line}p" "$cmd_file" 2>/dev/null | head -c 200)
      # Use jq -Rs for proper JSON string escaping (handles quotes, backslashes, newlines)
      snippet=$(echo "$raw_snippet" | jq -Rs '.' | sed 's/^"//;s/"$//')

      detail=$(cat <<DETAIL
{
  "name": "$cmd_name",
  "location": "$cmd_file",
  "rule_id": "CMD-004",
  "rule_name": "No direct skill commands",
  "severity": "critical",
  "evidence": "Command invokes skill directly instead of routing through manager agent",
  "matched_patterns": $evidence_json,
  "evidence_lines": $lines_json,
  "code_snippet": "$snippet",
  "remediation": [
    "Remove direct skill invocation from command",
    "Create or update manager agent to handle this operation",
    "Add --action flag support if creating new workflow step",
    "Update command to invoke manager agent with action parameter"
  ],
  "example_fix": {
    "before": "Skill: myproject-validator",
    "after": "Agent: myproject-manager, Request: {operation: validate}"
  }
}
DETAIL
)
      DETAILS+=("$detail")
    else
      COMPLIANT_COMMANDS+=("$cmd_name")
    fi
  done < <(find "$PROJECT_PATH/.claude/commands" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Build output
TOTAL_COMMANDS=$((${#COMPLIANT_COMMANDS[@]} + ${#NON_COMPLIANT_COMMANDS[@]}))
VIOLATIONS_FOUND=false
if [[ ${#NON_COMPLIANT_COMMANDS[@]} -gt 0 ]]; then
  VIOLATIONS_FOUND=true
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

# Build compliant list
COMPLIANT_JSON="["
if [[ ${#COMPLIANT_COMMANDS[@]} -gt 0 ]]; then
  first=true
  for cmd in "${COMPLIANT_COMMANDS[@]}"; do
    if [[ "$first" == "true" ]]; then
      COMPLIANT_JSON+="\"$cmd\""
      first=false
    else
      COMPLIANT_JSON+=",\"$cmd\""
    fi
  done
fi
COMPLIANT_JSON+="]"

# Output JSON
cat <<EOF
{
  "status": "success",
  "rule_id": "CMD-004",
  "rule_name": "No direct skill commands",
  "total_commands": $TOTAL_COMMANDS,
  "compliant_count": ${#COMPLIANT_COMMANDS[@]},
  "non_compliant_count": ${#NON_COMPLIANT_COMMANDS[@]},
  "violations_found": $VIOLATIONS_FOUND,
  "compliant_commands": $COMPLIANT_JSON,
  "details": $DETAILS_JSON
}
EOF
