#!/bin/bash
# aws/resource-naming.sh
# AWS resource naming conventions and pattern resolution

set -euo pipefail

# Resolve AWS resource name from pattern
resolve_resource_name() {
    local pattern="$1"
    local environment="$2"

    # Use global resolve_pattern function from config-loader
    resolve_pattern "$pattern" "$environment"
}

# Generate S3 bucket name (must be globally unique, lowercase, no underscores)
generate_s3_bucket_name() {
    local pattern="$1"
    local environment="$2"

    local name=$(resolve_pattern "$pattern" "$environment")

    # Convert to lowercase and replace underscores with hyphens
    echo "$name" | tr '[:upper:]' '[:lower:]' | tr '_' '-'
}

# Generate Lambda function name
generate_lambda_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Generate IAM role name
generate_iam_role_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Generate IAM policy name
generate_iam_policy_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Generate CloudWatch log group name
generate_log_group_name() {
    local service="$1"
    local resource="$2"
    local environment="$3"

    echo "/aws/${service}/${resource}-${environment}"
}

# Generate ECR repository name
generate_ecr_repository_name() {
    local pattern="$1"
    local environment="$2"

    local name=$(resolve_pattern "$pattern" "$environment")

    # ECR repository names must be lowercase
    echo "$name" | tr '[:upper:]' '[:lower:]'
}

# Generate Step Functions state machine name
generate_state_machine_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Generate SNS topic name
generate_sns_topic_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Generate CloudWatch dashboard name
generate_dashboard_name() {
    local pattern="$1"
    local environment="$2"

    resolve_pattern "$pattern" "$environment"
}

# Validate resource name meets AWS requirements
validate_resource_name() {
    local resource_type="$1"
    local name="$2"

    case "$resource_type" in
        s3)
            # S3 bucket names: 3-63 chars, lowercase, no underscores
            if [[ ! "$name" =~ ^[a-z0-9][a-z0-9-]{1,61}[a-z0-9]$ ]]; then
                echo "❌ Invalid S3 bucket name: $name"
                echo "   Must be 3-63 lowercase alphanumeric characters and hyphens"
                return 1
            fi
            ;;
        lambda)
            # Lambda function names: 1-64 chars
            if [ ${#name} -gt 64 ]; then
                echo "❌ Lambda function name too long: $name (max 64 chars)"
                return 1
            fi
            ;;
        iam_role)
            # IAM role names: 1-64 chars
            if [ ${#name} -gt 64 ]; then
                echo "❌ IAM role name too long: $name (max 64 chars)"
                return 1
            fi
            ;;
        *)
            # Generic validation
            if [ ${#name} -gt 255 ]; then
                echo "❌ Resource name too long: $name (max 255 chars)"
                return 1
            fi
            ;;
    esac

    return 0
}
