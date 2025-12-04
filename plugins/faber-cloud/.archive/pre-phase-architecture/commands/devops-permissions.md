---
description: Manage IAM permissions for deploy users
model: claude-haiku-4-5
allowed-tools: Bash, Read, Write, Edit, Skill
---

# Manage Deploy User Permissions

Add, verify, or list IAM permissions for deployment users.

## Your Task

Manage IAM permissions by:

1. **Load Configuration**
   - Source config loader
   - Get user/policy naming patterns
   - Determine target environment

2. **Authenticate with Discover Profile**
   - Use discover profile (has IAM permissions)
   - Validate credentials
   - Switch to IAM management mode

3. **Execute Permission Operation**
   - `add` - Add permission to deploy user
   - `verify` - Check if permission exists
   - `list` - List all current permissions
   - `audit` - Show permission change history

4. **Update IAM Audit System**
   - Track permission changes
   - Record reason and context
   - Update audit JSON file
   - Apply to AWS IAM policy

## Command Arguments

```bash
/devops:permissions <action> [args]
```

**Actions:**

1. **Add Permission**
   ```bash
   /devops:permissions add <permission> <environment> [reason]
   ```
   - `permission` - IAM permission (e.g., `s3:PutBucketPolicy`)
   - `environment` - Target environment (test, prod)
   - `reason` - Why this permission is needed (optional)

2. **Verify Permission**
   ```bash
   /devops:permissions verify <permission> <environment>
   ```
   - Checks if permission already exists

3. **List Permissions**
   ```bash
   /devops:permissions list <environment>
   ```
   - Shows all current permissions for deploy user

4. **Show Audit History**
   ```bash
   /devops:permissions audit <environment>
   ```
   - Displays permission change history from audit file

## Workflow

### Add Permission

```bash
# 1. Load configuration
source skills/devops-common/scripts/config-loader.sh
load_devops_config

# 2. Authenticate with discover profile
source skills/devops-deployer/providers/aws/auth.sh
export AWS_PROFILE="$PROFILE_DISCOVER"
authenticate_provider "discover"

# 3. Add permission
source skills/devops-deployer/providers/aws/permissions.sh
add_deployment_permission "$permission" "$environment" "$reason"
```

The `add_deployment_permission` function will:
1. Resolve user/policy names from patterns
2. Switch to discover profile
3. Call IAM audit system script
4. Update audit JSON file
5. Apply to AWS IAM policy
6. Restore original profile

### Verify Permission

```bash
source skills/devops-deployer/providers/aws/permissions.sh
if verify_permission "$permission" "$environment"; then
    echo "✓ Permission exists: $permission"
else
    echo "❌ Permission missing: $permission"
fi
```

### List Permissions

```bash
source skills/devops-deployer/providers/aws/permissions.sh
list_permissions "$environment"
```

## IAM Audit System Integration

Permission changes are tracked in:
```
/infrastructure/iam-policies/{environment}-deploy-permissions.json
```

Audit entry format:
```json
{
  "timestamp": "2025-10-17T14:07:22Z",
  "action": "added",
  "permissions": ["s3:PutBucketPolicy"],
  "reason": "Required for bucket configuration during deployment",
  "terraform_error": "Error: User is not authorized to perform: s3:PutBucketPolicy",
  "added_by": "devops-permissions-skill"
}
```

## Output Format

### Add Permission Success

```
Adding deployment permission: s3:PutBucketPolicy
  User: corthuxa-core-test-deploy
  Policy: corthography-test-deploy-terraform

✓ Permission added to audit system
✓ IAM policy updated in AWS
✓ Permission change recorded

Permission: s3:PutBucketPolicy
Environment: test
Reason: Required for bucket configuration
```

### Verify Permission

```
Checking permission: ecr:DescribeRepositories
  User: corthuxa-core-test-deploy
  Policy: corthography-test-deploy-terraform

✓ Permission exists
```

### List Permissions

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

Total: 9 permissions
```

### Audit History

```
Permission Audit History: test environment

2025-10-17 14:07:22
  Action: added
  Permissions: ecr:DescribeRepositories
  Reason: Required for Terraform to read ECR repository state
  Added by: devops-permissions-skill

2025-10-16 09:23:45
  Action: added
  Permissions: sns:SetTopicAttributes
  Reason: Required for SNS topic configuration
  Added by: devops-debugger-skill
  Terraform Error: User is not authorized to perform: sns:SetTopicAttributes

2025-10-15 11:42:33
  Action: added
  Permissions: s3:*, lambda:*, dynamodb:*
  Reason: Initial deployment permissions
  Added by: manual
```

## Delegation from Other Skills

This command/skill is designed to be invoked by:

- `devops-debugger` - When permission errors detected during deployment
- `devops-deployer` - When proactively adding permissions before deployment
- User directly - For manual permission management

Example delegation from debugger:
```bash
# In devops-debugger skill
if is_permission_error "$error"; then
    permission=$(extract_permission_from_error "$error")

    # Invoke devops-permissions skill
    # Use Skill tool: Skill(command: "devops-permissions add $permission $environment")
fi
```

## Safety Considerations

### Discover Profile Usage

- Only use discover profile for IAM operations
- Never use for actual deployments
- Switch back to deploy profile after IAM changes
- Minimize time in discover profile

### Permission Scope

- Add only specific permissions needed
- Avoid wildcard permissions unless necessary
- Document reason for each permission
- Review audit history regularly

### Multi-Environment

- Test environment: More permissive, faster iteration
- Production environment: Require approval for new permissions
- Separate audit files per environment

## Error Handling

### Profile Not Found

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
⚠️  IAM audit script not found
  Adding permission directly to AWS without audit tracking

✓ Permission added to AWS
⚠️  Consider setting up IAM audit system for better tracking
```

## Related Commands

- `/devops:debug` - Debug deployment errors (may delegate here)
- `/devops:deploy` - Deploy infrastructure (may delegate here)
- `/devops:validate` - Validate permissions are correct

## Related Skills

- `devops-permissions` - Main permission management agent
- `devops-debugger` - Error analysis (delegates here)
- `devops-deployer` - Deployment orchestration (may delegate here)
