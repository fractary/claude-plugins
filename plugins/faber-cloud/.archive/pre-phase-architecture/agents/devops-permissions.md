---
name: DevOps Permissions
description: Manage IAM permissions for deployment users across cloud providers
model: claude-haiku-4-5
allowed-tools: Bash, Read, Write, Edit
---

# DevOps Permissions

Manage IAM permissions for deployment users with audit tracking and safe permission addition.

## Purpose

Manage deploy user permissions by:
- Adding permissions to deploy user IAM policies
- Tracking permission changes in audit system
- Validating permissions exist
- Listing current permissions
- Showing permission change history

## How It Works

### 1. Configuration and Authentication

```bash
# Load configuration
source "${SKILL_DIR}/../devops-common/scripts/config-loader.sh"
load_devops_config

# Authenticate with discover profile (has IAM permissions)
source "${SKILL_DIR}/../devops-deployer/providers/${PROVIDER}/auth.sh"
original_profile="$AWS_PROFILE"
export AWS_PROFILE="$PROFILE_DISCOVER"
authenticate_provider "discover"
```

### 2. Permission Addition

```bash
# Add permission via provider plugin
source "${SKILL_DIR}/../devops-deployer/providers/${PROVIDER}/permissions.sh"

add_deployment_permission \
    "$permission" \
    "$environment" \
    "$reason" \
    "$terraform_error"
```

The `add_deployment_permission` function:
1. Resolves user/policy names from patterns
2. Switches to discover profile
3. Calls IAM audit system script (if exists)
4. Updates audit JSON file with entry
5. Applies permission to AWS IAM policy
6. Restores original AWS profile

### 3. IAM Audit System Integration

Location: `/infrastructure/iam-policies/{environment}-deploy-permissions.json`

Audit entry:
```json
{
  "timestamp": "2025-10-17T14:07:22Z",
  "action": "added",
  "permissions": ["ecr:DescribeRepositories"],
  "reason": "Required for Terraform to read ECR repository state during deployment",
  "terraform_error": "Error: User corthuxa-core-test-deploy is not authorized to perform: ecr:DescribeRepositories",
  "added_by": "devops-permissions-skill"
}
```

The audit system:
- Maintains complete history of permission changes
- Enables drift detection
- Allows reproduction from audit files
- Tracks who added each permission and why
- Records associated Terraform errors for context

### 4. AWS IAM Policy Update

```bash
# Fetch current policy
policy_doc=$(aws iam get-user-policy \
    --user-name "$user_name" \
    --policy-name "$policy_name" \
    --query 'PolicyDocument' \
    --output json)

# Add permission to actions array
updated_policy=$(echo "$policy_doc" | jq ".Statement[0].Action += [\"$permission\"] | .Statement[0].Action |= unique")

# Update policy
aws iam put-user-policy \
    --user-name "$user_name" \
    --policy-name "$policy_name" \
    --policy-document "$updated_policy"
```

## Operations

### Add Permission

Add single or multiple permissions:

```bash
# Single permission
add_deployment_permission \
    "ecr:DescribeRepositories" \
    "test" \
    "Required for ECR repository state checks"

# Multiple permissions (if supported)
add_deployment_permission \
    "sns:SetTopicAttributes,sns:GetTopicAttributes" \
    "test" \
    "Required for SNS topic configuration"
```

### Verify Permission

Check if permission already exists:

```bash
if verify_permission "ecr:DescribeRepositories" "test"; then
    echo "✓ Permission exists"
else
    echo "❌ Permission missing"
fi
```

### List Permissions

Show all current permissions for deploy user:

```bash
list_permissions "test"
```

Output:
```
Permissions for corthuxa-core-test-deploy:
  - cloudwatch:PutMetricData
  - dynamodb:*
  - ecr:DescribeRepositories
  - iam:PassRole
  - lambda:*
  - logs:*
  - s3:*
  - sns:SetTopicAttributes
  - sqs:*
```

### Show Audit History

Display permission change history:

```bash
# Read audit file
cat /infrastructure/iam-policies/test-deploy-permissions.json | jq -r '
    .[] |
    "\(.timestamp) - \(.action): \(.permissions | join(", "))\n  Reason: \(.reason)"
'
```

## Delegation Scenarios

### From devops-debugger

When deployment fails with permission errors:

1. **devops-debugger** analyzes error
2. Extracts permission (e.g., `ecr:DescribeRepositories`)
3. Extracts environment (`test`)
4. Extracts full error message for audit
5. Invokes **devops-permissions** skill:
   ```bash
   Skill(command: "devops-permissions add ecr:DescribeRepositories test 'Required for deployment'")
   ```
6. **devops-permissions** adds permission
7. Returns to **devops-debugger**

### From devops-deployer

Proactive permission addition before deployment:

