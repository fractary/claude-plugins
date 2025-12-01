#!/bin/bash
# config-loader.sh
# Loads faber-cloud configuration from .fractary/plugins/faber-cloud/config.json
# Provides pattern substitution and validation
# Migration: config.json (current) ← faber-cloud.json ← devops.json (legacy)

set -euo pipefail

# Configuration paths
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
CONFIG_DIR="${PROJECT_ROOT}/.fractary/plugins/faber-cloud"
CONFIG_FILE="${CONFIG_DIR}/config.json"
OLD_CONFIG_FILE="${CONFIG_DIR}/faber-cloud.json"
LEGACY_CONFIG_FILE="${CONFIG_DIR}/devops.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global configuration variables (exported for use by other scripts)
export DEVOPS_CONFIG_FILE=""
export DEVOPS_CONFIG_DIR=""
export DEVOPS_PROJECT_ROOT=""

# Project metadata
export DEVOPS_PROJECT_NAME=""
export DEVOPS_PROJECT_SUBSYSTEM=""
export DEVOPS_PROJECT_ORG=""

# Handler configuration
export DEVOPS_HOSTING_HANDLER=""
export DEVOPS_IAC_HANDLER=""

# Environment
export DEVOPS_ENVIRONMENT=""

# AWS-specific
export AWS_ACCOUNT_ID=""
export AWS_REGION=""
export AWS_PROFILE_DISCOVER=""
export AWS_PROFILE_TEST=""
export AWS_PROFILE_PROD=""
export AWS_PROFILE=""

# Terraform-specific
export TF_DIRECTORY=""
export TF_VAR_FILE_PATTERN=""
export TF_BACKEND_TYPE=""
export TF_BACKEND_BUCKET=""
export TF_BACKEND_KEY=""

# Resource naming
export DEVOPS_NAMING_PATTERN=""
export DEVOPS_NAMING_SEPARATOR=""

# Environment settings
export DEVOPS_AUTO_APPROVE=""
export DEVOPS_REQUIRE_CONFIRMATION=""

# Function: Print colored messages
log_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Function: Migrate old config to new naming standard
migrate_config_if_needed() {
    # If config.json exists, we're good
    if [[ -f "$CONFIG_FILE" ]]; then
        return 0
    fi

    # Check for faber-cloud.json (previous standard)
    if [[ -f "$OLD_CONFIG_FILE" ]]; then
        log_info "Migrating configuration: faber-cloud.json → config.json"
        mv "$OLD_CONFIG_FILE" "$CONFIG_FILE"
        log_success "Configuration migrated successfully"
        return 0
    fi

    # Check for devops.json (legacy)
    if [[ -f "$LEGACY_CONFIG_FILE" ]]; then
        log_warning "Legacy config found: devops.json"
        log_info "Please run: /fractary-faber-cloud:init to migrate configuration"
        log_info "Or manually rename: devops.json → config.json"
        return 1
    fi

    # No config found
    return 1
}

# Function: Check if config file exists
check_config_exists() {
    # First, attempt migration if needed
    migrate_config_if_needed

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Run /fractary-faber-cloud:init to create configuration"
        return 1
    fi
    return 0
}

# Function: Validate JSON syntax
validate_json() {
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        log_error "Invalid JSON in configuration file: $CONFIG_FILE"
        return 1
    fi
    return 0
}

