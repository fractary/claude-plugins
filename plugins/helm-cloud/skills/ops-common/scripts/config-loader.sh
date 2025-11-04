#!/bin/bash
# config-loader.sh - Helm-Cloud Configuration Loader
# Loads monitoring configuration and shared infrastructure config
# Used by all ops-* skills

set -euo pipefail

# Configuration paths
PROJECT_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || pwd)"
SHARED_CONFIG_DIR="${PROJECT_ROOT}/.fractary/shared"
HELM_CLOUD_CONFIG_DIR="${PROJECT_ROOT}/.fractary/plugins/helm-cloud/config"
MONITORING_CONFIG_FILE="${HELM_CLOUD_CONFIG_DIR}/monitoring.toml"
REGISTRY_DIR="${PROJECT_ROOT}/.fractary/registry"
DEPLOYMENTS_REGISTRY="${REGISTRY_DIR}/deployments.json"

# Backward compatibility with faber-cloud structure
LEGACY_CONFIG_DIR="${PROJECT_ROOT}/.fractary/plugins/faber-cloud/config"
LEGACY_CONFIG_FILE="${LEGACY_CONFIG_DIR}/devops.json"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Global configuration variables (exported for use by other scripts)
export HELM_CONFIG_FILE=""
export HELM_SHARED_CONFIG_DIR=""
export HELM_REGISTRY_DIR=""
export HELM_PROJECT_ROOT=""

# Environment
export HELM_ENVIRONMENT=""

# AWS-specific (from shared config or legacy)
export AWS_ACCOUNT_ID=""
export AWS_REGION=""
export AWS_PROFILE=""

# Monitoring configuration
export HELM_HEALTH_CHECK_INTERVAL="5m"
export HELM_ENABLED_CHECKS="resource_status,cloudwatch_metrics,cloudwatch_alarms"

# SLO thresholds
export HELM_SLO_LAMBDA_ERROR_RATE="0.1"
export HELM_SLO_LAMBDA_LATENCY="200"
export HELM_SLO_RDS_ERROR_RATE="0.01"
export HELM_SLO_RDS_CONNECTION_TIME="100"

# Remediation settings
export HELM_AUTO_REMEDIATE="restart_lambda,clear_cache"
export HELM_REQUIRE_CONFIRMATION="scale_resources,increase_capacity"

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

# Function: Check if jq is installed
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        log_error "jq is not installed. Please install jq to parse JSON configuration."
        log_info "Install: apt-get install jq (Ubuntu/Debian) or brew install jq (macOS)"
        return 1
    fi
}

# Function: Load shared AWS credentials
load_shared_aws_config() {
    local aws_config_file="${SHARED_CONFIG_DIR}/aws-credentials.json"

    if [[ -f "$aws_config_file" ]]; then
        log_info "Loading shared AWS configuration from: $aws_config_file"

        AWS_ACCOUNT_ID=$(jq -r '.aws.account_id // empty' "$aws_config_file")
        AWS_REGION=$(jq -r '.aws.region // "us-east-1"' "$aws_config_file")

        # Get profile for current environment
        if [[ -n "${HELM_ENVIRONMENT:-}" ]]; then
            AWS_PROFILE=$(jq -r ".aws.profiles.${HELM_ENVIRONMENT} // empty" "$aws_config_file")
        fi

        export AWS_ACCOUNT_ID AWS_REGION AWS_PROFILE
        log_success "Shared AWS config loaded"
        return 0
    else
        log_warning "Shared AWS config not found: $aws_config_file"
        return 1
    fi
}

# Function: Load legacy faber-cloud configuration (backward compatibility)
load_legacy_devops_config() {
    if [[ ! -f "$LEGACY_CONFIG_FILE" ]]; then
        log_warning "Legacy devops.json not found (this is OK for new installations)"
        return 1
    fi

    log_info "Loading legacy configuration for backward compatibility: $LEGACY_CONFIG_FILE"

    # Extract AWS configuration from legacy devops.json
    AWS_ACCOUNT_ID=$(jq -r '.providers.aws.account_id // empty' "$LEGACY_CONFIG_FILE")
    AWS_REGION=$(jq -r '.providers.aws.region // "us-east-1"' "$LEGACY_CONFIG_FILE")

    # Get profile for current environment
    if [[ -n "${HELM_ENVIRONMENT:-}" ]]; then
        AWS_PROFILE=$(jq -r ".providers.aws.profiles.${HELM_ENVIRONMENT} // empty" "$LEGACY_CONFIG_FILE")
    fi

    export AWS_ACCOUNT_ID AWS_REGION AWS_PROFILE
    log_success "Legacy configuration loaded"
    return 0
}

