#!/bin/bash
# Validates deployment plan before execution
# Prevents common multi-environment deployment bugs
# Usage: validate-plan.sh <env> <terraform_dir>

set -e

ENV=$1
TERRAFORM_DIR=${2:-"infrastructure/terraform"}

if [ -z "$ENV" ]; then
  echo "Usage: validate-plan.sh <env> [terraform_dir]"
  echo "  env: Environment (test, staging, prod)"
  echo "  terraform_dir: Path to Terraform directory (default: infrastructure/terraform)"
  exit 1
fi

echo "🔍 Environment Safety Validation"
echo "   Environment: $ENV"
echo "   Terraform directory: $TERRAFORM_DIR"
echo ""

# Change to Terraform directory
if [ ! -d "$TERRAFORM_DIR" ]; then
  echo "❌ ERROR: Terraform directory not found: $TERRAFORM_DIR"
  exit 1
fi

cd "$TERRAFORM_DIR"

# Get current Terraform workspace
WORKSPACE=$(terraform workspace show 2>/dev/null || echo "")

if [ -z "$WORKSPACE" ]; then
  echo "⚠️  WARNING: Could not determine Terraform workspace"
  echo "   This may be OK if using default workspace"
  WORKSPACE="default"
fi

echo "Validation checks:"
echo ""

# Check 1: Environment variable matches Terraform workspace
echo "1. Checking environment/workspace match..."
if [ "$ENV" != "$WORKSPACE" ] && [ "$WORKSPACE" != "default" ]; then
  echo "   ❌ FAILED: Environment mismatch!"
  echo ""
  echo "   ENV variable: $ENV"
  echo "   Terraform workspace: $WORKSPACE"
  echo ""
  echo "   This could deploy $ENV configuration to $WORKSPACE infrastructure!"
  echo ""
  echo "   Fix: terraform workspace select $ENV"
  exit 1
fi
echo "   ✅ Environment matches workspace"
echo ""

# Check 2: Validate required environment variables
echo "2. Checking required environment variables..."
REQUIRED_VARS=("ENV")
MISSING_VARS=()

for var in "${REQUIRED_VARS[@]}"; do
  if [ -z "${!var}" ]; then
    MISSING_VARS+=("$var")
  fi
done

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
  echo "   ❌ FAILED: Missing required environment variables:"
  for var in "${MISSING_VARS[@]}"; do
    echo "      - $var"
  done
  exit 1
fi
echo "   ✅ All required variables set"
echo ""

# Check 3: Validate AWS profile matches environment (if AWS_PROFILE set)
if [ ! -z "$AWS_PROFILE" ]; then
  echo "3. Checking AWS profile matches environment..."
  if [[ ! "$AWS_PROFILE" =~ $ENV ]]; then
    echo "   ⚠️  WARNING: AWS profile may not match environment"
    echo "      ENV: $ENV"
    echo "      AWS_PROFILE: $AWS_PROFILE"
    echo ""
    echo "   Ensure AWS_PROFILE is correct for this deployment."
    echo "   Press Ctrl+C within 5 seconds to abort..."
    sleep 5
  else
    echo "   ✅ AWS profile matches environment"
  fi
  echo ""
else
  echo "3. Skipping AWS profile check (AWS_PROFILE not set)"
  echo ""
fi

# Check 4: Validate Terraform backend configuration
echo "4. Checking Terraform backend configuration..."
if [ -f ".terraform/terraform.tfstate" ]; then
  BACKEND_CONFIG=$(cat .terraform/terraform.tfstate | grep -o '"backend"' || echo "")
  if [ ! -z "$BACKEND_CONFIG" ]; then
    echo "   ✅ Backend configured"
  else
    echo "   ⚠️  WARNING: Backend may not be configured"
  fi
else
  echo "   ⚠️  WARNING: Terraform not initialized (.terraform/terraform.tfstate not found)"
  echo "      Run: terraform init"
fi
echo ""

# Check 5: Check for hardcoded environment values in variables
echo "5. Checking for hardcoded environment values..."
WRONG_ENV_REFS=()

if [ "$ENV" = "test" ]; then
  # Look for prod references in code when deploying to test
  PROD_REFS=$(grep -r "prod" *.tf 2>/dev/null | grep -v "product" | grep -v "production_mode" | wc -l || echo "0")
  if [ "$PROD_REFS" -gt 0 ]; then
    WRONG_ENV_REFS+=("Found $PROD_REFS potential 'prod' references in Terraform files")
  fi
elif [ "$ENV" = "prod" ] || [ "$ENV" = "production" ]; then
  # Look for test references in code when deploying to prod
  TEST_REFS=$(grep -r "test" *.tf 2>/dev/null | grep -v "attest" | grep -v "latest" | wc -l || echo "0")
  if [ "$TEST_REFS" -gt 0 ]; then
    WRONG_ENV_REFS+=("Found $TEST_REFS potential 'test' references in Terraform files")
  fi
fi

if [ ${#WRONG_ENV_REFS[@]} -gt 0 ]; then
  echo "   ⚠️  WARNING: Potential hardcoded environment values detected:"
  for ref in "${WRONG_ENV_REFS[@]}"; do
    echo "      - $ref"
  done
  echo ""
  echo "   Review Terraform files to ensure no hardcoded environment values."
  echo "   Press Ctrl+C within 5 seconds to abort..."
  sleep 5
else
  echo "   ✅ No obvious hardcoded environment values found"
fi
echo ""

# All checks passed
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✅ Environment safety validation PASSED"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Safe to proceed with deployment to $ENV"
exit 0
