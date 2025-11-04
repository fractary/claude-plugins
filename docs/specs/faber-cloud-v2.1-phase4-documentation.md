# Phase 4: Documentation Updates - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 1-2 hours

## Overview

Update all documentation to reflect new naming, remove devops/ops references, and document new features (automated debugging, IAM audit system, environment safety validation).

## Documentation File Renames

### Specification Files

All `fractary-devops-*.md` files → `fractary-faber-cloud-*.md`

**Current Files** (in `plugins/faber-cloud/docs/specs/`):
- `fractary-devops-architecture.md` → `fractary-faber-cloud-architecture.md`
- `fractary-devops-configuration.md` → `fractary-faber-cloud-configuration.md`
- `fractary-devops-handlers.md` → `fractary-faber-cloud-handlers.md`
- `fractary-devops-workflows.md` → `fractary-faber-cloud-workflows.md`

**Actions**:
1. Rename each file
2. Update title headers inside files
3. Update cross-references between docs
4. Update references from other docs (README.md, CLAUDE.md)

---

## README.md Updates

**File**: `plugins/faber-cloud/README.md`

### Changes Required

#### 1. Title and Description

```markdown
# Before
# Fractary DevOps Plugin

Comprehensive cloud infrastructure and operations management plugin for Claude Code.

# After
# Fractary faber-cloud Plugin

Comprehensive cloud infrastructure lifecycle management plugin for Claude Code.

Focus: Infrastructure design, configuration, deployment, and teardown (FABER framework for cloud).
```

#### 2. Remove Operations References

**Current Section** (v2.0.0):
```markdown
## Breaking Changes in v2.0.0

**Operations Monitoring Removed**: ops-manager agent and all ops-* skills moved to helm-cloud plugin.
```

**Updated Section**:
```markdown
## What's New in v2.1.0

**Simplified Command Structure**: All commands renamed for clarity and Terraform alignment
- `devops-init` → `init`
- `architect` → `design`
- `engineer` → `configure`
- `preview` → `deploy-plan`
- `deploy` → `deploy-apply`
- `infra-manage` → `manage`

**New Commands**:
- `teardown` - Safely destroy infrastructure

**Enhanced Automation**:
- Automated error fixing with `--complete` flag on debug command
- IAM permission audit system with complete traceability
- Environment safety validation prevents multi-environment bugs

**Architecture Clarity**: Removed all "devops" naming for clear focus on infrastructure lifecycle.
```

#### 3. Update Quick Start

```markdown
# Before
/fractary-faber-cloud:devops-init
/fractary-faber-cloud:architect --feature "Add CloudWatch monitoring"
/fractary-faber-cloud:engineer
/fractary-faber-cloud:preview
/fractary-faber-cloud:deploy --env=test

# After
/fractary-faber-cloud:init
/fractary-faber-cloud:design "Add CloudWatch monitoring"
/fractary-faber-cloud:configure
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
```

#### 4. Add New Features Section

```markdown
## New Features in v2.1

### Automated Error Debugging

The `debug` command now supports automated error fixing:

```bash
# Interactive mode (default) - prompts before each fix
/fractary-faber-cloud:debug

# Automated mode - auto-fixes all errors and continues deployment
/fractary-faber-cloud:debug --complete
```

When deployment encounters errors, you'll be offered:
1. Run debug (interactive) - You control each fix step
2. Run debug --complete (automated) - Auto-fixes and continues deployment ⭐
3. Manual fix - Fix issues yourself

### IAM Permission Audit System

All IAM permission changes are now tracked with complete audit trails:

**Location**: `infrastructure/iam-policies/`

**Audit Files**:
- `test-deploy-permissions.json`
- `staging-deploy-permissions.json`
- `prod-deploy-permissions.json`

**Audit Scripts**:
```bash
# Update audit file with new permissions
./scripts/audit/update-audit.sh test "lambda:CreateFunction" "Deployment requires Lambda"

