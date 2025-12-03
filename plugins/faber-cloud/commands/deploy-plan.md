---
name: fractary-faber-cloud:deploy-plan
description: Generate and preview deployment plan (terraform plan)
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:deploy-plan
  - /fractary-faber-cloud:deploy-plan --env test
argument-hint: "[--env <environment>]"
---

# Deploy-Plan Command

Preview infrastructure changes before deployment (Terraform plan).

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:deploy-plan
/fractary-faber-cloud:deploy-plan --env test
/fractary-faber-cloud:deploy-plan --env prod

# Incorrect ❌
/fractary-faber-cloud:deploy-plan --env=test
```
</ARGUMENT_SYNTAX>

## Usage

```bash
/fractary-faber-cloud:deploy-plan [--env <environment>]
```

## Parameters

- `--env`: Environment to preview (test, staging, prod). Optional - uses current workspace if not specified.

## What This Does

1. Runs `terraform plan` for the environment
2. Shows resources to be created/modified/destroyed
3. Displays cost impact estimate
4. Identifies potential risks
5. Generates preview report

## Examples

**Preview current workspace changes:**
```
/fractary-faber-cloud:deploy-plan
```

**Preview test environment changes:**
```
/fractary-faber-cloud:deploy-plan --env test
```

**Preview production changes:**
```
/fractary-faber-cloud:deploy-plan --env prod
```

## Output Includes

**Resources:**
- ✅ To be created (green)
- ⚠️ To be modified (yellow)
- ❌ To be destroyed (red)

**Impact:**
- Estimated cost change
- Downtime risk
- Data loss risk
- Security impact

## When to Use

Run deploy-plan:
- Before every deployment
- After validating and testing
- To understand what will change
- Before approving production changes

## Next Steps

After reviewing plan:
- Deploy if acceptable: `/fractary-faber-cloud:deploy-apply --env test`
- Modify code if needed: `/fractary-faber-cloud:engineer`
- Re-test if concerned: `/fractary-faber-cloud:test`

## Production Safety

⚠️ **Always preview production changes** before deploying:
```bash
# Required workflow for production
/fractary-faber-cloud:validate
/fractary-faber-cloud:test
/fractary-faber-cloud:deploy-plan --env prod
# Review output carefully
/fractary-faber-cloud:deploy-apply --env prod
```

## Invocation

This command invokes the `infra-manager` agent with the `deploy-plan` operation.

USE AGENT: infra-manager with operation=deploy-plan and environment from --env parameter
