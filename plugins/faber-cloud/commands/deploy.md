---
name: deploy
description: Deploy infrastructure to AWS
examples:
  - /fractary-faber-cloud:deploy --env=test
  - /fractary-faber-cloud:deploy --env=prod
argument-hint: "--env=<environment>"
---

# Deploy Command

Deploy infrastructure to AWS (Terraform apply).

## Usage

```bash
/fractary-faber-cloud:deploy --env=<environment>
```

## Parameters

- `--env`: Environment to deploy to (test, prod). Required.

## What This Does

1. Validates configuration
2. Runs security and cost tests
3. Generates preview
4. Requests confirmation (for prod)
5. Applies Terraform changes
6. Verifies deployment success
7. Registers deployment in registry
8. Optionally triggers health check

## Examples

**Deploy to test:**
```
/fractary-faber-cloud:deploy --env=test
```

**Deploy to production:**
```
/fractary-faber-cloud:deploy --env=prod
```

## Complete Workflow

The deploy command orchestrates the full workflow:

```
1. Validate  → terraform validate
2. Test      → security scans, cost estimates
3. Preview   → terraform plan
4. Confirm   → user approval (if prod)
5. Apply     → terraform apply
6. Verify    → resource health check
7. Register  → update deployment registry
8. Document  → create/update DEPLOYED.md
```

## Production Safety

**For production deployments:**
- ⚠️ Requires explicit `--env=prod`
- ⚠️ Multiple confirmation prompts
- ⚠️ Shows detailed impact assessment
- ⚠️ Allows cancellation at any step
- ⚠️ Runs extra validation checks

**Safety checks:**
- Destructive changes flagged
- Cost impact shown
- Downtime risk assessed
- Rollback plan suggested

## Examples

**Standard test deployment:**
```
/fractary-faber-cloud:deploy --env=test
# Runs automatically with minimal prompts
```

**Production deployment (safe):**
```
# 1. Validate first
/fractary-faber-cloud:validate --env=prod

# 2. Run tests
/fractary-faber-cloud:test --env=prod

# 3. Preview changes
/fractary-faber-cloud:preview --env=prod
# Review output carefully!

# 4. Deploy with confirmation
/fractary-faber-cloud:deploy --env=prod
# Will prompt for confirmation at each step
```

## After Deployment

Deployment automatically:
- ✅ Updates deployment registry (`.fractary/registry/deployments.json`)
- ✅ Creates/updates resource documentation
- ✅ Saves Terraform state
- ✅ Enables monitoring (if helm-cloud installed)

## Monitoring

If helm-cloud is installed, you can monitor after deployment:
```
/fractary-helm-cloud:health --env=test
```

## Rollback

If deployment fails or causes issues:
```
# 1. Debug the issue
/fractary-faber-cloud:debug --error="<error-message>"

# 2. Fix and redeploy, or
# 3. Manually rollback via Terraform state
```

## Invocation

This command invokes the `infra-manager` agent with the `deploy` operation.

USE AGENT: infra-manager with operation=deploy and environment from --env parameter
