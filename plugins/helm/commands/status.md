---
name: status
description: Check status of monitored systems across domains
model: claude-haiku-4-5
examples:
  - /fractary-helm:status
  - /fractary-helm:status --domain infrastructure
  - /fractary-helm:status --env prod
argument-hint: "[--domain <domain>] [--env <environment>]"
---

# Status Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm:status --env test

# Incorrect ❌
/fractary-helm:status --env=test
```
</ARGUMENT_SYNTAX>

Check health and status of monitored systems across all domains or specific domain.

## Usage

```bash
/fractary-helm:status [options]
```

## Parameters

- `--domain <domain>`: Specific domain (infrastructure, application) or all. Default: all
- `--env <environment>`: Filter by environment (test, prod). Default: all

## What This Does

1. Routes to helm-director for domain status queries
2. Queries health from specified domain(s)
3. Returns detailed status information
4. Shows metrics and current state

## Examples

**All domains status:**
```
/fractary-helm:status
```

**Infrastructure status:**
```
/fractary-helm:status --domain infrastructure
```

**Production infrastructure:**
```
/fractary-helm:status --domain infrastructure --env prod
```

**Application status:**
```
/fractary-helm:status --domain application
```

## Output Includes

### Health Status
- Overall health: HEALTHY, DEGRADED, or UNHEALTHY
- Per-resource status
- Active alarms/issues

### Metrics
- Key performance indicators
- Resource utilization
- Error rates
- Latency

### Environment Information
- Active environments
- Resources per environment
- Last deployment times

### Issue Summary
- Count of active issues
- Severity breakdown
- Top issues affecting status

## When to Use

Check status:
- During incident investigation
- Before making changes
- After deployments
- Regular health checks
- In response to alerts

## Next Steps

After checking status:
- Investigate issues: `/fractary-helm-cloud:investigate --service <name>`
- View details: `/fractary-helm-cloud:health --env prod`
- Check dashboard: `/fractary-helm:dashboard`

## Invocation

This command invokes the `helm-director` agent with status operation.

USE AGENT: helm-director with operation=status, domain from --domain parameter, and environment from --env parameter
