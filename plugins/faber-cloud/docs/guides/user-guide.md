# Fractary DevOps Plugin - Complete User Guide

**Version:** 1.0.0

This comprehensive guide covers all features and operations of the fractary-faber-cloud plugin.

## Table of Contents

1. [Introduction](#introduction)
2. [Natural Language Interface](#natural-language-interface)
3. [Infrastructure Management](#infrastructure-management)
4. [Runtime Operations](#runtime-operations)
5. [Configuration](#configuration)
6. [Testing and Debugging](#testing-and-debugging)
7. [Production Deployments](#production-deployments)
8. [Monitoring and Auditing](#monitoring-and-auditing)
9. [Best Practices](#best-practices)
10. [Advanced Usage](#advanced-usage)

---

## Introduction

The fractary-faber-cloud plugin provides complete DevOps automation from infrastructure design through production operations. It features:

- **Natural language interface** for intuitive commands
- **Infrastructure lifecycle** management (architect → deploy)
- **Intelligent debugging** with learning from past errors
- **Runtime operations** (monitoring, incident response, auditing)
- **Production safety** with multiple confirmation levels
- **Auto-documentation** of all deployed resources

### Two Ways to Use the Plugin

**1. Natural Language (Recommended):**
```bash
/fractary-faber-cloud:director "deploy my infrastructure to test"
```

**2. Direct Commands:**
```bash
/fractary-faber-cloud:infra-manage deploy --env test
```

Both approaches work identically. Natural language is easier to remember.

---

## Natural Language Interface

The director agent understands natural language and routes to appropriate operations.

### Infrastructure Keywords

**Keywords:** design, architect, create, build, generate, implement, deploy, validate, preview, terraform

**Examples:**
```bash
/fractary-faber-cloud:director "design an S3 bucket for user uploads"
/fractary-faber-cloud:director "create infrastructure for an API service"
/fractary-faber-cloud:director "generate terraform code from the design"
/fractary-faber-cloud:director "validate my terraform configuration"
/fractary-faber-cloud:director "preview changes before deploying"
/fractary-faber-cloud:director "deploy to test environment"
/fractary-faber-cloud:director "deploy to production"
/fractary-faber-cloud:director "show me all deployed resources"
```

### Operations Keywords

**Keywords:** monitor, check, health, status, logs, investigate, debug, fix, remediate, restart, scale, audit, cost

**Examples:**
```bash
/fractary-faber-cloud:director "check health of my services"
/fractary-faber-cloud:director "monitor production"
/fractary-faber-cloud:director "show me the logs from Lambda"
/fractary-faber-cloud:director "investigate errors in API service"
/fractary-faber-cloud:director "fix the failing service"
/fractary-faber-cloud:director "restart the Lambda function"
/fractary-faber-cloud:director "analyze costs for test environment"
/fractary-faber-cloud:director "audit security posture"
```

### Environment Detection

The director automatically detects environments:
- "test", "testing", "dev", "development" → `--env test`
- "prod", "production", "live" → `--env prod`
- Default: test (if not specified)

### Handling Ambiguity

If your request is ambiguous, the director will ask for clarification:

```bash
/fractary-faber-cloud:director "check my infrastructure"

# Response:
Your request could mean:
1. Check health of running services (ops-manager)
2. Validate infrastructure configuration (infra-manager)
3. Show deployed resources (infra-manager)

Which one? (1/2/3)
```

---

## Infrastructure Management

Complete infrastructure lifecycle from design through deployment.

### 1. Design Infrastructure

**Natural Language:**
```bash
/fractary-faber-cloud:director "design infrastructure for user authentication"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage architect --feature="User authentication service"
```

**What it does:**
- Analyzes requirements
- Reviews existing infrastructure
- Designs AWS resources needed
- Creates detailed design document

**Output:**
- Design document at `.fractary/plugins/faber-cloud/designs/user-authentication.md`
- Includes: resource specifications, security considerations, cost estimates

### 2. Generate Terraform Code

**Natural Language:**
```bash
/fractary-faber-cloud:director "implement the user authentication design"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage engineer --design=user-authentication.md
```

**What it does:**
- Reads design document
- Generates Terraform files (main.tf, variables.tf, outputs.tf)
- Applies naming patterns and tagging
- Validates syntax

**Output:**
- `infrastructure/terraform/main.tf`
- `infrastructure/terraform/variables.tf`
- `infrastructure/terraform/outputs.tf`

### 3. Validate Configuration

**Natural Language:**
```bash
/fractary-faber-cloud:director "validate my terraform configuration"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage validate-config --env test
```

**What it checks:**
- Terraform syntax errors
- Resource configuration correctness
- Security settings
- Naming conventions
- Required tags

### 4. Run Tests

**Natural Language:**
```bash
/fractary-faber-cloud:director "test my infrastructure before deploying"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage test --env test --phase=pre-deployment
```

**Pre-deployment tests:**
- Security scanning (Checkov, tfsec)
- Cost estimation and budget validation
- Compliance checks (naming, tagging)
- Configuration best practices

**Test report location:**
`.fractary/plugins/faber-cloud/test-reports/{env}/{timestamp}-pre-deployment.json`

### 5. Preview Changes

**Natural Language:**
```bash
/fractary-faber-cloud:director "preview what will change in test"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage preview-changes --env test
```

**What it shows:**
- Resources to be added (+ symbol)
- Resources to be changed (~ symbol)
- Resources to be destroyed (- symbol)
- Detailed change descriptions

### 6. Deploy

**Natural Language:**
```bash
/fractary-faber-cloud:director "deploy to test environment"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage deploy --env test
```

**Deployment workflow:**
1. Pre-deployment tests (security, cost)
2. Preview changes
3. Request approval (you type "yes")
4. Execute deployment
5. Verify resources created
6. Post-deployment tests
7. Health checks
8. Update registry
9. Generate DEPLOYED.md

**Options:**
- `--skip-tests`: Skip pre-deployment tests (not recommended)
- `--skip-preview`: Skip preview step (not recommended)

### 7. View Deployed Resources

**Natural Language:**
```bash
/fractary-faber-cloud:director "show me deployed resources in test"
```

**Direct Command:**
```bash
/fractary-faber-cloud:infra-manage show-resources --env test
```

**What you see:**
- Resource type and name
- Resource ARN/ID
- AWS Console link (clickable)
- Deployment timestamp
- Configuration summary

**Documents generated:**
- Registry: `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`
- Human-readable: `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`

---

## Runtime Operations

Monitor health, investigate issues, and respond to incidents.

### 1. Check Health

**Natural Language:**
```bash
/fractary-faber-cloud:director "check health of production services"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage check-health --env prod
```

**What it checks:**
- Resource status (running/stopped/degraded)
- CloudWatch metrics (errors, latency, throughput)
- Performance indicators
- Anomaly detection
- Overall health categorization

**Health statuses:**
- HEALTHY: All metrics normal
- DEGRADED: Some metrics abnormal
- UNHEALTHY: Critical metrics failing

**For specific services:**
```bash
/fractary-faber-cloud:ops-manage check-health --env prod --service=api-lambda
```

### 2. Query Logs

**Natural Language:**
```bash
/fractary-faber-cloud:director "show me error logs from API Lambda"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env prod --service=api-lambda --filter=ERROR
```

**Query options:**
- `--filter=ERROR`: Show only error messages
- `--filter=WARN`: Show warnings
- `--timeframe=2h`: Last 2 hours
- `--timeframe=24h`: Last 24 hours
- `--limit=100`: Limit results

**Log sources:**
- Lambda: CloudWatch Logs
- ECS: Container logs
- RDS: Database logs
- API Gateway: Access logs

### 3. Investigate Incidents

**Natural Language:**
```bash
/fractary-faber-cloud:director "investigate errors in API service"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage investigate --env prod --service=api-lambda --timeframe=2h
```

**Investigation includes:**
- Timeline of events
- Error pattern identification
- Event correlation across services
- Root cause analysis
- Affected resources
- Remediation recommendations

**Incident report location:**
`.fractary/plugins/faber-cloud/incidents/{env}/{timestamp}-incident.json`

### 4. Analyze Performance

**Natural Language:**
```bash
/fractary-faber-cloud:director "analyze performance of API Lambda"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage analyze-performance --env prod --service=api-lambda
```

**Metrics analyzed:**
- Invocations and errors
- Duration and latency
- Throttles and concurrency
- Trends over time
- Performance recommendations

### 5. Apply Remediation

**Natural Language:**
```bash
/fractary-faber-cloud:director "restart API Lambda in production"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage remediate --env prod --service=api-lambda --action=restart
```

**Remediation actions:**
- `restart`: Restart service (Lambda, ECS)
- `scale`: Scale resources (ECS tasks, Lambda concurrency)
- `rollback`: Rollback to previous version

**Production safety:**
- Impact assessment shown
- Confirmation required (type "yes")
- Expected downtime estimated
- Verification after remediation
- Action documented

**Remediation log:**
`.fractary/plugins/faber-cloud/remediations/{env}/remediation-log.json`

### 6. Audit Costs and Security

**Natural Language:**
```bash
/fractary-faber-cloud:director "analyze costs for test environment"
```

**Direct Command:**
```bash
/fractary-faber-cloud:ops-manage audit --env test --focus=cost
```

**Cost audit includes:**
- Current monthly spending
- Cost breakdown by resource
- Top cost drivers
- Cost trends over time
- Optimization opportunities
- Potential savings estimates

**Security audit:**
```bash
/fractary-faber-cloud:ops-manage audit --env prod --focus=security
```

**Security audit includes:**
- Runtime security posture
- Vulnerability identification
- Compliance checks
- Access control review
- Best practices validation

**Audit report location:**
`logs/infrastructure/audits/{env}/{timestamp}-audit.json`

---

## Configuration

The plugin is configured via `.fractary/plugins/faber-cloud/devops.json`.

### Initialize Configuration

```bash
/fractary-faber-cloud:init --provider aws --iac terraform
```

### Configuration Structure

```json
{
  "version": "1.0",
  "project": {
    "name": "my-project",
    "subsystem": "core",
    "organization": "my-org"
  },
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {
          "discover": "my-project-discover-deploy",
          "test": "my-project-test-deploy",
          "prod": "my-project-prod-deploy"
        }
      }
    },
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform",
        "var_file_pattern": "{environment}.tfvars",
        "backend": {
          "type": "s3",
          "bucket": "{project}-terraform-state",
          "key": "{subsystem}/terraform.tfstate"
        }
      }
    }
  },
  "resource_naming": {
    "pattern": "{project}-{subsystem}-{environment}-{resource}",
    "separator": "-"
  },
  "environments": {
    "test": {
      "auto_approve": false,
      "cost_threshold": 100,
      "require_confirmation": false
    },
    "prod": {
      "auto_approve": false,
      "cost_threshold": 500,
      "require_confirmation": true
    }
  }
}
```

### Pattern Substitution

Available variables:
- `{project}`: Project name (e.g., "my-project")
- `{subsystem}`: Subsystem name (e.g., "core")
- `{environment}`: Environment (e.g., "test", "prod")
- `{resource}`: Resource name (e.g., "database")
- `{organization}`: Organization name (e.g., "my-org")

**Example:**
Pattern: `{project}-{subsystem}-{environment}-{resource}`
Result: `my-project-core-test-database`

### AWS Profile Configuration

**Three profiles required:**

1. **discover profile** (temporary use only):
   - Used for IAM permission management
   - Has IAM permissions
   - Only used when auto-fixing permission errors

2. **test profile**:
   - Used for test deployments
   - No IAM permissions
   - Deploy to test environment

3. **prod profile**:
   - Used for production deployments
   - No IAM permissions
   - Deploy to production environment

**Profile separation enforced at multiple levels for safety.**

### Environment Configuration

Each environment can have:
- `auto_approve`: Whether to auto-approve (false for safety)
- `cost_threshold`: Monthly cost limit ($)
- `require_confirmation`: Production safety confirmation protocol
  - `true`: Requires 2-step user confirmation before deployment (recommended for prod)
  - `false`: No confirmation required (use for test/dev environments)
  - See [SECURITY.md](../SECURITY.md#production-deployment-safety) for full details on the confirmation protocol

---

## Testing and Debugging

### Pre-Deployment Testing

Automatic before every deployment:

**Security Scans:**
- Checkov: Infrastructure security scanning
- tfsec: Terraform-specific security checks
- Identifies misconfigurations, public resources, missing encryption

**Cost Estimation:**
- Estimates monthly cost of resources
- Compares against budget threshold
- Identifies top cost drivers
- Provides cost breakdown

**Compliance Checks:**
- Naming convention validation
- Required tagging verification
- Configuration best practices

**Skip tests (not recommended):**
```bash
/fractary-faber-cloud:infra-manage deploy --env test --skip-tests
```

### Post-Deployment Testing

Automatic after successful deployment:

**Resource Verification:**
- Confirms all resources created
- Validates resource configuration
- Checks security settings

**Integration Tests:**
- Tests resource connectivity
- Validates IAM permissions
- Checks network configuration

**Health Checks:**
- Initial health assessment
- Monitoring setup verification
- Alerting configuration

### Intelligent Debugging

When deployments fail, the debugger automatically analyzes errors.

**Error Categories:**
1. **Permission errors** (auto-fixable)
2. **Configuration errors** (manual fix)
3. **Resource errors** (resolution required)
4. **State errors** (guided resolution)
5. **Network errors** (retry logic)
6. **Quota errors** (manual resolution)

**Learning System:**
- Errors normalized and logged
- Solutions ranked by success rate
- Future occurrences use best solution
- Continuous improvement over time

**Manual debugging:**
```bash
/fractary-faber-cloud:director "debug the deployment error"
```

Or:
```bash
/fractary-faber-cloud:infra-manage debug --error="<error message>" --operation=deploy --env test
```

**Issue log location:**
`.fractary/plugins/faber-cloud/deployments/issue-log.json`

---

## Production Deployments

Production deployments have extra safety measures.

### Production Safety Features

**1. Multiple confirmation checks:**
- Command validates prod flag
- Manager requires explicit confirmation
- Skill validates environment
- Handler verifies AWS profile

**2. Cannot bypass confirmations:**
- `--auto-approve` ignored for production
- Must type "yes" explicitly
- No shortcuts allowed

**3. Extra warnings:**
```
⚠️  WARNING: Production Deployment
═══════════════════════════════════════
You are about to deploy to PRODUCTION.
This will affect live systems.

Resources to be changed:
+ 2 new resources
~ 1 resource modified
- 0 resources destroyed

Estimated cost impact: +$12.50/month

Type 'yes' to confirm: _
```

**4. Complete audit trail:**
- All actions logged with timestamps
- User context captured
- Resource changes documented
- Remediation history tracked

### Production Deployment Workflow

```bash
# 1. Deploy to test first
/fractary-faber-cloud:director "deploy to test"
# Verify everything works

# 2. Monitor test environment
/fractary-faber-cloud:director "check health of test services"
# Ensure stable for 24+ hours

# 3. Deploy to production
/fractary-faber-cloud:director "deploy to production"
# Extra confirmations required
# Type "yes" when prompted

# 4. Monitor production
/fractary-faber-cloud:director "check health of production"
# Verify deployment successful

# 5. Investigate any issues
/fractary-faber-cloud:director "investigate production errors"
# If problems detected
```

### Production Rollback

If production deployment causes issues:

**Option 1: Terraform rollback**
```bash
cd infrastructure/terraform
terraform apply -target=<resource> -var-file=prod.tfvars
# Manually revert problematic resources
```

**Option 2: Code rollback**
```bash
git revert <commit>
/fractary-faber-cloud:director "deploy to production"
# Deploy previous version
```

**Option 3: Service rollback**
```bash
/fractary-faber-cloud:director "roll back API Lambda to previous version"
```

---

## Monitoring and Auditing

### Health Monitoring

**Check all services:**
```bash
/fractary-faber-cloud:director "check health of production"
```

**Check specific service:**
```bash
/fractary-faber-cloud:ops-manage check-health --env prod --service=api-lambda
```

**Recommended frequency:**
- Production: Every hour
- Test: Daily

### Log Monitoring

**Query recent errors:**
```bash
/fractary-faber-cloud:director "show me errors from the last hour"
```

**Search for specific pattern:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env prod --filter="Database timeout" --timeframe=24h
```

### Cost Auditing

**Monthly cost analysis:**
```bash
/fractary-faber-cloud:director "analyze costs for production"
```

**Cost optimization recommendations:**
- Right-size over-provisioned resources
- Enable cost-saving features
- Remove unused resources
- Use reserved instances

### Security Auditing

**Security posture:**
```bash
/fractary-faber-cloud:director "audit security for production"
```

**Checks include:**
- Vulnerability scanning
- Access control review
- Encryption verification
- Compliance validation
- Best practices adherence

### Compliance Auditing

**Configuration compliance:**
```bash
/fractary-faber-cloud:ops-manage audit --env prod --focus=compliance
```

**Verifies:**
- Naming conventions followed
- Required tags present
- Security groups properly configured
- IAM policies least-privilege
- Logging enabled

---

## Best Practices

### General

1. **Always deploy to test first**
   - Verify in test before production
   - Let test run 24+ hours before prod

2. **Use natural language**
   - Easier to remember
   - More intuitive
   - Harder to make mistakes

3. **Review previews carefully**
   - Always check what will change
   - Pay attention to destructive changes (-)
   - Verify cost estimates

4. **Let errors auto-fix**
   - Accept automated permission fixes
   - Faster than manual fixes
   - Tracked in audit trail

5. **Monitor regularly**
   - Production: Hourly health checks
   - Test: Daily health checks
   - Investigate degradations immediately

### Infrastructure

1. **Design before implementing**
   - Use architect skill to create designs
   - Review and modify designs
   - Then generate Terraform code

2. **Validate before deploying**
   - Run validate-config
   - Run pre-deployment tests
   - Preview changes

3. **Document as you go**
   - Plugin auto-documents deployments
   - Add comments to Terraform files
   - Update design docs if changes occur

4. **Tag everything**
   - Use consistent tagging
   - Required tags in config
   - Helps with cost tracking

5. **Use pattern substitution**
   - Consistent naming across resources
   - Easier to identify resources
   - Pattern-based organization

### Operations

1. **Investigate before remediating**
   - Understand root cause first
   - Don't just restart blindly
   - Document findings

2. **Test remediations in test first**
   - If possible, replicate in test
   - Test remediation there first
   - Then apply to production

3. **Monitor after remediations**
   - Verify remediation worked
   - Watch for recurring issues
   - Document outcome

4. **Regular audits**
   - Weekly cost audits
   - Monthly security audits
   - Quarterly compliance reviews

5. **Keep issue log clean**
   - Archive old logs to S3
   - Remove duplicate entries
   - Maintain solution accuracy

### Security

1. **Use profile separation**
   - Never use discover profile for deployments
   - Keep test and prod profiles separate
   - Rotate credentials regularly

2. **Principle of least privilege**
   - Only grant needed permissions
   - Document reason for each permission
   - Review permissions quarterly

3. **Enable encryption**
   - Encrypt at rest (S3, RDS, EBS)
   - Encrypt in transit (TLS/HTTPS)
   - Use AWS KMS for keys

4. **Private by default**
   - Resources private unless explicitly public
   - Use VPCs and security groups
   - Minimize public exposure

5. **Audit trails**
   - Keep complete IAM audit trail
   - Monitor CloudTrail logs
   - Alert on suspicious activity

---

## Advanced Usage

### Batch Operations

Deploy multiple environments:
```bash
for env in test staging prod; do
  /fractary-faber-cloud:director "deploy to $env"
done
```

### Custom Workflows

Create custom deployment workflows:
```bash
# Design → Implement → Test → Deploy
/fractary-faber-cloud:director "design API service"
/fractary-faber-cloud:director "implement the design"
/fractary-faber-cloud:director "test the infrastructure"
/fractary-faber-cloud:director "deploy to test"
```

### Integration with CI/CD

Use in automation pipelines:
```yaml
# GitHub Actions example
- name: Deploy infrastructure
  run: |
    /fractary-faber-cloud:infra-manage deploy --env test
```

### Multi-Region Deployments

Configure multiple regions:
```json
{
  "handlers": {
    "hosting": {
      "aws": {
        "regions": ["us-east-1", "eu-west-1"]
      }
    }
  }
}
```

### Cost Optimization

Regular cost reviews:
```bash
# Weekly cost audit
/fractary-faber-cloud:director "analyze costs"

# Apply recommendations
# Right-size resources
# Enable cost-saving features
# Remove unused resources
```

### Disaster Recovery

Backup and restore:
```bash
# Backup state
aws s3 cp s3://my-terraform-state/terraform.tfstate ./backup/

# Restore if needed
aws s3 cp ./backup/terraform.tfstate s3://my-terraform-state/
```

---

## Summary

The fractary-faber-cloud plugin provides complete DevOps automation with:
- Natural language interface for ease of use
- Complete infrastructure lifecycle management
- Intelligent debugging with learning
- Runtime operations and monitoring
- Production-ready safety features
- Comprehensive documentation

**Key takeaways:**
1. Use natural language for easiest experience
2. Always test in test environment first
3. Review previews before deploying
4. Let permission errors auto-fix
5. Monitor regularly and investigate issues promptly
6. Follow security best practices
7. Keep documentation updated

For more information:
- [Getting Started Guide](getting-started.md)
- [Troubleshooting Guide](troubleshooting.md)
- [Architecture Documentation](../architecture/ARCHITECTURE.md)
- [README](../../README.md)
