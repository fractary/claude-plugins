#!/usr/bin/env bash
set -euo pipefail

# validate-terraform.sh
# Validates Terraform code using terraform fmt and validate
# Usage: ./validate-terraform.sh [terraform_dir]
# Output: JSON with validation results

TF_DIR="${1:-./infrastructure/terraform}"
CONFIG_FILE=".fractary/plugins/faber-cloud/config/devops.json"

# Check Terraform directory exists
if [ ! -d "$TF_DIR" ]; then
    echo "{\"error\": \"Terraform directory not found: $TF_DIR\"}" >&2
    exit 1
fi

# Check main.tf exists
if [ ! -f "$TF_DIR/main.tf" ]; then
    echo "{\"error\": \"main.tf not found in $TF_DIR\"}" >&2
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
if [ ! -d ".terraform" ]; then
    echo "🔧 Initializing Terraform..." >&2

    # Check for backend config
    if [ -f "../../$CONFIG_FILE" ]; then
        BACKEND_BUCKET=$(jq -r '.terraform.backend.bucket // empty' "../../$CONFIG_FILE")
        BACKEND_KEY=$(jq -r '.terraform.backend.key // empty' "../../$CONFIG_FILE")
        BACKEND_REGION=$(jq -r '.terraform.backend.region // empty' "../../$CONFIG_FILE")

        if [ -n "$BACKEND_BUCKET" ] && [ -n "$BACKEND_KEY" ] && [ -n "$BACKEND_REGION" ]; then
            terraform init \
                -backend-config="bucket=$BACKEND_BUCKET" \
                -backend-config="key=$BACKEND_KEY" \
                -backend-config="region=$BACKEND_REGION" \
                -reconfigure > /dev/null 2>&1 || {
                    echo "⚠️  Backend init failed, trying local state..." >&2
                    terraform init > /dev/null 2>&1
                }
        else
            terraform init > /dev/null 2>&1
        fi
    else
        terraform init > /dev/null 2>&1
    fi
fi

# Step 3: Validate syntax and configuration
echo "🔍 Validating Terraform configuration..." >&2
VALIDATE_OUTPUT=$(terraform validate -json 2>&1 || echo '{"valid":false}')

VALIDATE_VALID=$(echo "$VALIDATE_OUTPUT" | jq -r '.valid')

if [ "$VALIDATE_VALID" = "true" ]; then
    VALIDATE_STATUS="passed"
    VALIDATE_MESSAGE="Terraform validation passed"
else
    VALIDATE_STATUS="failed"
    VALIDATE_MESSAGE="Terraform validation failed"
    VALIDATE_ERRORS=$(echo "$VALIDATE_OUTPUT" | jq -r '.diagnostics[]?.summary' 2>/dev/null | paste -sd '; ' - || echo "Unknown validation errors")
fi

# Step 4: Check for common issues
WARNINGS=()

# Check for hardcoded values
if grep -rq "us-east-1" *.tf 2>/dev/null | grep -vq "variable\|default"; then
    WARNINGS+=("Found potentially hardcoded AWS region")
fi

# Check for missing tags (simplified check)
RESOURCE_COUNT=$(grep -c '^resource "aws_' main.tf 2>/dev/null || echo "0")
TAGGED_COUNT=$(grep -c 'tags.*=' main.tf 2>/dev/null || echo "0")

if [ "$RESOURCE_COUNT" -gt 0 ] && [ "$TAGGED_COUNT" -lt "$RESOURCE_COUNT" ]; then
    WARNINGS+=("Some resources may be missing tags")
fi

# Check S3 buckets have encryption
if grep -q 'resource "aws_s3_bucket"' main.tf 2>/dev/null; then
    if ! grep -q 'aws_s3_bucket_server_side_encryption_configuration' main.tf 2>/dev/null; then
        WARNINGS+=("S3 buckets may be missing encryption configuration")
    fi
fi

# Build warnings JSON array
WARNINGS_JSON="[]"
for warning in "${WARNINGS[@]}"; do
    WARNINGS_JSON=$(echo "$WARNINGS_JSON" | jq --arg w "$warning" '. += [$w]')
done

# Generate validation report
REPORT_FILE="validation-report.txt"
cat > "$REPORT_FILE" <<EOF
Terraform Validation Report
===========================
Date: $(date -u +"%Y-%m-%d %H:%M:%S UTC")

Formatting: $FORMAT_STATUS
Syntax: $VALIDATE_STATUS

Files Validated:
$(find . -name "*.tf" -type f | sed 's|^./||')

Resource Count: $RESOURCE_COUNT

Warnings:
$(printf '%s\n' "${WARNINGS[@]}" || echo "None")

Next Steps:
- Review generated code
- Test with: /fractary-faber-cloud:test
- Preview changes: /fractary-faber-cloud:deploy-plan
EOF

echo "📄 Validation report saved to: $TF_DIR/$REPORT_FILE" >&2

# Output JSON result
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

# Exit with appropriate code
if [ "$VALIDATE_STATUS" = "passed" ]; then
    exit 0
else
    exit 1
fi
