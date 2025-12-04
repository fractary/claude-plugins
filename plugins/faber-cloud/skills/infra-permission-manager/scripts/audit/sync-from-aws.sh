#!/bin/bash
# Fetches current IAM policy from AWS and updates audit file
# Usage: sync-from-aws.sh <env>

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: sync-from-aws.sh <env>"
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

if [ -z "$POLICY_ARN" ] || [ "$POLICY_ARN" = "null" ]; then
  echo "ERROR: policy_arn not found in audit file"
  exit 1
fi

echo "🔍 Fetching current IAM policy from AWS"
echo "   Profile: $AWS_AUDIT_PROFILE"
echo "   Policy ARN: $POLICY_ARN"
echo ""

# Get policy version
POLICY_VERSION=$(aws iam get-policy \
  --policy-arn "$POLICY_ARN" \
  --profile "$AWS_AUDIT_PROFILE" \
  --query 'Policy.DefaultVersionId' \
  --output text 2>/dev/null || echo "")

if [ -z "$POLICY_VERSION" ]; then
  echo "ERROR: Failed to fetch policy from AWS"
  echo "Please check:"
  echo "  1. AWS profile configured: $AWS_AUDIT_PROFILE"
  echo "  2. Policy ARN is correct: $POLICY_ARN"
  echo "  3. Profile has IAM read permissions"
  exit 1
fi

# Get policy document
AWS_POLICY=$(aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$POLICY_VERSION" \
  --profile "$AWS_AUDIT_PROFILE" \
  --query 'PolicyVersion.Document' \
  --output json)

# Get current audit file policy
AUDIT_POLICY=$(jq '.permissions' "$AUDIT_FILE")

# Compare policies
echo "📊 Comparing policies..."
echo ""

# Show differences
DIFF_OUTPUT=$(diff <(echo "$AUDIT_POLICY" | jq -S .) <(echo "$AWS_POLICY" | jq -S .) || true)

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ Policies are in sync - no differences found"
  exit 0
fi

echo "⚠️  Differences detected between audit file and AWS:"
echo ""
echo "$DIFF_OUTPUT"
echo ""

# Prompt to update audit file
read -p "Update audit file with AWS policy? (y/n) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
  TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

  # Update audit file with AWS policy
  jq --argjson policy "$AWS_POLICY" \
     --arg timestamp "$TIMESTAMP" \
     '.permissions = $policy |
      .last_updated = $timestamp |
      .audit_trail += [{
        "timestamp": $timestamp,
        "operation": "sync_from_aws",
        "description": "Synced permissions from AWS IAM policy",
        "reason": "Manual sync requested"
      }]' \
     "$AUDIT_FILE" > "${AUDIT_FILE}.tmp"

  mv "${AUDIT_FILE}.tmp" "$AUDIT_FILE"

  echo "✅ Audit file updated from AWS"
else
  echo "Audit file not updated"
fi
