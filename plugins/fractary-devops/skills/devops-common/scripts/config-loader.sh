#!/bin/bash
# config-loader.sh
# Loads DevOps configuration from .fractary/.config/devops.json
# Provides pattern substitution and auto-discovery fallbacks

set -euo pipefail

# Configuration file path
CONFIG_FILE=".fractary/.config/devops.json"

# Default values
DEFAULT_AWS_REGION="us-east-1"
DEFAULT_TERRAFORM_DIR="infrastructure/terraform"
DEFAULT_IAM_POLICIES_DIR="infrastructure/iam-policies"

# Global configuration variables (exported for use by other scripts)
export PROJECT_NAME=""
export NAMESPACE=""
export ORGANIZATION=""
export AWS_REGION=""
export TERRAFORM_DIR=""
export IAM_POLICIES_DIR=""
export PROVIDER=""
export IAC_TOOL=""

# AWS-specific
export AWS_ACCOUNT_ID=""
export PROFILE_DISCOVER=""
export PROFILE_TEST=""
export PROFILE_PROD=""
export USER_NAME_PATTERN=""
export POLICY_NAME_PATTERN=""
export RESOURCE_PREFIX=""

# Terraform-specific
export TERRAFORM_REQUIRED_VERSION=""
export TERRAFORM_BACKEND=""

# Load configuration from file or auto-discover
load_devops_config() {
    local config_file="${1:-$CONFIG_FILE}"

    echo "Loading DevOps configuration..."

    # Check if config file exists
    if [ ! -f "$config_file" ]; then
        echo "⚠️  Configuration file not found: $config_file"
        echo "   Run /devops:init to create configuration"
        echo "   Using auto-discovery and defaults..."
        auto_discover_config
        return 0
    fi

    # Validate JSON
    if ! jq empty "$config_file" >/dev/null 2>&1; then
        echo "❌ Invalid JSON in configuration file: $config_file"
        exit 1
    fi

    # Load core configuration
    PROJECT_NAME=$(jq -r '.project.name // empty' "$config_file")
    NAMESPACE=$(jq -r '.project.namespace // empty' "$config_file")
    ORGANIZATION=$(jq -r '.project.organization // empty' "$config_file")
    PROVIDER=$(jq -r '.provider // empty' "$config_file")
    IAC_TOOL=$(jq -r '.iac_tool // empty' "$config_file")

    # Load directories
    TERRAFORM_DIR=$(jq -r '.directories.terraform // empty' "$config_file")
    IAM_POLICIES_DIR=$(jq -r '.directories.iam_policies // empty' "$config_file")

    # Apply defaults and fallbacks
    : "${PROJECT_NAME:=$(auto_discover_project_name)}"
    : "${NAMESPACE:=$PROJECT_NAME}"
    : "${ORGANIZATION:=$(auto_discover_organization)}"
    : "${TERRAFORM_DIR:=$DEFAULT_TERRAFORM_DIR}"
    : "${IAM_POLICIES_DIR:=$DEFAULT_IAM_POLICIES_DIR}"

    # Load provider-specific config
    case "$PROVIDER" in
        aws)
            load_aws_config "$config_file"
            ;;
        gcp)
            load_gcp_config "$config_file"
            ;;
        azure)
            load_azure_config "$config_file"
            ;;
        *)
            if [ -n "$PROVIDER" ]; then
                echo "⚠️  Unknown provider: $PROVIDER"
            fi
            ;;
    esac

    # Load IaC tool-specific config
    case "$IAC_TOOL" in
        terraform)
            load_terraform_config "$config_file"
            ;;
        pulumi)
            load_pulumi_config "$config_file"
            ;;
        *)
            if [ -n "$IAC_TOOL" ]; then
                echo "⚠️  Unknown IaC tool: $IAC_TOOL"
            fi
            ;;
    esac

    echo "✓ Configuration loaded"
    echo "  Project: $PROJECT_NAME"
    echo "  Provider: $PROVIDER"
    echo "  IaC Tool: $IAC_TOOL"
}

# Load AWS-specific configuration
load_aws_config() {
    local config_file="$1"

    AWS_ACCOUNT_ID=$(jq -r '.aws.account_id // empty' "$config_file")
    AWS_REGION=$(jq -r '.aws.region // empty' "$config_file")
    PROFILE_DISCOVER=$(jq -r '.aws.profiles.discover // empty' "$config_file")
    PROFILE_TEST=$(jq -r '.aws.profiles.test // empty' "$config_file")
    PROFILE_PROD=$(jq -r '.aws.profiles.prod // empty' "$config_file")
    USER_NAME_PATTERN=$(jq -r '.aws.iam.user_name_pattern // empty' "$config_file")
    POLICY_NAME_PATTERN=$(jq -r '.aws.iam.policy_name_pattern // empty' "$config_file")
    RESOURCE_PREFIX=$(jq -r '.aws.resource_naming.prefix // empty' "$config_file")

    # Apply defaults
    : "${AWS_REGION:=$DEFAULT_AWS_REGION}"
    : "${PROFILE_DISCOVER:=${NAMESPACE}-discover-deploy}"
    : "${PROFILE_TEST:=${NAMESPACE}-test-deploy}"
    : "${PROFILE_PROD:=${NAMESPACE}-prod-deploy}"
    : "${USER_NAME_PATTERN:={namespace}-{environment}-deploy}"
    : "${POLICY_NAME_PATTERN:={project}-{environment}-deploy-terraform}"
    : "${RESOURCE_PREFIX:=$PROJECT_NAME}"

    # Auto-discover AWS account if not specified
    if [ -z "$AWS_ACCOUNT_ID" ]; then
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    fi
}

