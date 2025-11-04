# IAM Permission Audit System

Complete audit trail for all deploy user IAM permissions.

## Purpose

Track all IAM permission changes for deploy users with full traceability:
- When permissions were added
- Why they were added
- Who requested them
- Complete audit trail

## Files

- `test-deploy-permissions.json` - Test environment deploy user permissions
- `staging-deploy-permissions.json` - Staging environment deploy user permissions
- `prod-deploy-permissions.json` - Production environment deploy user permissions

## Audit File Schema

Each file contains:
- Current IAM policy (JSON format matching AWS IAM policy structure)
- Complete audit trail with timestamps
- Metadata (environment, deploy user, policy ARN)

## Scripts

Located in: `plugins/faber-cloud/skills/infra-permission-manager/scripts/audit/`

### update-audit.sh

Record permission changes:
```bash
./update-audit.sh <env> <actions> <reason>
```

Example:
```bash
./update-audit.sh test "lambda:CreateFunction,lambda:UpdateFunctionCode" "Deployment requires Lambda management"
```

### sync-from-aws.sh

Pull current AWS IAM state:
```bash
./sync-from-aws.sh <env>
```

Shows differences between audit file and actual AWS state.

### apply-to-aws.sh

Apply audit file permissions to AWS:
```bash
./apply-to-aws.sh <env>
```

Applies permissions from audit file to actual AWS IAM policy.

### diff-audit-aws.sh

Compare audit vs AWS:
```bash
./diff-audit-aws.sh <env>
```

Shows differences in readable format.

## Deploy vs Resource Permissions

**CRITICAL**: This system ONLY manages deploy user permissions, NOT resource permissions.

### ✅ Deploy User Permissions (Managed Here)

Infrastructure operations during deployment:
- Terraform state access (S3, DynamoDB)
- Resource creation/updates (Lambda, S3, API Gateway, etc.)
- IAM role creation/attachment
- CloudWatch log group creation
- VPC and networking setup

### ❌ Resource Permissions (Managed in Terraform)

Runtime operations by deployed applications:
- Lambda reading from S3 bucket → Use Terraform IAM role
- API Gateway invoking Lambda → Use Terraform resource policy
- Application logging to CloudWatch → Use Terraform IAM role

**If you request a resource permission**, the plugin will:
1. Reject the request
2. Explain the distinction
3. Provide Terraform example code

## Workflow

1. Plugin encounters permission error during deployment
2. infra-debugger identifies it as a permission issue
3. Delegates to infra-permission-manager
4. Permission-manager validates: Deploy user permission or resource permission?
5. If resource permission → Rejects with Terraform example
6. If deploy user permission:
   - Updates audit file
   - Records audit trail entry
   - Applies to AWS
   - Returns success

## Audit Trail

Each permission addition is recorded:

```json
{
  "timestamp": "2025-11-04T10:30:00Z",
  "operation": "add_permission",
  "description": "Added Lambda management permissions for deployment",
  "added_actions": ["lambda:CreateFunction", "lambda:UpdateFunctionCode"],
  "reason": "Deployment failed with AccessDenied for lambda:CreateFunction",
  "requested_by": "user@example.com"
}
```

## Best Practices

1. **Always sync before applying**: Run `diff-audit-aws.sh` before `apply-to-aws.sh`
2. **Review audit trail**: Check `audit_trail` array in JSON files regularly
3. **Use least privilege**: Only add permissions actually needed
4. **Document reasons**: Always provide clear reason when adding permissions
5. **Regular audits**: Review permissions quarterly, remove unused

## Security

- Deploy user permissions should follow least privilege principle
- Production permissions require additional approval
- All changes are audited and traceable
- Audit files should be committed to git for version control

## Setup

To initialize the IAM audit system for your project:

1. Copy these template files to your project's `infrastructure/iam-policies/` directory:
   ```bash
   cp -r plugins/faber-cloud/skills/infra-permission-manager/templates/iam-policies infrastructure/
   ```

2. Update each file with your AWS account details:
   - Replace `ACCOUNT_ID` with your AWS account ID
   - Update `policy_arn` with your actual policy ARN
   - Update `deploy_user` with your actual IAM user/role name

3. Commit the audit files to git:
   ```bash
   git add infrastructure/iam-policies/
   git commit -m "Initialize IAM permission audit system"
   ```

4. Configure your faber-cloud config with audit settings:
   ```json
   {
     "environments": {
       "test": {
         "aws_audit_profile": "test-deploy-discover",
         "iam_audit_file": "infrastructure/iam-policies/test-deploy-permissions.json"
       }
     }
   }
   ```
