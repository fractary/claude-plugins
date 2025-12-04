#!/bin/bash
# Shows differences between audit file and actual AWS state
# Usage: diff-audit-aws.sh <env>

set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Usage: diff-audit-aws.sh <env>"
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

echo "🔍 Comparing audit file with AWS IAM policy"
echo "   Environment: $ENV"
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
  echo "❌ Failed to fetch policy from AWS"
  echo ""
  echo "Please check:"
  echo "  1. AWS profile configured: $AWS_AUDIT_PROFILE"
  echo "  2. Policy ARN is correct: $POLICY_ARN"
  echo "  3. Profile has IAM read permissions"
  exit 1
fi

# Get policy document from AWS
AWS_POLICY=$(aws iam get-policy-version \
  --policy-arn "$POLICY_ARN" \
  --version-id "$POLICY_VERSION" \
  --profile "$AWS_AUDIT_PROFILE" \
  --query 'PolicyVersion.Document' \
  --output json)

# Get policy document from audit file
AUDIT_POLICY=$(jq '.permissions' "$AUDIT_FILE")

# Create temp files for comparison
TMP_AUDIT=$(mktemp)
TMP_AWS=$(mktemp)

echo "$AUDIT_POLICY" | jq -S . > "$TMP_AUDIT"
echo "$AWS_POLICY" | jq -S . > "$TMP_AWS"

# Compare policies
DIFF_OUTPUT=$(diff -u "$TMP_AUDIT" "$TMP_AWS" || true)

# Clean up temp files
rm -f "$TMP_AUDIT" "$TMP_AWS"

if [ -z "$DIFF_OUTPUT" ]; then
  echo "✅ No differences - Audit file and AWS are in sync"
  echo ""
  echo "Last updated: $(jq -r '.last_updated' "$AUDIT_FILE")"
  exit 0
fi

echo "⚠️  Differences detected:"
echo ""
echo "Legend:"
echo "  - Lines in audit file"
echo "  + Lines in AWS"
echo ""
echo "$DIFF_OUTPUT"
echo ""

# Extract actions differences
AUDIT_ACTIONS=$(echo "$AUDIT_POLICY" | jq -r '.Statement[].Action | if type == "array" then .[] else . end' | sort -u)
AWS_ACTIONS=$(echo "$AWS_POLICY" | jq -r '.Statement[].Action | if type == "array" then .[] else . end' | sort -u)

# Find actions only in audit file
ONLY_IN_AUDIT=$(comm -23 <(echo "$AUDIT_ACTIONS") <(echo "$AWS_ACTIONS") || true)

# Find actions only in AWS
ONLY_IN_AWS=$(comm -13 <(echo "$AUDIT_ACTIONS") <(echo "$AWS_ACTIONS") || true)

if [ ! -z "$ONLY_IN_AUDIT" ]; then
  echo "📝 Actions in audit file but NOT in AWS:"
  echo "$ONLY_IN_AUDIT" | sed 's/^/  - /'
  echo ""
fi

if [ ! -z "$ONLY_IN_AWS" ]; then
  echo "☁️  Actions in AWS but NOT in audit file:"
  echo "$ONLY_IN_AWS" | sed 's/^/  - /'
  echo ""
fi

echo "Next steps:"
echo "  1. To sync audit file FROM AWS: ./sync-from-aws.sh $ENV"
echo "  2. To apply audit file TO AWS: ./apply-to-aws.sh $ENV"
