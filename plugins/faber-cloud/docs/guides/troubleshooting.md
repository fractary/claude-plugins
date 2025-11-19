# faber-cloud Troubleshooting Guide

This guide covers common issues, error messages, and solutions when using faber-cloud for infrastructure management.

## Table of Contents

1. [Adoption Issues](#adoption-issues)
2. [Environment Validation Errors](#environment-validation-errors)
3. [Deployment Failures](#deployment-failures)
4. [Hook Failures](#hook-failures)
5. [AWS Authentication Issues](#aws-authentication-issues)
6. [Terraform Errors](#terraform-errors)
7. [Configuration Issues](#configuration-issues)
8. [State Management Issues](#state-management-issues)
9. [Module Errors](#module-errors)
10. [Debugging Techniques](#debugging-techniques)

## Adoption Issues

### Issue: No Terraform Files Found

**Error Message:**
```
Error: No Terraform files discovered
Could not find *.tf files in project
```

**Cause:** Adoption script couldn't find Terraform files in expected locations.

**Solutions:**

1. **Verify Terraform files exist**:
   ```bash
   find . -name "*.tf" -type f
   ```

2. **Check directory structure**:
   ```bash
   ls -la terraform/
   # or
   ls -la infrastructure/
   ```

3. **Specify project root explicitly**:
   ```bash
   /fractary-faber-cloud:adopt --project-root=/path/to/terraform
   ```

4. **If using different directory name**, update search paths in discovery script.

### Issue: No AWS Profiles Found

**Error Message:**
```
Warning: No AWS profiles found matching project pattern
Adoption will continue but AWS configuration may need manual setup
```

**Cause:** No AWS CLI profiles configured or profiles don't match expected naming.

**Solutions:**

1. **Check existing profiles**:
   ```bash
   cat ~/.aws/config
   cat ~/.aws/credentials
   ```

2. **Create missing profiles**:
   ```bash
   aws configure --profile myapp-test
   aws configure --profile myapp-prod
   ```

3. **Adoption continues** - You can manually update `faber-cloud.json` after adoption:
   ```json
   {
     "environments": [
       {
         "name": "test",
         "aws_profile": "your-actual-profile-name"
       }
     ]
   }
   ```

### Issue: Adoption Selected Wrong Template

**Error Message:**
```
Warning: Auto-selected template may not match your expectations
Selected: flat
Expected: modular
```

**Cause:** Directory structure doesn't match expected patterns.

**Solutions:**

1. **For Modular Template**, ensure modules are in exact directory name:
   ```bash
   # Must be exactly "modules" (not "tf-modules" or "terraform-modules")
   mkdir terraform/modules
   mv terraform/my-modules/* terraform/modules/
   ```

2. **For Multi-Environment Template**, ensure environments directory:
   ```bash
   # Must be exactly "environments"
   mkdir terraform/environments
   mv terraform/test terraform/environments/
   mv terraform/prod terraform/environments/
   ```

3. **Re-run adoption** after restructuring:
   ```bash
   /fractary-faber-cloud:adopt
   ```

### Issue: Custom Agents Not Version Controlled

**Error Message:**
```
WARNING: 5 custom scripts are not version controlled
These scripts may be lost during migration
```

**Cause:** Custom scripts are not committed to git.

**Solutions:**

1. **Commit scripts before migration**:
   ```bash
   git add scripts/
   git commit -m "Add custom infrastructure scripts before faber-cloud migration"
   ```

2. **Or create backup**:
   ```bash
   mkdir -p .fractary/backup/scripts
   cp -r scripts/ .fractary/backup/scripts/
   ```

3. **Then re-run adoption**:
   ```bash
   /fractary-faber-cloud:adopt
   ```

## Environment Validation Errors

### Issue: Environment Mismatch Detected

**Error Message:**
```
ERROR: Environment mismatch detected
Requested: prod
Detected: test (from AWS profile)
```

**Cause:** Enhanced environment validation detected mismatch between requested environment and detected environment from profile/state/directory.

**Solutions:**

1. **Verify correct AWS profile is active**:
   ```bash
   aws configure list
   echo $AWS_PROFILE
   ```

2. **Check faber-cloud configuration**:
   ```bash
   cat .fractary/plugins/faber-cloud/faber-cloud.json | grep -A 5 "name.*prod"
   ```

3. **Ensure profile matches environment**:
   ```json
   {
     "environments": [
       {
         "name": "prod",
         "aws_profile": "myapp-prod"  // Must contain "prod"
       }
     ]
   }
   ```

4. **If intentional**, temporarily disable validation (NOT RECOMMENDED):
   ```json
   {
     "deployment": {
       "validation": {
         "enhanced_environment_detection": false
       }
     }
   }
   ```

### Issue: Workspace Mismatch

**Error Message:**
```
ERROR: Terraform workspace mismatch
Requested: prod
Current workspace: test
```

**Cause:** Terraform workspace doesn't match requested environment (Flat/Modular templates).

**Solutions:**

1. **Switch to correct workspace**:
   ```bash
   cd terraform/
   terraform workspace select prod
   ```

2. **Or let faber-cloud handle it** - ensure auto-switching enabled:
   ```json
   {
     "handlers": {
       "iac": {
         "terraform": {
           "auto_init": true,
           "auto_workspace_select": true
         }
       }
     }
   }
   ```

3. **Verify workspaces exist**:
   ```bash
   terraform workspace list
   ```

### Issue: tfvars File Not Found

**Error Message:**
```
ERROR: Variable file not found
Expected: ./terraform/prod.tfvars
```

**Cause:** Configuration references tfvars file that doesn't exist.

**Solutions:**

1. **Create missing tfvars file**:
   ```bash
   touch terraform/prod.tfvars
   # Add required variables
   ```

2. **Or update configuration** to reference correct file:
   ```json
   {
     "environments": [
       {
         "name": "prod",
         "terraform_vars": "production.tfvars"  // Use actual filename
       }
     ]
   }
   ```

3. **Check var_file_pattern** matches your naming:
   ```json
   {
     "terraform": {
       "var_file_pattern": "{environment}.tfvars"  // or "terraform.{environment}.tfvars"
     }
   }
   ```

### Issue: Directory Path Mismatch

**Error Message:**
```
ERROR: Directory path mismatch (Multi-Environment)
Expected: ./terraform/environments/prod
Current: ./terraform
```

**Cause:** Multi-environment template expects operation in environment-specific directory.

**Solutions:**

1. **Verify directory structure**:
   ```bash
   ls -la terraform/environments/
   # Should show: dev/ test/ staging/ prod/
   ```

2. **Ensure environment directories exist**:
   ```bash
   mkdir -p terraform/environments/prod
   ```

3. **Check environment configuration**:
   ```json
   {
     "environments": [
       {
         "name": "prod",
         "terraform_dir": "./terraform/environments/prod"  // Must match actual path
       }
     ]
   }
   ```

## Deployment Failures

### Issue: Terraform Init Failed

**Error Message:**
```
ERROR: terraform init failed
Error: Failed to get existing workspaces: state file is empty
```

**Cause:** Terraform backend or state is corrupted.

**Solutions:**

1. **Re-initialize Terraform**:
   ```bash
   cd terraform/
   rm -rf .terraform/
   terraform init
   ```

2. **Check backend configuration**:
   ```bash
   cat backend.tf
   # or check main.tf for terraform { backend } block
   ```

3. **For S3 backend**, verify bucket exists and is accessible:
   ```bash
   aws s3 ls s3://your-state-bucket/
   ```

4. **Check AWS credentials**:
   ```bash
   aws sts get-caller-identity --profile myapp-prod
   ```

### Issue: Terraform Plan Failed

**Error Message:**
```
ERROR: terraform plan failed
Error: Provider configuration not present
```

**Cause:** Provider not configured or credentials missing.

**Solutions:**

1. **Check provider configuration**:
   ```hcl
   # In terraform files
   provider "aws" {
     region = var.region
     profile = var.aws_profile  # or use environment variables
   }
   ```

2. **Verify AWS credentials**:
   ```bash
   aws configure list --profile myapp-prod
   ```

3. **Check required variables are set**:
   ```bash
   cat terraform/prod.tfvars
   # Should include: region, aws_profile, etc.
   ```

4. **Run plan manually to debug**:
   ```bash
   cd terraform/
   terraform plan -var-file=prod.tfvars
   ```

### Issue: Terraform Apply Failed

**Error Message:**
```
ERROR: terraform apply failed
Error: timeout while waiting for resource to be created
```

**Cause:** AWS resource creation timed out or failed.

**Solutions:**

1. **Check AWS service health**:
   ```bash
   # Visit: https://status.aws.amazon.com/
   ```

2. **Increase timeout** in resource definition:
   ```hcl
   resource "aws_db_instance" "main" {
     # ...
     timeouts {
       create = "60m"  # Increase from default
       update = "60m"
       delete = "60m"
     }
   }
   ```

3. **Check AWS service quotas**:
   ```bash
   aws service-quotas get-service-quota \
     --service-code ec2 \
     --quota-code L-1216C47A
   ```

4. **Review AWS CloudFormation events** (if using):
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name your-stack \
     --profile myapp-prod
   ```

5. **Check Terraform logs**:
   ```bash
   TF_LOG=DEBUG terraform apply -var-file=prod.tfvars 2>&1 | tee terraform-debug.log
   ```

### Issue: State Lock Error

**Error Message:**
```
ERROR: Error acquiring the state lock
Lock Info:
  ID: xxx-xxx-xxx
  Who: user@host
```

**Cause:** Another Terraform operation is in progress, or previous operation crashed without releasing lock.

**Solutions:**

1. **Wait for other operation to complete** (if legitimately running)

2. **Force unlock** (DANGEROUS - only if you're sure no other operation is running):
   ```bash
   terraform force-unlock xxx-xxx-xxx
   ```

3. **For DynamoDB state locks**, check lock table:
   ```bash
   aws dynamodb scan \
     --table-name terraform-locks \
     --profile myapp-prod
   ```

4. **Prevent future locks** by ensuring clean exits:
   - Don't kill Terraform processes
   - Use Ctrl+C gracefully
   - Enable rollback on failures

## Hook Failures

### Issue: Hook Timeout

**Error Message:**
```
ERROR: Hook timed out
Hook: build-lambdas
Timeout: 300s
```

**Cause:** Hook exceeded configured timeout.

**Solutions:**

1. **Increase timeout**:
   ```json
   {
     "hooks": {
       "pre_deploy": [
         {
           "name": "build-lambdas",
           "command": "bash ./scripts/build-lambdas.sh {{environment}}",
           "timeout": 600  // Increase from 300
         }
       ]
     }
   }
   ```

2. **Optimize hook script** to run faster:
   ```bash
   # Add parallel execution
   for func_dir in */; do
     build_function "$func_dir" &  # Run in background
   done
   wait  # Wait for all to complete
   ```

3. **Split into multiple hooks** if doing too much:
   ```json
   {
     "hooks": {
       "pre_deploy": [
         {"name": "build-lambdas", "command": "...", "timeout": 300},
         {"name": "build-layers", "command": "...", "timeout": 300}
       ]
     }
   }
   ```

### Issue: Critical Hook Failed

**Error Message:**
```
ERROR: Critical hook failed - deployment aborted
Hook: security-scan
Exit code: 1
```

**Cause:** Hook marked as critical returned non-zero exit code.

**Solutions:**

1. **Debug hook script**:
   ```bash
   bash -x ./scripts/security-scan.sh test
   # Review output for failure reason
   ```

2. **Check hook logs** in `.fractary/plugins/faber-cloud/deployments/{env}/logs/`

3. **Fix underlying issue** identified by hook:
   ```bash
   # Example: Security scan found vulnerabilities
   npm audit fix
   # Then retry deployment
   ```

4. **Temporarily make non-critical** (NOT RECOMMENDED for security hooks):
   ```json
   {
     "hooks": {
       "pre_deploy": [
         {
           "name": "security-scan",
           "critical": false  // Won't block deployment
         }
       ]
     }
   }
   ```

### Issue: Hook Command Not Found

**Error Message:**
```
ERROR: Hook command failed
bash: ./scripts/hook.sh: No such file or directory
```

**Cause:** Hook references script that doesn't exist.

**Solutions:**

1. **Verify script exists**:
   ```bash
   ls -la ./scripts/hook.sh
   ```

2. **Check script permissions**:
   ```bash
   chmod +x ./scripts/hook.sh
   ```

3. **Use absolute paths** in hooks:
   ```json
   {
     "hooks": {
       "pre_deploy": [
         {
           "command": "bash $PWD/scripts/hook.sh {{environment}}"
         }
       ]
     }
   }
   ```

4. **Create missing script**:
   ```bash
   mkdir -p scripts
   touch scripts/hook.sh
   chmod +x scripts/hook.sh
   ```

### Issue: Hook Template Variable Not Resolved

**Error Message:**
```
ERROR: Hook failed
./scripts/hook.sh: line 5: {{environment}}: command not found
```

**Cause:** Template variables not being substituted properly.

**Solutions:**

1. **Check template variable syntax**:
   ```json
   {
     "hooks": {
       "pre_deploy": [
         {
           "command": "bash ./scripts/hook.sh {{environment}}"  // Correct
           // NOT: {environment} or ${environment}
         }
       ]
     }
   }
   ```

2. **Available template variables**:
   - `{{environment}}` - Environment name (test, prod)
   - `{{aws_profile}}` - AWS profile for environment
   - `{{terraform_dir}}` - Terraform directory path
   - `{{project}}` - Project name

3. **Use environment variables as fallback**:
   ```bash
   # In hook script
   ENVIRONMENT="${1:-${FABER_ENVIRONMENT:-test}}"
   ```

## AWS Authentication Issues

### Issue: AWS Credentials Not Found

**Error Message:**
```
ERROR: Unable to locate credentials
You can configure credentials with `aws configure`
```

**Cause:** AWS credentials not configured for specified profile.

**Solutions:**

1. **Configure AWS profile**:
   ```bash
   aws configure --profile myapp-prod
   # Enter: Access Key ID, Secret Access Key, Region
   ```

2. **Verify credentials file**:
   ```bash
   cat ~/.aws/credentials
   # Should show [myapp-prod] section
   ```

3. **Use environment variables** (alternative):
   ```bash
   export AWS_ACCESS_KEY_ID="..."
   export AWS_SECRET_ACCESS_KEY="..."
   export AWS_DEFAULT_REGION="us-east-1"
   ```

4. **Check profile name matches configuration**:
   ```bash
   grep aws_profile .fractary/plugins/faber-cloud/faber-cloud.json
   ```

### Issue: AWS Access Denied

**Error Message:**
```
ERROR: AccessDenied
User is not authorized to perform: ec2:CreateVpc
```

**Cause:** IAM permissions insufficient for operation.

**Solutions:**

1. **Review required permissions** for resources being created

2. **Check IAM user/role policy**:
   ```bash
   aws iam get-user-policy \
     --user-name deploy-user \
     --policy-name deploy-policy \
     --profile myapp-prod
   ```

3. **Add missing permissions** to IAM policy:
   ```json
   {
     "Statement": [
       {
         "Effect": "Allow",
         "Action": [
           "ec2:CreateVpc",
           "ec2:CreateSubnet",
           "ec2:CreateInternetGateway"
         ],
         "Resource": "*"
       }
     ]
   }
   ```

4. **Use least-privilege approach** - only grant necessary permissions

5. **Test permissions**:
   ```bash
   aws ec2 describe-vpcs --profile myapp-prod
   ```

### Issue: AssumeRole Failed

**Error Message:**
```
ERROR: AssumeRole failed
User is not authorized to perform: sts:AssumeRole on resource
```

**Cause:** Cannot assume role specified in AWS profile.

**Solutions:**

1. **Check role ARN** in profile:
   ```bash
   cat ~/.aws/config
   # Look for role_arn in profile
   ```

2. **Verify trust relationship** on role:
   ```bash
   aws iam get-role --role-name DeployRole
   # Check trust policy allows your user
   ```

3. **Update trust policy** if needed:
   ```json
   {
     "Statement": [
       {
         "Effect": "Allow",
         "Principal": {
           "AWS": "arn:aws:iam::ACCOUNT:user/deploy-user"
         },
         "Action": "sts:AssumeRole"
       }
     ]
   }
   ```

4. **Test assume role manually**:
   ```bash
   aws sts assume-role \
     --role-arn arn:aws:iam::ACCOUNT:role/DeployRole \
     --role-session-name test
   ```

## Terraform Errors

### Issue: Terraform Version Mismatch

**Error Message:**
```
ERROR: Terraform version mismatch
Required: >= 1.0
Installed: 0.15.5
```

**Cause:** Installed Terraform version doesn't meet requirements.

**Solutions:**

1. **Upgrade Terraform**:
   ```bash
   # Using tfenv
   tfenv install 1.5.0
   tfenv use 1.5.0

   # Or download from terraform.io
   ```

2. **Update version constraint** if you cannot upgrade:
   ```json
   {
     "terraform": {
       "version": "0.15"  // Match your installed version
     }
   }
   ```

3. **Use Docker** for consistent Terraform version:
   ```bash
   docker run --rm -v $PWD:/workspace -w /workspace \
     hashicorp/terraform:1.5 init
   ```

### Issue: Provider Version Conflict

**Error Message:**
```
ERROR: Provider version conflict
Requested: aws ~> 5.0
Locked: 4.67.0
```

**Cause:** Provider version in lock file doesn't match requirements.

**Solutions:**

1. **Update provider**:
   ```bash
   terraform init -upgrade
   ```

2. **Or delete lock file** and reinitialize:
   ```bash
   rm .terraform.lock.hcl
   terraform init
   ```

3. **Commit new lock file**:
   ```bash
   git add .terraform.lock.hcl
   git commit -m "Update provider lock file"
   ```

### Issue: Resource Already Exists

**Error Message:**
```
ERROR: Resource already exists
VPC vpc-12345 already exists
```

**Cause:** Attempting to create resource that already exists in AWS.

**Solutions:**

1. **Import existing resource**:
   ```bash
   terraform import aws_vpc.main vpc-12345
   ```

2. **Or use data source** to reference existing resource:
   ```hcl
   data "aws_vpc" "existing" {
     id = "vpc-12345"
   }
   ```

3. **Remove resource from Terraform** if should not be managed:
   ```bash
   terraform state rm aws_vpc.main
   ```

## Configuration Issues

### Issue: Invalid Configuration Syntax

**Error Message:**
```
ERROR: Invalid JSON in faber-cloud.json
Unexpected token at line 45
```

**Cause:** Syntax error in configuration file.

**Solutions:**

1. **Validate JSON syntax**:
   ```bash
   cat .fractary/plugins/faber-cloud/faber-cloud.json | jq .
   # Will show exact error location
   ```

2. **Common JSON errors**:
   - Trailing commas
   - Missing quotes
   - Unescaped characters
   - Missing brackets

3. **Use JSON validator online** or in editor (VS Code, etc.)

4. **Regenerate configuration** if severely broken:
   ```bash
   /fractary-faber-cloud:adopt
   # Review generated config before installing
   ```

### Issue: Required Field Missing

**Error Message:**
```
ERROR: Configuration validation failed
Missing required field: environments[0].aws_profile
```

**Cause:** Configuration missing required fields.

**Solutions:**

1. **Add missing field**:
   ```json
   {
     "environments": [
       {
         "name": "prod",
         "aws_profile": "myapp-prod",  // Add this
         "terraform_dir": "./terraform"
       }
     ]
   }
   ```

2. **Validate against schema**:
   ```bash
   # Use generated validation script
   bash plugins/faber-cloud/skills/infra-adoption/scripts/validate-generated-config.sh \
     .fractary/plugins/faber-cloud/faber-cloud.json
   ```

3. **Reference example configurations**:
   ```bash
   cat plugins/faber-cloud/skills/infra-adoption/templates/config-flat-terraform.json
   ```

## State Management Issues

### Issue: State Drift Detected

**Error Message:**
```
WARNING: State drift detected
Resources in AWS differ from Terraform state
```

**Cause:** Resources were modified outside of Terraform.

**Solutions:**

1. **Review drift**:
   ```bash
   terraform plan -detailed-exitcode
   # Exit code 2 = drift detected
   ```

2. **Refresh state**:
   ```bash
   terraform refresh -var-file=prod.tfvars
   ```

3. **Import manual changes** if intentional:
   ```bash
   terraform import aws_security_group.main sg-12345
   ```

4. **Apply to reconcile**:
   ```bash
   terraform apply -var-file=prod.tfvars
   ```

5. **Use audit regularly** to catch drift early:
   ```bash
   /fractary-faber-cloud:audit --env=prod --check=drift
   ```

### Issue: State Corruption

**Error Message:**
```
ERROR: State file appears to be corrupt
Error: state snapshot was created by Terraform v1.3, which is newer than current v1.0
```

**Cause:** State file created with newer Terraform version or corrupted.

**Solutions:**

1. **Restore from backup**:
   ```bash
   # For S3 backend
   aws s3 cp s3://bucket/terraform.tfstate.backup ./terraform.tfstate

   # For local backend
   cp terraform.tfstate.backup terraform.tfstate
   ```

2. **Upgrade Terraform** if version mismatch:
   ```bash
   tfenv install 1.3.0
   tfenv use 1.3.0
   ```

3. **Pull fresh state** (if using remote backend):
   ```bash
   terraform state pull > terraform.tfstate
   ```

4. **Last resort - rebuild state**:
   ```bash
   # Remove all resources from state
   terraform state list | xargs -n 1 terraform state rm
   # Re-import all resources
   terraform import aws_vpc.main vpc-12345
   # ... for each resource
   ```

## Module Errors

### Issue: Module Not Found

**Error Message:**
```
ERROR: Module not found
Could not find module: ./modules/networking
```

**Cause:** Module path doesn't exist or is incorrect.

**Solutions:**

1. **Verify module path**:
   ```bash
   ls -la terraform/modules/networking/
   ```

2. **Check relative paths** in multi-environment setup:
   ```hcl
   # In environments/prod/main.tf
   module "networking" {
     source = "../../modules/networking"  // Two levels up
   }
   ```

3. **Update module source** in configuration:
   ```json
   {
     "terraform": {
       "modules_directory": "./terraform/modules"  // Correct path
     }
   }
   ```

4. **Initialize modules**:
   ```bash
   terraform get
   terraform init
   ```

### Issue: Module Output Not Available

**Error Message:**
```
ERROR: Reference to undeclared output value
module.networking.vpc_id
```

**Cause:** Module doesn't declare referenced output.

**Solutions:**

1. **Add output to module**:
   ```hcl
   # In modules/networking/outputs.tf
   output "vpc_id" {
     value = aws_vpc.main.id
   }
   ```

2. **Check output name spelling**:
   ```bash
   grep "output" modules/networking/outputs.tf
   ```

3. **Reinitialize after changes**:
   ```bash
   terraform init
   ```

### Issue: Module Version Conflict

**Error Message:**
```
ERROR: Module version conflict
Required: ~> 2.0
Available: 1.5.0
```

**Cause:** Module version constraint not satisfied.

**Solutions:**

1. **Update module source** to newer version:
   ```hcl
   module "networking" {
     source  = "terraform-aws-modules/vpc/aws"
     version = "~> 3.0"  // Update version
   }
   ```

2. **Or relax constraint** if compatible:
   ```hcl
   module "networking" {
     source  = "terraform-aws-modules/vpc/aws"
     version = ">= 1.5"  // Allow 1.5+
   }
   ```

3. **Update modules**:
   ```bash
   terraform init -upgrade
   ```

## Debugging Techniques

### Enable Verbose Logging

```bash
# Terraform debug logs
export TF_LOG=DEBUG
export TF_LOG_PATH=./terraform-debug.log

# AWS CLI debug
aws s3 ls --debug

# faber-cloud verbose mode
export FABER_CLOUD_DEBUG=1
```

### Check What faber-cloud Will Do

```bash
# Dry-run adoption
/fractary-faber-cloud:adopt --dry-run

# Preview deployment (plan only)
/fractary-faber-cloud:deploy-plan --env=test

# Audit without changes
/fractary-faber-cloud:audit --env=test --check=config-valid
```

### Inspect Configuration

```bash
# View current configuration
cat .fractary/plugins/faber-cloud/faber-cloud.json | jq .

# Validate configuration
bash plugins/faber-cloud/skills/infra-adoption/scripts/validate-generated-config.sh \
  .fractary/plugins/faber-cloud/faber-cloud.json

# Check environment detection
grep -A 5 "name.*prod" .fractary/plugins/faber-cloud/faber-cloud.json
```

### Review Deployment Logs

```bash
# Check recent deployment logs
ls -lt .fractary/plugins/faber-cloud/deployments/prod/logs/

# View last deployment
cat .fractary/plugins/faber-cloud/deployments/prod/logs/deploy-$(date +%Y%m%d)-*.log

# Check hook execution logs
cat .fractary/plugins/faber-cloud/deployments/prod/logs/hooks/*.log
```

### Test Components Individually

```bash
# Test AWS authentication
aws sts get-caller-identity --profile myapp-prod

# Test Terraform init
cd terraform/ && terraform init

# Test Terraform plan
terraform plan -var-file=prod.tfvars

# Test hook script directly
bash ./scripts/hooks/build-lambdas.sh prod

# Test environment validation
bash plugins/faber-cloud/skills/infra-validator/scripts/validate-environment.sh prod
```

### Use Audit Command

```bash
# Quick validation check (~2-3 seconds)
/fractary-faber-cloud:audit --env=prod --check=config-valid

# Security audit (~5-7 seconds)
/fractary-faber-cloud:audit --env=prod --check=security

# Drift detection (~5-10 seconds)
/fractary-faber-cloud:audit --env=prod --check=drift

# Full comprehensive audit (~20-30 seconds)
/fractary-faber-cloud:audit --env=prod --check=full
```

## Getting Help

### Review Documentation

- [GETTING-STARTED.md](../../GETTING-STARTED.md) - Initial setup guide
- [CONFIGURATION-TEMPLATES.md](./CONFIGURATION-TEMPLATES.md) - Template reference
- [HOOKS.md](./HOOKS.md) - Hook system guide
- [MIGRATION-FROM-CUSTOM-AGENTS.md](./MIGRATION-FROM-CUSTOM-AGENTS.md) - Migration guide

### Check Specifications

- [SPEC-00030-01](../../specs/SPEC-00030-01-faber-cloud-adoption-migration.md) - Adoption specification
- [SPEC-00030-02](../../specs/SPEC-00030-02-enhanced-environment-validation.md) - Validation specification
- [SPEC-00030-03](../../specs/SPEC-00030-03-infrastructure-discovery.md) - Discovery specification

### Debug Mode

Run commands with debug mode enabled:

```bash
export FABER_CLOUD_DEBUG=1
export TF_LOG=DEBUG

# Then run your command
/fractary-faber-cloud:deploy-execute --env=test
```

### Report Issues

If you encounter a bug:

1. **Collect information**:
   - Error message
   - Configuration file (redact sensitive data)
   - Terraform version: `terraform version`
   - AWS CLI version: `aws --version`
   - Debug logs

2. **Check if issue is known** in project issues

3. **Create minimal reproduction** if possible

4. **Open issue** with:
   - Clear description
   - Steps to reproduce
   - Expected vs actual behavior
   - Environment details

## Common Error Patterns

### Pattern: "Permission Denied"

**Usually caused by:**
- AWS IAM permissions insufficient
- Script file not executable (`chmod +x`)
- File ownership issues

**Debug checklist:**
1. Check IAM policy
2. Verify script permissions
3. Test command manually

### Pattern: "Not Found"

**Usually caused by:**
- Incorrect file paths
- Missing files
- Wrong directory
- Typo in configuration

**Debug checklist:**
1. Verify file exists: `ls -la path/to/file`
2. Check current directory: `pwd`
3. Review configuration paths
4. Check for typos

### Pattern: "Timeout"

**Usually caused by:**
- Hook taking too long
- AWS service slow
- Network issues
- Resource creation slow (RDS, etc.)

**Debug checklist:**
1. Increase timeout value
2. Check AWS service health
3. Optimize hook scripts
4. Check network connectivity

### Pattern: "Already Exists"

**Usually caused by:**
- Resource created manually
- Previous failed deployment
- State out of sync

**Debug checklist:**
1. Import existing resource
2. Use data source instead
3. Remove from state if shouldn't manage
4. Refresh state

## Prevention Best Practices

**Prevent issues before they happen:**

1. **Always test in test environment first**
2. **Use audit regularly** to catch drift and issues
3. **Enable enhanced validation** in configuration
4. **Use hooks** for pre-deployment checks
5. **Keep Terraform and providers updated**
6. **Commit state files to backup** (encrypted)
7. **Document custom changes** in runbooks
8. **Use least-privilege IAM** policies
9. **Enable rollback** in configuration
10. **Monitor deployments** with CloudWatch/Slack

## Quick Reference

| Issue | Quick Fix | Documentation |
|-------|-----------|---------------|
| No Terraform files | Check directory structure, use --project-root | [Adoption](#adoption-issues) |
| Environment mismatch | Verify AWS profile, check configuration | [Validation](#environment-validation-errors) |
| Deployment failed | Check logs, test Terraform manually | [Deployment](#deployment-failures) |
| Hook timeout | Increase timeout, optimize script | [Hooks](#hook-failures) |
| AWS access denied | Review IAM policies, add permissions | [AWS Auth](#aws-authentication-issues) |
| State lock | Wait or force-unlock carefully | [State](#state-management-issues) |
| Module not found | Check paths, use correct relative paths | [Modules](#module-errors) |

---

**Still stuck?** Enable debug mode and review logs carefully. Most issues have clear error messages when debug logging is enabled.
