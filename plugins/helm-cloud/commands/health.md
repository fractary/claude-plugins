---
name: health
description: Check health of deployed cloud infrastructure
examples:
  - /fractary-helm-cloud:health --env=test
  - /fractary-helm-cloud:health --env=prod
  - /fractary-helm-cloud:health
argument-hint: "--env=<environment>"
---

# Health Check Command

Check the health status of deployed infrastructure resources.

## Usage

```bash
/fractary-helm-cloud:health [--env=<environment>]
```

## Parameters

- `--env`: Environment to check (test, prod). Defaults to test.

## What This Does

1. Loads deployment registry from `.fractary/registry/deployments.json`
2. Queries health status of all deployed resources
3. Checks CloudWatch metrics against SLO targets
4. Reports overall health status and any degraded resources

## Examples

**Check test environment:**
```
/fractary-helm-cloud:health --env=test
```

**Check production:**
```
/fractary-helm-cloud:health --env=prod
```

## Invocation

This command invokes the `ops-manager` agent with the `check-health` operation.

USE AGENT: ops-manager with operation=check-health and environment from --env parameter (defaults to test)
