#!/bin/bash
# Execute terraform destroy
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

# Get configuration
TERRAFORM_DIR=$(get_terraform_dir)
AWS_PROFILE=$(get_aws_profile "$ENV")
WORKSPACE=$(get_terraform_workspace "$ENV")

cd "$TERRAFORM_DIR"

# Select workspace
terraform workspace select "$WORKSPACE"

# Set timeout based on environment
if [ "$ENV" = "prod" ]; then
  TIMEOUT=1800  # 30 minutes
else
  TIMEOUT=600   # 10 minutes
fi

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔴 DESTROYING INFRASTRUCTURE"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Environment: $ENV"
echo "Workspace: $WORKSPACE"
echo "AWS Profile: $AWS_PROFILE"
echo "Timeout: ${TIMEOUT}s"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo

# Execute destroy with timeout
AWS_PROFILE="$AWS_PROFILE" timeout "$TIMEOUT" \
  terraform destroy -auto-approve

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
  echo
  echo "✓ Destruction completed successfully"
elif [ $EXIT_CODE -eq 124 ]; then
  echo
  echo "⚠ Destruction timed out after ${TIMEOUT}s"
  echo "  Some resources may still be destroying"
  echo "  Check AWS console and Terraform state"
  exit 124
else
  echo
  echo "✗ Destruction failed with exit code $EXIT_CODE"
  exit $EXIT_CODE
fi
