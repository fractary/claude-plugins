#!/bin/bash
# enhanced-validate-environment.sh - Multi-source environment validation
#
# Detects environment from multiple sources (tfvars, workspace, state) and validates
# consistency to prevent multi-environment deployment bugs (e.g., deploying test resources to prod)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function: Display usage
usage() {
  cat <<EOF
Usage: enhanced-validate-environment.sh <terraform_dir> <environment> [plan_file]

Validate environment consistency across multiple sources to prevent deployment bugs.

Arguments:
  terraform_dir  Terraform working directory
  environment    Expected environment (test, prod, staging, etc.)
  plan_file      Optional: Terraform plan file to validate (default: terraform-plan.tfplan)

Validation Checks:
  1. tfvars file matches environment
  2. Terraform workspace matches environment
  3. State file resources tagged with correct environment
  4. Resource naming patterns include environment
  5. Production-specific safety checks (if prod)

Exit Codes:
  0 - Validation passed
  1 - Validation failed (environment mismatch detected)
  2 - Invalid arguments or configuration error

Examples:
  enhanced-validate-environment.sh ./infrastructure/terraform test
  enhanced-validate-environment.sh ./terraform prod terraform-plan.tfplan
EOF
  exit 2
}

# Function: Log with color
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[✓]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[✗ ERROR]${NC} $*"
}

# Function: Detect environment from tfvars file
detect_env_from_tfvars() {
  local terraform_dir="$1"

  log_info "Detecting environment from tfvars files..."

  # Look for environment-specific tfvars files
  local tfvars_files=$(find "$terraform_dir" -maxdepth 1 -name "*.tfvars" -o -name "*.tfvars.json" 2>/dev/null || true)

  if [ -z "$tfvars_files" ]; then
    log_info "No tfvars files found"
    echo ""
    return
  fi

  # Check for common patterns: test.tfvars, prod.tfvars, staging.tfvars, etc.
  for file in $tfvars_files; do
    local basename=$(basename "$file")

    # Extract environment from filename
    if [[ "$basename" =~ ^(test|prod|production|staging|stage|dev|development)\.tfvars ]]; then
      local detected_env="${BASH_REMATCH[1]}"

      # Normalize prod/production
      if [ "$detected_env" = "production" ]; then
        detected_env="prod"
      fi

      # Normalize dev/development
      if [ "$detected_env" = "development" ]; then
        detected_env="dev"
      fi

      # Normalize stage/staging
      if [ "$detected_env" = "stage" ]; then
        detected_env="staging"
      fi

      log_info "Found tfvars file: $basename → $detected_env"
      echo "$detected_env"
      return
    fi
  done

  log_info "No environment-specific tfvars file found"
  echo ""
}

# Function: Detect environment from Terraform workspace
detect_env_from_workspace() {
  local terraform_dir="$1"

  log_info "Detecting environment from Terraform workspace..."

  cd "$terraform_dir" || return

  # Get current workspace
  local workspace=$(terraform workspace show 2>/dev/null || echo "")

  if [ -z "$workspace" ] || [ "$workspace" = "default" ]; then
    log_info "Using default workspace (no environment detected)"
    echo ""
    return
  fi

  log_info "Current workspace: $workspace"
  echo "$workspace"
}

# Function: Detect environment from state file
detect_env_from_state() {
  local terraform_dir="$1"

  log_info "Detecting environment from state file..."

  cd "$terraform_dir" || return

  local state_file="terraform.tfstate"

  if [ ! -f "$state_file" ]; then
    log_info "No local state file found (may be using remote backend)"
    echo ""
    return
  fi

  # Look for environment tags in resources
  local env_from_tags=$(jq -r '.resources[]?.instances[]?.attributes.tags.Environment // .resources[]?.instances[]?.attributes.tags.environment // empty' "$state_file" 2>/dev/null | head -1 || echo "")

  if [ -n "$env_from_tags" ]; then
    log_info "Found environment in resource tags: $env_from_tags"
    echo "$env_from_tags"
    return
  fi

  # Look for environment in resource names
  local env_from_names=$(jq -r '.resources[]?.instances[]?.attributes.name // .resources[]?.instances[]?.attributes.id // empty' "$state_file" 2>/dev/null | grep -oE '(test|prod|production|staging|stage|dev|development)' | head -1 || echo "")

  if [ -n "$env_from_names" ]; then
    # Normalize environment name
    if [ "$env_from_names" = "production" ]; then
      env_from_names="prod"
    fi
    if [ "$env_from_names" = "development" ]; then
      env_from_names="dev"
    fi
    if [ "$env_from_names" = "stage" ]; then
      env_from_names="staging"
    fi

    log_info "Found environment in resource names: $env_from_names"
    echo "$env_from_names"
    return
  fi

  log_info "No environment detected in state file"
  echo ""
}

