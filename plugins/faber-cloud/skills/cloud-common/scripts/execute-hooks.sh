#!/bin/bash
# execute-hooks.sh - Execute lifecycle hooks for faber-cloud operations
#
# Executes pre/post hooks at key lifecycle points (plan, deploy, destroy)
# Supports critical vs optional hooks, timeouts, environment filtering

set -euo pipefail

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source config loader
source "${SCRIPT_DIR}/config-loader.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display usage
usage() {
  cat <<EOF
Usage: execute-hooks.sh <hook_type> <environment> [terraform_dir]

Execute hooks for a specific lifecycle point.

Arguments:
  hook_type     Hook type: pre-plan, post-plan, pre-deploy, post-deploy, pre-destroy, post-destroy
  environment   Environment name (test, prod, staging, etc.)
  terraform_dir Terraform working directory (optional, defaults to current dir)

Environment Variables Set for Hooks:
  FABER_CLOUD_ENV             - Environment name
  FABER_CLOUD_TERRAFORM_DIR   - Terraform working directory
  FABER_CLOUD_PROJECT         - Project name
  FABER_CLOUD_SUBSYSTEM       - Subsystem name
  FABER_CLOUD_OPERATION       - Operation type (plan, deploy, destroy)
  FABER_CLOUD_HOOK_TYPE       - Hook type (pre-plan, post-deploy, etc.)
  AWS_PROFILE                 - Active AWS profile for this environment

Examples:
  execute-hooks.sh pre-deploy test ./infrastructure/terraform
  execute-hooks.sh post-plan prod
  execute-hooks.sh pre-destroy test

Exit Codes:
  0 - All hooks executed successfully
  1 - Critical hook failed (deployment should be blocked)
  2 - Invalid arguments or configuration error
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Function: Extract operation type from hook type
get_operation_type() {
  local hook_type="$1"
  case "$hook_type" in
    pre-plan|post-plan)
      echo "plan"
      ;;
    pre-deploy|post-deploy)
      echo "deploy"
      ;;
    pre-destroy|post-destroy)
      echo "destroy"
      ;;
    *)
      echo "unknown"
      ;;
  esac
}

# Function: Get hook type (legacy string, script object, or skill object)
get_hook_type() {
  local config_file="$1"
  local hook_type_key="$2"
  local hook_index="$3"

  # Check if hook is a string (legacy format)
  local hook_value_type=$(jq -r ".hooks[\"$hook_type_key\"][$hook_index] | type" "$config_file")

  if [ "$hook_value_type" = "string" ]; then
    echo "legacy-script"
    return 0
  fi

  # Check if hook is an object with type field
  local hook_object_type=$(jq -r ".hooks[\"$hook_type_key\"][$hook_index].type // \"\"" "$config_file")

  if [ "$hook_object_type" = "skill" ]; then
    echo "skill"
  elif [ "$hook_object_type" = "script" ]; then
    echo "script"
  else
    echo "unknown"
  fi
}

# Function: Execute a script hook
execute_script_hook() {
  local hook_index="$1"
  local hook_name="$2"
  local hook_command="$3"
  local hook_critical="${4:-true}"
  local hook_timeout="${5:-300}"
  local hook_envs="$6"
  local current_env="$7"

  # Check if hook applies to this environment
  if [ -n "$hook_envs" ]; then
    if ! echo "$hook_envs" | grep -qw "$current_env"; then
      log_info "Skipping hook '$hook_name' (not configured for $current_env)"
      return 0
    fi
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Executing SCRIPT hook [$hook_index]: $hook_name"
  log_info "Command: $hook_command"
  log_info "Critical: $hook_critical | Timeout: ${hook_timeout}s"
  echo "═══════════════════════════════════════════════════════════"

  # Execute hook with timeout
  local start_time=$(date +%s)
  local exit_code=0

  if timeout "$hook_timeout" bash -c "$hook_command"; then
    exit_code=0
  else
    exit_code=$?
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  echo "───────────────────────────────────────────────────────────"

  # Handle hook result
  if [ $exit_code -eq 0 ]; then
    log_success "Hook '$hook_name' completed successfully (${duration}s)"
    return 0
  elif [ $exit_code -eq 124 ]; then
    log_error "Hook '$hook_name' timed out after ${hook_timeout}s"
    if [ "$hook_critical" = "true" ]; then
      log_error "CRITICAL hook failed - blocking operation"
      return 1
    else
      log_warning "Optional hook failed - continuing"
      return 0
    fi
  else
    log_error "Hook '$hook_name' failed with exit code $exit_code (${duration}s)"
    if [ "$hook_critical" = "true" ]; then
      log_error "CRITICAL hook failed - blocking operation"
      return 1
    else
      log_warning "Optional hook failed - continuing"
      return 0
    fi
  fi
}

