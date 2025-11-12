#!/bin/bash
set -euo pipefail

# detect-inline-logic.sh
# Detect inline logic in agent and skill files that should be extracted to scripts

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Inline logic patterns to detect
# Pattern categories:
# 1. Bash commands (grep, awk, sed, find, etc.)
# 2. Algorithms (for loops, step-by-step logic)
# 3. Data processing (parse, transform, filter)
# 4. Validation logic (if/then checks)

BASH_PATTERNS=(
  "grep -"
  "awk "
  "sed "
  "find "
  "jq "
  "curl "
  "sort "
  "uniq "
  "cut "
  "tr "
)

ALGORITHM_PATTERNS=(
  "for each"
  "for every"
  "loop through"
  "iterate over"
  "step 1:"
  "step 2:"
  "1\. "
  "2\. "
  "3\. "
)

DATA_PATTERNS=(
  "parse.*json"
  "transform"
  "filter.*results"
  "extract.*field"
  "calculate"
  "aggregate"
)

VALIDATION_PATTERNS=(
  "if.*missing"
  "if.*invalid"
  "if.*not.*found"
  "validate"
  "check.*format"
)

# Exclusion patterns (NOT inline logic - legitimate orchestration)
EXCLUSION_PATTERNS=(
  "Invoke:"
  "Execute:"
  "Use the @skill"
  "Use the @agent"
  "AskUserQuestion"
  "Phase [0-9]:"
  "<WORKFLOW>"
  "<OPERATIONS>"
)

BY_FILE_JSON="["
first_file=true
total_instances=0
total_lines=0

# Scan agents
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    instances=()

    # Check each pattern category
    line_num=0
    while IFS= read -r line; do
      line_num=$((line_num + 1))

      # Skip excluded patterns
      is_excluded=false
      for exclude_pattern in "${EXCLUSION_PATTERNS[@]}"; do
        if echo "$line" | grep -qi "$exclude_pattern" 2>/dev/null; then
          is_excluded=true
          break
        fi
      done

      if [[ "$is_excluded" == "true" ]]; then
        continue
      fi

      # Check bash patterns
      for pattern in "${BASH_PATTERNS[@]}"; do
        if echo "$line" | grep -q "$pattern" 2>/dev/null; then
          # Extract snippet (up to 80 chars)
          snippet=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)

          instance=$(cat <<INSTANCE
{
  "pattern_type": "bash_command",
  "line_number": $line_num,
  "code_snippet": "$(echo "$snippet" | sed 's/"/\\"/g')",
  "severity": "high",
  "extraction_candidate": true
}
INSTANCE
)
          instances+=("$instance")
          total_instances=$((total_instances + 1))
          break
        fi
      done

      # Check algorithm patterns
      for pattern in "${ALGORITHM_PATTERNS[@]}"; do
        if echo "$line" | grep -qi "$pattern" 2>/dev/null; then
          snippet=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)

          instance=$(cat <<INSTANCE
{
  "pattern_type": "algorithm",
  "line_number": $line_num,
  "code_snippet": "$(echo "$snippet" | sed 's/"/\\"/g')",
  "severity": "medium",
  "extraction_candidate": true
}
INSTANCE
)
          instances+=("$instance")
          total_instances=$((total_instances + 1))
          break
        fi
      done

      # Check data processing patterns
      for pattern in "${DATA_PATTERNS[@]}"; do
        if echo "$line" | grep -qi "$pattern" 2>/dev/null; then
          snippet=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)

          instance=$(cat <<INSTANCE
{
  "pattern_type": "data_processing",
  "line_number": $line_num,
  "code_snippet": "$(echo "$snippet" | sed 's/"/\\"/g')",
  "severity": "medium",
  "extraction_candidate": true
}
INSTANCE
)
          instances+=("$instance")
          total_instances=$((total_instances + 1))
          break
        fi
      done

    done < "$agent_file"

    # If instances found, add to output
    if [[ ${#instances[@]} -gt 0 ]]; then
      patterns_json="["
      first_pattern=true
      for inst in "${instances[@]}"; do
        if [[ "$first_pattern" == "true" ]]; then
          patterns_json+="$inst"
          first_pattern=false
        else
          patterns_json+=",$inst"
        fi
      done
      patterns_json+="]"

      file_entry=$(cat <<FILE
{
  "file": "$agent_file",
  "type": "agent",
  "instances": ${#instances[@]},
  "patterns": $patterns_json
}
FILE
)

      if [[ "$first_file" == "true" ]]; then
        BY_FILE_JSON+="$file_entry"
        first_file=false
      else
        BY_FILE_JSON+=",$file_entry"
      fi

      total_lines=$((total_lines + ${#instances[@]}))
    fi

  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Scan skills
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    instances=()

    line_num=0
    while IFS= read -r line; do
      line_num=$((line_num + 1))

      # Skip excluded patterns
      is_excluded=false
      for exclude_pattern in "${EXCLUSION_PATTERNS[@]}"; do
        if echo "$line" | grep -qi "$exclude_pattern" 2>/dev/null; then
          is_excluded=true
          break
        fi
      done

      if [[ "$is_excluded" == "true" ]]; then
        continue
      fi

      # Check patterns (same as agents)
      for pattern in "${BASH_PATTERNS[@]}"; do
        if echo "$line" | grep -q "$pattern" 2>/dev/null; then
          snippet=$(echo "$line" | sed 's/^[[:space:]]*//' | cut -c1-80)

          instance=$(cat <<INSTANCE
{
  "pattern_type": "bash_command",
  "line_number": $line_num,
  "code_snippet": "$(echo "$snippet" | sed 's/"/\\"/g')",
  "severity": "high",
  "extraction_candidate": true
}
INSTANCE
)
          instances+=("$instance")
          total_instances=$((total_instances + 1))
          break
        fi
      done
    done < "$skill_file"

    # If instances found, add to output
    if [[ ${#instances[@]} -gt 0 ]]; then
      patterns_json="["
      first_pattern=true
      for inst in "${instances[@]}"; do
        if [[ "$first_pattern" == "true" ]]; then
          patterns_json+="$inst"
          first_pattern=false
        else
          patterns_json+=",$inst"
        fi
      done
      patterns_json+="]"

      file_entry=$(cat <<FILE
{
  "file": "$skill_file",
  "type": "skill",
  "instances": ${#instances[@]},
  "patterns": $patterns_json
}
FILE
)

      if [[ "$first_file" == "true" ]]; then
        BY_FILE_JSON+="$file_entry"
        first_file=false
      else
        BY_FILE_JSON+=",$file_entry"
      fi

      total_lines=$((total_lines + ${#instances[@]}))
    fi

  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

BY_FILE_JSON+="]"

# Determine if inline logic detected
INLINE_LOGIC_DETECTED=false
if [[ $total_instances -gt 0 ]]; then
  INLINE_LOGIC_DETECTED=true
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "inline_logic_detected": $INLINE_LOGIC_DETECTED,
  "total_instances": $total_instances,
  "by_file": $BY_FILE_JSON,
  "total_lines_of_inline_logic": $total_lines
}
EOF
