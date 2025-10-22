# AWS Provider Plugin

AWS-specific implementation for DevOps automation.

## Purpose

Handles AWS-specific operations:
- Authentication via AWS profiles
- IAM permission management for deploy users
- Resource naming conventions
- AWS resource validation

## Components

### auth.sh

Authentication and credential management:
- `authenticate_provider(environment)` - Authenticate with AWS for environment
- `validate_aws_cli()` - Check AWS CLI is installed
- `profile_exists(profile)` - Check if profile exists
- `get_aws_account_id()` - Get current AWS account ID
- `validate_all_profiles()` - Validate all configured profiles

### permissions.sh

IAM permission management for deploy users:
- `add_deployment_permission(permission, environment, reason, error)` - Add permission to deploy user
- `verify_permission(permission, environment)` - Check permission exists
- `list_permissions(environment)` - List all deploy user permissions
- `check_required_permissions(environment, permissions...)` - Validate required permissions

### resource-naming.sh

AWS resource naming conventions:
- `resolve_resource_name(pattern, environment)` - Resolve resource name
- `generate_s3_bucket_name(pattern, environment)` - Generate S3 bucket name (lowercase, hyphens)
- `generate_lambda_name(pattern, environment)` - Generate Lambda function name
- `generate_iam_role_name(pattern, environment)` - Generate IAM role name
- `generate_log_group_name(service, resource, environment)` - Generate CloudWatch log group name
- `validate_resource_name(type, name)` - Validate name meets AWS requirements

## Configuration

Required config values (from `.fractary/.config/devops.json`):

```json
{
  "provider": "aws",
  "aws": {
    "account_id": "123456789012",
    "region": "us-east-1",
    "profiles": {
      "discover": "myproject-discover-deploy",
      "test": "myproject-test-deploy",
      "prod": "myproject-prod-deploy"
    },
    "iam": {
      "user_name_pattern": "{namespace}-{environment}-deploy",
      "policy_name_pattern": "{project}-{environment}-deploy-terraform"
    },
    "resource_naming": {
      "prefix": "myproject",
      "separator": "-"
    }
  }
}
```

## Usage

```bash
# Source provider plugin
source "${SKILL_DIR}/providers/aws/auth.sh"
source "${SKILL_DIR}/providers/aws/permissions.sh"
source "${SKILL_DIR}/providers/aws/resource-naming.sh"

# Authenticate
authenticate_provider "test"

# Add permission
add_deployment_permission "s3:PutBucketPolicy" "test" "Required for bucket configuration"

# Generate resource names
bucket_name=$(generate_s3_bucket_name "{prefix}-{environment}-data" "test")
# Result: myproject-test-data
```

## AWS Profiles

The plugin uses three types of AWS profiles:

1. **Discover Profile** (`{namespace}-discover-deploy`)
   - Used for IAM management operations
   - Has permissions to modify deploy user policies
   - Temporary use only

2. **Test Deploy Profile** (`{namespace}-test-deploy`)
   - Used for test environment deployments
   - Limited to test resources
   - Safe for experimentation

3. **Prod Deploy Profile** (`{namespace}-prod-deploy`)
   - Used for production deployments
   - Full production permissions
   - Requires approval for operations

## IAM Permission Audit System

Permission changes are tracked via the IAM audit system:
- Location: `/infrastructure/iam-policies/{environment}-deploy-permissions.json`
- Maintains complete history of permission changes
- Allows drift detection
- Enables reproduction from audit files

## AWS Resource Naming Conventions

**S3 Buckets:**
- Lowercase only
- Hyphens allowed, no underscores
- 3-63 characters
- Globally unique

**Lambda Functions:**
- 1-64 characters
- Alphanumeric, hyphens, underscores

**IAM Roles/Users:**
- 1-64 characters
- Alphanumeric, hyphens, underscores, plus signs

**CloudWatch Log Groups:**
- Format: `/aws/{service}/{resource}-{environment}`
- Example: `/aws/lambda/build-trigger-test`

## Error Handling

Common AWS errors and resolutions:

**AccessDenied:**
- Check AWS profile is correct
- Verify credentials haven't expired
- Use `/devops:permissions` to add missing permissions

**Profile Not Found:**
- Run `aws configure --profile {profile-name}`
- Update `.fractary/.config/devops.json` with correct profile names

**Invalid Credentials:**
- Run `aws configure --profile {profile-name}`
- Check AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY

## See Also

- [AWS Configuration Guide](/docs/guides/aws-configuration-guide.md)
- [IAM Permission Audit System](/infrastructure/iam-policies/README.md)
- [Fractary DevOps Plugin Spec](/docs/specs/fractary-devops-plugin-spec.md)
