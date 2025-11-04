---
name: preview
description: Preview infrastructure changes before deployment
examples:
  - /fractary-faber-cloud:preview --env=test
  - /fractary-faber-cloud:preview --env=prod
argument-hint: "--env=<environment>"
---

# Preview Command

Preview infrastructure changes before deployment (Terraform plan).

## Usage

```bash
/fractary-faber-cloud:preview --env=<environment>
```

## Parameters

- `--env`: Environment to preview (test, prod). Required.

## What This Does

1. Runs `terraform plan` for the environment
2. Shows resources to be created/modified/destroyed
3. Displays cost impact estimate
4. Identifies potential risks
5. Generates preview report

## Examples

**Preview test environment changes:**
```
/fractary-faber-cloud:preview --env=test
```

**Preview production changes:**
```
/fractary-faber-cloud:preview --env=prod
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

Run preview:
- Before every deployment
- After validating and testing
- To understand what will change
- Before approving production changes

## Next Steps

After reviewing preview:
- Deploy if acceptable: `/fractary-faber-cloud:deploy --env=test`
- Modify code if needed: `/fractary-faber-cloud:engineer <design>`
- Re-test if concerned: `/fractary-faber-cloud:test --env=test`

## Production Safety

⚠️ **Always preview production changes** before deploying:
```bash
# Required workflow for production
/fractary-faber-cloud:validate --env=prod
/fractary-faber-cloud:test --env=prod
/fractary-faber-cloud:preview --env=prod
# Review output carefully
/fractary-faber-cloud:deploy --env=prod
```

## Invocation

This command invokes the `infra-manager` agent with the `preview-changes` operation.

USE AGENT: infra-manager with operation=preview-changes and environment from --env parameter
