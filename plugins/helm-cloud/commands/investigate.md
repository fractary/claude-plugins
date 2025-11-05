---
name: investigate
description: Investigate incidents and analyze logs
examples:
  - /fractary-helm-cloud:investigate "Lambda errors" --env prod
  - /fractary-helm-cloud:investigate --issue=infra-001
  - /fractary-helm-cloud:investigate "high latency" --env test
argument-hint: '"<query>" [--env <environment>] [--issue <issue-id>]'
---

# Investigate Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm-cloud:investigate --env test

# Incorrect ❌
/fractary-helm-cloud:investigate --env=test
```
</ARGUMENT_SYNTAX>

Investigate incidents, query logs, and perform root cause analysis.

## Usage

```bash
/fractary-helm-cloud:investigate <query> [--env <environment>] [--issue <issue-id>]
```

## Parameters

- `query`: Natural language description of what to investigate
- `--env`: Environment to investigate (test, prod). Defaults to test.
- `--issue`: Specific issue ID to investigate (optional)

## What This Does

1. Queries CloudWatch Logs for the specified service/resource
2. Analyzes error patterns and correlates with metrics
3. Identifies root cause based on logs and metrics
4. Generates investigation report with timeline and recommendations

## Examples

**Investigate Lambda errors:**
```
/fractary-helm-cloud:investigate "Lambda errors in API function" --env prod
```

**Investigate specific issue:**
```
/fractary-helm-cloud:investigate --issue=infra-001 --env prod
```

**Investigate performance issue:**
```
/fractary-helm-cloud:investigate "high latency on RDS connections" --env test
```

## Invocation

This command invokes the `ops-manager` agent with the `investigate` operation.

USE AGENT: ops-manager with operation=investigate, query from user input, and environment from --env parameter (defaults to test)
