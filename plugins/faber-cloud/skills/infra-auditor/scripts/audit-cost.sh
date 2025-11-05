#!/bin/bash
# audit-cost.sh - Analyze infrastructure costs and identify optimization opportunities
# Usage: audit-cost.sh --env <environment>

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
init_audit_report "$ENVIRONMENT" "cost"
generate_report_header "cost" "$ENVIRONMENT"
init_json_report "cost" "$ENVIRONMENT"

# Validate AWS credentials
if ! validate_aws_credentials; then
    log_error "Cannot proceed without valid AWS credentials"
    exit 1
fi

log_info "Starting cost analysis audit for ${ENVIRONMENT}"

# Get current month dates
CURRENT_MONTH_START=$(date +"%Y-%m-01")
CURRENT_MONTH_END=$(date +"%Y-%m-%d")
NEXT_MONTH_START=$(date -d "+1 month" +"%Y-%m-01")

# Check 1: Get current month costs
log_info "Fetching current month costs..."
CURRENT_COST=$(aws ce get-cost-and-usage \
    --time-period Start=${CURRENT_MONTH_START},End=${CURRENT_MONTH_END} \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.ResultsByTime[0].Total.UnblendedCost.Amount' || echo "0")

CURRENT_COST_ROUNDED=$(printf "%.2f" "$CURRENT_COST")
add_check_result "Current Month Cost" "pass" "Current month spending: \$${CURRENT_COST_ROUNDED}"
add_metric "current_month_cost" "\$${CURRENT_COST_ROUNDED}"

# Check 2: Get forecasted monthly cost
log_info "Fetching cost forecast..."
FORECAST_COST=$(aws ce get-cost-forecast \
    --time-period Start=${CURRENT_MONTH_END},End=${NEXT_MONTH_START} \
    --metric UNBLENDED_COST \
    --granularity MONTHLY \
    --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.Total.Amount' || echo "0")

FORECAST_COST_ROUNDED=$(printf "%.2f" "$FORECAST_COST")
add_check_result "Forecasted Cost" "pass" "Estimated monthly cost: \$${FORECAST_COST_ROUNDED}"
add_metric "forecasted_monthly_cost" "\$${FORECAST_COST_ROUNDED}"

# Check 3: Cost breakdown by service
log_info "Analyzing cost by service..."
COST_BY_SERVICE=$(aws ce get-cost-and-usage \
    --time-period Start=${CURRENT_MONTH_START},End=${CURRENT_MONTH_END} \
    --granularity MONTHLY \
    --metrics UnblendedCost \
    --group-by Type=DIMENSION,Key=SERVICE \
    --profile "$AWS_PROFILE" 2>/dev/null || echo '{"ResultsByTime":[{"Groups":[]}]}')

TOP_SERVICES=$(echo "$COST_BY_SERVICE" | jq -r '.ResultsByTime[0].Groups[] | "\(.Keys[0]): $\(.Metrics.UnblendedCost.Amount | tonumber | round * 100 / 100)"' | sort -t'$' -k2 -rn | head -5)

if [[ -n "$TOP_SERVICES" ]]; then
    add_check_result "Top 5 Services by Cost" "pass" "$(echo "$TOP_SERVICES" | paste -sd ', ')"
fi

# Check 4: Identify underutilized resources
log_info "Checking for underutilized resources..."

# EC2 instances with low utilization
EC2_INSTANCES=$(aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" "Name=tag:Project,Values=${DEVOPS_PROJECT_NAME}" \
    --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.Reservations[].Instances[].InstanceId' || echo "")

UNDERUTILIZED_EC2=0
for instance in $EC2_INSTANCES; do
    # Get average CPU utilization for last 7 days
    AVG_CPU=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/EC2 \
        --metric-name CPUUtilization \
        --dimensions Name=InstanceId,Value=$instance \
        --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 86400 \
        --statistics Average \
        --profile "$AWS_PROFILE" 2>/dev/null | \
        jq -r '.Datapoints | if length > 0 then (map(.Average) | add / length) else 100 end' || echo "100")

    if (( $(echo "$AVG_CPU < 10" | bc -l) )); then
        UNDERUTILIZED_EC2=$((UNDERUTILIZED_EC2 + 1))
    fi
done

if [[ $UNDERUTILIZED_EC2 -gt 0 ]]; then
    add_check_result "Underutilized EC2" "warn" "${UNDERUTILIZED_EC2} EC2 instances with low CPU utilization (< 10%)"
    add_recommendation "optimization" "Review and downsize or terminate underutilized EC2 instances"
else
    add_check_result "Underutilized EC2" "pass" "No underutilized EC2 instances detected"
fi

# Check 5: RDS instances utilization
log_info "Checking RDS utilization..."
RDS_INSTANCES=$(aws rds describe-db-instances \
    --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.DBInstances[] | select(.DBInstanceIdentifier | startswith("'${DEVOPS_PROJECT_NAME}'")) | .DBInstanceIdentifier' || echo "")

UNDERUTILIZED_RDS=0
for instance in $RDS_INSTANCES; do
    # Get average connections for last 7 days
    AVG_CONNECTIONS=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/RDS \
        --metric-name DatabaseConnections \
        --dimensions Name=DBInstanceIdentifier,Value=$instance \
        --start-time $(date -u -d '7 days ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 86400 \
        --statistics Average \
        --profile "$AWS_PROFILE" 2>/dev/null | \
        jq -r '.Datapoints | if length > 0 then (map(.Average) | add / length) else 100 end' || echo "100")

    if (( $(echo "$AVG_CONNECTIONS < 5" | bc -l) )); then
        UNDERUTILIZED_RDS=$((UNDERUTILIZED_RDS + 1))
    fi
done

if [[ $UNDERUTILIZED_RDS -gt 0 ]]; then
    add_check_result "Underutilized RDS" "warn" "${UNDERUTILIZED_RDS} RDS instances with low connection count"
    add_recommendation "optimization" "Review RDS instance sizing and consider downsizing"
else
    add_check_result "Underutilized RDS" "pass" "RDS instances appear well-utilized"
fi

# Check 6: S3 storage costs
log_info "Analyzing S3 storage..."
S3_BUCKETS=$(aws s3api list-buckets --profile "$AWS_PROFILE" 2>/dev/null | \
    jq -r '.Buckets[] | select(.Name | startswith("'${DEVOPS_PROJECT_NAME}'")) | .Name' || echo "")

TOTAL_S3_SIZE=0
for bucket in $S3_BUCKETS; do
    BUCKET_SIZE=$(aws cloudwatch get-metric-statistics \
        --namespace AWS/S3 \
        --metric-name BucketSizeBytes \
        --dimensions Name=BucketName,Value=$bucket Name=StorageType,Value=StandardStorage \
        --start-time $(date -u -d '1 day ago' +%Y-%m-%dT%H:%M:%S) \
        --end-time $(date -u +%Y-%m-%dT%H:%M:%S) \
        --period 86400 \
        --statistics Average \
        --profile "$AWS_PROFILE" 2>/dev/null | \
        jq -r '.Datapoints | if length > 0 then .[0].Average else 0 end' || echo "0")

    TOTAL_S3_SIZE=$(echo "$TOTAL_S3_SIZE + $BUCKET_SIZE" | bc)
done

TOTAL_S3_GB=$(echo "scale=2; $TOTAL_S3_SIZE / 1073741824" | bc)
add_check_result "S3 Storage" "pass" "Total S3 storage: ${TOTAL_S3_GB} GB"
add_metric "s3_storage_gb" "$TOTAL_S3_GB"

# If > 100 GB, suggest lifecycle policies
if (( $(echo "$TOTAL_S3_GB > 100" | bc -l) )); then
    add_recommendation "optimization" "Consider S3 lifecycle policies to transition old data to cheaper storage classes"
fi

# Check 7: Cost budget compliance (if budget exists)
log_info "Checking budget compliance..."
BUDGET_NAME="${DEVOPS_PROJECT_NAME}-${DEVOPS_PROJECT_SUBSYSTEM}-${ENVIRONMENT}"
BUDGET_INFO=$(aws budgets describe-budget \
    --account-id "$AWS_ACCOUNT_ID" \
    --budget-name "$BUDGET_NAME" \
    --profile "$AWS_PROFILE" 2>/dev/null || echo '{"Budget":null}')

if [[ $(echo "$BUDGET_INFO" | jq '.Budget') != "null" ]]; then
    BUDGET_LIMIT=$(echo "$BUDGET_INFO" | jq -r '.Budget.BudgetLimit.Amount')
    BUDGET_PERCENT=$(echo "scale=0; ($FORECAST_COST / $BUDGET_LIMIT) * 100" | bc)

    if (( $(echo "$BUDGET_PERCENT > 90" | bc -l) )); then
        add_check_result "Budget Compliance" "warn" "Budget usage at ${BUDGET_PERCENT}% (limit: \$${BUDGET_LIMIT})"
        add_recommendation "important" "Cost approaching budget limit - review and optimize"
    elif (( $(echo "$BUDGET_PERCENT > 75" | bc -l) )); then
        add_check_result "Budget Compliance" "warn" "Budget usage at ${BUDGET_PERCENT}% (limit: \$${BUDGET_LIMIT})"
        add_recommendation "optimization" "Monitor costs closely as budget threshold approached"
    else
        add_check_result "Budget Compliance" "pass" "Within budget: ${BUDGET_PERCENT}% of \$${BUDGET_LIMIT}"
    fi

    add_metric "budget_limit" "\$${BUDGET_LIMIT}"
    add_metric "budget_usage_percent" "${BUDGET_PERCENT}%"
else
    add_check_result "Budget Configuration" "warn" "No budget configured for this environment"
    add_recommendation "optimization" "Create a budget to track and alert on cost overruns"
fi

# Finalize report
finalize_report

log_success "Cost analysis audit complete"

# Return appropriate exit code
get_exit_code
exit $?
