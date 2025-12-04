---
description: Deploy infrastructure to specified environment
model: claude-haiku-4-5
allowed-tools: Bash, Read, Skill
---

# Deploy Infrastructure

Deploy infrastructure to specified environment using configured provider and IaC tool.

## Your Task

Orchestrate infrastructure deployment by:

1. **Load Configuration**
   - Source `skills/devops-common/scripts/config-loader.sh`
   - Load `.fractary/.config/devops.json`
   - Validate configuration exists

2. **Determine Provider and IaC Tool**
   - Read `provider` from config (aws, gcp, azure)
   - Read `iac_tool` from config (terraform, pulumi, cdk)
   - Load appropriate plugins

3. **Authenticate with Provider**
   - Source `skills/devops-deployer/providers/{provider}/auth.sh`
   - Call `authenticate_provider(environment)`
   - Verify credentials valid

4. **Run IaC Workflow**
   - Source `skills/devops-deployer/iac-tools/{tool}/init.sh`
   - Source `skills/devops-deployer/iac-tools/{tool}/plan.sh`
   - Source `skills/devops-deployer/iac-tools/{tool}/apply.sh`
   - Execute: init → validate → plan → review → apply

5. **Handle Errors**
   - On failure: Parse errors with error-parser
   - Categorize: permission, configuration, resource, state
   - Delegate permission errors to `/devops:permissions`
   - Report configuration/resource errors for manual fix

## Command Arguments

```bash
/devops:deploy [environment] [options]
```

**Arguments:**
- `environment` - Target environment (test, prod, discover) - defaults to "test"

**Options:**
- `--auto-approve` - Skip interactive approval (for CI/CD)
- `--plan-only` - Generate plan without applying
- `--var-file=PATH` - Custom tfvars file path
- `--complete` - Auto-fix permission errors without prompting

## Workflow

### Standard Deployment

```bash
# 1. Load config
source skills/devops-common/scripts/config-loader.sh
load_devops_config

# 2. Authenticate
source skills/devops-deployer/providers/${PROVIDER}/auth.sh
authenticate_provider "$environment"

# 3. Initialize IaC tool
source skills/devops-deployer/iac-tools/${IAC_TOOL}/init.sh
terraform_init "$environment"  # or pulumi_init, etc.

# 4. Validate
source skills/devops-deployer/iac-tools/${IAC_TOOL}/validate.sh
validate_terraform_all "$environment"

# 5. Plan
source skills/devops-deployer/iac-tools/${IAC_TOOL}/plan.sh
terraform_plan "$environment" "$var_file"

# 6. Show plan
show_terraform_plan "$environment"

# 7. Prompt for approval (unless --auto-approve)
if [ "$auto_approve" != "true" ]; then
    read -p "Apply this plan? (yes/no): " response
    if [ "$response" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi

# 8. Apply
source skills/devops-deployer/iac-tools/${IAC_TOOL}/apply.sh
terraform_apply "$environment" "$auto_approve" "$var_file"

# 9. Success
echo "✓ Deployment complete"
terraform_output  # Show outputs
```

### Error Handling Workflow

```bash
# If terraform_apply fails:

# 1. Capture error output
error_output=$(terraform apply 2>&1 || true)

# 2. Parse errors
source skills/devops-deployer/iac-tools/${IAC_TOOL}/error-parser.sh
parse_terraform_error "$error_output"

# 3. Check for permission errors
if is_permission_error "$error_output"; then
    # Extract permission
    permission=$(extract_permission_from_error "$error_output")

    # Delegate to permissions skill
    # Use Skill tool to invoke managing-deploy-permissions
    # (or use /devops:permissions command)
fi

# 4. Report other errors for manual fix
```

## Plan-Only Mode

When `--plan-only` specified:

1. Run init → validate → plan
2. Display plan summary
3. Save plan file
4. Exit without applying

Usage:
```bash
/devops:deploy test --plan-only
```

## Auto-Approve Mode

When `--auto-approve` specified:

1. Skip interactive approval prompt
2. Apply plan automatically
3. Useful for CI/CD pipelines

Usage:
```bash
/devops:deploy prod --auto-approve
```

## Provider-Specific Behavior

### AWS

- Authenticate using AWS profile from config
- Profile pattern: `{namespace}-{environment}-deploy`
- Set `AWS_PROFILE` environment variable
- Validate credentials with `aws sts get-caller-identity`

