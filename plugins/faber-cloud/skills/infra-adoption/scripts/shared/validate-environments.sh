#!/bin/bash
# validate-environments.sh - Validate that detected environments are legitimate deployment environments
#
# This prevents IAM utility users (discover, admin, ci, etc.) from being treated as deployment environments

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log_info() { echo -e "${BLUE}[INFO]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[✓]${NC} $*" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*" >&2; }
log_error() { echo -e "${RED}[✗]${NC} $*" >&2; }

# Standard allowed environments (can be extended by user configuration)
STANDARD_ENVIRONMENTS=("test" "prod" "staging" "dev")

# IAM utility user patterns that should NEVER be environments
IAM_UTILITY_PATTERNS=("discover" "admin" "ci" "terraform" "backup" "monitor" "audit" "readonly" "poweruser")

# Function: Check if a value is a standard environment
is_standard_environment() {
  local env="$1"
  local lower_env=$(echo "$env" | tr '[:upper:]' '[:lower:]')

  for std_env in "${STANDARD_ENVIRONMENTS[@]}"; do
    if [ "$lower_env" = "$std_env" ]; then
      echo "true"
      return
    fi
  done

  echo "false"
}

# Function: Check if a value matches IAM utility pattern
is_iam_utility_pattern() {
  local env="$1"
  local lower_env=$(echo "$env" | tr '[:upper:]' '[:lower:]')

  for pattern in "${IAM_UTILITY_PATTERNS[@]}"; do
    if [ "$lower_env" = "$pattern" ]; then
      echo "true"
      return
    fi
  done

  echo "false"
}

# Function: Validate an environment name
validate_environment() {
  local env="$1"
  local source="${2:-unknown}"  # Where this environment came from (for logging)

  # Check if it's a standard environment
  if [ "$(is_standard_environment "$env")" = "true" ]; then
    log_success "Environment '$env' is valid (standard environment)"
    echo "valid"
    return 0
  fi

  # Check if it matches an IAM utility pattern
  if [ "$(is_iam_utility_pattern "$env")" = "true" ]; then
    log_error "Environment '$env' is INVALID - matches IAM utility user pattern (source: $source)"
    log_error "  → This is likely an IAM user/role, not a deployment environment"
    log_error "  → IAM utility users should NOT be treated as environments"
    echo "invalid-iam-utility"
    return 1
  fi

  # Unknown environment - warn but don't fail
  log_warning "Environment '$env' is non-standard (source: $source)"
  log_warning "  → Standard environments: ${STANDARD_ENVIRONMENTS[*]}"
  log_warning "  → Consider renaming to match standard pattern"
  echo "warning-non-standard"
  return 2
}

# Function: Validate a list of environments (JSON array or space-separated)
validate_environment_list() {
  local env_list="$1"
  local source="${2:-unknown}"

  local has_invalid=false
  local has_warnings=false

  # Parse as JSON array if it looks like JSON
  if [[ "$env_list" =~ ^\[.*\]$ ]]; then
    # JSON array
    local count=$(echo "$env_list" | jq 'length')
    log_info "Validating $count environment(s) from $source..."

    for i in $(seq 0 $((count - 1))); do
      local env=$(echo "$env_list" | jq -r ".[$i]")
      local result=$(validate_environment "$env" "$source")

      case "$result" in
        "invalid-iam-utility")
          has_invalid=true
          ;;
        "warning-non-standard")
          has_warnings=true
          ;;
      esac
    done
  else
    # Space-separated list
    log_info "Validating environment(s) from $source..."

    for env in $env_list; do
      local result=$(validate_environment "$env" "$source")

      case "$result" in
        "invalid-iam-utility")
          has_invalid=true
          ;;
        "warning-non-standard")
          has_warnings=true
          ;;
      esac
    done
  fi

  # Return appropriate exit code
  if [ "$has_invalid" = "true" ]; then
    log_error "Validation FAILED - Invalid environments detected"
    return 1
  elif [ "$has_warnings" = "true" ]; then
    log_warning "Validation passed with WARNINGS - Non-standard environments detected"
    return 2
  else
    log_success "Validation passed - All environments are standard"
    return 0
  fi
}

# Function: Filter out invalid environments from a list
filter_environments() {
  local env_list="$1"

  local filtered="[]"

  # Parse as JSON array if it looks like JSON
  if [[ "$env_list" =~ ^\[.*\]$ ]]; then
    local count=$(echo "$env_list" | jq 'length')

    for i in $(seq 0 $((count - 1))); do
      local env=$(echo "$env_list" | jq -r ".[$i]")

      # Skip IAM utility patterns
      if [ "$(is_iam_utility_pattern "$env")" = "false" ] && [ "$env" != "unknown" ]; then
        filtered=$(echo "$filtered" | jq --arg env "$env" '. + [$env]')
      fi
    done
  else
    # Space-separated list - convert to JSON
    for env in $env_list; do
      # Skip IAM utility patterns
      if [ "$(is_iam_utility_pattern "$env")" = "false" ] && [ "$env" != "unknown" ]; then
        filtered=$(echo "$filtered" | jq --arg env "$env" '. + [$env]')
      fi
    done
  fi

  echo "$filtered"
}

# If script is run directly (not sourced)
if [ "${BASH_SOURCE[0]}" = "$0" ]; then
  if [ $# -lt 1 ]; then
    echo "Usage: validate-environments.sh <environment_list> [source]"
    echo ""
    echo "Examples:"
    echo "  validate-environments.sh '[\"test\", \"prod\"]' 'AWS profiles'"
    echo "  validate-environments.sh 'test prod staging' 'config file'"
    echo "  validate-environments.sh 'discover' 'AWS profile'"  # This should fail
    exit 2
  fi

  validate_environment_list "$1" "${2:-command-line}"
  exit $?
fi
