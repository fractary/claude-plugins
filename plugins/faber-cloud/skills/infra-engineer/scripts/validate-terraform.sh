#!/usr/bin/env bash
set -euo pipefail

# validate-terraform.sh
# Validates Terraform code using terraform fmt and validate
# Usage: ./validate-terraform.sh [terraform_dir]
# Output: JSON with validation results

TF_DIR="${1:-./infrastructure/terraform}"
CONFIG_FILE="${FABER_CLOUD_CONFIG_FILE:-.fractary/plugins/faber-cloud/devops.json}"

# Check Terraform directory exists
if [ ! -d "$TF_DIR" ]; then
    jq -n --arg error "Terraform directory not found: $TF_DIR" '{error: $error}' >&2
    exit 1
fi

# Check main.tf exists
if [ ! -f "$TF_DIR/main.tf" ]; then
    jq -n --arg error "main.tf not found in $TF_DIR" '{error: $error}' >&2
    exit 1
fi

cd "$TF_DIR"

# Step 1: Format code
echo "🔧 Formatting Terraform code..." >&2
if terraform fmt -recursive > /dev/null 2>&1; then
    FORMAT_STATUS="passed"
    FORMAT_MESSAGE="Terraform code formatted successfully"
else
    FORMAT_STATUS="failed"
    FORMAT_MESSAGE="Terraform fmt failed"

    jq -n \
        --arg status "failed" \
        --arg format_status "$FORMAT_STATUS" \
        --arg format_message "$FORMAT_MESSAGE" \
        '{
            validation_status: $status,
            terraform_fmt: $format_status,
            terraform_validate: "skipped",
            error: $format_message
        }'
    exit 1
fi

# Step 2: Initialize Terraform (if not already initialized)
BACKEND_MODE="local"
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..." >&2

    # Check for backend config
    if [ -f "../../$CONFIG_FILE" ]; then
        BACKEND_BUCKET=$(jq -r '.terraform.backend.bucket // empty' "../../$CONFIG_FILE")
        BACKEND_KEY=$(jq -r '.terraform.backend.key // empty' "../../$CONFIG_FILE")
        BACKEND_REGION=$(jq -r '.terraform.backend.region // empty' "../../$CONFIG_FILE")

        if [ -n "$BACKEND_BUCKET" ] && [ -n "$BACKEND_KEY" ] && [ -n "$BACKEND_REGION" ]; then
            echo "🔧 Configuring S3 backend (bucket: $BACKEND_BUCKET)..." >&2
            if terraform init \
                -backend-config="bucket=$BACKEND_BUCKET" \
                -backend-config="key=$BACKEND_KEY" \
                -backend-config="region=$BACKEND_REGION" \
                -reconfigure > /dev/null 2>&1; then
                BACKEND_MODE="s3"
                echo "✅ S3 backend initialized successfully" >&2
            else
                echo "⚠️  WARNING: S3 backend init failed - falling back to local state" >&2
                echo "⚠️  This may cause state management issues in team environments" >&2
                echo "⚠️  Check your AWS credentials and S3 bucket permissions" >&2
                terraform init > /dev/null 2>&1
                BACKEND_MODE="local (fallback)"
            fi
        else
            echo "ℹ️  No backend config found - using local state" >&2
            terraform init > /dev/null 2>&1
        fi
    else
        echo "ℹ️  Config file not found - using local state" >&2
        terraform init > /dev/null 2>&1
    fi
fi

# Step 3: Validate syntax and configuration
echo "🔍 Validating Terraform configuration..." >&2
VALIDATE_OUTPUT=$(terraform validate -json 2>&1 || echo '{"valid":false}')

VALIDATE_VALID=$(echo "$VALIDATE_OUTPUT" | jq -r '.valid')
VALIDATE_ERRORS=""

if [ "$VALIDATE_VALID" = "true" ]; then
    VALIDATE_STATUS="passed"
    VALIDATE_MESSAGE="Terraform validation passed"
else
    VALIDATE_STATUS="failed"
    VALIDATE_MESSAGE="Terraform validation failed"
    # Extract errors for user visibility
    VALIDATE_ERRORS=$(echo "$VALIDATE_OUTPUT" | jq -r '.diagnostics[]?.summary' 2>/dev/null | paste -sd '; ' - || echo "Unknown validation errors")
fi

# Step 4: Check for common issues (Performance: cache .tf file content)
WARNINGS=()

# Cache all .tf file content for multiple checks
TF_CONTENT=$(cat *.tf 2>/dev/null)

# Check for hardcoded values (Fixed: correct grep order and use extended regex)
if echo "$TF_CONTENT" | grep -Ev "(variable|default)" | grep -q "us-east-1"; then
    WARNINGS+=("Found potentially hardcoded AWS region")
fi