# Function: Load configuration
load_config() {
    local env="${1:-test}"

    log_info "Loading faber-cloud configuration..."

    # Check if config exists
    if ! check_config_exists; then
        return 1
    fi

    # Validate JSON
    if ! validate_json; then
        return 1
    fi

    # Export configuration variables
    export DEVOPS_CONFIG_FILE="$CONFIG_FILE"
    export DEVOPS_CONFIG_DIR="$CONFIG_DIR"
    export DEVOPS_PROJECT_ROOT="$PROJECT_ROOT"

    # Load project metadata
    export DEVOPS_PROJECT_NAME=$(jq -r '.project.name' "$CONFIG_FILE")
    export DEVOPS_PROJECT_SUBSYSTEM=$(jq -r '.project.subsystem' "$CONFIG_FILE")
    export DEVOPS_PROJECT_ORG=$(jq -r '.project.organization' "$CONFIG_FILE")

    # Load handler configuration
    export DEVOPS_HOSTING_HANDLER=$(jq -r '.handlers.hosting.active' "$CONFIG_FILE")
    export DEVOPS_IAC_HANDLER=$(jq -r '.handlers.iac.active' "$CONFIG_FILE")

    # Load environment
    export DEVOPS_ENVIRONMENT="$env"

    # Load AWS configuration (if AWS is active)
    if [[ "$DEVOPS_HOSTING_HANDLER" == "aws" ]]; then
        export AWS_ACCOUNT_ID=$(jq -r '.handlers.hosting.aws.account_id' "$CONFIG_FILE")
        export AWS_REGION=$(jq -r '.handlers.hosting.aws.region' "$CONFIG_FILE")
        export AWS_PROFILE_DISCOVER=$(jq -r '.handlers.hosting.aws.profiles.discover_deploy' "$CONFIG_FILE")
        export AWS_PROFILE_TEST=$(jq -r '.handlers.hosting.aws.profiles.test_deploy' "$CONFIG_FILE")
        export AWS_PROFILE_PROD=$(jq -r '.handlers.hosting.aws.profiles.prod_deploy' "$CONFIG_FILE")

        # Set active AWS profile based on environment
        case "$env" in
            test)
                export AWS_PROFILE="$AWS_PROFILE_TEST"
                ;;
            prod)
                export AWS_PROFILE="$AWS_PROFILE_PROD"
                ;;
            discover)
                export AWS_PROFILE="$AWS_PROFILE_DISCOVER"
                ;;
            *)
                log_warning "Unknown environment: $env, defaulting to test"
                export AWS_PROFILE="$AWS_PROFILE_TEST"
                ;;
        esac
    fi

    # Load Terraform configuration (if Terraform is active)
    if [[ "$DEVOPS_IAC_HANDLER" == "terraform" ]]; then
        export TF_DIRECTORY=$(jq -r '.handlers.iac.terraform.directory' "$CONFIG_FILE")
        export TF_VAR_FILE_PATTERN=$(jq -r '.handlers.iac.terraform.var_file_pattern' "$CONFIG_FILE")
        export TF_BACKEND_TYPE=$(jq -r '.handlers.iac.terraform.backend.type' "$CONFIG_FILE")
        export TF_BACKEND_BUCKET=$(jq -r '.handlers.iac.terraform.backend.bucket' "$CONFIG_FILE")
        export TF_BACKEND_KEY=$(jq -r '.handlers.iac.terraform.backend.key' "$CONFIG_FILE")

        # Substitute patterns in terraform directory
        TF_DIRECTORY="${TF_DIRECTORY/\{project\}/$DEVOPS_PROJECT_NAME}"
        TF_DIRECTORY="${TF_DIRECTORY/\{subsystem\}/$DEVOPS_PROJECT_SUBSYSTEM}"
        export TF_DIRECTORY
    fi

    # Load resource naming pattern
    export DEVOPS_NAMING_PATTERN=$(jq -r '.resource_naming.pattern' "$CONFIG_FILE")
    export DEVOPS_NAMING_SEPARATOR=$(jq -r '.resource_naming.separator' "$CONFIG_FILE")

    # Load environment-specific settings
    export DEVOPS_AUTO_APPROVE=$(jq -r ".environments.${env}.auto_approve" "$CONFIG_FILE")
    export DEVOPS_REQUIRE_CONFIRMATION=$(jq -r ".environments.${env}.require_confirmation" "$CONFIG_FILE")

    log_success "Configuration loaded successfully"
    log_info "Project: ${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}"
    log_info "Environment: ${DEVOPS_ENVIRONMENT}"
    log_info "Hosting: ${DEVOPS_HOSTING_HANDLER}"
    log_info "IaC: ${DEVOPS_IAC_HANDLER}"

    if [[ "$DEVOPS_HOSTING_HANDLER" == "aws" ]]; then
        log_info "AWS Profile: ${AWS_PROFILE}"
        log_info "AWS Region: ${AWS_REGION}"
    fi

    return 0
}

# Function: Get resource name with pattern substitution
get_resource_name() {
    local resource_type="$1"
    local resource_name="$2"
    local env="${3:-$DEVOPS_ENVIRONMENT}"

    local name="$DEVOPS_NAMING_PATTERN"
    name="${name/\{project\}/$DEVOPS_PROJECT_NAME}"
    name="${name/\{subsystem\}/$DEVOPS_PROJECT_SUBSYSTEM}"
    name="${name/\{environment\}/$env}"
    name="${name/\{resource\}/$resource_name}"
    name="${name/\{organization\}/$DEVOPS_PROJECT_ORG}"

    echo "$name"
}

# Function: Validate environment
validate_environment() {
    local env="$1"

    if [[ ! "$env" =~ ^(test|prod|discover)$ ]]; then
        log_error "Invalid environment: $env"
        log_info "Valid environments: test, prod, discover"
        return 1
    fi

    return 0
}

# Function: Validate AWS profile separation
validate_profile_separation() {
    local operation="$1"  # deploy or discover
    local env="$2"

    # discover operations can ONLY use discover-deploy profile
    if [[ "$operation" == "discover" ]] && [[ "$AWS_PROFILE" != "$AWS_PROFILE_DISCOVER" ]]; then
        log_error "CRITICAL: IAM permission discovery must use discover-deploy profile"
        log_error "Current: $AWS_PROFILE"
        log_error "Required: $AWS_PROFILE_DISCOVER"
        return 1
    fi

    # deploy operations can NEVER use discover-deploy profile
    if [[ "$operation" == "deploy" ]] && [[ "$AWS_PROFILE" == "$AWS_PROFILE_DISCOVER" ]]; then
        log_error "CRITICAL: Deployment cannot use discover-deploy profile"
        log_error "Current: $AWS_PROFILE"
        log_error "Use: $AWS_PROFILE_TEST (test) or $AWS_PROFILE_PROD (prod)"
        return 1
    fi

    # Production deployments must use prod-deploy profile
    if [[ "$env" == "prod" ]] && [[ "$AWS_PROFILE" != "$AWS_PROFILE_PROD" ]]; then
        log_error "CRITICAL: Production deployment must use prod-deploy profile"
        log_error "Current: $AWS_PROFILE"
        log_error "Required: $AWS_PROFILE_PROD"
        return 1
    fi

    # Test deployments must use test-deploy profile
    if [[ "$env" == "test" ]] && [[ "$AWS_PROFILE" != "$AWS_PROFILE_TEST" ]]; then
        log_error "CRITICAL: Test deployment must use test-deploy profile"
        log_error "Current: $AWS_PROFILE"
        log_error "Required: $AWS_PROFILE_TEST"
        return 1
    fi

    log_success "Profile separation validated: $AWS_PROFILE for $operation in $env"
    return 0
}

# Main execution if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    ENV="${1:-test}"

    if validate_environment "$ENV"; then
        load_config "$ENV"
    else
        exit 1
    fi
fi
