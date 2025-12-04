---
name: fractary-faber-cloud:audit
description: Audit infrastructure status, health, and compliance without changes
model: claude-haiku-4-5
examples:
  - /fractary-faber-cloud:audit --env test
  - /fractary-faber-cloud:audit --env prod --check drift
  - /fractary-faber-cloud:audit --env prod --check full
argument-hint: "--env <environment> [--check <type>]"
---

# Audit Command

Audit infrastructure status, health, and compliance without making any changes.

## Usage

```bash
/fractary-faber-cloud:audit [--env <environment>] [--check <type>]
```

## Parameters

- `--env`: Environment to audit (test, prod). Defaults to test.
- `--check`: Type of audit check to perform. Defaults to config-valid.

## Audit Check Types

| Check Type | Duration | Purpose |
|------------|----------|---------|
| `config-valid` | ~2-3s | Terraform configuration syntax and structure |
| `iam-health` | ~3-5s | IAM users, roles, permissions current |
| `drift` | ~5-10s | Detect configuration drift (Terraform vs AWS) |
| `cost` | ~3-5s | Cost analysis, anomalies, projections |
| `security` | ~5-7s | Security posture, compliance checks |
| `full` | ~20-30s | Comprehensive audit (all checks) |

## What This Does

### Non-Destructive Inspection
1. Read current infrastructure state
2. Compare with expected configuration
3. Analyze health, security, and cost
4. Generate structured report
5. Provide actionable recommendations

### No Modifications
- **Read-only operations**: Never modifies infrastructure
- **Safe for production**: Run anytime without risk
- **Fast targeted checks**: Most complete in <10 seconds
- **Comprehensive audits**: Full audit in <30 seconds

## Examples

**Quick config validation:**
```
/fractary-faber-cloud:audit --env test
```

**Check for drift in production:**
```
/fractary-faber-cloud:audit --env prod --check drift
```

**Comprehensive production audit:**
```
/fractary-faber-cloud:audit --env prod --check full
```

**Security posture check:**
```
/fractary-faber-cloud:audit --env prod --check security
```

**Cost analysis:**
```
/fractary-faber-cloud:audit --env test --check cost
```

## Output Format

```markdown
## Audit Report: infrastructure/{env}

**Check Type**: {check_type}
**Timestamp**: {ISO8601}
**Duration**: {seconds}s

### Status Summary
✅ {passing} passing
⚠️  {warnings} warnings
❌ {failures} failures

### Checks Performed

#### ✅ Terraform Configuration Valid
- Syntax: Valid
- Variables: All defined
- Backend: Configured

#### ⚠️ Configuration Drift Detected
- S3 bucket tags modified manually
- Lambda timeout increased outside Terraform
- Recommendation: Import changes or re-apply

#### ✅ IAM Health
- Deploy users: Healthy
- Service roles: All present
- Unused resources: None

### Metrics
- Total resources: 42
- Drift items: 2
- Estimated monthly cost: $15.23
- Last deployment: 2 days ago

### Recommendations
1. Address configuration drift
2. Review S3 bucket tags
3. Update Lambda timeout in Terraform
```

## Use Cases

### Pre-Deployment Verification
```bash
# Audit before deploying
/fractary-faber-cloud:audit --env test --check full
# Review output
/fractary-faber-cloud:deploy-apply --env test
```

### Post-Deployment Validation
```bash
# Deploy infrastructure
/fractary-faber-cloud:deploy-apply --env test
# Verify deployment health
/fractary-faber-cloud:audit --env test --check full
```

### Regular Health Checks
```bash
# Daily production health check
/fractary-faber-cloud:audit --env prod --check drift
/fractary-faber-cloud:audit --env prod --check security
```

### Troubleshooting Preparation
```bash
# Gather state before debugging
/fractary-faber-cloud:audit --env prod --check full
# Use output to inform debugging
/fractary-faber-cloud:debug
```

### Cost Monitoring
```bash
# Weekly cost review
/fractary-faber-cloud:audit --env prod --check cost
```

## When to Use

Run audit:
- Before any deployment (pre-deployment verification)
- After deployment (post-deployment validation)
- Daily for production environments (drift detection)
- Weekly for cost monitoring
- Before troubleshooting (gather current state)
- During compliance reviews

## Integration with Deployment Workflow

Audit is integrated into the deployment workflow:

```
1. Audit (pre-deployment) → config-valid, security
2. Architect → Design solution
3. Engineer → Generate IaC code
4. Validate → Syntax checking
5. Test → Security scans, cost estimates
6. Preview (Plan) → Show changes
7. Execute (Deploy) → Apply changes
8. Audit (post-deployment) → full check
```

## Next Steps

After audit:
- If issues found: Address findings before deployment
- If drift detected: Import changes or re-apply Terraform
- If security issues: Fix configuration and re-audit
- If cost concerns: Optimize resources
- If all clear: Proceed with deployment

## Invocation

This command invokes the `infra-manager` agent with the `audit` operation.

USE AGENT: infra-manager with operation=audit, environment from --env parameter (defaults to test), and check-type from --check parameter (defaults to config-valid)