# Check for missing tags (improved check - skip resources that don't support tags)
# List of AWS resources that DON'T support tags (as of 2025)
# Source: AWS documentation - these resources lack tag support
NON_TAGGABLE_RESOURCES=(
    "aws_iam_policy_attachment"
    "aws_iam_role_policy_attachment"
    "aws_iam_user_policy_attachment"
    "aws_route_table_association"
    "aws_subnet_route_table_association"
    "aws_vpc_endpoint_route_table_association"
    "aws_main_route_table_association"
    "aws_route"
    "aws_security_group_rule"
    "aws_network_interface_sg_attachment"
    "aws_lb_target_group_attachment"
    "aws_iam_account_alias"
    "aws_iam_account_password_policy"
)

# Count total AWS resources
TOTAL_RESOURCE_COUNT=$(echo "$TF_CONTENT" | grep -c '^resource "aws_' || echo "0")

# Count non-taggable resources
NON_TAGGABLE_COUNT=0
for resource_type in "${NON_TAGGABLE_RESOURCES[@]}"; do
    count=$(echo "$TF_CONTENT" | grep -c "^resource \"$resource_type\"" || echo "0")
    NON_TAGGABLE_COUNT=$((NON_TAGGABLE_COUNT + count))
done

# Calculate taggable resources count
TAGGABLE_COUNT=$((TOTAL_RESOURCE_COUNT - NON_TAGGABLE_COUNT))

# Count resources with tags
TAGGED_COUNT=$(echo "$TF_CONTENT" | grep -c 'tags.*=' || echo "0")

# Warn only if taggable resources are missing tags
if [ "$TAGGABLE_COUNT" -gt 0 ] && [ "$TAGGED_COUNT" -lt "$TAGGABLE_COUNT" ]; then
    WARNINGS+=("Some taggable resources may be missing tags ($TAGGED_COUNT/$TAGGABLE_COUNT tagged)")
fi

# Check S3 buckets have encryption
if echo "$TF_CONTENT" | grep -q 'resource "aws_s3_bucket"'; then
    if ! echo "$TF_CONTENT" | grep -q 'aws_s3_bucket_server_side_encryption_configuration'; then
        WARNINGS+=("S3 buckets may be missing encryption configuration")
    fi
fi

# Build warnings JSON array
WARNINGS_JSON="[]"
for warning in "${WARNINGS[@]}"; do
    WARNINGS_JSON=$(echo "$WARNINGS_JSON" | jq --arg w "$warning" '. += [$w]')
done

# Generate validation report with timestamp
TIMESTAMP=$(date -u +"%Y%m%d-%H%M%S")
REPORT_FILE="validation-report-${TIMESTAMP}.txt"
cat > "$REPORT_FILE" <<EOF
Terraform Validation Report
===========================
Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")
Backend Mode: $BACKEND_MODE

Formatting: $FORMAT_STATUS
Syntax: $VALIDATE_STATUS

Files Validated:
$(find . -name "*.tf" -type f | sed 's|^./||')

Resource Count: $TOTAL_RESOURCE_COUNT

$(if [ -n "$VALIDATE_ERRORS" ]; then
    echo "Validation Errors:"
    echo "$VALIDATE_ERRORS"
    echo ""
fi)

Warnings:
$(printf '%s\n' "${WARNINGS[@]}" 2>/dev/null || echo "None")

Next Steps:
- Review generated code
- Test with: /fractary-faber-cloud:test
- Preview changes: /fractary-faber-cloud:deploy-plan
EOF

# Also create a symlink to latest report for convenience
ln -sf "$REPORT_FILE" "validation-report-latest.txt" 2>/dev/null || true

echo "📄 Validation report saved to: $TF_DIR/$REPORT_FILE" >&2

# Output JSON result (Fixed: include VALIDATE_ERRORS in output)
if [ "$VALIDATE_STATUS" = "failed" ] && [ -n "$VALIDATE_ERRORS" ]; then
    jq -n \
        --arg status "$VALIDATE_STATUS" \
        --arg format_status "$FORMAT_STATUS" \
        --arg format_message "$FORMAT_MESSAGE" \
        --arg validate_status "$VALIDATE_STATUS" \
        --arg validate_message "$VALIDATE_MESSAGE" \
        --arg validate_errors "$VALIDATE_ERRORS" \
        --argjson warnings "$WARNINGS_JSON" \
        --arg report_file "$REPORT_FILE" \
        '{
            validation_status: $status,
            terraform_fmt: $format_status,
            terraform_validate: $validate_status,
            validation_errors: $validate_errors,
            issues_found: [],
            warnings: $warnings,
            report_file: $report_file,
            message: $validate_message
        }'
else
    jq -n \
        --arg status "$VALIDATE_STATUS" \
        --arg format_status "$FORMAT_STATUS" \
        --arg format_message "$FORMAT_MESSAGE" \
        --arg validate_status "$VALIDATE_STATUS" \
        --arg validate_message "$VALIDATE_MESSAGE" \
        --argjson warnings "$WARNINGS_JSON" \
        --arg report_file "$REPORT_FILE" \
        '{
            validation_status: $status,
            terraform_fmt: $format_status,
            terraform_validate: $validate_status,
            issues_found: [],
            warnings: $warnings,
            report_file: $report_file,
            message: $validate_message
        }'
fi

# Exit with appropriate code
if [ "$VALIDATE_STATUS" = "passed" ]; then
    exit 0
else
    exit 1
fi
