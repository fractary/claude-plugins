# Phase 3: Skill Enhancements - faber-cloud v2.1

**Parent Spec**: `faber-cloud-v2.1-simplification.md`
**Estimated Effort**: 2-3 hours

## Overview

Rename skills to align with new command names and implement major enhancements from reference implementations (corthuxa.ai and corthovore.ai).

## Skill Renames

### 1. infra-architect → infra-designer

**Current Directory**: `plugins/faber-cloud/skills/infra-architect/`
**New Directory**: `plugins/faber-cloud/skills/infra-designer/`

**Files to Update**:
- Rename directory
- Update `SKILL.md` frontmatter
- Update skill invocation references in infra-manager

**Rationale**: Aligns with `/fractary-faber-cloud:design` command

---

### 2. infra-engineer → infra-configurator

**Current Directory**: `plugins/faber-cloud/skills/infra-engineer/`
**New Directory**: `plugins/faber-cloud/skills/infra-configurator/`

**Files to Update**:
- Rename directory
- Update `SKILL.md` frontmatter
- Update skill invocation references in infra-manager

**Rationale**: Aligns with `/fractary-faber-cloud:configure` command; "configurator" clearer than "engineer"

---

### 3. infra-previewer → infra-planner

**Current Directory**: `plugins/faber-cloud/skills/infra-previewer/`
**New Directory**: `plugins/faber-cloud/skills/infra-planner/`

**Files to Update**:
- Rename directory
- Update `SKILL.md` frontmatter
- Update skill invocation references in infra-manager

**Rationale**: Aligns with `/fractary-faber-cloud:deploy-plan` command; matches Terraform terminology

---

### 4. devops-common → cloud-common

**Current Directory**: `plugins/faber-cloud/skills/devops-common/`
**New Directory**: `plugins/faber-cloud/skills/cloud-common/`

**Files to Update**:
- Rename directory
- Update `SKILL.md` frontmatter
- Update all skill references to cloud-common
- Update config loading (devops.json → faber-cloud.json)

**Rationale**: Remove "devops" naming; plugin is "faber-cloud"

---

## Major Skill Enhancements

### 5. infra-debugger (ENHANCE)

**Directory**: `plugins/faber-cloud/skills/infra-debugger/` (no rename)

**Reference Implementation**: `core.corthuxa.ai/infrastructure-debugger`

#### New Features

**1. --complete Flag for Automated Fix-and-Continue**

Add support for fully automated error fixing that returns control to parent skill.

**Behavior**:
- **Without --complete**: Interactive mode (current behavior)
  - Show diagnosis
  - Prompt for approval before each fix
  - Wait for user confirmation

- **With --complete**: Automated mode (NEW)
  - Auto-fix all detected issues
  - No prompts or confirmations
  - Return control to parent skill (infra-deployer)
  - Parent skill continues deployment automatically

**Implementation in SKILL.md**:

