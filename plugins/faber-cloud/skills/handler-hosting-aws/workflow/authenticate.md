# AWS Authentication Workflow

## Step 1: Load Configuration

```bash
# Source the config loader
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../../devops-common/scripts/config-loader.sh"

# Load configuration for the specified environment
load_config "${environment}"
```

## Step 2: Validate Profile

```bash
# Validate that we're using the correct profile for the operation
validate_profile_separation "deploy" "${environment}"
```

## Step 3: Verify AWS Credentials

```bash
# Get caller identity to verify authentication
CALLER_IDENTITY=$(aws sts get-caller-identity --profile "${AWS_PROFILE}" 2>&1)

if [ $? -ne 0 ]; then
    echo "❌ AWS authentication failed"
    echo "Profile: ${AWS_PROFILE}"
    echo "Error: ${CALLER_IDENTITY}"
    exit 1
fi

# Extract account ID
ACCOUNT_ID=$(echo "${CALLER_IDENTITY}" | jq -r '.Account')
USER_ARN=$(echo "${CALLER_IDENTITY}" | jq -r '.Arn')

echo "✓ AWS authentication successful"
echo "  Account: ${ACCOUNT_ID}"
echo "  Profile: ${AWS_PROFILE}"
echo "  Region: ${AWS_REGION}"
echo "  User: ${USER_ARN}"
```

## Step 4: Return Authentication Status

Return JSON response:
```json
{
  "status": "success",
  "operation": "authenticate",
  "account_id": "${ACCOUNT_ID}",
  "region": "${AWS_REGION}",
  "profile": "${AWS_PROFILE}",
  "user_arn": "${USER_ARN}"
}
```
