---
description: Validate DevOps configuration and infrastructure setup
model: claude-haiku-4-5
allowed-tools: Bash, Read
---

# Validate DevOps Configuration

Validate DevOps configuration file, cloud provider credentials, and IaC tool setup.

## Your Task

Run comprehensive validation checks:

1. **Configuration File Validation**
   - Check `.fractary/.config/devops.json` exists
   - Validate JSON syntax
   - Verify required fields present
   - Check pattern syntax valid

2. **Provider Validation**
   - Validate cloud provider credentials
   - Check all configured profiles exist
   - Verify account access
   - Test authentication

3. **IaC Tool Validation**
   - Check IaC tool installed
   - Validate tool configuration
   - Verify directory structure
   - Check for required files

4. **Project Structure Validation**
   - Verify Terraform/IaC directory exists
   - Check for environment variable files
   - Validate naming patterns

## Command Arguments

```bash
/devops:validate [component]
```

**Arguments:**
- `component` - Specific component to validate (optional)
  - `config` - Configuration file only
  - `provider` - Cloud provider credentials only
  - `iac` - IaC tool setup only
  - `all` - Everything (default)

## Validation Workflow

```bash
# Load configuration
source skills/devops-common/scripts/config-loader.sh
load_devops_config

# Validate based on detected provider/tool
if [ "$PROVIDER" = "aws" ]; then
    source skills/devops-deployer/providers/aws/auth.sh
    validate_all_profiles
fi

if [ "$IAC_TOOL" = "terraform" ]; then
    source skills/devops-deployer/iac-tools/terraform/validate.sh
    validate_terraform_all "test"
fi
```

## Validation Checks

### Configuration File

```
✓ Configuration file exists: .fractary/.config/devops.json
✓ Valid JSON syntax
✓ Required fields present:
  - provider
  - iac_tool
  - project.name
  - project.namespace
✓ Pattern syntax valid:
  - {namespace}-{environment}-deploy
  - {project}-{environment}-deploy-terraform
```

### AWS Provider

```
✓ AWS CLI installed: v2.x.x
✓ AWS profiles configured:
  ✓ Discover: corthuxa-core-discover-deploy (valid)
  ✓ Test: corthuxa-core-test-deploy (valid)
  ✓ Prod: corthuxa-core-prod-deploy (valid)
✓ Account ID matches config: 123456789012
✓ Region configured: us-east-1
```

### Terraform

```
✓ Terraform installed: v1.x.x
✓ Terraform directory exists: ./infrastructure/terraform
✓ Terraform syntax valid
✓ Terraform files properly formatted
✓ Backend configured: s3
✓ Variable files found:
  - test.tfvars
  - prod.tfvars
✓ State accessible
```

## Error Reporting

### Configuration Errors

```
❌ Configuration file validation failed

Issues:
  1. Missing required field: project.namespace
  2. Invalid pattern syntax: {invalid-pattern}
  3. Provider not supported: unknown-provider

Fix:
  - Edit .fractary/.config/devops.json
  - Add missing fields
  - Fix pattern syntax
  - Use supported provider (aws, gcp, azure)
```

### Provider Errors

```
❌ AWS provider validation failed

Issues:
  1. AWS CLI not installed
  2. Profile not found: corthuxa-core-test-deploy
  3. Invalid credentials for profile: corthuxa-core-prod-deploy

Fix:
  - Install AWS CLI: https://aws.amazon.com/cli/
  - Configure profile: aws configure --profile corthuxa-core-test-deploy
  - Update credentials: aws configure --profile corthuxa-core-prod-deploy
```

### IaC Tool Errors

```
❌ Terraform validation failed

Issues:
  1. Terraform not installed
  2. Directory not found: ./infrastructure/terraform
  3. Syntax errors in configuration
  4. Variable file missing: test.tfvars

Fix:
  - Install Terraform: https://www.terraform.io/downloads
  - Create directory: mkdir -p infrastructure/terraform
  - Run: terraform validate
  - Create variable files for each environment
```

## Exit Codes

- `0` - All validations passed
- `1` - Configuration validation failed
- `2` - Provider validation failed
- `3` - IaC tool validation failed
- `4` - Multiple validation failures

## Related Commands

- `/devops:init` - Initialize configuration
- `/devops:status` - Show current status
- `/devops:deploy` - Deploy infrastructure