# Load GCP-specific configuration
load_gcp_config() {
    local config_file="$1"
    # TODO: Implement GCP config loading
    echo "⚠️  GCP configuration not yet implemented"
}

# Load Azure-specific configuration
load_azure_config() {
    local config_file="$1"
    # TODO: Implement Azure config loading
    echo "⚠️  Azure configuration not yet implemented"
}

# Load Terraform-specific configuration
load_terraform_config() {
    local config_file="$1"

    TERRAFORM_REQUIRED_VERSION=$(jq -r '.terraform.required_version // empty' "$config_file")
    TERRAFORM_BACKEND=$(jq -r '.terraform.backend // empty' "$config_file")

    : "${TERRAFORM_REQUIRED_VERSION:=>=1.5.0}"
    : "${TERRAFORM_BACKEND:=s3}"
}

# Load Pulumi-specific configuration
load_pulumi_config() {
    local config_file="$1"
    # TODO: Implement Pulumi config loading
    echo "⚠️  Pulumi configuration not yet implemented"
}

# Auto-discover configuration when file doesn't exist
auto_discover_config() {
    PROJECT_NAME=$(auto_discover_project_name)
    NAMESPACE="$PROJECT_NAME"
    ORGANIZATION=$(auto_discover_organization)
    TERRAFORM_DIR="$DEFAULT_TERRAFORM_DIR"
    IAM_POLICIES_DIR="$DEFAULT_IAM_POLICIES_DIR"
    AWS_REGION="$DEFAULT_AWS_REGION"

    # Try to detect provider and IaC tool
    if command -v aws >/dev/null 2>&1; then
        PROVIDER="aws"
        AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
    fi

    if command -v terraform >/dev/null 2>&1 && [ -d "$TERRAFORM_DIR" ]; then
        IAC_TOOL="terraform"
    fi
}

# Auto-discover project name from Git
auto_discover_project_name() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        basename "$(git rev-parse --show-toplevel)" | sed 's/\.git$//'
    else
        basename "$(pwd)"
    fi
}

# Auto-discover organization from Git remote
auto_discover_organization() {
    if git rev-parse --git-dir > /dev/null 2>&1; then
        git remote get-url origin 2>/dev/null | sed -E 's|.*[:/]([^/]+)/.*|\1|' || echo ""
    else
        echo ""
    fi
}

# Get configuration value
get_config_value() {
    local key="$1"
    local config_file="${2:-$CONFIG_FILE}"

    if [ -f "$config_file" ]; then
        jq -r ".$key // empty" "$config_file"
    else
        echo ""
    fi
}

# Resolve pattern with placeholder substitution
resolve_pattern() {
    local pattern="$1"
    local environment="${2:-test}"

    # Substitute placeholders
    echo "$pattern" | \
        sed "s/{project}/$PROJECT_NAME/g" | \
        sed "s/{namespace}/$NAMESPACE/g" | \
        sed "s/{organization}/$ORGANIZATION/g" | \
        sed "s/{environment}/$environment/g" | \
        sed "s/{prefix}/$RESOURCE_PREFIX/g"
}

# Get AWS profile for environment
get_aws_profile() {
    local environment="$1"

    case "$environment" in
        test)
            echo "$PROFILE_TEST"
            ;;
        prod)
            echo "$PROFILE_PROD"
            ;;
        discover)
            echo "$PROFILE_DISCOVER"
            ;;
        *)
            echo "❌ Invalid environment: $environment" >&2
            exit 1
            ;;
    esac
}

# Validate configuration is loaded
validate_config_loaded() {
    if [ -z "$PROJECT_NAME" ]; then
        echo "❌ Configuration not loaded. Call load_devops_config first." >&2
        exit 1
    fi
}

# Display current configuration
show_config() {
    validate_config_loaded

    echo "=== DevOps Configuration ==="
    echo ""
    echo "Project:"
    echo "  Name: $PROJECT_NAME"
    echo "  Namespace: $NAMESPACE"
    echo "  Organization: $ORGANIZATION"
    echo ""
    echo "Infrastructure:"
    echo "  Provider: ${PROVIDER:-not set}"
    echo "  IaC Tool: ${IAC_TOOL:-not set}"
    echo ""
    echo "Directories:"
    echo "  Terraform: $TERRAFORM_DIR"
    echo "  IAM Policies: $IAM_POLICIES_DIR"
    echo ""

    if [ "$PROVIDER" = "aws" ]; then
        echo "AWS Configuration:"
        echo "  Account ID: $AWS_ACCOUNT_ID"
        echo "  Region: $AWS_REGION"
        echo "  Profiles:"
        echo "    Discover: $PROFILE_DISCOVER"
        echo "    Test: $PROFILE_TEST"
        echo "    Prod: $PROFILE_PROD"
        echo "  Patterns:"
        echo "    User: $USER_NAME_PATTERN"
        echo "    Policy: $POLICY_NAME_PATTERN"
        echo "  Resource Prefix: $RESOURCE_PREFIX"
        echo ""
    fi

    if [ "$IAC_TOOL" = "terraform" ]; then
        echo "Terraform Configuration:"
        echo "  Required Version: $TERRAFORM_REQUIRED_VERSION"
        echo "  Backend: $TERRAFORM_BACKEND"
        echo "  Directory: $TERRAFORM_DIR"
        echo ""
    fi
}