```markdown
<INPUTS>
- errors: List of deployment errors (from infra-deployer or conversation history)
- complete: Boolean flag (--complete) for automated mode
- context: Deployment context (environment, resources, etc.)
</INPUTS>

<WORKFLOW>
1. Parse errors from input or conversation history
2. Categorize each error by type:
   - Permission Issues (IAM)
   - Configuration Issues (Terraform syntax, invalid values)
   - State Issues (locks, drift)
   - Resource Conflicts (already exists, name collision)

3. Create task list (TodoWrite) for each distinct issue

4. For each task:
   IF complete flag is TRUE:
     - Automatically apply fix without prompts
     - Document fix in task notes
   ELSE:
     - Show diagnosis
     - Show proposed fix
     - Prompt user for approval
     - Apply if approved

5. Delegate to specialized skills as needed:
   - Permission errors → infra-permission-manager
   - Other errors → handle directly

6. IF complete flag is TRUE:
     - Document all fixes applied
     - Return control to parent skill (infra-deployer)
     - Output: "All errors fixed. Returning to deployment."
   ELSE:
     - Wait for next instruction
</WORKFLOW>

<ERROR_CATEGORIES>
1. Permission Issues
   - IAM policy insufficient
   - Missing role permissions
   → Delegate to infra-permission-manager

2. Configuration Issues
   - Terraform syntax errors
   - Invalid resource values
   - Missing required arguments
   → Edit Terraform files directly

3. State Issues
   - State file locked
   - State drift detected
   - State file corrupted
   → Present resolution options to user

4. Resource Conflicts
   - Resource already exists
   - Name collision
   - Dependency conflict
   → Present resolution options to user
</ERROR_CATEGORIES>

<COMPLETE_FLAG_BEHAVIOR>
When --complete flag is TRUE:
- MUST auto-fix all fixable errors without prompts
- MUST return control to parent skill after completion
- MUST document all fixes in output
- MAY still prompt for unresolvable conflicts (state, resource conflicts)

When --complete flag is FALSE (default):
- Show diagnosis for each error
- Prompt for approval before each fix
- Wait for user input at each step
- Do NOT return to parent automatically
</COMPLETE_FLAG_BEHAVIOR>

<DELEGATION>
When encountering permission errors:
1. Extract IAM-related error details
2. Invoke infra-permission-manager:

Use the @skill-fractary-faber-cloud:infra-permission-manager to fix permission issue:
{
  "error": "{permission error details}",
  "environment": "{env}",
  "complete": {complete flag value}
}

3. Wait for permission-manager to complete
4. Continue with remaining errors
</DELEGATION>

<OUTPUTS>
🎯 STARTING: Infrastructure Debugger
Mode: {Interactive | Automated (--complete)}
Errors detected: {count}
───────────────────────────────────────

{... error analysis and fixes ...}

✅ COMPLETED: Infrastructure Debugger
Errors fixed: {count}
Fixes applied:
- {fix 1}
- {fix 2}
...

{IF complete flag:}
Returning control to infra-deployer to continue deployment.
{ELSE:}
Ready for next instruction.
───────────────────────────────────────
</OUTPUTS>
```

**New Scripts Required**:

Create `skills/infra-debugger/scripts/`:
- `parse-errors.sh` - Extract structured error data from Terraform output
- `categorize-error.sh` - Determine error category
- `apply-fix.sh` - Apply fix automatically (for --complete mode)

---

### 6. infra-permission-manager (ENHANCE)

**Directory**: `plugins/faber-cloud/skills/infra-permission-manager/` (no rename)

**Reference Implementation**: `core.corthuxa.ai/managing-deploy-permissions`

#### New Features

**1. IAM Permission Audit System**

Implement complete audit trail for all permission changes with JSON files and sync scripts.

**Directory Structure**:

```
infrastructure/
  iam-policies/
    test-deploy-permissions.json
    staging-deploy-permissions.json
    prod-deploy-permissions.json
    README.md
```

**Audit File Schema** (`{env}-deploy-permissions.json`):

```json
{
  "version": "1.0",
  "environment": "test",
  "deploy_user": "test-deploy",
  "last_updated": "2025-11-04T10:30:00Z",
  "policy_arn": "arn:aws:iam::123456789012:policy/test-deploy-policy",
  "permissions": {
    "Version": "2012-10-17",
    "Statement": [
      {
        "Sid": "TerraformStateAccess",
        "Effect": "Allow",
        "Action": [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ],
        "Resource": "arn:aws:s3:::terraform-state-bucket/*"
      },
      {
        "Sid": "LambdaManagement",
        "Effect": "Allow",
        "Action": [
          "lambda:CreateFunction",
          "lambda:UpdateFunctionCode",
          "lambda:DeleteFunction"
        ],
        "Resource": "*"
      }
    ]
  },
  "audit_trail": [
    {
      "timestamp": "2025-11-04T10:30:00Z",
      "operation": "add_permission",
      "description": "Added Lambda management permissions for deployment",
      "added_actions": ["lambda:CreateFunction", "lambda:UpdateFunctionCode"],
      "reason": "Deployment failed with AccessDenied for lambda:CreateFunction"
    }
  ]
}
```

**2. Audit Scripts**

Create `skills/infra-permission-manager/scripts/audit/`:

**update-audit.sh** - Record permission changes:
```bash
#!/bin/bash
# Updates audit file with new permission changes

ENV=$1
ACTIONS=$2
REASON=$3

AUDIT_FILE="infrastructure/iam-policies/${ENV}-deploy-permissions.json"

# Add entry to audit_trail array
# Update last_updated timestamp
# Merge new actions into permissions
```

**sync-from-aws.sh** - Pull current AWS IAM state:
```bash
#!/bin/bash
# Fetches current IAM policy from AWS and updates audit file

ENV=$1
PROFILE="${ENV}-deploy-discover"  # Read-only profile for auditing

# Get current policy from AWS
# Compare with audit file
# Show differences
# Option to update audit file
```

