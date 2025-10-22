#!/bin/bash
# terraform/init.sh
# Terraform initialization

set -euo pipefail

# Initialize Terraform for environment
terraform_init() {
    local environment="$1"

    echo "Initializing Terraform for $environment environment..."

    # Validate Terraform directory exists
    if [ ! -d "$TERRAFORM_DIR" ]; then
        echo "❌ Terraform directory not found: $TERRAFORM_DIR"
        return 1
    fi

    # Run terraform init
    cd "$TERRAFORM_DIR"

    if terraform init; then
        echo "✓ Terraform initialized successfully"
        return 0
    else
        echo "❌ Terraform initialization failed"
        return 1
    fi
}

# Check if Terraform is installed
validate_terraform_cli() {
    if ! command -v terraform >/dev/null 2>&1; then
        echo "❌ Terraform not installed"
        echo "   Install: https://www.terraform.io/downloads"
        return 1
    fi

    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    echo "✓ Terraform installed: v$tf_version"
    return 0
}

# Validate Terraform configuration
validate_terraform_config() {
    local environment="$1"

    echo "Validating Terraform configuration..."

    cd "$TERRAFORM_DIR"

    if terraform validate; then
        echo "✓ Terraform configuration valid"
        return 0
    else
        echo "❌ Terraform configuration invalid"
        return 1
    fi
}
