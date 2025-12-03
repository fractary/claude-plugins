#!/bin/bash
# generate-config.sh - Generate faber-cloud configuration from discovery reports
#
# Takes discovery reports and generates a complete config.json configuration
# with intelligent defaults based on discovered infrastructure

set -euo pipefail

# Get script directory for sourcing shared functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source environment validation functions
# shellcheck source=./shared/validate-environments.sh
source "$SCRIPT_DIR/shared/validate-environments.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function: Display usage
usage() {
  cat <<EOF
Usage: generate-config.sh <terraform_report> <aws_report> <custom_agents_report> <output_file>

Generate faber-cloud configuration from discovery reports.

Arguments:
  terraform_report        Path to Terraform discovery report JSON
  aws_report              Path to AWS profiles discovery report JSON
  custom_agents_report    Path to custom agents discovery report JSON
  output_file             Output path for generated config.json

The script analyzes discovery reports and generates a complete config.json
configuration with:
  - Appropriate structure template (flat, modular, multi-environment)
  - AWS profile mappings to environments
  - Terraform paths and settings
  - Hook suggestions based on custom agents
  - Intelligent defaults for all settings

Exit Codes:
  0 - Configuration generated successfully
  1 - Error during generation
  2 - Invalid arguments or missing reports

Examples:
  generate-config.sh terraform.json aws.json agents.json config.json
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

# Function: Validate discovery reports exist
validate_reports() {
  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"

  log_info "Validating discovery reports..."

  if [ ! -f "$tf_report" ]; then
    log_error "Terraform discovery report not found: $tf_report"
    return 1
  fi

  if [ ! -f "$aws_report" ]; then
    log_error "AWS discovery report not found: $aws_report"
    return 1
  fi

  if [ ! -f "$agents_report" ]; then
    log_error "Custom agents discovery report not found: $agents_report"
    return 1
  fi

  # Validate JSON format
  if ! jq empty "$tf_report" 2>/dev/null; then
    log_error "Invalid JSON in Terraform report"
    return 1
  fi

  if ! jq empty "$aws_report" 2>/dev/null; then
    log_error "Invalid JSON in AWS report"
    return 1
  fi

  if ! jq empty "$agents_report" 2>/dev/null; then
    log_error "Invalid JSON in custom agents report"
    return 1
  fi

  log_success "All discovery reports valid"
  return 0
}

# Function: Determine which template to use
select_template() {
  local tf_report="$1"

  local structure=$(jq -r '.summary.primary_structure // "flat"' "$tf_report")

  log_info "Detected Terraform structure: $structure"

  echo "$structure"
}

# Function: Generate environment configurations from AWS profiles
generate_environments() {
  local aws_report="$1"
  local tf_report="$2"

  log_info "Generating environment configurations..."

  local environments="[]"

  # Get project-related profiles
  local profiles=$(jq -c '.profiles[] | select(.project_related == true)' "$aws_report")

  if [ -z "$profiles" ]; then
    log_warning "No project-related AWS profiles found, using defaults"

    # Create default test and prod environments
    local default_test=$(jq -n \
      --arg tf_dir "$(jq -r '.summary.primary_directory // "./terraform"' "$tf_report")" \
      '{
        name: "test",
        aws_profile: "default",
        terraform_dir: $tf_dir,
        terraform_workspace: "default",
        auto_approve: false,
        protected: false
      }')

    local default_prod=$(jq -n \
      --arg tf_dir "$(jq -r '.summary.primary_directory // "./terraform"' "$tf_report")" \
      '{
        name: "prod",
        aws_profile: "default",
        terraform_dir: $tf_dir,
        terraform_workspace: "default",
        auto_approve: false,
        protected: true
      }')

    environments=$(echo "[]" | jq --argjson test "$default_test" --argjson prod "$default_prod" '. + [$test, $prod]')
  else
    # Generate environment for each project-related profile
    while IFS= read -r profile; do
      [ -z "$profile" ] && continue

      local profile_name=$(echo "$profile" | jq -r '.name')
      local environment=$(echo "$profile" | jq -r '.environment')
      local region=$(echo "$profile" | jq -r '.region')
      local is_iam_utility=$(echo "$profile" | jq -r '.is_iam_utility // false')

      # CRITICAL: Skip IAM utility profiles - they are NOT deployment environments
      if [ "$is_iam_utility" = "true" ] || [ "$environment" = "iam-utility" ]; then
        log_warning "  └─ Skipped IAM utility profile: $profile_name (not an environment)"
        continue
      fi

      # CRITICAL: Skip unknown environments
      if [ "$environment" = "unknown" ]; then
        log_warning "  └─ Skipped profile with unknown environment: $profile_name"
        continue
      fi

      # CRITICAL: Validate environment is legitimate
      local validation_result=$(validate_environment "$environment" "AWS profile $profile_name" 2>&1 >/dev/null || echo "invalid")
      if [[ "$validation_result" == *"invalid"* ]]; then
        log_error "  └─ Skipped profile with invalid environment: $profile_name → $environment"
        continue
      fi

      # Determine if protected (production)
      local is_protected="false"
      if [ "$environment" = "prod" ]; then
        is_protected="true"
      fi

      # Get terraform directory
      local tf_dir=$(jq -r '.summary.primary_directory // "./terraform"' "$tf_report")

      # Build environment entry
      local env_entry=$(jq -n \
        --arg name "$environment" \
        --arg profile "$profile_name" \
        --arg tf_dir "$tf_dir" \
        --arg region "$region" \
        --arg protected "$is_protected" \
        '{
          name: $name,
          aws_profile: $profile,
          terraform_dir: $tf_dir,
          terraform_workspace: $name,
          auto_approve: false,
          protected: ($protected == "true"),
          aws_region: $region
        }')

      environments=$(echo "$environments" | jq --argjson entry "$env_entry" '. + [$entry]')

      log_info "  └─ Added environment: $environment (profile: $profile_name)"

    done <<< "$profiles"
  fi

  echo "$environments"
}

# Function: Generate hooks suggestions from custom agents
generate_hooks_suggestions() {
  local agents_report="$1"

  log_info "Generating hook suggestions from custom agents..."

  local hooks='{
    "pre_plan": [],
    "post_plan": [],
    "pre_deploy": [],
    "post_deploy": [],
    "pre_destroy": [],
    "post_destroy": []
  }'

  # Check if custom agents were discovered
  local discovered=$(jq -r '.discovered // false' "$agents_report")
  if [ "$discovered" = "false" ]; then
    log_info "  └─ No custom agents found, using empty hooks"
    echo "$hooks"
    return
  fi

  # Extract files and their purposes
  local files=$(jq -c '.files[]?' "$agents_report")

  while IFS= read -r file; do
    [ -z "$file" ] && continue

    local file_path=$(echo "$file" | jq -r '.path')
    local purposes=$(echo "$file" | jq -r '.purposes[]')

    # Map purposes to hook types
    while IFS= read -r purpose; do
      [ -z "$purpose" ] && continue

      case "$purpose" in
        validate)
          # Validation scripts go in post-plan
          local hook=$(jq -n \
            --arg path "$file_path" \
            '{
              name: ("validate-" + ($path | split("/")[-1] | split(".")[0])),
              command: ("bash " + $path),
              critical: false,
              timeout: 300,
              environments: ["test", "prod"]
            }')
          hooks=$(echo "$hooks" | jq --argjson hook "$hook" '.post_plan += [$hook]')
          log_info "  └─ Added post-plan validation hook: $file_path"
          ;;

        deploy)
          # Deploy scripts could be pre-deploy
          local hook=$(jq -n \
            --arg path "$file_path" \
            '{
              name: ("pre-deploy-" + ($path | split("/")[-1] | split(".")[0])),
              command: ("bash " + $path),
              critical: true,
              timeout: 600,
              environments: ["test", "prod"]
            }')
          hooks=$(echo "$hooks" | jq --argjson hook "$hook" '.pre_deploy += [$hook]')
          log_info "  └─ Added pre-deploy hook: $file_path"
          ;;

        audit)
          # Audit scripts go post-deploy
          local hook=$(jq -n \
            --arg path "$file_path" \
            '{
              name: ("audit-" + ($path | split("/")[-1] | split(".")[0])),
              command: ("bash " + $path),
              critical: false,
              timeout: 300,
              environments: ["test", "prod"]
            }')
          hooks=$(echo "$hooks" | jq --argjson hook "$hook" '.post_deploy += [$hook]')
          log_info "  └─ Added post-deploy audit hook: $file_path"
          ;;

        teardown)
          # Backup before destroy
          local hook=$(jq -n \
            --arg path "$file_path" \
            '{
              name: ("backup-" + ($path | split("/")[-1] | split(".")[0])),
              command: ("bash " + $path),
              critical: true,
              timeout: 600,
              environments: ["prod"]
            }')
          hooks=$(echo "$hooks" | jq --argjson hook "$hook" '.pre_destroy += [$hook]')
          log_info "  └─ Added pre-destroy backup hook: $file_path"
          ;;
      esac

    done <<< "$purposes"

  done <<< "$files"

  echo "$hooks"
}