# Sync current AWS state to audit file
./scripts/audit/sync-from-aws.sh test

# Compare audit file vs actual AWS state
./scripts/audit/diff-audit-aws.sh test

# Apply audit file permissions to AWS
./scripts/audit/apply-to-aws.sh test
```

**Deploy vs Resource Permissions**:

✅ **Deploy User Permissions** (managed by plugin):
- Infrastructure operations during deployment
- Terraform state access, resource creation/updates
- Examples: `lambda:CreateFunction`, `s3:CreateBucket`

❌ **Resource Permissions** (managed in Terraform):
- Runtime operations by deployed applications
- Must be defined as IAM roles/policies in Terraform
- Examples: Lambda reading S3, API Gateway invoking Lambda

The plugin will reject resource permission requests and provide Terraform examples.

### Environment Safety Validation

Prevents common multi-environment deployment bugs:

**Validates**:
- Environment variable matches Terraform workspace
- AWS profile correct for environment
- No hardcoded values for wrong environment
- Backend configuration valid

**When**: Automatically run before every deployment

### Infrastructure Teardown

Safely destroy infrastructure with production safeguards:

```bash
# Destroy test environment
/fractary-faber-cloud:teardown --env=test

# Auto-approve for non-production (be careful!)
/fractary-faber-cloud:teardown --env=test --confirm
```

**Safety Features**:
- Automatic state backup before destruction
- Production requires 3 confirmations + typing environment name
- Post-destruction verification
- Documented in deployment history
```

#### 5. Update Commands Reference

```markdown
## Commands

### Lifecycle Commands

| Command | Description | Example |
|---------|-------------|---------|
| `init` | Initialize plugin configuration | `/fractary-faber-cloud:init` |
| `design` | Design infrastructure from requirements | `/fractary-faber-cloud:design "Add monitoring"` |
| `configure` | Generate IaC configuration files | `/fractary-faber-cloud:configure` |
| `validate` | Validate configuration files | `/fractary-faber-cloud:validate` |
| `test` | Run security and cost tests | `/fractary-faber-cloud:test` |
| `deploy-plan` | Preview deployment changes | `/fractary-faber-cloud:deploy-plan` |
| `deploy-apply` | Execute deployment | `/fractary-faber-cloud:deploy-apply --env=test` |
| `status` | Check deployment status | `/fractary-faber-cloud:status` |
| `resources` | Show deployed resources | `/fractary-faber-cloud:resources --env=test` |
| `debug` | Analyze and fix errors | `/fractary-faber-cloud:debug [--complete]` |
| `teardown` | Destroy infrastructure | `/fractary-faber-cloud:teardown --env=test` |
| `manage` | Unified workflow orchestrator | `/fractary-faber-cloud:manage <operation>` |

### Workflow Examples

**Full Deployment Workflow**:
```bash
/fractary-faber-cloud:design "Add CloudWatch monitoring for Lambda functions"
/fractary-faber-cloud:configure
/fractary-faber-cloud:validate
/fractary-faber-cloud:test
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-apply --env=test
```

**Error Recovery Workflow**:
```bash
# Deployment fails with errors
/fractary-faber-cloud:deploy-apply --env=test
# → Select Option 2: Run debug --complete
# → Errors auto-fixed, deployment continues automatically ✅
```

**Teardown Workflow**:
```bash
# Preview what will be destroyed
/fractary-faber-cloud:deploy-plan --destroy

# Execute destruction
/fractary-faber-cloud:teardown --env=test
```
```

#### 6. Update Architecture Section

```markdown
## Architecture

### Three-Layer Pattern

```
Commands (Entry Points)
   ↓
Agents (Workflow Orchestration)
   ↓
