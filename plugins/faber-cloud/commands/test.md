---
name: fractary-faber-cloud:test
description: Run security scans and cost estimates on infrastructure
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:test --env test
  - /fractary-faber-cloud:test --env prod --phase pre-deployment
argument-hint: "[--env <environment>] [--phase <pre-deployment|post-deployment>]"
---

# Test Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:test --env test

# Incorrect ❌
/fractary-faber-cloud:test --env=test
```
</ARGUMENT_SYNTAX>

Run security scans, cost estimates, and compliance checks on infrastructure.

## Usage

```bash
/fractary-faber-cloud:test [--env <environment>] [--phase <phase>]
```

## Parameters

- `--env`: Environment to test (test, prod). Defaults to test.
- `--phase`: Test phase (pre-deployment, post-deployment). Defaults to pre-deployment.

## What This Does

### Pre-Deployment Tests
1. Security scanning (Checkov, tfsec)
2. Cost estimation (Terraform plan analysis)
3. Compliance checks
4. Best practices validation
5. Risk assessment

### Post-Deployment Tests
1. Resource health verification
2. Security group validation
3. IAM policy checks
4. Cost validation
5. Smoke tests

## Examples

**Test before deployment:**
```
/fractary-faber-cloud:test --env test --phase pre-deployment
```

**Test after deployment:**
```
/fractary-faber-cloud:test --env prod --phase post-deployment
```

**Test with defaults:**
```
/fractary-faber-cloud:test
```

## Test Types

**Security:**
- Open security groups
- Unencrypted resources
- Public S3 buckets
- IAM overpermissions

**Cost:**
- Estimated monthly cost
- Cost by resource type
- Comparison to budget
- Optimization opportunities

**Compliance:**
- CIS benchmarks
- Industry standards
- Company policies

## Next Steps

After tests pass:
- Preview changes: `/fractary-faber-cloud:preview --env test`
- Deploy: `/fractary-faber-cloud:deploy --env test`

If tests fail:
- Review findings
- Fix issues
- Re-run tests

## Invocation

This command invokes the `infra-manager` agent with the `test-changes` operation.

USE AGENT: infra-manager with operation=test-changes, environment from --env parameter (defaults to test), and phase from --phase parameter (defaults to pre-deployment)
