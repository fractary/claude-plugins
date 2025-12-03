---
name: fractary-faber-cloud:deploy-apply
description: Apply infrastructure deployment (terraform apply)
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:deploy-apply --env test
  - /fractary-faber-cloud:deploy-apply --env prod
argument-hint: "--env <environment> [--auto-approve]"
---

# Deploy-Apply Command

Apply infrastructure deployment to AWS (Terraform apply).

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:deploy-apply --env test
/fractary-faber-cloud:deploy-apply --env prod --auto-approve

# Incorrect ❌
/fractary-faber-cloud:deploy-apply --env=test
/fractary-faber-cloud:deploy-apply --env=prod --auto-approve=true
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-faber-cloud:deploy-apply --env <environment> [--auto-approve]
```

## Parameters

- `--env`: Environment to deploy to (test, staging, prod). Required.
- `--auto-approve`: Skip confirmation prompts (not allowed for production)

## What This Does

1. Validates environment configuration
2. Runs environment safety validation
3. Generates deployment plan
4. Requests confirmation (for prod)
5. Applies Terraform changes
6. Verifies deployment success
7. Updates deployment history
8. Generates documentation

## Examples

**Deploy to test:**
```
/fractary-faber-cloud:deploy-apply --env test
```

**Deploy to production:**
```
/fractary-faber-cloud:deploy-apply --env prod
```

## Complete Workflow

The deploy-apply command orchestrates the full workflow:

```
1. Validate  → Environment safety check
2. Plan      → terraform plan
3. Confirm   → User approval (if prod)
4. Apply     → terraform apply
5. Verify    → Resource health check
6. Document  → Update DEPLOYED.md and deployment history
```

## Production Safety

**For production deployments:**
- ⚠️ Requires explicit `--env prod`
- ⚠️ Multiple confirmation prompts
- ⚠️ Shows detailed impact assessment
- ⚠️ Allows cancellation at any step
- ⚠️ Runs environment safety validation

**Safety checks:**
- Environment variable matches Terraform workspace
- AWS profile correct for environment
- No hardcoded values for wrong environment
- Destructive changes flagged
- Cost impact shown

## Error Recovery

If deployment encounters errors, you'll be offered 3 options:

1. **Run debug (interactive)** - You control each fix step
2. **Run debug --complete (automated)** - Auto-fixes and continues deployment ⭐
3. **Manual fix** - Fix issues yourself

## Examples

**Standard test deployment:**
```
/fractary-faber-cloud:deploy-apply --env test
```

**Production deployment (safe):**
```
# 1. Validate first
/fractary-faber-cloud:validate

# 2. Run tests
/fractary-faber-cloud:test

# 3. Preview changes
/fractary-faber-cloud:deploy-plan --env prod
# Review output carefully!

# 4. Deploy with confirmation
/fractary-faber-cloud:deploy-apply --env prod
# Will prompt for confirmation at each step
```

## After Deployment

Deployment automatically:
- ✅ Updates deployment history (`docs/infrastructure/deployments.md`)
- ✅ Creates/updates resource documentation (`infrastructure/DEPLOYED.md`)
- ✅ Saves Terraform state
- ✅ Verifies all resources created

## Monitoring

Check deployment status:
```
/fractary-faber-cloud:status --env test
/fractary-faber-cloud:list --env test
```

## Rollback

If deployment fails or causes issues:
```
# 1. Debug the issue
/fractary-faber-cloud:debug

# Or use automated debugging
/fractary-faber-cloud:debug --complete
```

## Invocation

This command invokes the `infra-manager` agent with the `deploy-apply` operation.

USE AGENT: infra-manager with operation=deploy-apply and environment from --env parameter
