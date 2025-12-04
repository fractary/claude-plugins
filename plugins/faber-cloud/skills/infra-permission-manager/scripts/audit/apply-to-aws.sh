#!/bin/bash
# Applies permissions from audit file to AWS IAM
# Usage: apply-to-aws.sh <env>

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: apply-to-aws.sh <env>"
  echo "  env: Environment (test, staging, prod)"
  exit 1
fi

AUDIT_FILE="infrastructure/iam-policies/${ENV}-deploy-permissions.json"
CONFIG_FILE=".fractary/plugins/faber-cloud/config.json"

# Check if audit file exists
if [ ! -f "$AUDIT_FILE" ]; then
  echo "ERROR: Audit file not found: $AUDIT_FILE"
  exit 1
fi

# Check if config file exists
if [ ! -f "$CONFIG_FILE" ]; then
  # Try old config file names for backward compatibility
  CONFIG_FILE=".fractary/plugins/faber-cloud/faber-cloud.json"
  if [ ! -f "$CONFIG_FILE" ]; then
    CONFIG_FILE=".fractary/plugins/faber-cloud/devops.json"
    if [ ! -f "$CONFIG_FILE" ]; then
      echo "ERROR: Config file not found"
      exit 1
    fi
  fi
fi

# Check if jq is installed
if ! command -v jq &> /dev/null; then
  echo "ERROR: jq is required but not installed."
  exit 1
fi

# Load configuration
AWS_AUDIT_PROFILE=$(jq -r ".environments.${ENV}.aws_audit_profile // \"${ENV}-deploy-discover\"" "$CONFIG_FILE")
POLICY_ARN=$(jq -r '.policy_arn // ""' "$AUDIT_FILE")
DEPLOY_USER=$(jq -r '.deploy_user // ""' "$AUDIT_FILE")

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "null" ]; then
  echo "ERROR: policy_arn not found in audit file"
  exit 1
fi

if [ -z "$DEPLOY_USER" ] || [ "$DEPLOY_USER" = "null" ]; then
  echo "ERROR: deploy_user not found in audit file"
  exit 1
fi

echo "🚀 Applying permissions from audit file to AWS"
echo "   Environment: $ENV"
echo "   Profile: $AWS_AUDIT_PROFILE"
echo "   Deploy User: $DEPLOY_USER"
echo "   Policy ARN: $POLICY_ARN"
echo ""

# Production safety check
if [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then
  echo "⚠️  WARNING: You are applying permissions to PRODUCTION"
  echo ""
  read -p "Type 'prod' to confirm: " CONFIRM
  if [ "$CONFIRM" != "prod" ]; then
    echo "Cancelled"
    exit 1
  fi
fi

# Get policy document from audit file
POLICY_DOCUMENT=$(jq -c '.permissions' "$AUDIT_FILE")

# Create temporary file for policy document
TMP_POLICY=$(mktemp)
echo "$POLICY_DOCUMENT" > "$TMP_POLICY"

# Create new policy version
echo "📝 Creating new policy version..."
NEW_VERSION=$(aws iam create-policy-version \
  --policy-arn "$POLICY_ARN" \
  --policy-document "file://$TMP_POLICY" \
  --set-as-default \
  --profile "$AWS_AUDIT_PROFILE" \
  --query 'PolicyVersion.VersionId' \
  --output text 2>&1)

# Clean up temp file
rm -f "$TMP_POLICY"

# Check if successful
if [ $? -ne 0 ]; then
  echo "❌ Failed to apply policy to AWS"
  echo ""
  echo "Error: $NEW_VERSION"
  echo ""
  echo "Troubleshooting:"
  echo "  1. Check AWS profile has IAM write permissions: $AWS_AUDIT_PROFILE"
  echo "  2. Verify policy ARN is correct: $POLICY_ARN"
  echo "  3. Ensure policy document is valid JSON"
  echo "  4. Check AWS credentials are configured"
  exit 1
fi

echo "✅ Policy applied successfully"
echo "   New version: $NEW_VERSION"
echo ""

# Verify policy active
echo "🔍 Verifying policy..."
CURRENT_VERSION=$(aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --profile "$AWS_AUDIT_PROFILE" \
  --query 'Policy.DefaultVersionId' \
  --output text)

if [ "$CURRENT_VERSION" = "$NEW_VERSION" ]; then
  echo "✅ Verification successful - policy is active"
  echo ""

  # Update audit file with application timestamp
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  jq --arg timestamp "$TIMESTAMP" \
     --arg version "$NEW_VERSION" \
     '.last_updated = $timestamp |
      .audit_trail += [{
        "timestamp": $timestamp,
        "operation": "apply_to_aws",
        "description": "Applied audit file permissions to AWS IAM policy",
        "policy_version": $version,
        "reason": "Manual application requested"
      }]' \
     "$AUDIT_FILE" > "${AUDIT_FILE}.tmp"

  mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"

  echo "📝 Audit file updated with application record"
else
  echo "⚠️  Warning: Policy version mismatch"
  echo "   Expected: $NEW_VERSION"
  echo "   Current: $CURRENT_VERSION"
fi