**apply-to-aws.sh** - Apply audit file to AWS:
```bash
#!/bin/bash
# Applies permissions from audit file to AWS IAM

ENV=$1
PROFILE="${ENV}-deploy-discover"  # Profile with IAM update permissions

AUDIT_FILE="infrastructure/iam-policies/${ENV}-deploy-permissions.json"

# Read permissions from audit file
# Apply to AWS IAM policy
# Verify application successful
```

**diff-audit-aws.sh** - Compare audit vs AWS:
```bash
#!/bin/bash
# Shows differences between audit file and actual AWS state

ENV=$1
PROFILE="${ENV}-deploy-discover"

# Fetch current AWS policy
# Compare with audit file
# Display differences in readable format
```

**3. Deploy vs Resource Permission Enforcement**

Add critical validation to prevent security boundary violations.

**Updated SKILL.md Section**:

```markdown
<CRITICAL_RULES>
1. ONLY manage deploy user permissions (infrastructure operations)
2. NEVER manage resource permissions (runtime operations)
3. ALL permission changes MUST be recorded in audit trail
4. Production permissions require additional approval
5. Always use appropriate AWS profile for environment
</CRITICAL_RULES>

<PERMISSION_TYPES>
✅ DEPLOY USER PERMISSIONS (OK to add)
- Infrastructure operations performed during deployment
- Examples:
  - Terraform state access (S3, DynamoDB)
  - Resource creation/updates (Lambda, API Gateway, S3 buckets)
  - IAM role creation/attachment
  - CloudWatch log group creation
  - VPC and networking setup

❌ RESOURCE PERMISSIONS (REJECT - use Terraform)
- Runtime operations performed by deployed applications
- Examples:
  - Lambda function reading from S3 bucket (use Terraform IAM role)
  - API Gateway invoking Lambda (use Terraform resource policy)
  - Application logging to CloudWatch (use Terraform IAM role)
  - Cross-service access (use Terraform IAM policies)

VALIDATION RULE:
If user requests permission for runtime/application behavior → REJECT
→ Explain: "This is a resource permission. Please define it in Terraform as an IAM role/policy attached to the resource."
</PERMISSION_TYPES>

<AUDIT_WORKFLOW>
1. Receive permission request
2. Validate: Deploy user permission or resource permission?
   - If resource permission → REJECT with explanation
   - If deploy user permission → Continue

3. Determine environment from context
4. Load audit file: infrastructure/iam-policies/{env}-deploy-permissions.json
5. Add requested permissions to audit file
6. Record in audit_trail with timestamp and reason
7. Apply to AWS using apply-to-aws.sh script
8. Verify application successful
9. Return success status
</AUDIT_WORKFLOW>

<SCRIPTS>
Audit System Scripts (skills/infra-permission-manager/scripts/audit/):

update-audit.sh <env> <actions> <reason>
  - Updates audit file with new permissions
  - Records audit trail entry

sync-from-aws.sh <env>
  - Fetches current AWS IAM policy
  - Shows differences from audit file
  - Options to update audit file

apply-to-aws.sh <env>
  - Applies audit file permissions to AWS
  - Uses {env}-deploy-discover profile

diff-audit-aws.sh <env>
  - Compares audit file vs actual AWS state
  - Shows differences in readable format
</SCRIPTS>

<ERROR_HANDLING>
If permission request is for resource (not deploy user):
1. Identify the resource type (Lambda, API Gateway, etc.)
2. Explain the distinction
3. Provide Terraform example:

```hcl
# Example: Lambda function reading S3 bucket
resource "aws_iam_role" "lambda_role" {
  name = "my-function-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "lambda.amazonaws.com"
      }
    }]
  })
}

resource "aws_iam_role_policy" "lambda_s3_access" {
  role = aws_iam_role.lambda_role.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = ["s3:GetObject", "s3:PutObject"]
      Resource = "arn:aws:s3:::my-bucket/*"
    }]
  })
}

