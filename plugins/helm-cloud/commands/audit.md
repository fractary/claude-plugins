---
name: audit
description: Audit cost, security, and compliance
model: claude-haiku-4-5
examples:
  - /fractary-helm-cloud:audit --type=cost --env prod
  - /fractary-helm-cloud:audit --type=security --env prod
  - /fractary-helm-cloud:audit --type=compliance --env test
argument-hint: "--type <audit-type> [--env <environment>]"
---

# Audit Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm-cloud:audit --env test

# Incorrect ❌
/fractary-helm-cloud:audit --env=test
```
</ARGUMENT_SYNTAX>

Perform audits for cost optimization, security posture, and compliance.

## Usage

```bash
/fractary-helm-cloud:audit --type <audit-type> [--env <environment>]
```

## Parameters

- `--type`: Type of audit to perform (required)
  - `cost`: Cost analysis and optimization recommendations
  - `security`: Security posture and vulnerability assessment
  - `compliance`: Compliance checks and policy violations
- `--env`: Environment to audit (test, prod). Defaults to test.

## What This Does

### Cost Audit
1. Analyzes AWS Cost Explorer data
2. Identifies cost anomalies and spikes
3. Detects underutilized resources
4. Provides optimization recommendations
5. Estimates potential savings

### Security Audit
1. Queries AWS Security Hub findings
2. Checks for open security groups
3. Validates IAM policies
4. Identifies unencrypted resources
5. Reports security score and critical issues

### Compliance Audit
1. Evaluates AWS Config Rules
2. Checks compliance with standards (CIS, PCI, HIPAA)
3. Identifies policy violations
4. Reports compliance percentage
5. Provides remediation guidance

## Examples

**Cost audit:**
```
/fractary-helm-cloud:audit --type=cost --env prod
```

**Security audit:**
```
/fractary-helm-cloud:audit --type=security --env prod
```

**Compliance audit:**
```
/fractary-helm-cloud:audit --type=compliance --env test
```

## Output

Generates a detailed audit report including:
- Executive summary
- Findings by severity
- Recommendations
- Estimated impact (cost savings, risk reduction)
- Action items

## Invocation

This command invokes the `ops-manager` agent with the `audit` operation.

USE AGENT: ops-manager with operation=audit, audit type from --type parameter, and environment from --env parameter (defaults to test)