### GCP

- Authenticate using `gcloud auth`
- Project from config: `gcp.project_id`
- Set `GOOGLE_APPLICATION_CREDENTIALS` if service account

### Azure

- Authenticate using `az login`
- Subscription from config: `azure.subscription_id`

## IaC Tool-Specific Behavior

### Terraform

Workflow: `init → validate → plan → apply`

Files:
- Config: `*.tf` files in `terraform.directory`
- Variables: `{environment}.tfvars`
- State: Managed by backend configuration

### Pulumi

Workflow: `login → stack select → preview → up`

Files:
- Config: `Pulumi.yaml` and `Pulumi.{stack}.yaml`
- Stack: `{namespace}-{environment}`

### CloudFormation

Workflow: `validate → create-change-set → execute-change-set`

Files:
- Template: `template.yaml` or `template.json`
- Parameters: `{environment}-parameters.json`

## Output Format

### Successful Deployment

```
=== DevOps Deployment ===
Environment: test
Provider: AWS (account: 123456789012)
IaC Tool: Terraform

✓ Configuration loaded
✓ Authenticated with AWS (profile: corthuxa-core-test-deploy)
✓ Terraform initialized
✓ Configuration validated

Terraform Plan Summary:
  CREATE: aws_s3_bucket.data
  CREATE: aws_lambda_function.processor
  UPDATE: aws_iam_role.lambda_role

Total changes: 3 to create, 1 to update, 0 to destroy

Apply this plan? (yes/no): yes

Applying changes...
✓ Terraform apply successful

Outputs:
  bucket_name = "corthuxa-test-data"
  lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:processor-test"

✓ Deployment complete
```

### Deployment with Errors

```
=== DevOps Deployment ===
Environment: test
Provider: AWS
IaC Tool: Terraform

✓ Configuration loaded
✓ Authenticated with AWS
✓ Terraform initialized
✓ Configuration validated
✓ Plan generated

Applying changes...
❌ Terraform apply failed

=== Error Analysis ===

Permission Errors (2):
  1. AccessDenied: User corthuxa-core-test-deploy is not authorized to perform: ecr:DescribeRepositories
  2. AccessDenied: User corthuxa-core-test-deploy is not authorized to perform: sns:SetTopicAttributes

Configuration Errors (1):
  3. ValidationError: Batch compute environment missing required field: subnets

---

Recommendation:
  → Permission errors detected. Delegate to /devops:permissions to add missing IAM permissions?
  → Configuration error requires manual fix in Terraform files

Fix permission errors? (yes/no):
```

## Environment Safety

### Test Environment
- Lower risk, safe for experimentation
- Auto-approve allowed
- Permissive error handling

### Production Environment
- High risk, requires caution
- MUST prompt for approval (ignore --auto-approve)
- Show detailed plan review
- Require explicit "yes" confirmation

```bash
if [ "$environment" = "prod" ]; then
    echo "⚠️  PRODUCTION DEPLOYMENT"
    echo ""
    show_terraform_plan "$environment"
    echo ""
    echo "⚠️  This will modify PRODUCTION infrastructure"
    read -p "Type 'yes' to confirm: " confirmation

    if [ "$confirmation" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi
fi
```

## Error Recovery

When deployment fails:

1. **Permission Errors**
   - Invoke `/devops:permissions add {permission} {environment}`
   - Retry deployment
   - Track changes in IAM audit system

2. **Configuration Errors**
   - Display error details
   - Show file location
   - Provide fix suggestions
   - User must manually fix and retry

3. **Resource Errors**
   - Check for existing resources
   - Suggest import or manual cleanup
   - User must resolve and retry

4. **State Errors**
   - Validate backend configuration
   - Check state lock
   - Suggest state recovery commands

## Related Skills

- `devops-deployer` - Main deployment orchestration agent
- `devops-debugger` - Error analysis and categorization
- `devops-permissions` - IAM permission management

## Related Commands

- `/devops:validate` - Validate configuration before deployment
- `/devops:status` - Show deployment status
- `/devops:permissions` - Manage IAM permissions
- `/devops:debug` - Debug deployment errors

## Implementation Notes

- MUST validate environment parameter (test, prod, discover)
- MUST authenticate before any IaC operations
- MUST show plan before apply (unless --plan-only)
- MUST handle errors gracefully with categorization
- SHOULD track deployment history
- SHOULD validate configuration exists before starting