Skills (Task Execution)
```

### Agents

**cloud-director** (Natural Language Router):
- Parses natural language requests
- Routes to infra-manager with structured request
- **Never invokes skills directly**

**infra-manager** (Workflow Orchestrator):
- Orchestrates infrastructure lifecycle
- Invokes appropriate skills
- Handles error delegation chain
- Tracks progress with TodoWrite

### Skills

**Infrastructure Lifecycle**:
- `infra-designer` - Design solutions from requirements
- `infra-configurator` - Generate Terraform/IaC code
- `infra-validator` - Validate configurations
- `infra-tester` - Security scans, cost estimation
- `infra-planner` - Generate deployment plans (terraform plan)
- `infra-deployer` - Execute deployments (terraform apply)
- `infra-debugger` - Analyze and fix errors (with --complete automation)
- `infra-permission-manager` - Manage IAM with audit trails
- `infra-teardown` - Destroy infrastructure safely

**Handlers** (Provider Abstraction):
- `handler-iac-terraform` - Terraform operations
- `handler-hosting-aws` - AWS operations

**Utilities**:
- `cloud-common` - Shared configuration and utilities

### Error Delegation Chain

```
infra-deployer encounters error
  ↓
Presents 3 options to user
  ↓ (Option 2: automated)
infra-debugger (--complete flag)
  ↓ (Permission error detected)
infra-permission-manager
  ↓ (Updates audit file, applies to AWS)
Returns to infra-debugger
  ↓ (All errors fixed)
Returns to infra-deployer
  ↓
Deployment continues automatically ✅
```
```

#### 7. Update Configuration Section

```markdown
## Configuration

**Location**: `.fractary/plugins/faber-cloud/config/faber-cloud.json`

**Migration from v2.0**:
```bash
# Rename config file
mv .fractary/plugins/faber-cloud/config/devops.json \
   .fractary/plugins/faber-cloud/config/faber-cloud.json
```

### IAM Audit Configuration

**Setup**:
1. Create audit directory: `infrastructure/iam-policies/`
2. Initialize audit files for each environment
3. Configure AWS profiles in config:

```json
{
  "handlers": {
    "iac": {"active": "terraform"},
    "hosting": {"active": "aws"}
  },
  "environments": {
    "test": {
      "aws_profile": "test-deploy",
      "aws_audit_profile": "test-deploy-discover",
      "iam_audit_file": "infrastructure/iam-policies/test-deploy-permissions.json"
    },
    "prod": {
      "aws_profile": "prod-deploy",
      "aws_audit_profile": "prod-deploy-discover",
      "iam_audit_file": "infrastructure/iam-policies/prod-deploy-permissions.json"
    }
  }
}
```
```

#### 8. Add Troubleshooting Section

```markdown
## Troubleshooting

### Deployment Errors

**Automated Recovery**:
1. Let deployment run until it encounters errors
2. Select Option 2: "Run debug --complete"
3. Debugger auto-fixes all errors
4. Deployment continues automatically

**Common Error Categories**:
- **Permission Issues** → Delegated to infra-permission-manager, audit trail updated
- **Configuration Issues** → Terraform files auto-corrected
- **State Issues** → Resolution options presented
- **Resource Conflicts** → Resolution options presented

### IAM Permission Issues

**Check audit trail**:
```bash
cd infrastructure/iam-policies/
cat test-deploy-permissions.json | jq '.audit_trail'
```

**Sync with AWS**:
```bash
./scripts/audit/diff-audit-aws.sh test
```

**Apply missing permissions**:
```bash
./scripts/audit/apply-to-aws.sh test
```

### Environment Mismatch

If you see "Environment mismatch" error:
```
ERROR: Environment mismatch!
  ENV variable: test
  Terraform workspace: prod