# Function: Load template and populate with discovered values
generate_from_template() {
  local structure="$1"
  local tf_report="$2"
  local aws_report="$3"
  local agents_report="$4"

  log_info "Generating configuration for $structure structure..."

  # Get script directory
  local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
  local templates_dir="$script_dir/../templates"

  # Select template file
  local template_file=""
  case "$structure" in
    flat)
      template_file="$templates_dir/config-flat-terraform.json"
      ;;
    modular)
      template_file="$templates_dir/config-modular-terraform.json"
      ;;
    multi-environment)
      template_file="$templates_dir/config-multi-environment.json"
      ;;
    *)
      log_error "Unknown structure: $structure"
      return 1
      ;;
  esac

  if [ ! -f "$template_file" ]; then
    log_error "Template file not found: $template_file"
    return 1
  fi

  log_info "Using template: $template_file"

  # Load base template
  local config=$(cat "$template_file")

  # Generate environments
  local environments=$(generate_environments "$aws_report" "$tf_report")

  # Generate hooks
  local hooks=$(generate_hooks_suggestions "$agents_report")

  # Get Terraform settings
  local tf_dir=$(jq -r '.summary.primary_directory // "./terraform"' "$tf_report")
  local tf_version=$(jq -r '.terraform_directories[0].terraform_version // "1.0"' "$tf_report")
  local backend_type=$(jq -r '.terraform_directories[0].backend.type // "local"' "$tf_report")

  # Get AWS settings
  local default_region=$(jq -r '.summary.most_common_region // "us-east-1"' "$aws_report")

  # Update config with discovered values
  config=$(echo "$config" | jq \
    --argjson envs "$environments" \
    --argjson hooks "$hooks" \
    --arg tf_dir "$tf_dir" \
    --arg tf_version "$tf_version" \
    --arg backend "$backend_type" \
    --arg region "$default_region" \
    '
    .environments = $envs |
    .hooks = $hooks |
    .terraform.default_directory = $tf_dir |
    .terraform.version = $tf_version |
    .terraform.backend_type = $backend |
    .aws.default_region = $region
    ')

  echo "$config"
}