resource "aws_lambda_function" "my_function" {
  function_name = "my-function"
  role = aws_iam_role.lambda_role.arn
  # ...
}
```

4. REJECT the request
</ERROR_HANDLING>

<OUTPUTS>
🎯 STARTING: IAM Permission Manager
Environment: {env}
Operation: {add/remove/sync}
───────────────────────────────────────

{... permission analysis ...}

✅ COMPLETED: IAM Permission Manager
Permissions updated: {count}
Audit file: infrastructure/iam-policies/{env}-deploy-permissions.json
Audit trail entry added: {timestamp}

Changes applied:
- {action 1}
- {action 2}
...

Verification: ✅ AWS policy updated successfully
───────────────────────────────────────
Next: Return to infra-debugger (or parent skill)
</OUTPUTS>
```

---

### 7. infra-deployer (ENHANCE)

**Directory**: `plugins/faber-cloud/skills/infra-deployer/` (no rename)

**Reference Implementation**: `core.corthuxa.ai/infrastructure-deployer`

#### New Features

**1. Environment Safety Validation**

Add pre-deployment validation to prevent multi-environment bugs.

**New Script**: `skills/infra-deployer/scripts/validate-plan.sh`

```bash
#!/bin/bash
# Validates deployment plan before execution
# Prevents common multi-environment deployment bugs

ENV=$1
WORKSPACE=$2

# Validate environment variable matches Terraform workspace
if [ "$ENV" != "$WORKSPACE" ]; then
  echo "ERROR: Environment mismatch!"
  echo "  ENV variable: $ENV"
  echo "  Terraform workspace: $WORKSPACE"
  exit 1
fi

# Validate required environment variables set
# Validate AWS profile matches environment
# Validate Terraform backend configuration
# Validate no hardcoded values for wrong environment

echo "✅ Environment safety validation passed"
exit 0
```

**2. TodoWrite Progress Tracking**

Add detailed progress tracking for 12-step deployment workflow.

**Updated SKILL.md Section**:

```markdown
<WORKFLOW>
Use TodoWrite to track deployment progress:

1. ⏳ Validate environment configuration
2. ⏳ Run environment safety validation
3. ⏳ Initialize Terraform
4. ⏳ Select Terraform workspace
5. ⏳ Validate Terraform configuration
6. ⏳ Generate deployment plan
7. ⏳ Review plan for safety
8. ⏳ Execute deployment (terraform apply)
9. ⏳ Verify resources created
10. ⏳ Run post-deployment tests
11. ⏳ Generate documentation
12. ⏳ Update deployment history

Mark each step in_progress → completed as you go.
</WORKFLOW>

<SAFETY_VALIDATION>
Before deployment (step 2):

1. Run validate-plan.sh script:
   - Validates ENV matches Terraform workspace
   - Validates AWS profile correct
   - Validates backend configuration
   - Checks for hardcoded environment values

2. If validation fails:
   - STOP immediately
   - Show validation errors
   - Do NOT proceed with deployment
   - Wait for user to fix issues

3. If validation passes:
   - Continue to terraform init (step 3)
</SAFETY_VALIDATION>

<ERROR_DELEGATION>
When deployment encounters errors during terraform apply (step 8):

1. STOP deployment immediately
2. Capture error output
3. Present user with 3 options:

   Option 1: Run debug (interactive mode)
   → Invoke infra-debugger without --complete
   → User controls each fix step
   → Deployment does NOT continue automatically

   Option 2: Run debug --complete (automated mode) [RECOMMENDED]
   → Invoke infra-debugger with --complete flag
   → Auto-fixes all errors
   → Returns control to infra-deployer
   → Deployment continues automatically from step 8

   Option 3: Manual fix
   → User fixes issues manually
   → Run deploy-apply again when ready

4. Wait for user selection
</ERROR_DELEGATION>

<COMPLETE_FLAG_INTEGRATION>
When infra-debugger returns (Option 2 selected):

1. Verify debugger marked as completed
2. Check if all errors fixed
3. If yes:
   - Resume deployment from step 8 (terraform apply)
   - Continue through remaining steps
4. If no:
   - Present options again
</COMPLETE_FLAG_INTEGRATION>

<STRUCTURED_OUTPUTS>
Return JSON output format:

{
  "success": true/false,
  "operation": "deploy-apply",
  "environment": "{env}",
  "results": {
    "resources_created": 15,
    "resources_updated": 3,
    "resources_destroyed": 0,
    "endpoints": [
      "https://api.example.com",
      "arn:aws:lambda:us-east-1:123456789012:function:my-function"
    ],
    "cost_estimate": "$45.23/month",
    "deployment_time": "3m 42s"
  },
  "artifacts": [
    "infrastructure/DEPLOYED.md",
    "infrastructure/terraform.tfstate",
    "docs/infrastructure/deployments.md"
  ],
  "errors": []
}
</STRUCTURED_OUTPUTS>

<POST_DEPLOYMENT>
After successful deployment (step 9):

1. Verify resources created:
   - Run terraform show
   - Check expected resources exist
   - Validate endpoints accessible

2. Generate documentation (step 11):
   - Update infrastructure/DEPLOYED.md
   - Document all resources created
   - Include endpoints and access information

3. Update deployment history (step 12):
   - Append to docs/infrastructure/deployments.md
   - Include: timestamp, environment, deployer, resources, cost
</POST_DEPLOYMENT>
```

