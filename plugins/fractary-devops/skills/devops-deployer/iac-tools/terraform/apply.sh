#!/bin/bash
# terraform/apply.sh
# Apply Terraform changes

set -euo pipefail

# Apply Terraform plan
terraform_apply() {
    local environment="$1"
    local auto_approve="${2:-false}"
    local var_file="${3:-${environment}.tfvars}"

    echo "Applying Terraform changes for $environment environment..."

    cd "$TERRAFORM_DIR"

    # Check for existing plan file
    local plan_file="tfplan-${environment}"

    if [ -f "$plan_file" ]; then
        echo "Using existing plan: $plan_file"

        if terraform apply "$plan_file"; then
            echo "✓ Terraform apply successful"
            rm -f "$plan_file"
            return 0
        else
            echo "❌ Terraform apply failed"
            return 1
        fi
    else
        echo "No plan file found, applying directly..."

        local apply_cmd="terraform apply"

        if [ "$auto_approve" = "true" ]; then
            apply_cmd="$apply_cmd -auto-approve"
        fi

        if [ -n "$var_file" ] && [ -f "$var_file" ]; then
            apply_cmd="$apply_cmd -var-file=$var_file"
        fi

        if eval "$apply_cmd"; then
            echo "✓ Terraform apply successful"
            return 0
        else
            echo "❌ Terraform apply failed"
            return 1
        fi
    fi
}

# Destroy Terraform-managed infrastructure
terraform_destroy() {
    local environment="$1"
    local auto_approve="${2:-false}"
    local var_file="${3:-${environment}.tfvars}"

    echo "⚠️  Destroying Terraform-managed infrastructure for $environment..."

    cd "$TERRAFORM_DIR"

    local destroy_cmd="terraform destroy"

    if [ "$auto_approve" = "true" ]; then
        destroy_cmd="$destroy_cmd -auto-approve"
    fi

    if [ -n "$var_file" ] && [ -f "$var_file" ]; then
        destroy_cmd="$destroy_cmd -var-file=$var_file"
    fi

    if eval "$destroy_cmd"; then
        echo "✓ Infrastructure destroyed"
        return 0
    else
        echo "❌ Terraform destroy failed"
        return 1
    fi
}

# Get Terraform output values
terraform_output() {
    local output_name="${1:-}"

    cd "$TERRAFORM_DIR"

    if [ -n "$output_name" ]; then
        terraform output -raw "$output_name"
    else
        terraform output -json
    fi
}

# Refresh Terraform state
terraform_refresh() {
    local environment="$1"
    local var_file="${2:-${environment}.tfvars}"

    echo "Refreshing Terraform state..."

    cd "$TERRAFORM_DIR"

    if [ -n "$var_file" ] && [ -f "$var_file" ]; then
        terraform refresh -var-file="$var_file"
    else
        terraform refresh
    fi
}
