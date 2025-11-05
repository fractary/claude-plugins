#!/bin/bash
# audit-drift.sh - Detect configuration drift between Terraform and AWS
# Usage: audit-drift.sh --env <environment>

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
init_audit_report "$ENVIRONMENT" "drift"
generate_report_header "drift" "$ENVIRONMENT"
init_json_report "drift" "$ENVIRONMENT"

# Validate AWS credentials (needed for terraform operations that might access AWS)
if ! validate_aws_credentials; then
    log_error "Cannot proceed without valid AWS credentials"
    exit 1
fi

log_info "Starting drift detection audit for ${ENVIRONMENT}"

# Check if Terraform directory exists
if [[ ! -d "$TF_DIRECTORY" ]]; then
    add_check_result "Terraform Directory" "fail" "Directory not found: ${TF_DIRECTORY}"
    finalize_report
    exit 2
fi

cd "$TF_DIRECTORY"

# Check 1: Initialize Terraform if needed
log_info "Ensuring Terraform is initialized..."
if [[ ! -d ".terraform" ]]; then
    log_warning "Terraform not initialized, running init..."
    terraform init -backend=true &>/dev/null || {
        add_check_result "Terraform Init" "fail" "Failed to initialize Terraform"
        finalize_report
        exit 2
    }
fi

# Check 2: Run terraform plan with detailed exit code
log_info "Running terraform plan to detect drift..."
PLAN_OUTPUT=$(mktemp)
PLAN_EXIT_CODE=0

terraform plan -detailed-exitcode -out=/dev/null -no-color > "$PLAN_OUTPUT" 2>&1 || PLAN_EXIT_CODE=$?

# detailed-exitcode meanings:
# 0 = No changes (no drift)
# 1 = Error
# 2 = Changes detected (drift exists)

case $PLAN_EXIT_CODE in
    0)
        add_check_result "Drift Detection" "pass" "No drift detected - infrastructure matches Terraform configuration"
        add_metric "drift_items" "0"
        ;;
    2)
        # Count resources with drift
        DRIFT_COUNT=$(grep -c "# .* will be updated in-place" "$PLAN_OUTPUT" || echo "0")
        DRIFT_CREATE=$(grep -c "# .* will be created" "$PLAN_OUTPUT" || echo "0")
        DRIFT_DESTROY=$(grep -c "# .* will be destroyed" "$PLAN_OUTPUT" || echo "0")
        DRIFT_REPLACE=$(grep -c "# .* must be replaced" "$PLAN_OUTPUT" || echo "0")

        TOTAL_DRIFT=$((DRIFT_COUNT + DRIFT_CREATE + DRIFT_DESTROY + DRIFT_REPLACE))

        if [[ $TOTAL_DRIFT -gt 0 ]]; then
            add_check_result "Drift Detection" "warn" "Drift detected: ${TOTAL_DRIFT} resources differ from Terraform state"
            add_metric "drift_items" "$TOTAL_DRIFT"
            add_metric "drift_updates" "$DRIFT_COUNT"
            add_metric "drift_creates" "$DRIFT_CREATE"
            add_metric "drift_destroys" "$DRIFT_DESTROY"
            add_metric "drift_replaces" "$DRIFT_REPLACE"

            # Analyze risk level
            if [[ $DRIFT_DESTROY -gt 0 || $DRIFT_REPLACE -gt 0 ]]; then
                add_recommendation "critical" "High-risk drift detected: ${DRIFT_DESTROY} destroys, ${DRIFT_REPLACE} replaces - review immediately"
            elif [[ $DRIFT_COUNT -gt 5 ]]; then
                add_recommendation "important" "Moderate drift detected: ${DRIFT_COUNT} updates - review and reconcile"
            else
                add_recommendation "optimization" "Minor drift detected: ${DRIFT_COUNT} updates - consider reconciling"
            fi
        fi
        ;;
    1)
        ERROR_MSG=$(cat "$PLAN_OUTPUT" | tail -20)
        add_check_result "Drift Detection" "fail" "Error running terraform plan: ${ERROR_MSG}"
        rm -f "$PLAN_OUTPUT"
        finalize_report
        exit 2
        ;;
esac

# Check 3: Identify specific drift patterns
log_info "Analyzing drift patterns..."

# Tags drift
TAG_DRIFT=$(grep -c "tags" "$PLAN_OUTPUT" 2>/dev/null || echo "0")
if [[ $TAG_DRIFT -gt 0 ]]; then
    add_check_result "Tag Drift" "warn" "${TAG_DRIFT} resources have tag changes"
    add_recommendation "optimization" "Review and update tags in Terraform configuration"
fi

# Security group drift
SG_DRIFT=$(grep -c "security_group" "$PLAN_OUTPUT" 2>/dev/null || echo "0")
if [[ $SG_DRIFT -gt 0 ]]; then
    add_check_result "Security Group Drift" "warn" "${SG_DRIFT} security groups have changes"
    add_recommendation "important" "Review security group changes for security implications"
fi

# IAM drift
IAM_DRIFT=$(grep -c "iam_" "$PLAN_OUTPUT" 2>/dev/null || echo "0")
if [[ $IAM_DRIFT -gt 0 ]]; then
    add_check_result "IAM Drift" "warn" "${IAM_DRIFT} IAM resources have changes"
    add_recommendation "important" "Review IAM changes for permission implications"
fi

# Lambda drift
LAMBDA_DRIFT=$(grep -c "lambda" "$PLAN_OUTPUT" 2>/dev/null || echo "0")
if [[ $LAMBDA_DRIFT -gt 0 ]]; then
    add_check_result "Lambda Drift" "warn" "${LAMBDA_DRIFT} Lambda resources have changes"
    add_recommendation "optimization" "Review Lambda configuration changes"
fi

# Check 4: Check for resources not in state
log_info "Checking for resources not in Terraform state..."
STATE_RESOURCES=$(terraform state list 2>/dev/null | wc -l || echo "0")
add_metric "terraform_managed_resources" "$STATE_RESOURCES"

# Check 5: Check last deployment time
log_info "Checking last deployment time..."
DEPLOYMENT_DIR="${DEVOPS_PROJECT_ROOT}/.fractary/plugins/faber-cloud/deployments/${ENVIRONMENT}"
if [[ -f "${DEPLOYMENT_DIR}/registry.json" ]]; then
    LAST_DEPLOYMENT=$(jq -r '.last_updated' "${DEPLOYMENT_DIR}/registry.json" 2>/dev/null || echo "unknown")
    if [[ "$LAST_DEPLOYMENT" != "unknown" ]]; then
        add_metric "last_deployment" "$LAST_DEPLOYMENT"

        # Calculate days since deployment
        DEPLOY_TIMESTAMP=$(date -d "$LAST_DEPLOYMENT" +%s 2>/dev/null || echo "0")
        CURRENT_TIMESTAMP=$(date +%s)
        DAYS_SINCE=$(( (CURRENT_TIMESTAMP - DEPLOY_TIMESTAMP) / 86400 ))

        if [[ $DAYS_SINCE -gt 30 ]]; then
            add_check_result "Deployment Staleness" "warn" "Last deployment was ${DAYS_SINCE} days ago"
            add_recommendation "optimization" "Consider updating infrastructure to latest Terraform configuration"
        else
            add_check_result "Deployment Staleness" "pass" "Infrastructure recently updated (${DAYS_SINCE} days ago)"
        fi
    fi
fi

# Cleanup
rm -f "$PLAN_OUTPUT"

# Finalize report
finalize_report

log_success "Drift detection audit complete"

# Return appropriate exit code
get_exit_code
exit $?