---

### 8. infra-teardown (NEW SKILL)

**Directory**: `plugins/faber-cloud/skills/infra-teardown/` (create new)

**Purpose**: Safely destroy infrastructure with production safeguards.

**Files to Create**:
- `SKILL.md` - Skill definition
- `scripts/backup-state.sh` - Backup Terraform state before destruction
- `scripts/destroy.sh` - Execute terraform destroy
- `scripts/verify-removal.sh` - Verify all resources removed
- `scripts/document-teardown.sh` - Document destruction in history

**SKILL.md Content**:

```markdown
---
name: infra-teardown
description: Safely destroy infrastructure with production safeguards
---

# Infrastructure Teardown Skill

<CONTEXT>
You are the infra-teardown skill for destroying deployed infrastructure.

You handle terraform destroy operations with strict safety measures for production.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS backup Terraform state before destruction
2. Production requires 3 confirmations and typed environment name
3. NEVER use --confirm flag for production
4. Verify all resources removed after destruction
5. Document all teardowns in deployment history
</CRITICAL_RULES>

<INPUTS>
- environment: Environment to destroy (test, staging, prod)
- confirm: Boolean flag to skip confirmations (NEVER for production)
- resources: Optional list of specific resources to destroy
</INPUTS>

<WORKFLOW>
Use TodoWrite to track teardown progress:

1. ⏳ Validate environment exists
2. ⏳ Backup Terraform state
3. ⏳ Determine safety level (production vs non-production)
4. ⏳ Request confirmations
5. ⏳ Generate destruction plan
6. ⏳ Review plan with user
7. ⏳ Execute terraform destroy
8. ⏳ Verify resource removal
9. ⏳ Document teardown
10. ⏳ Clean up workspace

Mark each step in_progress → completed as you go.
</WORKFLOW>

<SAFETY_LEVELS>
Non-Production (test, staging):
- 1 confirmation required (unless --confirm flag)
- Standard timeout (10 minutes)
- Automatic if --confirm flag present

Production:
- 3 separate confirmations required
- User must type environment name to confirm
- Extended timeout (30 minutes)
- --confirm flag REJECTED
- Additional approval checkpoint after plan review
</SAFETY_LEVELS>

<TEARDOWN_WORKFLOW>
Step 1: Validate environment
- Check environment exists in Terraform
- Verify workspace exists
- Load environment configuration

Step 2: Backup state
- Run backup-state.sh script
- Copy terraform.tfstate to backup location
- Timestamp: infrastructure/backups/tfstate-{env}-{timestamp}.backup

Step 3: Determine safety level
IF environment is "prod" or "production":
  - Set safety_level = PRODUCTION
  - Require 3 confirmations
  - Reject --confirm flag
ELSE:
  - Set safety_level = NON_PRODUCTION
  - Require 1 confirmation (unless --confirm)

Step 4: Request confirmations
IF confirm flag is TRUE and safety_level is NON_PRODUCTION:
  - Skip confirmations
ELSE:
  - Show warning about destruction
  - Request confirmation(s) based on safety_level
  - For PRODUCTION: User must type environment name

Step 5: Generate destruction plan
- Run: terraform plan -destroy
- Show resources to be destroyed
- Show estimated cost savings

Step 6: Review plan
- Display destruction plan
- Highlight critical resources (databases, storage)
- Request final confirmation if PRODUCTION

Step 7: Execute terraform destroy
- Run destroy.sh script
- Stream output to user
- Handle errors (timeouts, resource dependencies)

Step 8: Verify removal
- Run verify-removal.sh script
- Check that all resources removed
- Query AWS to confirm deletion

Step 9: Document teardown
- Run document-teardown.sh script
- Append to docs/infrastructure/deployments.md:
  ```
  ## Teardown: {env} - {timestamp}
  - **Destroyed by**: {user}
  - **Resources removed**: {count}
  - **Cost savings**: ${amount}/month
  - **Reason**: {user-provided reason}
  - **State backup**: infrastructure/backups/tfstate-{env}-{timestamp}.backup
  ```

Step 10: Clean up workspace
- Remove Terraform workspace (optional)
- Clean up temporary files
- Archive configuration if requested
</TEARDOWN_WORKFLOW>

<SCRIPTS>
backup-state.sh <env>
  - Backs up current Terraform state
  - Returns: Backup file path

destroy.sh <env> [--auto-approve]
  - Executes terraform destroy
  - Streams output
  - Returns: Success status

verify-removal.sh <env>
  - Queries AWS for remaining resources
  - Compares against expected resources
  - Returns: Verification status

document-teardown.sh <env> <user> <resources> <cost_savings> <reason>
  - Appends teardown record to deployment history
  - Updates infrastructure documentation
</SCRIPTS>

<ERROR_HANDLING>
If destruction fails:
1. Show error output
2. Identify stuck resources (dependencies, protection)
3. Suggest resolution:
   - Remove resource protection
   - Manually delete dependent resources
   - Use terraform state rm to remove from state
4. Do NOT continue if critical resources remain

If verification fails (resources remain):
1. List remaining resources
2. Attempt manual cleanup
3. Document orphaned resources
4. Warn user about potential costs
</ERROR_HANDLING>

<OUTPUTS>
🎯 STARTING: Infrastructure Teardown
Environment: {env}
Safety Level: {PRODUCTION | NON_PRODUCTION}
───────────────────────────────────────

⚠️  WARNING: This will destroy all infrastructure in {env}!

Resources to be destroyed: {count}
Estimated cost savings: ${amount}/month

State backup: infrastructure/backups/tfstate-{env}-{timestamp}.backup

{... destruction progress ...}

✅ COMPLETED: Infrastructure Teardown
Environment: {env}
Resources destroyed: {count}
Cost savings: ${amount}/month

Verification: ✅ All resources removed from AWS

Documentation updated:
- docs/infrastructure/deployments.md

State backup available at:
- infrastructure/backups/tfstate-{env}-{timestamp}.backup
───────────────────────────────────────
Next: Infrastructure destroyed successfully
</OUTPUTS>

<COMPLETION_CRITERIA>
- State backed up successfully
- All confirmations received
- Terraform destroy executed
- All resources verified removed
- Teardown documented in history
- Workspace cleaned up
</COMPLETION_CRITERIA>
```

