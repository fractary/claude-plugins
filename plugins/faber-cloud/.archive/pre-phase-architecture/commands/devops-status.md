---
description: Show current DevOps configuration and deployment status
model: claude-haiku-4-5
allowed-tools: Bash, Read
---

# Show DevOps Status

Display current DevOps configuration, infrastructure state, and deployment status.

## Your Task

Show comprehensive status information:

1. **Configuration Status**
   - Load and display current config
   - Show project information
   - Display provider and IaC tool settings

2. **Provider Status**
   - Show active cloud provider
   - Display configured profiles/credentials
   - Show current authentication state

3. **Infrastructure Status**
   - Show Terraform/IaC state summary
   - List deployed resources (if any)
   - Display recent deployments

4. **Environment Status**
   - Show status for each environment (test, prod)
   - Display last deployment time
   - Show resource counts

## Command Arguments

```bash
/devops:status [environment] [options]
```

**Arguments:**
- `environment` - Specific environment to show (optional, default: all)

**Options:**
- `--verbose` - Show detailed information
- `--resources` - Include resource list
- `--config` - Show full configuration

## Output Format

### Standard Status

```
=== DevOps Status ===

Project: corthography
Namespace: corthuxa-core
Organization: corthos

Configuration:
  File: .fractary/.config/devops.json
  Provider: AWS
  IaC Tool: Terraform
  Status: ✓ Valid

AWS Provider:
  Account: 123456789012
  Region: us-east-1
  Profiles:
    ✓ Discover: corthuxa-core-discover-deploy
    ✓ Test: corthuxa-core-test-deploy
    ✓ Prod: corthuxa-core-prod-deploy
  Current: corthuxa-core-test-deploy

Terraform:
  Version: 1.5.7
  Directory: ./infrastructure/terraform
  Status: ✓ Initialized

Environments:
  Test:
    Last Deploy: 2025-10-17 14:23:45
    Resources: 12
    Status: ✓ Healthy

  Prod:
    Last Deploy: 2025-10-15 09:15:32
    Resources: 18
    Status: ✓ Healthy
```

### Verbose Status (--verbose)

```
=== DevOps Status (Verbose) ===

Configuration:
  File: .fractary/.config/devops.json
  Last Modified: 2025-10-17 10:30:15
  Size: 2.3 KB

  Project:
    Name: corthography
    Namespace: corthuxa-core
    Organization: corthos

  Provider: AWS
    Account ID: 123456789012
    Region: us-east-1
    Profiles:
      discover: corthuxa-core-discover-deploy (✓ valid)
      test: corthuxa-core-test-deploy (✓ valid)
      prod: corthuxa-core-prod-deploy (✓ valid)

  IaC Tool: Terraform
    Directory: ./infrastructure/terraform
    Version: 1.5.7
    Backend: s3
      Bucket: corthuxa-terraform-state
      Key: corthography/terraform.tfstate

  Resource Naming:
    Prefix: corthuxa
    Separator: -
    User Pattern: {namespace}-{environment}-deploy
    Policy Pattern: {project}-{environment}-deploy-terraform

Test Environment:
  Status: ✓ Deployed
  Last Deploy: 2025-10-17 14:23:45
  Resources: 12
    - S3 Buckets: 2
    - Lambda Functions: 4
    - DynamoDB Tables: 1
    - IAM Roles: 3
    - CloudWatch Log Groups: 2

  Permissions: 9
    - s3:*, lambda:*, dynamodb:*, ecr:DescribeRepositories, ...

  Recent Changes:
    2025-10-17 14:23: Applied terraform plan (3 resources created)
    2025-10-17 14:07: Added IAM permission: ecr:DescribeRepositories
    2025-10-16 11:42: Initial deployment
```

### Resource List (--resources)

```
Test Environment Resources:

S3 Buckets (2):
  - corthuxa-test-data
  - corthuxa-test-logs

Lambda Functions (4):
  - build-trigger-test
  - webhook-handler-test
  - data-processor-test
  - notification-sender-test

DynamoDB Tables (1):
  - corthuxa-builds-test

IAM Roles (3):
  - lambda-execution-test
  - build-service-test
  - webhook-role-test

CloudWatch Log Groups (2):
  - /aws/lambda/build-trigger-test
  - /aws/lambda/webhook-handler-test
```

### Configuration Only (--config)

```
=== DevOps Configuration ===

{
  "provider": "aws",
  "iac_tool": "terraform",
  "project": {
    "name": "corthography",
    "namespace": "corthuxa-core",
    "organization": "corthos"
  },
  "aws": {
    "account_id": "123456789012",
    "region": "us-east-1",
    "profiles": {
      "discover": "corthuxa-core-discover-deploy",
      "test": "corthuxa-core-test-deploy",
      "prod": "corthuxa-core-prod-deploy"
    },
    "iam": {
      "user_name_pattern": "{namespace}-{environment}-deploy",
      "policy_name_pattern": "{project}-{environment}-deploy-terraform"
    },
    "resource_naming": {
      "prefix": "corthuxa",
      "separator": "-"
    }
  },
  "terraform": {
    "directory": "./infrastructure/terraform",
    "var_file_pattern": "{environment}.tfvars",
    "backend": {
      "type": "s3",
      "bucket": "{namespace}-terraform-state",
      "key": "{project}/terraform.tfstate"
    }
  }
}
```

## Implementation

```bash
# Load configuration
source skills/devops-common/scripts/config-loader.sh
load_devops_config

# Show configuration
show_config

# Validate provider
if [ "$PROVIDER" = "aws" ]; then
    source skills/devops-deployer/providers/aws/auth.sh
    validate_all_profiles
fi

# Show IaC status
if [ "$IAC_TOOL" = "terraform" ]; then
    source skills/devops-deployer/iac-tools/terraform/validate.sh
    validate_terraform_state "$environment"

    # Get resource count
    cd "$TERRAFORM_DIR"
    resource_count=$(terraform state list 2>/dev/null | wc -l)
    echo "  Resources: $resource_count"
fi

# Show recent deployments (from audit files if available)
if [ -f "/infrastructure/iam-policies/${environment}-deploy-permissions.json" ]; then
    echo "Recent permission changes:"
    jq -r '.[-3:] | .[] | "  \(.timestamp): \(.permissions | join(", "))"' \
        "/infrastructure/iam-policies/${environment}-deploy-permissions.json"
fi
```

## Use Cases

### Quick Health Check

```bash
/devops:status
```

Shows overview of all environments and current configuration.

### Detailed Environment Review

```bash
/devops:status test --verbose --resources
```

Shows comprehensive information about test environment including all resources.

### Configuration Review

```bash
/devops:status --config
```

Displays full configuration file for review or troubleshooting.

### Pre-Deployment Check

```bash
/devops:status prod
```

Before deploying to production, check current state and last deployment.

## Related Commands

- `/devops:validate` - Validate configuration and setup
- `/devops:deploy` - Deploy infrastructure
- `/devops:permissions audit` - Show permission history
