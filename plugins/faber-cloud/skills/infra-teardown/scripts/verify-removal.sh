#!/bin/bash
# Verify all resources have been removed
set -e

ENV=$1

if [ -z "$ENV" ]; then
  echo "Error: Environment not specified"
  exit 1
fi

# Source config loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../cloud-common/scripts/config-loader.sh"

# Load configuration
load_config

TERRAFORM_DIR=$(get_terraform_dir)
AWS_PROFILE=$(get_aws_profile "$ENV")

cd "$TERRAFORM_DIR"

echo "Verifying resource removal..."
echo

# Check Terraform state
STATE_RESOURCES=$(terraform state list | wc -l)

if [ "$STATE_RESOURCES" -gt 0 ]; then
  echo "⚠ Warning: Terraform state still contains $STATE_RESOURCES resource(s)"
  echo
  echo "Remaining resources in state:"
  terraform state list
  echo
  exit 1
fi

echo "✓ Terraform state is clean (0 resources)"
echo

# Query AWS to verify key resource types are gone
AWS_PROFILE="$AWS_PROFILE" aws lambda list-functions --query 'Functions[].FunctionName' --output text > /tmp/lambdas.txt || true
AWS_PROFILE="$AWS_PROFILE" aws s3 ls > /tmp/s3.txt || true
AWS_PROFILE="$AWS_PROFILE" aws rds describe-db-instances --query 'DBInstances[].DBInstanceIdentifier' --output text > /tmp/rds.txt || true

LAMBDA_COUNT=$(cat /tmp/lambdas.txt | wc -w)
S3_COUNT=$(cat /tmp/s3.txt | wc -l)
RDS_COUNT=$(cat /tmp/rds.txt | wc -w)

echo "AWS Resource Verification:"
echo "  Lambda functions: $LAMBDA_COUNT"
echo "  S3 buckets: $S3_COUNT"
echo "  RDS instances: $RDS_COUNT"
echo

if [ "$LAMBDA_COUNT" -eq 0 ] && [ "$S3_COUNT" -eq 0 ] && [ "$RDS_COUNT" -eq 0 ]; then
  echo "✓ All key resources verified removed"
else
  echo "⚠ Some resources may still exist"
  echo "  Review AWS console to confirm complete removal"
fi

# Cleanup temp files
rm -f /tmp/lambdas.txt /tmp/s3.txt /tmp/rds.txt
