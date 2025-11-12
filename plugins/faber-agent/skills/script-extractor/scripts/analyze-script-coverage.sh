#!/bin/bash
set -euo pipefail

# analyze-script-coverage.sh
# Calculate what percentage of operations are properly scripted vs inline

PROJECT_PATH="${1:-.}"

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  echo "{\"status\": \"error\", \"error\": \"invalid_project\"}"
  exit 1
fi

# Count total operations vs scripted operations

total_operations=0
scripted_operations=0
inline_operations=0

agents_total=0
agents_scripted=0
agents_inline=0

skills_total=0
skills_scripted=0
skills_inline=0

# Scan agents for operations
if [[ -d "$PROJECT_PATH/.claude/agents" ]]; then
  while IFS= read -r -d '' agent_file; do
    # Count operations (look for operation markers)
    ops_count=$(grep -ci "##\s*\|^-\s*\|^[0-9]\.\s*\|Execute:\|Invoke:" "$agent_file" 2>/dev/null || echo "0")

    # Count script invocations
    script_count=$(grep -ci "scripts/.*\.sh\|bash.*\.sh" "$agent_file" 2>/dev/null || echo "0")

    # Estimate inline operations (operations without scripts)
    inline_count=$((ops_count > script_count ? ops_count - script_count : 0))

    agents_total=$((agents_total + ops_count))
    agents_scripted=$((agents_scripted + script_count))
    agents_inline=$((agents_inline + inline_count))

  done < <(find "$PROJECT_PATH/.claude/agents" -type f -name "*.md" -print0 2>/dev/null || true)
fi

# Scan skills for operations
if [[ -d "$PROJECT_PATH/.claude/skills" ]]; then
  while IFS= read -r -d '' skill_file; do
    # Count operations in skill
    ops_count=$(grep -ci "##\s*\|^-\s*\|Execute:\|scripts/" "$skill_file" 2>/dev/null || echo "0")

    # Count script invocations
    script_count=$(grep -ci "scripts/.*\.sh\|bash.*\.sh" "$skill_file" 2>/dev/null || echo "0")

    # Skills SHOULD use scripts, so inline = ops - scripts
    inline_count=$((ops_count > script_count ? ops_count - script_count : 0))

    skills_total=$((skills_total + ops_count))
    skills_scripted=$((skills_scripted + script_count))
    skills_inline=$((skills_inline + inline_count))

  done < <(find "$PROJECT_PATH/.claude/skills" -type f -name "SKILL.md" -print0 2>/dev/null || true)
fi

# Calculate totals
total_operations=$((agents_total + skills_total))
scripted_operations=$((agents_scripted + skills_scripted))
inline_operations=$((agents_inline + skills_inline))

# Calculate coverage percentage
if [[ $total_operations -gt 0 ]]; then
  coverage_percentage=$(awk "BEGIN {printf \"%.2f\", $scripted_operations / $total_operations}")
else
  coverage_percentage=0
fi

# Determine grade
grade="Poor"
if (( $(awk "BEGIN {print ($coverage_percentage >= 0.90)}") )); then
  grade="Excellent"
elif (( $(awk "BEGIN {print ($coverage_percentage >= 0.70)}") )); then
  grade="Good"
elif (( $(awk "BEGIN {print ($coverage_percentage >= 0.50)}") )); then
  grade="Acceptable"
elif (( $(awk "BEGIN {print ($coverage_percentage >= 0.30)}") )); then
  grade="Needs Improvement"
fi

# Calculate breakdown percentages
agents_coverage=0
if [[ $agents_total -gt 0 ]]; then
  agents_coverage=$(awk "BEGIN {printf \"%.2f\", $agents_scripted / $agents_total}")
fi

skills_coverage=0
if [[ $skills_total -gt 0 ]]; then
  skills_coverage=$(awk "BEGIN {printf \"%.2f\", $skills_scripted / $skills_total}")
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "coverage_analysis": {
    "total_operations": $total_operations,
    "scripted_operations": $scripted_operations,
    "inline_operations": $inline_operations,
    "coverage_percentage": $coverage_percentage,
    "grade": "$grade"
  },
  "breakdown": {
    "agents": {
      "total": $agents_total,
      "scripted": $agents_scripted,
      "inline": $agents_inline,
      "coverage": $agents_coverage
    },
    "skills": {
      "total": $skills_total,
      "scripted": $skills_scripted,
      "inline": $skills_inline,
      "coverage": $skills_coverage
    }
  },
  "thresholds": {
    "excellent": 0.90,
    "good": 0.70,
    "acceptable": 0.50,
    "needs_improvement": 0.30
  }
}
EOF