# Function: Validate resource naming in plan
validate_resource_naming() {
  local plan_file="$1"
  local environment="$2"

  log_info "Validating resource naming patterns..."

  if [ ! -f "$plan_file" ]; then
    log_warning "Plan file not found: $plan_file (skipping naming validation)"
    return 0
  fi

  # Convert plan to JSON
  local plan_json="${plan_file}.json"
  terraform show -json "$plan_file" > "$plan_json" 2>/dev/null || {
    log_warning "Could not convert plan to JSON (skipping naming validation)"
    return 0
  }

  # Check resources being created or updated
  local resources_without_env=$(jq -r '
    .resource_changes[]?
    | select(.change.actions[] | contains("create") or contains("update"))
    | select(.address | contains("'"$environment"'") | not)
    | .address
  ' "$plan_json" 2>/dev/null | head -10 || echo "")

  if [ -n "$resources_without_env" ]; then
    log_warning "Found resources without '$environment' in name:"
    echo "$resources_without_env" | while read -r resource; do
      log_warning "  - $resource"
    done
    log_warning "This may indicate resources for different environment"
    return 0  # Warning only, not fatal
  fi

  log_success "Resource naming validation passed"
  return 0
}

# Function: Production-specific validation
validate_production_safety() {
  local plan_file="$1"

  log_info "Running production-specific safety checks..."

  if [ ! -f "$plan_file" ]; then
    log_warning "Plan file not found: $plan_file (skipping production validation)"
    return 0
  fi

  # Convert plan to JSON if not already done
  local plan_json="${plan_file}.json"
  if [ ! -f "$plan_json" ]; then
    terraform show -json "$plan_file" > "$plan_json" 2>/dev/null || {
      log_warning "Could not convert plan to JSON (skipping production validation)"
      return 0
    }
  fi

  # Check for destructive changes
  local destroy_count=$(jq '[.resource_changes[]? | select(.change.actions[] | contains("delete"))] | length' "$plan_json" 2>/dev/null || echo "0")

  if [ "$destroy_count" -gt 0 ]; then
    log_warning "⚠️  This deployment will DESTROY $destroy_count resource(s) in PRODUCTION"
    log_warning "Review the plan carefully before proceeding!"
  fi

  # Check for replace (recreate) changes
  local replace_count=$(jq '[.resource_changes[]? | select(.change.actions | contains(["delete", "create"]))] | length' "$plan_json" 2>/dev/null || echo "0")

  if [ "$replace_count" -gt 0 ]; then
    log_warning "⚠️  This deployment will REPLACE (recreate) $replace_count resource(s) in PRODUCTION"
    log_warning "Resources will be destroyed and recreated - may cause downtime!"
  fi

  # Check for high number of changes
  local total_changes=$(jq '[.resource_changes[]? | select(.change.actions[] | contains("create") or contains("update") or contains("delete"))] | length' "$plan_json" 2>/dev/null || echo "0")

  if [ "$total_changes" -gt 20 ]; then
    log_warning "⚠️  Large production deployment: $total_changes changes"
    log_warning "Consider deploying in smaller batches for safety"
  fi

  log_success "Production safety checks complete"
  return 0
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 2 ]; then
    usage
  fi

  local terraform_dir="$1"
  local expected_env="$2"
  local plan_file="${3:-terraform-plan.tfplan}"

  # Validate terraform directory exists
  if [ ! -d "$terraform_dir" ]; then
    log_error "Terraform directory not found: $terraform_dir"
    exit 2
  fi

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "Enhanced Environment Validation"
  log_info "Expected Environment: $expected_env"
  log_info "Terraform Directory: $terraform_dir"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Detect environment from multiple sources
  local env_from_tfvars=$(detect_env_from_tfvars "$terraform_dir")
  local env_from_workspace=$(detect_env_from_workspace "$terraform_dir")
  local env_from_state=$(detect_env_from_state "$terraform_dir")

  echo ""
  echo "───────────────────────────────────────────────────────────"
  log_info "Environment Detection Summary"
  echo "───────────────────────────────────────────────────────────"
  echo "Expected:       $expected_env"
  echo "tfvars file:    ${env_from_tfvars:-<not detected>}"
  echo "Workspace:      ${env_from_workspace:-<default/none>}"
  echo "State file:     ${env_from_state:-<not detected>}"
  echo "───────────────────────────────────────────────────────────"
  echo ""

  # Validate consistency
  local mismatches=0
  local warnings=0

  # Check tfvars file
  if [ -n "$env_from_tfvars" ] && [ "$env_from_tfvars" != "$expected_env" ]; then
    log_error "Environment mismatch: tfvars indicates '$env_from_tfvars' but deploying to '$expected_env'"
    ((mismatches++))
  elif [ -n "$env_from_tfvars" ]; then
    log_success "tfvars file matches expected environment"
  fi

  # Check workspace
  if [ -n "$env_from_workspace" ] && [ "$env_from_workspace" != "$expected_env" ]; then
    log_error "Environment mismatch: workspace is '$env_from_workspace' but deploying to '$expected_env'"
    ((mismatches++))
  elif [ -n "$env_from_workspace" ]; then
    log_success "Terraform workspace matches expected environment"
  fi

  # Check state file
  if [ -n "$env_from_state" ] && [ "$env_from_state" != "$expected_env" ]; then
    log_warning "State file contains resources for '$env_from_state' but deploying to '$expected_env'"
    log_warning "This may indicate leftover resources from different environment"
    ((warnings++))
  elif [ -n "$env_from_state" ]; then
    log_success "State file matches expected environment"
  fi

  echo ""

  # Validate resource naming in plan
  cd "$terraform_dir" || exit 2
  if [ -f "$plan_file" ]; then
    validate_resource_naming "$plan_file" "$expected_env"
  fi

  echo ""

  # Production-specific validation
  if [ "$expected_env" = "prod" ] || [ "$expected_env" = "production" ]; then
    validate_production_safety "$plan_file"
    echo ""
  fi

  # Summary
  echo "═══════════════════════════════════════════════════════════"

  if [ $mismatches -gt 0 ]; then
    log_error "VALIDATION FAILED: $mismatches environment mismatch(es) detected"
    log_error "Deployment should be BLOCKED to prevent multi-environment bugs"
    echo "═══════════════════════════════════════════════════════════"
    exit 1
  elif [ $warnings -gt 0 ]; then
    log_warning "Validation passed with $warnings warning(s)"
    log_info "Review warnings above before proceeding"
    echo "═══════════════════════════════════════════════════════════"
    exit 0
  else
    log_success "Environment validation passed - safe to deploy"
    echo "═══════════════════════════════════════════════════════════"
    exit 0
  fi
}

# Run main function
main "$@"