# Function: Execute a skill hook
execute_skill_hook() {
  local hook_index="$1"
  local hook_name="$2"
  local skill_name="$3"
  local hook_critical="${4:-true}"
  local hook_timeout="${5:-300}"
  local hook_envs="$6"
  local current_env="$7"

  # Check if hook applies to this environment
  if [ -n "$hook_envs" ]; then
    if ! echo "$hook_envs" | grep -qw "$current_env"; then
      log_info "Skipping hook '$hook_name' (not configured for $current_env)"
      return 0
    fi
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Executing SKILL hook [$hook_index]: $hook_name"
  log_info "Skill: $skill_name"
  log_info "Critical: $hook_critical | Timeout: ${hook_timeout}s"
  echo "═══════════════════════════════════════════════════════════"

  # Execute skill hook with timeout
  local start_time=$(date +%s)
  local exit_code=0

  # Invoke skill via helper script
  if timeout "$hook_timeout" bash "${SCRIPT_DIR}/invoke-skill-hook.sh" "$skill_name"; then
    exit_code=0
  else
    exit_code=$?
  fi

  local end_time=$(date +%s)
  local duration=$((end_time - start_time))

  echo "───────────────────────────────────────────────────────────"

  # Handle hook result
  if [ $exit_code -eq 0 ]; then
    log_success "Skill hook '$hook_name' completed successfully (${duration}s)"
    return 0
  elif [ $exit_code -eq 124 ]; then
    log_error "Skill hook '$hook_name' timed out after ${hook_timeout}s"
    if [ "$hook_critical" = "true" ]; then
      log_error "CRITICAL skill hook failed - blocking operation"
      return 1
    else
      log_warning "Optional skill hook failed - continuing"
      return 0
    fi
  else
    log_error "Skill hook '$hook_name' failed with exit code $exit_code (${duration}s)"
    if [ "$hook_critical" = "true" ]; then
      log_error "CRITICAL skill hook failed - blocking operation"
      return 1
    else
      log_warning "Optional skill hook failed - continuing"
      return 0
    fi
  fi
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 2 ]; then
    usage
  fi

  local hook_type="$1"
  local environment="$2"
  local terraform_dir="${3:-.}"

  # Validate hook type
  case "$hook_type" in
    pre-plan|post-plan|pre-deploy|post-deploy|pre-destroy|post-destroy)
      ;;
    *)
      log_error "Invalid hook type: $hook_type"
      usage
      ;;
  esac

  # Load configuration
  log_info "Loading faber-cloud configuration..."
  if ! load_faber_cloud_config; then
    log_error "Failed to load configuration"
    exit 2
  fi

  # Get configuration file path
  local config_file
  if [ -f ".fractary/plugins/faber-cloud/config/faber-cloud.json" ]; then
    config_file=".fractary/plugins/faber-cloud/config/faber-cloud.json"
  elif [ -f ".fractary/plugins/devops/config/devops.json" ]; then
    config_file=".fractary/plugins/devops/config/devops.json"
    log_warning "Using deprecated devops.json - please rename to faber-cloud.json"
  else
    log_info "No configuration file found - no hooks to execute"
    exit 0
  fi

  # Check if hooks section exists
  if ! jq -e '.hooks' "$config_file" >/dev/null 2>&1; then
    log_info "No hooks configured in $config_file"
    exit 0
  fi

  # Check if hooks exist for this type
  local hooks_count=$(jq -r ".hooks[\"$hook_type\"] | length // 0" "$config_file")
  if [ "$hooks_count" -eq 0 ]; then
    log_info "No hooks configured for $hook_type"
    exit 0
  fi

  log_info "Found $hooks_count hook(s) for $hook_type"

  # Set environment variables for hooks
  export FABER_CLOUD_ENV="$environment"
  export FABER_CLOUD_TERRAFORM_DIR="$terraform_dir"
  export FABER_CLOUD_PROJECT="${PROJECT_NAME:-unknown}"
  export FABER_CLOUD_SUBSYSTEM="${SUBSYSTEM:-core}"
  export FABER_CLOUD_OPERATION="$(get_operation_type "$hook_type")"
  export FABER_CLOUD_HOOK_TYPE="$hook_type"

  # Set AWS profile for this environment
  local aws_profile=$(get_aws_profile "$environment")
  if [ -n "$aws_profile" ]; then
    export AWS_PROFILE="$aws_profile"
    log_info "AWS Profile: $AWS_PROFILE"
  fi

  log_info "Hook context: $FABER_CLOUD_PROJECT/$FABER_CLOUD_SUBSYSTEM ($FABER_CLOUD_ENV)"

  # Execute each hook
  local hook_index=0
  local failed_hooks=0

  while [ $hook_index -lt "$hooks_count" ]; do
    # Determine hook type (legacy string, script object, or skill object)
    local current_hook_type=$(get_hook_type "$config_file" "$hook_type" "$hook_index")

    # Extract common hook details
    local hook_name
    local hook_critical
    local hook_timeout
    local hook_envs

    # Handle different hook formats
    case "$current_hook_type" in
      "legacy-script")
        # Legacy string format: "script.sh" or "command"
        hook_name="hook-$hook_index"
        local hook_command=$(jq -r ".hooks[\"$hook_type\"][$hook_index]" "$config_file")
        hook_critical="true"
        hook_timeout="300"
        hook_envs=""

        log_info "Legacy script hook detected: $hook_command"

        # Execute as script hook
        if ! execute_script_hook "$((hook_index + 1))" "$hook_name" "$hook_command" "$hook_critical" "$hook_timeout" "$hook_envs" "$environment"; then
          ((failed_hooks++))
        fi
        ;;

      "script")
        # Script object format: {"type": "script", "path": "...", ...}
        hook_name=$(jq -r ".hooks[\"$hook_type\"][$hook_index].name // \"script-hook-$hook_index\"" "$config_file")
        local hook_path=$(jq -r ".hooks[\"$hook_type\"][$hook_index].path" "$config_file")
        hook_critical=$(jq -r ".hooks[\"$hook_type\"][$hook_index].required // true" "$config_file")
        hook_timeout=$(jq -r ".hooks[\"$hook_type\"][$hook_index].timeout // 300" "$config_file")
        hook_envs=$(jq -r ".hooks[\"$hook_type\"][$hook_index].environments[]? // empty" "$config_file" | tr '\n' ' ')

        # Use 'required' field for 'critical' (backward compatibility)
        local failure_mode=$(jq -r ".hooks[\"$hook_type\"][$hook_index].failureMode // \"stop\"" "$config_file")
        if [ "$failure_mode" = "warn" ]; then
          hook_critical="false"
        fi

        # Validate hook has path
        if [ -z "$hook_path" ] || [ "$hook_path" = "null" ]; then
          log_error "Script hook '$hook_name' has no path configured"
          ((hook_index++))
          continue
        fi

        # Execute as script hook
        if ! execute_script_hook "$((hook_index + 1))" "$hook_name" "bash $hook_path" "$hook_critical" "$hook_timeout" "$hook_envs" "$environment"; then
          ((failed_hooks++))
        fi
        ;;

      "skill")
        # Skill object format: {"type": "skill", "name": "...", ...}
        hook_name=$(jq -r ".hooks[\"$hook_type\"][$hook_index].name // \"skill-hook-$hook_index\"" "$config_file")
        local skill_name=$(jq -r ".hooks[\"$hook_type\"][$hook_index].name" "$config_file")
        hook_critical=$(jq -r ".hooks[\"$hook_type\"][$hook_index].required // true" "$config_file")
        hook_timeout=$(jq -r ".hooks[\"$hook_type\"][$hook_index].timeout // 300" "$config_file")
        hook_envs=$(jq -r ".hooks[\"$hook_type\"][$hook_index].environments[]? // empty" "$config_file" | tr '\n' ' ')

        # Use 'required' field for 'critical'
        local failure_mode=$(jq -r ".hooks[\"$hook_type\"][$hook_index].failureMode // \"stop\"" "$config_file")
        if [ "$failure_mode" = "warn" ]; then
          hook_critical="false"
        fi

        # Validate hook has skill name
        if [ -z "$skill_name" ] || [ "$skill_name" = "null" ]; then
          log_error "Skill hook has no name configured"
          ((hook_index++))
          continue
        fi

        # Execute as skill hook
        if ! execute_skill_hook "$((hook_index + 1))" "$hook_name" "$skill_name" "$hook_critical" "$hook_timeout" "$hook_envs" "$environment"; then
          ((failed_hooks++))
        fi
        ;;

      "unknown"|*)
        log_error "Unknown hook type at index $hook_index"
        log_error "Hook must be a string (legacy) or object with type='script' or type='skill'"
        ((failed_hooks++))
        ;;
    esac

    ((hook_index++))
  done

  echo ""
  echo "═══════════════════════════════════════════════════════════"

  # Summary
  if [ $failed_hooks -eq 0 ]; then
    log_success "All $hooks_count hook(s) completed successfully"
    exit 0
  else
    log_error "$failed_hooks critical hook(s) failed"
    log_error "Operation should be blocked"
    exit 1
  fi
}

# Run main function
main "$@"