```

**Fix**:
```bash
# Switch workspace to match ENV
terraform workspace select test
```

### Resource Permission Rejected

If the plugin rejects your permission request:

**Reason**: You're requesting a runtime/resource permission, not a deploy permission.

**Solution**: Define the permission in Terraform as an IAM role:

```hcl
resource "aws_iam_role" "lambda_role" {
  name = "my-function-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}
```
```

---

## New Documentation Files

### 1. deployment-history-template.md

**File**: `docs/infrastructure/deployments.md` (create template)

```markdown
# Deployment History

Complete audit trail of all infrastructure deployments and teardowns.

---

## Deployment: test - 2025-11-04T10:30:00Z

- **Environment**: test
- **Operation**: deploy-apply
- **Deployed by**: user@example.com
- **Resources created**: 15
- **Resources updated**: 2
- **Endpoints**:
  - API: https://api-test.example.com
  - Lambda: arn:aws:lambda:us-east-1:123456789012:function:my-function
- **Cost estimate**: $45.23/month
- **Deployment time**: 3m 42s
- **Status**: ✅ Success
- **Documentation**: infrastructure/DEPLOYED.md

---

## Teardown: test - 2025-11-04T14:15:00Z

- **Environment**: test
- **Destroyed by**: user@example.com
- **Resources removed**: 15
- **Cost savings**: $45.23/month
- **Reason**: Environment no longer needed for testing
- **State backup**: infrastructure/backups/tfstate-test-20251104-141500.backup
- **Status**: ✅ Complete
```

### 2. iam-audit-readme.md

**File**: `infrastructure/iam-policies/README.md` (create)

```markdown
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
```

---

## Implementation Checklist

### File Renames

- [ ] Rename `fractary-devops-architecture.md` → `fractary-faber-cloud-architecture.md`
- [ ] Rename `fractary-devops-configuration.md` → `fractary-faber-cloud-configuration.md`
- [ ] Rename `fractary-devops-handlers.md` → `fractary-faber-cloud-handlers.md`
- [ ] Rename `fractary-devops-workflows.md` → `fractary-faber-cloud-workflows.md`

### README.md Updates

- [ ] Update title and description
- [ ] Add "What's New in v2.1" section
- [ ] Update quick start examples
- [ ] Add automated debugging documentation
- [ ] Add IAM audit system documentation
- [ ] Add environment safety validation documentation
- [ ] Add teardown documentation
- [ ] Update commands reference table
- [ ] Update workflow examples
- [ ] Update architecture section
- [ ] Update configuration section
- [ ] Add troubleshooting section

### New Documentation Files

- [ ] Create `docs/infrastructure/deployments.md` template
- [ ] Create `infrastructure/iam-policies/README.md`

### Cross-Reference Updates

- [ ] Update references in CLAUDE.md (root)
- [ ] Update references in plugin.json
- [ ] Update references in all spec files
- [ ] Update references in command files
- [ ] Update references in agent files
- [ ] Update references in skill files

### Content Updates in Renamed Specs

**For each renamed spec file**:
- [ ] Update title header
- [ ] Replace "devops" → "faber-cloud" or "infrastructure"
- [ ] Replace "ops-manager" references with note about helm-cloud
- [ ] Update command names (architect→design, engineer→configure, etc.)
- [ ] Update agent names (devops-director→cloud-director)
- [ ] Update skill names (infra-architect→infra-designer, etc.)
- [ ] Update configuration file references (devops.json→faber-cloud.json)

## Testing

### Documentation Validation

- [ ] All internal links work
- [ ] All command examples execute correctly
- [ ] All code snippets are syntactically valid
- [ ] All references to old names updated
- [ ] No broken cross-references
- [ ] README.md renders correctly on GitHub

### Content Validation

- [ ] All new features documented
- [ ] Migration guide clear and complete
- [ ] Troubleshooting covers common scenarios
- [ ] Examples are accurate and tested

## Rollback Plan

If issues arise:

1. Git checkout original documentation files
2. Revert file renames
3. Document issues encountered
4. Revise specification before retry

## Next Phase

After Phase 4 completion, proceed to **Phase 5: Configuration Updates** (`faber-cloud-v2.1-phase5-configuration.md`)
