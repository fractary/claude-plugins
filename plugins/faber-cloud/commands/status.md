---
name: fractary-faber-cloud:status
description: Check deployment status and configuration
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:status
  - /fractary-faber-cloud:status --env prod
argument-hint: "[--env <environment>]"
---

# Status Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:status --env test

# Incorrect ❌
/fractary-faber-cloud:status --env=test
```
</ARGUMENT_SYNTAX>

Check deployment status and configuration.

## Usage

```bash
/fractary-faber-cloud:status [--env <environment>]
```

## Parameters

- `--env`: Environment to check (test, prod). If omitted, shows all environments.

## What This Does

1. Shows configuration status
2. Lists deployed resources
3. Displays Terraform state summary
4. Shows last deployment info
5. Reports any pending changes

## Examples

**Check all environments:**
```
/fractary-faber-cloud:status
```

**Check specific environment:**
```
/fractary-faber-cloud:status --env prod
```

## Output Includes

**Configuration:**
- Plugin version
- Terraform version
- AWS account and region
- Active handlers (IaC, hosting)

**Deployments:**
- Environment status (deployed/not deployed)
- Last deployment timestamp
- Deployed resources count
- Terraform state location

**Resources:**
- Resource types deployed
- Resource counts by type
- Key resource ARNs
- Estimated monthly cost

**Health:**
- Configuration valid
- State file accessible
- AWS credentials valid
- Recent issues (if any)

## When to Use

Check status:
- Before starting work
- After deployment
- To verify configuration
- When troubleshooting
- Before planning changes

## Next Steps

Based on status:
- If not deployed: `/fractary-faber-cloud:deploy --env test`
- If deployed: `/fractary-faber-cloud:resources --env test`
- If issues: `/fractary-faber-cloud:debug`
- If healthy: Continue monitoring with helm-cloud

## Invocation

This command invokes the `infra-manager` agent with the `check-status` operation.

USE AGENT: infra-manager with operation=check-status and environment from --env parameter (optional)