---

## Implementation Checklist

### Skill Renames

- [ ] Rename `infra-architect/` → `infra-designer/`
- [ ] Rename `infra-engineer/` → `infra-configurator/`
- [ ] Rename `infra-previewer/` → `infra-planner/`
- [ ] Rename `devops-common/` → `cloud-common/`
- [ ] Update all SKILL.md frontmatter names
- [ ] Update all skill invocation references in infra-manager

### infra-debugger Enhancements

- [ ] Add --complete flag support to SKILL.md
- [ ] Add COMPLETE_FLAG_BEHAVIOR section
- [ ] Add ERROR_CATEGORIES section
- [ ] Create `scripts/parse-errors.sh`
- [ ] Create `scripts/categorize-error.sh`
- [ ] Create `scripts/apply-fix.sh`
- [ ] Update WORKFLOW to handle automated mode
- [ ] Update OUTPUTS to show mode (Interactive | Automated)

### infra-permission-manager Enhancements

- [ ] Create `infrastructure/iam-policies/` directory
- [ ] Create audit file templates for each environment
- [ ] Create README.md in iam-policies/
- [ ] Create `scripts/audit/update-audit.sh`
- [ ] Create `scripts/audit/sync-from-aws.sh`
- [ ] Create `scripts/audit/apply-to-aws.sh`
- [ ] Create `scripts/audit/diff-audit-aws.sh`
- [ ] Add PERMISSION_TYPES section to SKILL.md
- [ ] Add AUDIT_WORKFLOW section to SKILL.md
- [ ] Add validation logic for deploy vs resource permissions

