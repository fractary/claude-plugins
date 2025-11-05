# IAM Health Audit Workflow

**Check Type**: iam-health
**Expected Duration**: 3-5 seconds
**Purpose**: Verify IAM users, roles, and permissions are healthy

## Workflow Steps

### 1. Load Configuration

```bash
# Get deployment profile for environment
profile=$(get_deployment_profile $env)  # e.g., myproject-infra-test-deploy
```

### 2. Check Deploy User Exists

```bash
aws iam get-user --user-name $profile --profile discover-deploy
```

Verify:
- ✅ User exists
- ✅ User has programmatic access
- ✅ Access keys are active
- ⚠️  Access keys not expired (>90 days old)

### 3. Check Deploy User Permissions

```bash
aws iam list-attached-user-policies --user-name $profile --profile discover-deploy
aws iam list-user-policies --user-name $profile --profile discover-deploy
```

Verify:
- ✅ Has required policies attached
- ✅ Can deploy to environment
- ⚠️  Not overprivileged (no AdministratorAccess unless prod)

### 4. Check Service Roles

Query deployed resources for IAM roles:

```bash
# Lambda functions
aws lambda list-functions --profile $profile | grep Role

# Check each role exists and is attached
for role in $roles; do
  aws iam get-role --role-name $role --profile $profile
done
```

Verify:
- ✅ All service roles exist
- ✅ Roles have trust policies configured
- ✅ Roles have required permissions
- ✅ No dangling role references

### 5. Check for Unused IAM Resources

```bash
# List all IAM resources in account
aws iam list-users --profile $profile
aws iam list-roles --profile $profile

# Cross-reference with deployed resources
# Identify IAM resources not referenced by infrastructure
```

Verify:
- ⚠️  Unused users (not referenced in Terraform)
- ⚠️  Unused roles (not attached to any resource)
- ⚠️  Orphaned policies

### 6. Check Least Privilege

For each role/user:
- ⚠️  Overly broad permissions (e.g., `s3:*` instead of specific actions)
- ⚠️  Resource wildcards (e.g., `Resource: "*"`)
- ⚠️  Unnecessary services granted

### 7. Generate Report

Format findings:

```markdown
#### ✅ IAM Health Check Passed
- Deploy user: {user_name} - Active
- Service roles: {count} roles, all healthy
- Access keys: Valid (created {days_ago} days ago)
- Permissions: Aligned with least privilege
- Unused resources: None

**OR if issues:**

#### ⚠️ IAM Health Issues Found
- Deploy user: {user_name} - ⚠️  Access key >90 days old
- Service roles: {count} roles
  - ❌ Lambda execution role missing trust policy
  - ✅ Other roles healthy
- Unused resources: 2 unused roles found
  - {role1}: Not referenced in Terraform
  - {role2}: Not attached to any resource
- Recommendations:
  1. Rotate access keys for deploy user
  2. Fix Lambda execution role trust policy
  3. Review and remove unused roles
```

### 8. Return Status

- Exit 0: All IAM resources healthy
- Exit 1: Warnings found (keys old, unused resources)
- Exit 2: Critical failures (missing roles, invalid permissions)

## Script Execution

Use: `scripts/audit-iam.sh --env={env}`

## Integration

**Pre-deployment**: Verify permissions before deploying
**Post-deployment**: Confirm roles created correctly
**Regular**: Weekly check for unused resources and key rotation
