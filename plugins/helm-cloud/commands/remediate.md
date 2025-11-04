---
name: remediate
description: Apply remediations to resolve issues
examples:
  - /fractary-helm-cloud:remediate --action=restart_lambda --env test
  - /fractary-helm-cloud:remediate --issue=infra-001 --env prod
  - /fractary-helm-cloud:remediate "restart the API Lambda" --env prod
argument-hint: "[<description>] [--action <action>] [--issue <issue-id>] [--env <environment>]"
---

# Remediate Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm-cloud:remediate --env test

# Incorrect ❌
/fractary-helm-cloud:remediate --env=test
```
</ARGUMENT_SYNTAX>

Apply remediation actions to resolve detected issues.

## Usage

```bash
/fractary-helm-cloud:remediate [<description>] [--action <action>] [--issue <issue-id>] [--env <environment>]
```

## Parameters

- `description`: Natural language description of remediation (optional)
- `--action`: Specific action to apply (restart_lambda, scale_resources, etc.)
- `--issue`: Issue ID to remediate (optional)
- `--env`: Environment to operate on (test, prod). Defaults to test.

## Safety

**Production remediations require explicit confirmation.**

Actions are categorized by safety level:
- **Auto-remediate:** restart_lambda, clear_cache (no confirmation)
- **Require confirmation:** scale_resources, increase_capacity
- **Never auto:** delete_resources, modify_security_groups

## What This Does

1. Diagnoses the issue (if issue ID provided)
2. Proposes remediation action(s)
3. Shows impact assessment
4. Requests confirmation for risky operations
5. Applies remediation
6. Verifies success
7. Documents action taken

## Examples

**Restart a Lambda function:**
```
/fractary-helm-cloud:remediate --action=restart_lambda --env test
```

**Remediate specific issue:**
```
/fractary-helm-cloud:remediate --issue=infra-001 --env prod
```

**Natural language remediation:**
```
/fractary-helm-cloud:remediate "increase RDS max connections to 200" --env prod
```

## Invocation

This command invokes the `ops-manager` agent with the `remediate` operation.

USE AGENT: ops-manager with operation=remediate, action/description from user input, and environment from --env parameter (defaults to test)
