#!/bin/bash
# validate-generated-config.sh - Validate generated faber-cloud configuration
#
# Validates that a generated configuration file has all required fields,
# proper structure, and valid values

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display usage
usage() {
  cat <<EOF
Usage: validate-generated-config.sh <config_file>

Validate a generated faber-cloud configuration file.

Arguments:
  config_file   Path to config.json configuration file

Validation Checks:
  - Valid JSON format
  - Required top-level fields present
  - At least one environment configured
  - Valid environment configurations
  - Valid handler configurations
  - Valid hook definitions
  - Valid deployment settings

Exit Codes:
  0 - Configuration is valid
  1 - Configuration is invalid
  2 - Invalid arguments

Examples:
  validate-generated-config.sh config.json
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" >&2
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*" >&2
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" >&2
}

log_error() {
  echo -e "${RED}[✗]${NC} $*" >&2
}

# Track validation errors
VALIDATION_ERRORS=0

# Function: Record validation error
validation_error() {
  log_error "$*"
  ((VALIDATION_ERRORS++))
}

# Function: Validate JSON format
validate_json_format() {
  local config_file="$1"

  log_info "Validating JSON format..."

  if ! jq empty "$config_file" 2>/dev/null; then
    validation_error "Invalid JSON format"
    return 1
  fi

  log_success "JSON format valid"
  return 0
}

# Function: Validate required top-level fields
validate_required_fields() {
  local config_file="$1"

  log_info "Validating required fields..."

  local required_fields=(
    "version"
    "project"
    "environments"
    "terraform"
    "aws"
    "handlers"
    "hooks"
    "deployment"
  )

  for field in "${required_fields[@]}"; do
    if ! jq -e ".$field" "$config_file" &>/dev/null; then
      validation_error "Missing required field: $field"
    else
      log_success "Found required field: $field"
    fi
  done

  return 0
}

# Function: Validate project configuration
validate_project() {
  local config_file="$1"

  log_info "Validating project configuration..."

  # Check for project fields
  local project_fields=("name" "description")

  for field in "${project_fields[@]}"; do
    if ! jq -e ".project.$field" "$config_file" &>/dev/null; then
      log_warning "Missing project.$field (optional but recommended)"
    fi
  done

  log_success "Project configuration valid"
  return 0
}

# Function: Validate environments
validate_environments() {
  local config_file="$1"

  log_info "Validating environments..."

  # Check that at least one environment exists
  local env_count=$(jq '.environments | length' "$config_file")

  if [ "$env_count" -eq 0 ]; then
    validation_error "No environments configured"
    return 1
  fi

  log_success "Found $env_count environment(s)"

  # Validate each environment
  local required_env_fields=("name" "aws_profile" "terraform_dir")

  for i in $(seq 0 $((env_count - 1))); do
    local env_name=$(jq -r ".environments[$i].name // \"unknown\"" "$config_file")
    log_info "  └─ Validating environment: $env_name"

    for field in "${required_env_fields[@]}"; do
      if ! jq -e ".environments[$i].$field" "$config_file" &>/dev/null; then
        validation_error "Environment '$env_name' missing required field: $field"
      fi
    done

    # Check protected flag for prod
    if [ "$env_name" = "prod" ]; then
      local is_protected=$(jq -r ".environments[$i].protected // false" "$config_file")
      if [ "$is_protected" != "true" ]; then
        log_warning "Production environment not marked as protected"
      fi
    fi
  done

  log_success "All environments valid"
  return 0
}

# Function: Validate Terraform configuration
validate_terraform() {
  local config_file="$1"

  log_info "Validating Terraform configuration..."

  local required_tf_fields=(
    "version"
    "default_directory"
    "backend_type"
  )

  for field in "${required_tf_fields[@]}"; do
    if ! jq -e ".terraform.$field" "$config_file" &>/dev/null; then
      validation_error "Missing terraform.$field"
    fi
  done

  # Validate backend type
  local backend_type=$(jq -r '.terraform.backend_type // ""' "$config_file")
  if [ -n "$backend_type" ]; then
    case "$backend_type" in
      local|s3|remote|azurerm|gcs)
        log_success "Valid backend type: $backend_type"
        ;;
      *)
        log_warning "Unknown backend type: $backend_type"
        ;;
    esac
  fi

  log_success "Terraform configuration valid"
  return 0
}

# Function: Validate AWS configuration
validate_aws() {
  local config_file="$1"

  log_info "Validating AWS configuration..."

  local required_aws_fields=("default_region")

  for field in "${required_aws_fields[@]}"; do
    if ! jq -e ".aws.$field" "$config_file" &>/dev/null; then
      validation_error "Missing aws.$field"
    fi
  done

  # Validate region format
  local region=$(jq -r '.aws.default_region // ""' "$config_file")
  if [ -n "$region" ]; then
    if [[ "$region" =~ ^[a-z]{2}-[a-z]+-[0-9]$ ]]; then
      log_success "Valid AWS region: $region"
    else
      log_warning "Invalid AWS region format: $region"
    fi
  fi

  log_success "AWS configuration valid"
  return 0
}