# Main execution
main() {
  # Validate arguments
  if [ $# -lt 4 ]; then
    usage
  fi

  local tf_report="$1"
  local aws_report="$2"
  local agents_report="$3"
  local output_file="$4"

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_info "faber-cloud Configuration Generation"
  echo "═══════════════════════════════════════════════════════════"
  echo ""

  # Validate all reports
  if ! validate_reports "$tf_report" "$aws_report" "$agents_report"; then
    exit 1
  fi

  echo ""

  # Select template based on structure
  local structure=$(select_template "$tf_report")

  echo ""

  # Generate configuration
  local config=$(generate_from_template "$structure" "$tf_report" "$aws_report" "$agents_report")

  if [ -z "$config" ]; then
    log_error "Failed to generate configuration"
    exit 1
  fi

  # Write to output file
  echo "$config" | jq . > "$output_file"

  echo ""
  echo "═══════════════════════════════════════════════════════════"
  log_success "Configuration generated successfully"
  log_info "Output: $output_file"
  log_info "Structure: $structure"
  log_info "Environments: $(echo "$config" | jq '.environments | length')"
  log_info "Hooks configured: $(echo "$config" | jq '[.hooks | to_entries[] | .value | length] | add')"
  echo "═══════════════════════════════════════════════════════════"
  echo ""
  echo "Next steps:"
  echo "  1. Review the generated configuration"
  echo "  2. Customize environment settings as needed"
  echo "  3. Test with: faber-cloud audit (read-only)"
  echo "  4. Test deployment in test environment first"
  echo ""

  exit 0
}

# Run main function
main "$@"
