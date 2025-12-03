#!/bin/bash
set -euo pipefail

# validate-rules.sh
# Validates the best-practices-rules.yaml file schema
# Run this in CI or before audit to catch configuration errors

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="$(dirname "$SCRIPT_DIR")"
RULES_FILE="${1:-$PLUGIN_DIR/config/best-practices-rules.yaml}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check dependencies
check_dependencies() {
  local missing=()

  if ! command -v yq &> /dev/null; then
    missing+=("yq")
  fi

  if [[ ${#missing[@]} -gt 0 ]]; then
    echo -e "${RED}ERROR: Missing dependencies: ${missing[*]}${NC}"
    echo "Install with: brew install yq (macOS) or snap install yq (Linux)"
    exit 1
  fi
}

# Validate file exists
validate_file_exists() {
  if [[ ! -f "$RULES_FILE" ]]; then
    echo -e "${RED}ERROR: Rules file not found: $RULES_FILE${NC}"
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Rules file found: $RULES_FILE"
}

# Validate YAML syntax
validate_yaml_syntax() {
  if ! yq eval '.' "$RULES_FILE" > /dev/null 2>&1; then
    echo -e "${RED}ERROR: Invalid YAML syntax${NC}"
    yq eval '.' "$RULES_FILE" 2>&1 | head -5
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Valid YAML syntax"
}

# Validate required top-level fields
validate_required_fields() {
  local errors=()

  # Check version field
  if ! yq eval '.version' "$RULES_FILE" | grep -q '^[0-9]'; then
    errors+=("Missing or invalid 'version' field (expected format: YYYY-MM-DD)")
  fi

  # Check rules section exists
  if [[ $(yq eval '.rules | type' "$RULES_FILE") != "!!map" ]]; then
    errors+=("Missing 'rules' section (expected: map)")
  fi

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo -e "${RED}ERROR: Required field validation failed:${NC}"
    for error in "${errors[@]}"; do
      echo "  - $error"
    done
    exit 1
  fi
  echo -e "${GREEN}✓${NC} Required top-level fields present"
}

# Validate rule categories
validate_rule_categories() {
  local valid_categories=("commands" "agents" "skills" "architecture" "hooks")
  local found_categories
  found_categories=$(yq eval '.rules | keys | .[]' "$RULES_FILE" 2>/dev/null)

  local invalid=()
  while IFS= read -r category; do
    if [[ ! " ${valid_categories[*]} " =~ " ${category} " ]]; then
      invalid+=("$category")
    fi
  done <<< "$found_categories"

  if [[ ${#invalid[@]} -gt 0 ]]; then
    echo -e "${YELLOW}WARNING: Unknown rule categories: ${invalid[*]}${NC}"
    echo "  Valid categories: ${valid_categories[*]}"
  else
    echo -e "${GREEN}✓${NC} All rule categories valid"
  fi
}

# Validate individual rules have required fields
validate_rule_structure() {
  local errors=()
  local rule_count=0

  # Get all rule IDs across all categories
  local categories
  categories=$(yq eval '.rules | keys | .[]' "$RULES_FILE" 2>/dev/null)

  while IFS= read -r category; do
    local rules
    rules=$(yq eval ".rules.$category | length" "$RULES_FILE" 2>/dev/null)

    for ((i=0; i<rules; i++)); do
      ((rule_count++))
      local rule_path=".rules.$category[$i]"

      # Check required fields: id, name, severity
      local rule_id
      rule_id=$(yq eval "$rule_path.id" "$RULES_FILE" 2>/dev/null)

      if [[ "$rule_id" == "null" || -z "$rule_id" ]]; then
        errors+=("$category[$i]: Missing 'id' field")
        continue
      fi

      local rule_name
      rule_name=$(yq eval "$rule_path.name" "$RULES_FILE" 2>/dev/null)
      if [[ "$rule_name" == "null" || -z "$rule_name" ]]; then
        errors+=("$rule_id: Missing 'name' field")
      fi

      local severity
      severity=$(yq eval "$rule_path.severity" "$RULES_FILE" 2>/dev/null)
      if [[ "$severity" == "null" || -z "$severity" ]]; then
        errors+=("$rule_id: Missing 'severity' field")
      elif [[ ! "$severity" =~ ^(critical|warning|info)$ ]]; then
        errors+=("$rule_id: Invalid severity '$severity' (must be: critical, warning, info)")
      fi

      # Check has either 'check' or 'anti_check'
      local has_check
      has_check=$(yq eval "$rule_path.check" "$RULES_FILE" 2>/dev/null)
      local has_anti_check
      has_anti_check=$(yq eval "$rule_path.anti_check" "$RULES_FILE" 2>/dev/null)

      if [[ "$has_check" == "null" && "$has_anti_check" == "null" ]]; then
        errors+=("$rule_id: Must have 'check' or 'anti_check' section")
      fi
    done
  done <<< "$categories"

  if [[ ${#errors[@]} -gt 0 ]]; then
    echo -e "${RED}ERROR: Rule structure validation failed:${NC}"
    for error in "${errors[@]}"; do
      echo "  - $error"
    done
    exit 1
  fi

  echo -e "${GREEN}✓${NC} All $rule_count rules have valid structure"
}

# Validate scoring configuration
validate_scoring() {
  local has_scoring
  has_scoring=$(yq eval '.scoring' "$RULES_FILE" 2>/dev/null)

  if [[ "$has_scoring" == "null" ]]; then
    echo -e "${YELLOW}WARNING: No 'scoring' section found (optional)${NC}"
    return
  fi

  # Check weights exist
  local weights
  weights=$(yq eval '.scoring.weights' "$RULES_FILE" 2>/dev/null)
  if [[ "$weights" == "null" ]]; then
    echo -e "${YELLOW}WARNING: No 'scoring.weights' section (optional)${NC}"
  fi

  # Check thresholds exist
  local thresholds
  thresholds=$(yq eval '.scoring.thresholds' "$RULES_FILE" 2>/dev/null)
  if [[ "$thresholds" == "null" ]]; then
    echo -e "${YELLOW}WARNING: No 'scoring.thresholds' section (optional)${NC}"
  fi

  echo -e "${GREEN}✓${NC} Scoring configuration valid"
}

# Main
main() {
  echo "═══════════════════════════════════════════════════════════"
  echo " Best Practices Rules Validator"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  check_dependencies
  validate_file_exists
  validate_yaml_syntax
  validate_required_fields
  validate_rule_categories
  validate_rule_structure
  validate_scoring

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  echo -e " ${GREEN}VALIDATION PASSED${NC}"
  echo "═══════════════════════════════════════════════════════════"

  # Output version info
  local version
  version=$(yq eval '.version' "$RULES_FILE" 2>/dev/null)
  echo "Rules version: $version"
}

main "$@"