### infra-deployer Enhancements

- [ ] Create `scripts/validate-plan.sh`
- [ ] Add SAFETY_VALIDATION section to SKILL.md
- [ ] Add ERROR_DELEGATION section to SKILL.md
- [ ] Add COMPLETE_FLAG_INTEGRATION section to SKILL.md
- [ ] Add TodoWrite integration to WORKFLOW
- [ ] Add STRUCTURED_OUTPUTS section
- [ ] Add POST_DEPLOYMENT section
- [ ] Update WORKFLOW to show 12-step process

### infra-teardown New Skill

- [ ] Create `skills/infra-teardown/` directory
- [ ] Create `SKILL.md` with full content
- [ ] Create `scripts/backup-state.sh`
- [ ] Create `scripts/destroy.sh`
- [ ] Create `scripts/verify-removal.sh`
- [ ] Create `scripts/document-teardown.sh`
- [ ] Add infra-teardown routing to infra-manager
- [ ] Add teardown command (from Phase 1)

### cloud-common Updates

- [ ] Update config loading path (devops.json → faber-cloud.json)
- [ ] Update all references to devops-common in other skills
- [ ] Verify pattern resolution works with new skill names

## Testing

### Skill Rename Testing

```bash
# Test each renamed skill still works
/fractary-faber-cloud:design "Test feature"  # → infra-designer
/fractary-faber-cloud:configure              # → infra-configurator
/fractary-faber-cloud:deploy-plan            # → infra-planner
```

### infra-debugger Testing

```bash
# Test interactive mode (existing behavior)
/fractary-faber-cloud:debug

# Test automated mode (new --complete flag)
/fractary-faber-cloud:debug --complete

# Test delegation to permission-manager
# (trigger permission error, verify delegation works)
```

**Validation**:
- [ ] Interactive mode shows diagnosis and prompts
- [ ] Automated mode auto-fixes without prompts
- [ ] Automated mode returns to parent skill
- [ ] Delegation to permission-manager works
- [ ] Error categorization correct

### infra-permission-manager Testing

```bash
# Test audit system
cd infrastructure/iam-policies/
./update-audit.sh test "lambda:CreateFunction" "Deployment requires Lambda creation"
./sync-from-aws.sh test
./diff-audit-aws.sh test
./apply-to-aws.sh test

# Test deploy vs resource permission validation
# (request resource permission, verify rejection)
```

**Validation**:
- [ ] Audit files created correctly
- [ ] update-audit.sh adds entry to audit_trail
- [ ] sync-from-aws.sh fetches current AWS state
- [ ] diff-audit-aws.sh shows differences
- [ ] apply-to-aws.sh applies permissions
- [ ] Resource permission requests rejected with Terraform example

### infra-deployer Testing

```bash
# Test environment safety validation
ENV=test WORKSPACE=prod /fractary-faber-cloud:deploy-apply --env=test
# Should fail with mismatch error

# Test TodoWrite tracking
/fractary-faber-cloud:deploy-apply --env=test
# Verify 12-step checklist appears

# Test error delegation with --complete
# (trigger error, select Option 2, verify auto-fix and continuation)
```

**Validation**:
- [ ] Safety validation prevents mismatched deployments
- [ ] TodoWrite checklist tracks 12 steps
- [ ] Error delegation presents 3 options
- [ ] Option 2 (--complete) auto-fixes and continues
- [ ] Structured JSON output returned
- [ ] Deployment history updated

### infra-teardown Testing

```bash
# Test non-production teardown
/fractary-faber-cloud:teardown --env=test

# Test production teardown (manual testing only!)
/fractary-faber-cloud:teardown --env=prod

# Test with --confirm flag
/fractary-faber-cloud:teardown --env=test --confirm
```

**Validation**:
- [ ] State backed up before destruction
- [ ] Confirmations required (1 for test, 3 for prod)
- [ ] --confirm flag works for non-production
- [ ] --confirm flag rejected for production
- [ ] All resources verified removed
- [ ] Teardown documented in history

## Rollback Plan

If issues arise:

1. Git checkout original skill directories
2. Revert renames
3. Disable new features (--complete flag, audit system)
4. Document issues encountered
5. Revise specification before retry

## Next Phase

After Phase 3 completion, proceed to **Phase 4: Documentation Updates** (`faber-cloud-v2.1-phase4-documentation.md`)