# Function: Validate handlers
validate_handlers() {
  local config_file="$1"

  log_info "Validating handlers..."

  # Check for required handlers
  local required_handlers=("iac" "hosting")

  for handler in "${required_handlers[@]}"; do
    if ! jq -e ".handlers.$handler" "$config_file" &>/dev/null; then
      validation_error "Missing handler: $handler"
    else
      # Check active handler
      local active=$(jq -r ".handlers.$handler.active // \"\"" "$config_file")
      if [ -z "$active" ]; then
        validation_error "Handler '$handler' missing 'active' field"
      else
        log_success "Handler '$handler' active: $active"
      fi
    fi
  done

  log_success "Handlers configuration valid"
  return 0
}

# Function: Validate hooks
validate_hooks() {
  local config_file="$1"

  log_info "Validating hooks..."

  # Check for all hook types
  local hook_types=(
    "pre_plan"
    "post_plan"
    "pre_deploy"
    "post_deploy"
    "pre_destroy"
    "post_destroy"
  )

  for hook_type in "${hook_types[@]}"; do
    if ! jq -e ".hooks.$hook_type" "$config_file" &>/dev/null; then
      log_warning "Missing hook type: $hook_type (using empty array)"
    else
      local hook_count=$(jq ".hooks.$hook_type | length" "$config_file")
      log_info "  └─ $hook_type: $hook_count hook(s)"

      # Validate each hook
      if [ "$hook_count" -gt 0 ]; then
        for i in $(seq 0 $((hook_count - 1))); do
          local hook_name=$(jq -r ".hooks.$hook_type[$i].name // \"unknown\"" "$config_file")

          # Check required hook fields
          if ! jq -e ".hooks.$hook_type[$i].command" "$config_file" &>/dev/null; then
            validation_error "Hook '$hook_name' missing 'command' field"
          fi
        done
      fi
    fi
  done

  log_success "Hooks configuration valid"
  return 0
}

# Function: Validate deployment settings
validate_deployment() {
  local config_file="$1"

  log_info "Validating deployment settings..."

  # Check for deployment sections
  local deployment_sections=("approval" "validation" "rollback")

  for section in "${deployment_sections[@]}"; do
    if ! jq -e ".deployment.$section" "$config_file" &>/dev/null; then
      log_warning "Missing deployment.$section (using defaults)"
    fi
  done

  # Validate approval settings
  if jq -e '.deployment.approval' "$config_file" &>/dev/null; then
    local required_approval=$(jq -r '.deployment.approval.required // false' "$config_file")
    log_info "  └─ Approval required: $required_approval"

    if [ "$required_approval" = "true" ]; then
      local approval_envs=$(jq -r '.deployment.approval.environments[]? // ""' "$config_file")
      if [ -z "$approval_envs" ]; then
        log_warning "Approval required but no environments specified"
      fi
    fi
  fi

  # Validate validation settings
  if jq -e '.deployment.validation' "$config_file" &>/dev/null; then
    local enhanced=$(jq -r '.deployment.validation.enhanced_environment_detection // false' "$config_file")
    log_info "  └─ Enhanced environment detection: $enhanced"
  fi

  log_success "Deployment settings valid"
  return 0
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 1 ]; then
    usage
  fi

  local config_file="$1"

  # Check file exists
  if [ ! -f "$config_file" ]; then
    log_error "Configuration file not found: $config_file"
    exit 2
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "faber-cloud Configuration Validation"
  log_info "File: $config_file"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Run validation checks
  validate_json_format "$config_file" || exit 1

  echo ""
  validate_required_fields "$config_file"

  echo ""
  validate_project "$config_file"

  echo ""
  validate_environments "$config_file"

  echo ""
  validate_terraform "$config_file"

  echo ""
  validate_aws "$config_file"

  echo ""
  validate_handlers "$config_file"

  echo ""
  validate_hooks "$config_file"

  echo ""
  validate_deployment "$config_file"

  echo ""
  echo "═══════════════════════════════════════════════════════════"

  if [ $VALIDATION_ERRORS -eq 0 ]; then
    log_success "Configuration is VALID"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Configuration is ready to use!"
    echo "Next steps:"
    echo "  1. Copy to project root: cp $config_file ./.fractary/plugins/faber-cloud/config.json"
    echo "  2. Test with read-only audit: faber-cloud audit test"
    echo "  3. Deploy to test environment first"
    echo ""
    exit 0
  else
    log_error "Configuration is INVALID"
    log_error "Found $VALIDATION_ERRORS validation error(s)"
    echo "═══════════════════════════════════════════════════════════"
    echo ""
    echo "Please fix the errors above and try again."
    echo ""
    exit 1
  fi
}

# Run main function
main "$@"
