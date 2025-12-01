#!/bin/bash
# terraform/plan.sh
# Generate Terraform plan

set -euo pipefail

# Generate Terraform plan for environment
terraform_plan() {
    local environment="$1"
    local var_file="${2:-${environment}.tfvars}"

    echo "Generating Terraform plan for $environment environment..."

    cd "$TERRAFORM_DIR"

    # Check if var file exists
    if [ ! -f "$var_file" ]; then
        echo "⚠️  Variable file not found: $var_file"
        echo "   Proceeding without var file..."
        var_file=""
    fi

    # Generate plan
    local plan_file="tfplan-${environment}"

    if [ -n "$var_file" ]; then
        if terraform plan -var-file="$var_file" -out="$plan_file"; then
            echo "✓ Terraform plan generated: $plan_file"
            return 0
        else
            echo "❌ Terraform plan failed"
            return 1
        fi
    else
        if terraform plan -out="$plan_file"; then
            echo "✓ Terraform plan generated: $plan_file"
            return 0
        else
            echo "❌ Terraform plan failed"
            return 1
        fi
    fi
}

# Show Terraform plan summary
show_terraform_plan() {
    local environment="$1"
    local plan_file="tfplan-${environment}"

    cd "$TERRAFORM_DIR"

    if [ ! -f "$plan_file" ]; then
        echo "❌ Plan file not found: $plan_file"
        return 1
    fi

    echo "Terraform Plan Summary:"
    terraform show -json "$plan_file" | jq -r '
        .resource_changes[] |
        select(.change.actions != ["no-op"]) |
        "\(.change.actions[0] | ascii_upcase): \(.type).\(.name)"
    ' | sort

    return 0
}

# Destroy Terraform plan (dry run)
terraform_plan_destroy() {
    local environment="$1"
    local var_file="${2:-${environment}.tfvars}"

    echo "Generating Terraform destroy plan for $environment..."

    cd "$TERRAFORM_DIR"

    local plan_file="tfplan-destroy-${environment}"

    if [ -n "$var_file" ] && [ -f "$var_file" ]; then
        terraform plan -destroy -var-file="$var_file" -out="$plan_file"
    else
        terraform plan -destroy -out="$plan_file"
    fi
}
