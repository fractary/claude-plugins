#!/bin/bash
set -euo pipefail

# skill-script-validator.sh
# Validates specialist skill has proper script structure

SKILL_FILE="${1:?Error: Skill file path required}"

# Validate file exists
if [[ ! -f "$SKILL_FILE" ]]; then
  echo '{"status": "error", "error": "file_not_found", "file": "'"$SKILL_FILE"'"}'
  exit 1
fi

# Initialize results
IS_SKILL=false
LOCATION_CORRECT=false
HAS_SKILL_MD=false
HAS_SCRIPTS_DIR=false
SCRIPTS_DIR_PATH=""
SCRIPT_COUNT=0
SCRIPTS_FOUND=()
ALL_EXECUTABLE=true
HAS_OPERATIONS=false
OPERATION_COUNT=0
ALL_REFERENCE_SCRIPTS=true
HAS_CONTEXT=false
HAS_CRITICAL_RULES=false
HAS_OPERATIONS_SECTION=false
HAS_DOCUMENTATION=false
ISSUES=()
WARNINGS=()

# Check location (should be in skills/ directory with /SKILL.md)
if [[ "$SKILL_FILE" == *"/skills/"* ]] && [[ "$SKILL_FILE" == *"/SKILL.md" ]]; then
  LOCATION_CORRECT=true
  IS_SKILL=true
  HAS_SKILL_MD=true
else
  LOCATION_CORRECT=false
  ISSUES+=('{"type": "wrong_location", "severity": "high", "message": "Skill not in skills/{name}/SKILL.md location"}')
fi

# Determine scripts directory path
SKILL_DIR=$(dirname "$SKILL_FILE")
SCRIPTS_DIR_PATH="${SKILL_DIR}/scripts"

# Check if scripts/ directory exists
if [[ -d "$SCRIPTS_DIR_PATH" ]]; then
  HAS_SCRIPTS_DIR=true

  # Count scripts
  if compgen -G "${SCRIPTS_DIR_PATH}/*.sh" > /dev/null; then
    # Find all .sh files
    while IFS= read -r -d '' script_file; do
      script_name=$(basename "$script_file")
      SCRIPTS_FOUND+=("$script_name")
      ((SCRIPT_COUNT++))

      # Check if executable
      if [[ ! -x "$script_file" ]]; then
        ALL_EXECUTABLE=false
        WARNINGS+=('{"type": "script_not_executable", "severity": "medium", "message": "Script not executable: '"$script_name"'", "fix": "chmod +x '"$script_file"'"}')
      fi
    done < <(find "$SCRIPTS_DIR_PATH" -maxdepth 1 -name "*.sh" -print0 2>/dev/null)
  fi

  if [[ $SCRIPT_COUNT -eq 0 ]]; then
    WARNINGS+=('{"type": "no_scripts_found", "severity": "medium", "message": "scripts/ directory exists but contains no .sh files"}')
  fi
else
  HAS_SCRIPTS_DIR=false
  ISSUES+=('{"type": "missing_scripts_directory", "severity": "high", "message": "Skill missing scripts/ directory", "fix": "Create: mkdir -p '"$SCRIPTS_DIR_PATH"'"}')
fi

# Check XML markup
if grep -q "<CONTEXT>" "$SKILL_FILE"; then HAS_CONTEXT=true; fi
if grep -q "<CRITICAL_RULES>" "$SKILL_FILE"; then HAS_CRITICAL_RULES=true; fi
if grep -q "<OPERATIONS>" "$SKILL_FILE"; then
  HAS_OPERATIONS_SECTION=true
  HAS_OPERATIONS=true
fi
if grep -q "<DOCUMENTATION>" "$SKILL_FILE"; then HAS_DOCUMENTATION=true; fi

# Count operations
OPERATION_COUNT=$(grep -c "^## [a-z-]*$" "$SKILL_FILE" 2>/dev/null || echo "0")

# Check if operations reference scripts
if [[ $OPERATION_COUNT -gt 0 ]]; then
  # Check if file contains script references
  if ! grep -qi "scripts/\|\.sh" "$SKILL_FILE"; then
    ALL_REFERENCE_SCRIPTS=false
    WARNINGS+=('{"type": "operations_without_scripts", "severity": "medium", "message": "Operations found but no script references detected"}')
  fi
fi

# Build scripts JSON array
SCRIPTS_JSON="["
if [[ ${#SCRIPTS_FOUND[@]} -gt 0 ]]; then
  FIRST=true
  for script in "${SCRIPTS_FOUND[@]}"; do
    if [[ "$FIRST" == "true" ]]; then
      SCRIPTS_JSON+="\"$script\""
      FIRST=false
    else
      SCRIPTS_JSON+=",\"$script\""
    fi
  done
fi
SCRIPTS_JSON+="]"

# Build issues JSON array
ISSUES_JSON="["
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  FIRST=true
  for issue in "${ISSUES[@]}"; do
    if [[ "$FIRST" == "true" ]]; then
      ISSUES_JSON+="$issue"
      FIRST=false
    else
      ISSUES_JSON+=",$issue"
    fi
  done
fi
ISSUES_JSON+="]"

# Build warnings JSON array
WARNINGS_JSON="["
if [[ ${#WARNINGS[@]} -gt 0 ]]; then
  FIRST=true
  for warning in "${WARNINGS[@]}"; do
    if [[ "$FIRST" == "true" ]]; then
      WARNINGS_JSON+="$warning"
      FIRST=false
    else
      WARNINGS_JSON+=",$warning"
    fi
  done
fi
WARNINGS_JSON+="]"

# Determine pass/fail
PASSED=true
if [[ ${#ISSUES[@]} -gt 0 ]]; then
  PASSED=false
fi

# Output JSON
cat <<EOF
{
  "status": "success",
  "file": "$SKILL_FILE",
  "validation": {
    "is_skill": $IS_SKILL,
    "location_correct": $LOCATION_CORRECT,
    "structure": {
      "has_skill_md": $HAS_SKILL_MD,
      "has_scripts_dir": $HAS_SCRIPTS_DIR,
      "scripts_dir_path": "$SCRIPTS_DIR_PATH"
    },
    "scripts": {
      "count": $SCRIPT_COUNT,
      "scripts_found": $SCRIPTS_JSON,
      "all_executable": $ALL_EXECUTABLE
    },
    "operations": {
      "has_operations": $HAS_OPERATIONS,
      "operation_count": $OPERATION_COUNT,
      "all_reference_scripts": $ALL_REFERENCE_SCRIPTS
    },
    "xml_markup": {
      "has_context": $HAS_CONTEXT,
      "has_critical_rules": $HAS_CRITICAL_RULES,
      "has_operations": $HAS_OPERATIONS_SECTION,
      "has_documentation": $HAS_DOCUMENTATION,
      "all_markup_present": $([ "$HAS_CONTEXT" == "true" ] && [ "$HAS_CRITICAL_RULES" == "true" ] && [ "$HAS_OPERATIONS_SECTION" == "true" ] && echo "true" || echo "false")
    }
  },
  "issues": $ISSUES_JSON,
  "warnings": $WARNINGS_JSON,
  "passed": $PASSED
}
EOF