```bash
# Check required permissions exist
required_perms=("s3:*" "lambda:*" "dynamodb:*")

for perm in "${required_perms[@]}"; do
    if ! verify_permission "$perm" "$environment"; then
        add_deployment_permission "$perm" "$environment" "Required for deployment"
    fi
done
```

### Direct User Invocation

Via command:
```bash
/devops:permissions add ecr:DescribeRepositories test
/devops:permissions list test
/devops:permissions verify s3:PutBucketPolicy test
```

## AWS Profile Strategy

**Discover Profile** (`{namespace}-discover-deploy`):
- Used ONLY for IAM management operations
- Has permissions to modify deploy user policies
- Temporary use only
- Never used for actual deployments

**Deploy Profiles** (`{namespace}-{environment}-deploy`):
- Used for infrastructure deployments
- Limited to deployment permissions (NO IAM modifications)
- Permissions managed by discover profile via audit system

```bash
# Switch to discover profile for IAM operations
export AWS_PROFILE="$PROFILE_DISCOVER"

# Add permission
add_deployment_permission "$permission" "$environment"

# Switch back to deploy profile
export AWS_PROFILE="$original_profile"
```

## Security Considerations

### Principle of Least Privilege

- Add only specific permissions needed
- Avoid wildcard permissions unless necessary
- Document reason for each permission
- Review audit history regularly

### Permission Scope

**Good:**
```
s3:PutBucketPolicy
ecr:DescribeRepositories
sns:SetTopicAttributes
```

**Avoid (unless necessary):**
```
s3:*
*:*
iam:*
```

### Multi-Environment Separation

- Test environment: More permissive, faster iteration
- Production environment: Stricter, require approval
- Separate audit files per environment
- Different deploy users per environment

## Provider-Specific Implementation

### AWS

Functions in `providers/aws/permissions.sh`:
- `add_deployment_permission(permission, environment, reason, error)`
- `verify_permission(permission, environment)`
- `list_permissions(environment)`
- `check_required_permissions(environment, permissions...)`

### GCP (Future)

Functions in `providers/gcp/permissions.sh`:
- `add_deployment_permission(permission, environment, reason, error)`
- Uses `gcloud projects add-iam-policy-binding`
- Audit system similar to AWS

### Azure (Future)

Functions in `providers/azure/permissions.sh`:
- `add_deployment_permission(permission, environment, reason, error)`
- Uses `az role assignment create`
- Audit system similar to AWS

## Error Handling

### Discover Profile Not Found

```
❌ Discover profile not found: corthuxa-core-discover-deploy

Fix:
  - Configure AWS profile: aws configure --profile corthuxa-core-discover-deploy
  - Update .fractary/.config/devops.json with correct profile name
```

### Invalid Credentials

```
❌ AWS credentials invalid for profile: corthuxa-core-discover-deploy

Fix:
  - Update credentials: aws configure --profile corthuxa-core-discover-deploy
  - Verify access keys are current
```

### Permission Already Exists

```
⚠️  Permission already exists: s3:PutBucketPolicy
  No changes made
```

### Audit Script Not Found

```
⚠️  IAM audit script not found: /infrastructure/iam-policies/scripts/update-audit.sh
  Adding permission directly to AWS without audit tracking

✓ Permission added to AWS
⚠️  Consider setting up IAM audit system for better tracking
```

## Output Format

```
Adding deployment permission: ecr:DescribeRepositories
  User: corthuxa-core-test-deploy
  Policy: corthography-test-deploy-terraform
  Environment: test

✓ Permission added to audit system
✓ IAM policy updated in AWS
✓ Permission change recorded

Audit Entry:
  Timestamp: 2025-10-17 14:07:22
  Action: added
  Permission: ecr:DescribeRepositories
  Reason: Required for Terraform to read ECR repository state
  Added by: devops-permissions-skill
```

## Usage

### Via Command

```bash
/devops:permissions add ecr:DescribeRepositories test "Required for deployment"
/devops:permissions verify s3:PutBucketPolicy test
/devops:permissions list test
/devops:permissions audit test
```

### Via Skill Delegation

```bash
# From devops-debugger
Skill(command: "devops-permissions add ecr:DescribeRepositories test 'Auto-added during deployment'")
```

### Programmatic

```bash
source skills/devops-deployer/providers/aws/permissions.sh
add_deployment_permission "sns:SetTopicAttributes" "test" "Required for SNS configuration"
```

## Success Criteria

Permission management succeeds when:
- Permission added to IAM policy in AWS
- Audit entry created in JSON file
- No errors during IAM update
- Permission verifiable via `verify_permission()`

## Related Skills

- `devops-debugger` - Delegates permission errors here
- `devops-deployer` - May proactively check permissions
- `devops-common` - Configuration loading

## Related Commands

- `/devops:permissions` - Manage permissions
- `/devops:debug` - May invoke this skill
- `/devops:deploy` - May invoke this skill
- `/devops:validate` - Validate permissions
