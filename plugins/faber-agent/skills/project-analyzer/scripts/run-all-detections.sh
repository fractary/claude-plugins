#!/bin/bash
set -euo pipefail

# run-all-detections.sh
# Master detection script - runs ALL anti-pattern detection scripts and aggregates results
# This script MUST be run by the project-auditor to ensure all checks execute
#
# Usage: ./run-all-detections.sh <project_path>
#
# Output: Single JSON object with aggregated results from all detection scripts

PROJECT_PATH="${1:-.}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate dependencies
if ! command -v jq &> /dev/null; then
  echo '{"status": "error", "error": "missing_dependency", "message": "jq is required but not installed"}'
  exit 1
fi

# Validate project path
if [[ ! -d "$PROJECT_PATH/.claude" ]]; then
  jq -n --arg path "$PROJECT_PATH" '{
    status: "error",
    error: "invalid_project",
    message: ".claude/ directory not found at \($path)"
  }'
  exit 1
fi

# Initialize results
RESULTS='{}'
ERRORS=()
TOTAL_VIOLATIONS=0
ERROR_VIOLATIONS=0      # v2.0: ERROR severity (ARC-006, ARC-007)
CRITICAL_VIOLATIONS=0
WARNING_VIOLATIONS=0
INFO_VIOLATIONS=0

# Helper to run a detection script and capture output
run_detection() {
  local script_name="$1"
  local script_path="$SCRIPT_DIR/$script_name"

  if [[ ! -x "$script_path" ]]; then
    echo "WARN: Script not executable or missing: $script_name" >&2
    ERRORS+=("$script_name: not found or not executable")
    return 1
  fi

  local output
  if output=$("$script_path" "$PROJECT_PATH" 2>&1); then
    # Validate JSON output
    if echo "$output" | jq -e . >/dev/null 2>&1; then
      echo "$output"
      return 0
    else
      echo "WARN: Invalid JSON from $script_name: $output" >&2
      ERRORS+=("$script_name: invalid JSON output")
      return 1
    fi
  else
    echo "WARN: Script failed: $script_name" >&2
    ERRORS+=("$script_name: execution failed")
    return 1
  fi
}

# Aggregate violation counts from detection result
count_violations() {
  local result="$1"
  local severity="${2:-warning}"

  # Extract non_compliant_count or instances count
  local count
  count=$(echo "$result" | jq -r '.non_compliant_count // .instances // 0')

  if [[ "$count" =~ ^[0-9]+$ ]] && [[ "$count" -gt 0 ]]; then
    TOTAL_VIOLATIONS=$((TOTAL_VIOLATIONS + count))

    case "$severity" in
      error) ERROR_VIOLATIONS=$((ERROR_VIOLATIONS + count)) ;;       # v2.0: ERROR severity
      critical) CRITICAL_VIOLATIONS=$((CRITICAL_VIOLATIONS + count)) ;;
      warning) WARNING_VIOLATIONS=$((WARNING_VIOLATIONS + count)) ;;
      info) INFO_VIOLATIONS=$((INFO_VIOLATIONS + count)) ;;
    esac
  fi
}

echo "Running all detection scripts on: $PROJECT_PATH" >&2
echo "-------------------------------------------" >&2

# Detection scripts to run (in order)
# v2.0: Added ARC-006 and ARC-007 as ERROR severity (blocks workflows)
DETECTION_SCRIPTS=(
  "detect-project-specific-director.sh:error" # ARC-006 (v2.0 - ERROR severity)
  "detect-project-specific-manager.sh:error"  # ARC-007 (v2.0 - ERROR severity)
  "detect-manager-as-skill.sh:critical"       # SKL/AGT anti-pattern
  "detect-director-as-agent.sh:critical"      # SKL/AGT anti-pattern
  "detect-workflow-logging.sh:warning"        # AGT-005
  "detect-direct-skill-commands.sh:critical"  # CMD-004
  "detect-director-patterns.sh:info"          # ARC-004
  "detect-response-format-compliance.sh:warning" # RESP-001 (v2.1 - response format)
)

# Run each detection and build results
# v2.0: Added project-specific director/manager detection
# v2.1: Added response format compliance (RESP-001)
PROJECT_SPECIFIC_DIRECTOR='{"status": "skipped"}'
PROJECT_SPECIFIC_MANAGER='{"status": "skipped"}'
MANAGER_AS_SKILL='{"status": "skipped"}'
DIRECTOR_AS_AGENT='{"status": "skipped"}'
WORKFLOW_LOGGING='{"status": "skipped"}'
DIRECT_SKILL_COMMANDS='{"status": "skipped"}'
DIRECTOR_PATTERNS='{"status": "skipped"}'
RESPONSE_FORMAT_COMPLIANCE='{"status": "skipped"}'

