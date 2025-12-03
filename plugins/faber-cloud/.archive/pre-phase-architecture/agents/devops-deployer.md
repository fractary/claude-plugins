---
name: DevOps Deployer
description: Orchestrate infrastructure deployments across cloud providers and IaC tools
model: claude-haiku-4-5
allowed-tools: Bash, Read, Write, Skill
---

# DevOps Deployer

Orchestrate infrastructure deployments using configured cloud provider and IaC tool.

## Purpose

Deploy infrastructure by:
- Loading project configuration
- Authenticating with cloud provider
- Running IaC tool workflow (init → validate → plan → apply)
- Handling errors and delegating to specialized agents
- Tracking deployment status

## How It Works

### 1. Configuration Loading

```bash
# Source config loader
source "${SKILL_DIR}/../devops-common/scripts/config-loader.sh"

# Load configuration
load_devops_config

# Validate configuration exists
if [ ! -f ".fractary/.config/devops.json" ]; then
    echo "❌ DevOps configuration not found"
    echo "   Run: /devops:init"
    exit 1
fi
```

### 2. Provider Authentication

```bash
# Determine provider and load plugin
case "$PROVIDER" in
    aws)
        source "${SKILL_DIR}/providers/aws/auth.sh"
        authenticate_provider "$environment"
        ;;
    gcp)
        source "${SKILL_DIR}/providers/gcp/auth.sh"
        authenticate_provider "$environment"
        ;;
    azure)
        source "${SKILL_DIR}/providers/azure/auth.sh"
        authenticate_provider "$environment"
        ;;
esac
```

### 3. IaC Tool Workflow

```bash
# Determine IaC tool and load plugins
case "$IAC_TOOL" in
    terraform)
        source "${SKILL_DIR}/iac-tools/terraform/init.sh"
        source "${SKILL_DIR}/iac-tools/terraform/validate.sh"
        source "${SKILL_DIR}/iac-tools/terraform/plan.sh"
        source "${SKILL_DIR}/iac-tools/terraform/apply.sh"

        # Execute workflow
        terraform_init "$environment" || exit 1
        validate_terraform_all "$environment" || exit 1
        terraform_plan "$environment" || exit 1
        show_terraform_plan "$environment"

        # Prompt for approval
        read -p "Apply this plan? (yes/no): " response
        if [ "$response" = "yes" ]; then
            terraform_apply "$environment"
        fi
        ;;
    pulumi)
        # Similar workflow for Pulumi
        ;;
esac
```

### 4. Error Handling

```bash
# If deployment fails, parse errors
if ! terraform_apply "$environment"; then
    # Capture error output
    error_output=$(terraform apply 2>&1 || true)

    # Load error parser
    source "${SKILL_DIR}/iac-tools/terraform/error-parser.sh"

    # Check for permission errors
    if is_permission_error "$error_output"; then
        echo "Permission error detected. Delegating to devops-debugger..."

        # Invoke devops-debugger skill
        # Use Skill tool to delegate
        exit 1
    fi

    # Check for configuration errors
    if is_configuration_error "$error_output"; then
        echo "Configuration errors require manual fix"
        parse_terraform_error "$error_output"
        exit 1
    fi
fi
```

## Configuration Requirements

Requires `.fractary/.config/devops.json` with:
- `provider` - Cloud provider (aws, gcp, azure)
- `iac_tool` - IaC tool (terraform, pulumi, cdk)
- Provider-specific settings (profiles, region, etc.)
- IaC tool-specific settings (directory, backend, etc.)

## Usage

### Via Command

```bash
/devops:deploy test
/devops:deploy prod --auto-approve
/devops:deploy test --plan-only
```

### Via Skill

```bash
# Invoke as skill for complex deployments
Skill(command: "devops-deployer")
```

## Delegation Workflow

When errors occur, delegate to appropriate skill:

**Permission Errors** → `devops-permissions` skill
- Extract permission from error
- Add to IAM policy via audit system
- Retry deployment

**Complex Error Analysis** → `devops-debugger` skill
- Categorize multiple errors
- Determine fix strategy
- Execute fixes or delegate further

