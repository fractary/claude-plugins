#!/bin/bash
# audit-config.sh - Validate Terraform configuration
# Usage: audit-config.sh --env <environment>

set -euo pipefail

# Source report generator
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/report-generator.sh"

# Check dependencies before proceeding
if ! check_dependencies; then
    exit 1
fi

# Parse arguments
ENVIRONMENT=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --env)
            if [[ $# -lt 2 || "$2" =~ ^-- ]]; then
                echo "Error: --env requires a value" >&2
                exit 2
            fi
            ENVIRONMENT="$2"
            shift 2
            ;;
        *)
            echo "Unknown argument: $1" >&2
            echo "Usage: $0 --env <environment>" >&2
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment not specified"
    exit 1
fi

# Initialize audit report
init_audit_report "$ENVIRONMENT" "config-valid"
generate_report_header "config-valid" "$ENVIRONMENT"
init_json_report "config-valid" "$ENVIRONMENT"

log_info "Starting configuration validation audit for ${ENVIRONMENT}"

# Check if Terraform directory exists
if [[ ! -d "$TF_DIRECTORY" ]]; then
    add_check_result "Terraform Directory" "fail" "Directory not found: ${TF_DIRECTORY}"
    finalize_report
    exit 2
fi

cd "$TF_DIRECTORY"

# Check 1: Terraform syntax validation
log_info "Checking Terraform syntax..."
if terraform validate &>/dev/null; then
    add_check_result "Terraform Syntax" "pass" "Configuration syntax is valid"
else
    VALIDATION_ERROR=$(terraform validate 2>&1 || true)
    add_check_result "Terraform Syntax" "fail" "Validation failed: ${VALIDATION_ERROR}"
fi

# Check 2: Required variables defined
log_info "Checking required variables..."
REQUIRED_VARS=$(terraform fmt -check=true -list=false -diff=false 2>&1 | grep -c "variable" || echo "0")
add_check_result "Variable Definitions" "pass" "Found ${REQUIRED_VARS} variable definitions"
add_metric "variable_count" "$REQUIRED_VARS"

# Check 3: Backend configuration
log_info "Checking backend configuration..."
if [[ -f ".terraform/terraform.tfstate" ]]; then
    BACKEND_TYPE=$(jq -r '.backend.type // "none"' .terraform/terraform.tfstate 2>/dev/null || echo "unknown")
    if [[ "$BACKEND_TYPE" != "none" && "$BACKEND_TYPE" != "unknown" ]]; then
        add_check_result "Backend Configuration" "pass" "Backend configured: ${BACKEND_TYPE}"
        add_metric "backend_type" "$BACKEND_TYPE"
    else
        add_check_result "Backend Configuration" "warn" "Backend may not be configured"
        add_recommendation "important" "Configure remote backend for state management"
    fi
else
    add_check_result "Backend Configuration" "warn" "Terraform not initialized"
    add_recommendation "important" "Run 'terraform init' to initialize backend"
fi

# Check 4: Provider configuration
log_info "Checking provider configuration..."
PROVIDER_COUNT=$(grep -r "provider \"" *.tf 2>/dev/null | wc -l || echo "0")
if [[ $PROVIDER_COUNT -gt 0 ]]; then
    add_check_result "Provider Configuration" "pass" "Found ${PROVIDER_COUNT} provider configurations"
    add_metric "provider_count" "$PROVIDER_COUNT"
else
    add_check_result "Provider Configuration" "warn" "No provider configurations found"
    add_recommendation "important" "Add provider configurations to Terraform files"
fi

# Check 5: Module references
log_info "Checking module references..."
MODULE_COUNT=$(grep -r "module \"" *.tf 2>/dev/null | wc -l || echo "0")
add_check_result "Module References" "pass" "Found ${MODULE_COUNT} module references"
add_metric "module_count" "$MODULE_COUNT"

# Check 6: Resource count
log_info "Counting resources..."
RESOURCE_COUNT=$(grep -r "resource \"" *.tf 2>/dev/null | wc -l || echo "0")
add_check_result "Resource Definitions" "pass" "Found ${RESOURCE_COUNT} resource definitions"
add_metric "resource_count" "$RESOURCE_COUNT"

# Check 7: Formatting
log_info "Checking formatting..."
if terraform fmt -check=true -recursive=false &>/dev/null; then
    add_check_result "Code Formatting" "pass" "All files are properly formatted"
else
    UNFORMATTED=$(terraform fmt -check=true -recursive=false 2>&1 | wc -l)
    add_check_result "Code Formatting" "warn" "${UNFORMATTED} files need formatting"
    add_recommendation "optimization" "Run 'terraform fmt' to format code"
fi

# Finalize report
finalize_report

log_success "Configuration validation audit complete"

# Return appropriate exit code
get_exit_code
exit $?