# Function: Load deployment registry
load_deployment_registry() {
    if [[ ! -f "$DEPLOYMENTS_REGISTRY" ]]; then
        log_warning "Deployment registry not found: $DEPLOYMENTS_REGISTRY"
        log_info "No deployments have been registered yet."
        return 1
    fi

    log_info "Deployment registry found: $DEPLOYMENTS_REGISTRY"
    export HELM_DEPLOYMENTS_REGISTRY="$DEPLOYMENTS_REGISTRY"
    return 0
}

# Function: Get deployments for environment
get_deployments_for_env() {
    local env="$1"

    if [[ ! -f "$DEPLOYMENTS_REGISTRY" ]]; then
        echo "[]"
        return 0
    fi

    jq --arg env "$env" '[.deployments[] | select(.environment == $env)]' "$DEPLOYMENTS_REGISTRY"
}

# Function: Get resources for deployment
get_resources_for_deployment() {
    local deployment_id="$1"

    if [[ ! -f "$DEPLOYMENTS_REGISTRY" ]]; then
        echo "[]"
        return 0
    fi

    jq --arg id "$deployment_id" '
        (.deployments[] | select(.id == $id) | .resources) // []
    ' "$DEPLOYMENTS_REGISTRY"
}

# Function: Load helm-cloud monitoring configuration
load_monitoring_config() {
    if [[ ! -f "$MONITORING_CONFIG_FILE" ]]; then
        log_warning "Monitoring config not found: $MONITORING_CONFIG_FILE"
        log_info "Using default monitoring settings"
        return 1
    fi

    log_info "Loading monitoring configuration: $MONITORING_CONFIG_FILE"

    # Note: TOML parsing requires toml-cli or yq
    # For now, we'll use defaults and note that this should be enhanced
    log_warning "TOML parsing not yet implemented - using defaults"
    log_info "To enable TOML parsing, install: pip install toml-cli"

    return 0
}

# Function: Validate environment
validate_environment() {
    local env="${1:-}"

    if [[ -z "$env" ]]; then
        log_error "Environment not specified"
        return 1
    fi

    if [[ "$env" != "test" && "$env" != "prod" ]]; then
        log_error "Invalid environment: $env (must be 'test' or 'prod')"
        return 1
    fi

    export HELM_ENVIRONMENT="$env"
    log_success "Environment set to: $env"
    return 0
}

# Function: Load complete configuration
load_helm_config() {
    local env="${1:-test}"

    check_jq_installed || return 1
    validate_environment "$env" || return 1

    # Set paths
    export HELM_PROJECT_ROOT="$PROJECT_ROOT"
    export HELM_SHARED_CONFIG_DIR="$SHARED_CONFIG_DIR"
    export HELM_REGISTRY_DIR="$REGISTRY_DIR"
    export HELM_CONFIG_FILE="$MONITORING_CONFIG_FILE"

    log_info "Loading Helm-Cloud configuration for environment: $env"

    # Try to load shared AWS config first
    if ! load_shared_aws_config; then
        # Fall back to legacy config for backward compatibility
        load_legacy_devops_config || {
            log_error "Could not load AWS configuration (neither shared nor legacy found)"
            return 1
        }
    fi

    # Load deployment registry
    load_deployment_registry || true  # Non-fatal

    # Load monitoring config
    load_monitoring_config || true  # Non-fatal, use defaults

    log_success "Configuration loaded successfully"
    log_info "AWS Account: ${AWS_ACCOUNT_ID:-<not set>}"
    log_info "AWS Region: ${AWS_REGION:-<not set>}"
    log_info "AWS Profile: ${AWS_PROFILE:-<not set>}"
    log_info "Environment: ${HELM_ENVIRONMENT}"

    return 0
}

# Function: Get AWS profile for current environment
get_aws_profile() {
    echo "${AWS_PROFILE:-}"
}

# Function: Check if in production
is_production() {
    [[ "${HELM_ENVIRONMENT:-}" == "prod" ]]
}

# Function: Require confirmation for environment
requires_confirmation() {
    local env="${1:-${HELM_ENVIRONMENT}}"
    [[ "$env" == "prod" ]]
}

# If script is run directly (not sourced), show usage
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo "Usage: source config-loader.sh"
    echo ""
    echo "Functions provided:"
    echo "  load_helm_config <environment>     - Load complete configuration"
    echo "  get_deployments_for_env <env>      - Get deployments for environment"
    echo "  get_resources_for_deployment <id>  - Get resources for deployment"
    echo "  get_aws_profile                    - Get AWS profile for current env"
    echo "  is_production                      - Check if current env is prod"
    echo "  requires_confirmation              - Check if env requires confirmation"
    echo ""
    echo "Example:"
    echo "  source config-loader.sh"
    echo "  load_helm_config test"
    echo "  get_deployments_for_env test"
fi
