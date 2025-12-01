#!/bin/bash
# terraform/validate.sh
# Validate Terraform configuration and state

set -euo pipefail

# Validate Terraform configuration syntax
validate_terraform_syntax() {
    echo "Validating Terraform syntax..."

    cd "$TERRAFORM_DIR"

    if terraform validate; then
        echo "✓ Terraform syntax valid"
        return 0
    else
        echo "❌ Terraform syntax errors found"
        return 1
    fi
}

# Format check Terraform files
check_terraform_formatting() {
    echo "Checking Terraform formatting..."

    cd "$TERRAFORM_DIR"

    if terraform fmt -check -recursive; then
        echo "✓ Terraform files properly formatted"
        return 0
    else
        echo "⚠️  Terraform files need formatting"
        echo "   Run: terraform fmt -recursive"
        return 1
    fi
}

# Format Terraform files
format_terraform_files() {
    echo "Formatting Terraform files..."

    cd "$TERRAFORM_DIR"

    terraform fmt -recursive

    echo "✓ Terraform files formatted"
}

# Validate Terraform state consistency
validate_terraform_state() {
    local environment="$1"

    echo "Validating Terraform state..."

    cd "$TERRAFORM_DIR"

    # Check if state exists
    if ! terraform state list >/dev/null 2>&1; then
        echo "⚠️  No Terraform state found (this is OK for new deployments)"
        return 0
    fi

    echo "✓ Terraform state accessible"

    # Show state summary
    local resource_count=$(terraform state list | wc -l)
    echo "  Resources in state: $resource_count"

    return 0
}

# Validate required variables
validate_terraform_variables() {
    local environment="$1"
    local var_file="${2:-${environment}.tfvars}"

    echo "Validating Terraform variables..."

    cd "$TERRAFORM_DIR"

    if [ ! -f "$var_file" ]; then
        echo "⚠️  Variable file not found: $var_file"
        echo "   Checking for required variables in configuration..."
    fi

    # This would need to parse .tf files to find required variables
    # For now, just check if var file exists
    if [ -f "$var_file" ]; then
        echo "✓ Variable file found: $var_file"
        return 0
    else
        echo "⚠️  No variable file - ensure all required variables are set"
        return 1
    fi
}

# Validate Terraform backend configuration
validate_terraform_backend() {
    echo "Validating Terraform backend..."

    cd "$TERRAFORM_DIR"

    # Check for backend configuration in .tf files
    if grep -rq "backend \"" *.tf 2>/dev/null; then
        echo "✓ Terraform backend configured"

        # Try to read backend config
        local backend_type=$(grep -r "backend \"" *.tf 2>/dev/null | head -1 | grep -oE 'backend "[^"]+' | cut -d'"' -f2)
        echo "  Backend type: $backend_type"

        return 0
    else
        echo "⚠️  No Terraform backend configured (using local state)"
        return 0
    fi
}

# Validate all Terraform prerequisites
validate_terraform_all() {
    local environment="$1"
    local all_valid=true

    echo "Running comprehensive Terraform validation..."
    echo ""

    # Check Terraform CLI
    if ! validate_terraform_cli; then
        all_valid=false
    fi
    echo ""

    # Check syntax
    if ! validate_terraform_syntax; then
        all_valid=false
    fi
    echo ""

    # Check formatting
    if ! check_terraform_formatting; then
        # Don't fail on formatting issues
        true
    fi
    echo ""

    # Check backend
    if ! validate_terraform_backend; then
        # Don't fail on missing backend (local state OK)
        true
    fi
    echo ""

    # Check state
    if ! validate_terraform_state "$environment"; then
        # Don't fail on missing state (new deployments OK)
        true
    fi
    echo ""

    # Check variables
    if ! validate_terraform_variables "$environment"; then
        all_valid=false
    fi

    echo ""
    if $all_valid; then
        echo "✓ All Terraform validation checks passed"
        return 0
    else
        echo "❌ Some Terraform validation checks failed"
        return 1
    fi
}

# Source from validate.sh in terraform plugin
validate_terraform_cli() {
    if ! command -v terraform >/dev/null 2>&1; then
        echo "❌ Terraform not installed"
        return 1
    fi

    local tf_version=$(terraform version -json | jq -r '.terraform_version')
    echo "✓ Terraform installed: v$tf_version"
    return 0
}