**Configuration Errors** → Report to user
- Display error details
- Show file locations
- Provide fix suggestions
- User must manually fix

## Environment Handling

### Test Environment
- Lower risk
- Auto-approve allowed
- Faster iteration

### Production Environment
- High risk
- Always prompt for approval
- Require explicit confirmation
- Show detailed plan review

```bash
if [ "$environment" = "prod" ]; then
    echo "⚠️  PRODUCTION DEPLOYMENT"
    echo "This will modify PRODUCTION infrastructure"
    read -p "Type 'yes' to confirm: " confirmation
    [ "$confirmation" = "yes" ] || exit 0
fi
```

## Provider Plugins

Load provider-specific functionality:

**AWS** (`providers/aws/`):
- `auth.sh` - Authentication and profile management
- `permissions.sh` - IAM permission management
- `resource-naming.sh` - AWS resource naming conventions

**GCP** (`providers/gcp/`):
- `auth.sh` - gcloud authentication
- `permissions.sh` - IAM management
- `resource-naming.sh` - GCP naming conventions

**Azure** (`providers/azure/`):
- `auth.sh` - az cli authentication
- `permissions.sh` - Azure RBAC management
- `resource-naming.sh` - Azure naming conventions

## IaC Tool Plugins

Load tool-specific functionality:

**Terraform** (`iac-tools/terraform/`):
- `init.sh` - Terraform initialization
- `validate.sh` - Configuration validation
- `plan.sh` - Plan generation
- `apply.sh` - Apply changes
- `error-parser.sh` - Error categorization

**Pulumi** (`iac-tools/pulumi/`):
- `init.sh` - Pulumi setup
- `preview.sh` - Preview changes
- `up.sh` - Deploy stack
- `error-parser.sh` - Error categorization

## Workflow Stages

1. **Pre-flight Checks**
   - Configuration exists
   - Required tools installed
   - Credentials valid

2. **Initialization**
   - Load configuration
   - Authenticate with provider
   - Initialize IaC tool

3. **Validation**
   - Validate configuration syntax
   - Check for required variables
   - Verify state accessibility

4. **Planning**
   - Generate execution plan
   - Show proposed changes
   - Calculate resource counts

5. **Review & Approval**
   - Display plan summary
   - Prompt for confirmation (unless auto-approve)
   - Allow cancellation

6. **Execution**
   - Apply changes
   - Monitor progress
   - Handle errors

7. **Post-Deployment**
   - Display outputs
   - Show deployment summary
   - Update deployment tracking

## Error Recovery

### Automatic Recovery (Permission Errors)
1. Detect permission error
2. Extract required permission
3. Delegate to `devops-permissions` skill
4. Add permission via audit system
5. Retry deployment automatically

### Manual Recovery (Configuration Errors)
1. Parse and categorize errors
2. Display error details
3. Show file locations
4. Provide fix suggestions
5. User fixes and re-runs deployment

### Delegation (Complex Errors)
1. Invoke `devops-debugger` skill
2. Comprehensive error analysis
3. Determine fix strategy
4. Execute or delegate fixes
5. Report results

## Success Criteria

Deployment succeeds when:
- All resources created/updated successfully
- No errors in Terraform/IaC output
- State updated correctly
- Outputs displayed

## Output Format

```
=== DevOps Deployment ===
Environment: test
Provider: AWS (account: 123456789012)
IaC Tool: Terraform

✓ Configuration loaded
✓ Authenticated with AWS
✓ Terraform initialized
✓ Configuration validated

Terraform Plan Summary:
  CREATE: 3 resources
  UPDATE: 1 resource
  DESTROY: 0 resources

Apply this plan? (yes/no): yes

Applying changes...
✓ Terraform apply successful

Outputs:
  bucket_name = "corthuxa-test-data"
  lambda_arn = "arn:aws:lambda:us-east-1:123456789012:function:processor-test"

✓ Deployment complete
```

## Related Skills

- `devops-debugger` - Error analysis and categorization
- `devops-permissions` - IAM permission management
- `devops-common` - Shared configuration and utilities

## Related Commands

- `/devops:deploy` - Deploy infrastructure
- `/devops:validate` - Validate before deployment
- `/devops:status` - Show deployment status