for script_spec in "${DETECTION_SCRIPTS[@]}"; do
  script_name="${script_spec%%:*}"
  severity="${script_spec##*:}"

  echo "  Running: $script_name" >&2

  if result=$(run_detection "$script_name"); then
    count_violations "$result" "$severity"

    case "$script_name" in
      "detect-project-specific-director.sh") PROJECT_SPECIFIC_DIRECTOR="$result" ;;
      "detect-project-specific-manager.sh") PROJECT_SPECIFIC_MANAGER="$result" ;;
      "detect-manager-as-skill.sh") MANAGER_AS_SKILL="$result" ;;
      "detect-director-as-agent.sh") DIRECTOR_AS_AGENT="$result" ;;
      "detect-workflow-logging.sh") WORKFLOW_LOGGING="$result" ;;
      "detect-direct-skill-commands.sh") DIRECT_SKILL_COMMANDS="$result" ;;
      "detect-director-patterns.sh") DIRECTOR_PATTERNS="$result" ;;
      "detect-response-format-compliance.sh") RESPONSE_FORMAT_COMPLIANCE="$result" ;;
    esac
  fi
done

echo "-------------------------------------------" >&2

# Run inspect-structure for context
STRUCTURE='{"status": "skipped"}'
if [[ -x "$SCRIPT_DIR/inspect-structure.sh" ]]; then
  echo "  Running: inspect-structure.sh" >&2
  STRUCTURE=$("$SCRIPT_DIR/inspect-structure.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"status": "error"}')
fi

# Run context load calculation
CONTEXT_LOAD='{"status": "skipped"}'
if [[ -x "$SCRIPT_DIR/calculate-context-load.sh" ]]; then
  echo "  Running: calculate-context-load.sh" >&2
  CONTEXT_LOAD=$("$SCRIPT_DIR/calculate-context-load.sh" "$PROJECT_PATH" 2>/dev/null || echo '{"status": "error"}')
fi

# Calculate compliance score
# Formula: (total_checks - weighted_violations) / total_checks * 100
# Weights: error=15 (v2.0), critical=10, warning=3, info=1
TOTAL_CHECKS=31  # Base number of checks across all rules (v2.1: added RESP-001)
WEIGHTED_VIOLATIONS=$((ERROR_VIOLATIONS * 15 + CRITICAL_VIOLATIONS * 10 + WARNING_VIOLATIONS * 3 + INFO_VIOLATIONS * 1))
if [[ $WEIGHTED_VIOLATIONS -gt $TOTAL_CHECKS ]]; then
  WEIGHTED_VIOLATIONS=$TOTAL_CHECKS
fi
COMPLIANCE_SCORE=$((100 * (TOTAL_CHECKS - WEIGHTED_VIOLATIONS) / TOTAL_CHECKS))
if [[ $COMPLIANCE_SCORE -lt 0 ]]; then
  COMPLIANCE_SCORE=0
fi

# Build errors array
ERRORS_JSON='[]'
if [[ ${#ERRORS[@]} -gt 0 ]]; then
  ERRORS_JSON=$(printf '%s\n' "${ERRORS[@]}" | jq -R . | jq -s .)
fi

# Output comprehensive results
jq -n \
  --arg project_path "$PROJECT_PATH" \
  --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  --argjson compliance_score "$COMPLIANCE_SCORE" \
  --argjson total_violations "$TOTAL_VIOLATIONS" \
  --argjson error "$ERROR_VIOLATIONS" \
  --argjson critical "$CRITICAL_VIOLATIONS" \
  --argjson warning "$WARNING_VIOLATIONS" \
  --argjson info "$INFO_VIOLATIONS" \
  --argjson errors "$ERRORS_JSON" \
  --argjson structure "$STRUCTURE" \
  --argjson context_load "$CONTEXT_LOAD" \
  --argjson project_specific_director "$PROJECT_SPECIFIC_DIRECTOR" \
  --argjson project_specific_manager "$PROJECT_SPECIFIC_MANAGER" \
  --argjson manager_as_skill "$MANAGER_AS_SKILL" \
  --argjson director_as_agent "$DIRECTOR_AS_AGENT" \
  --argjson workflow_logging "$WORKFLOW_LOGGING" \
  --argjson direct_skill_commands "$DIRECT_SKILL_COMMANDS" \
  --argjson director_patterns "$DIRECTOR_PATTERNS" \
  --argjson response_format_compliance "$RESPONSE_FORMAT_COMPLIANCE" \
  '{
    status: "success",
    project_path: $project_path,
    timestamp: $timestamp,
    summary: {
      compliance_score: $compliance_score,
      total_violations: $total_violations,
      by_severity: {
        error: $error,
        critical: $critical,
        warning: $warning,
        info: $info
      }
    },
    structure: $structure,
    context_load: $context_load,
    detections: {
      project_specific_director: $project_specific_director,
      project_specific_manager: $project_specific_manager,
      manager_as_skill: $manager_as_skill,
      director_as_agent: $director_as_agent,
      workflow_logging: $workflow_logging,
      direct_skill_commands: $direct_skill_commands,
      director_patterns: $director_patterns,
      response_format_compliance: $response_format_compliance
    },
    execution: {
      scripts_run: 10,
      errors: $errors
    }
  }'

echo "" >&2
echo "Detection complete. Total violations: $TOTAL_VIOLATIONS (Error: $ERROR_VIOLATIONS, Critical: $CRITICAL_VIOLATIONS, Warning: $WARNING_VIOLATIONS, Info: $INFO_VIOLATIONS)" >&2
