# Commands Reference

Complete reference for all fractary-faber-cloud commands.

## Natural Language Entry Point

### /fractary-faber-cloud:director

**Description:** Natural language router for all plugin operations

**Syntax:**
```bash
/fractary-faber-cloud:director "<natural language request>"
```

**Examples:**
```bash
# Infrastructure
/fractary-faber-cloud:director "deploy my infrastructure to test"
/fractary-faber-cloud:director "design an S3 bucket for user uploads"
/fractary-faber-cloud:director "validate my terraform configuration"

# Operations
/fractary-faber-cloud:director "check if production is healthy"
/fractary-faber-cloud:director "investigate errors in API Lambda"
/fractary-faber-cloud:director "show me the logs"
```

**How it works:**
1. Parses your natural language request
2. Identifies keywords (deploy, check, investigate, etc.)
3. Determines intent (infrastructure vs operations)
4. Detects environment (test/prod)
5. Routes to appropriate manager with correct command

**See also:** [devops-director agent](agents.md#devops-director)

---

## Infrastructure Commands

### /fractary-faber-cloud:infra-manage

**Description:** Manage infrastructure lifecycle

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage <command> [options]
```

#### architect

Design infrastructure solutions from requirements.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage architect --feature="<description>"
```

**Options:**
- `--feature="<text>"`: Feature description (required)
- `--env=<env>`: Target environment (optional)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage architect --feature="S3 bucket for user uploads"
/fractary-faber-cloud:infra-manage architect --feature="API service with RDS database"
```

**Output:**
- Design document at `.fractary/plugins/faber-cloud/designs/<feature>.md`
- Includes: resources, security, cost estimate, implementation plan

#### engineer

Generate Terraform code from design documents.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage engineer --design=<design-file>
```

**Options:**
- `--design=<file>`: Design document filename (required)
- `--env=<env>`: Target environment (optional)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage engineer --design=s3-bucket.md
/fractary-faber-cloud:infra-manage engineer --design=api-service.md --env=test
```

**Output:**
- `infrastructure/terraform/main.tf`
- `infrastructure/terraform/variables.tf`
- `infrastructure/terraform/outputs.tf`

#### validate-config

Validate Terraform configuration.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage validate-config [--env=<env>]
```

**Options:**
- `--env=<env>`: Environment to validate (optional)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage validate-config
/fractary-faber-cloud:infra-manage validate-config --env=test
```

**Checks:**
- Terraform syntax
- Configuration correctness
- Security settings
- Naming conventions
- Required tags

#### test

Run pre or post-deployment tests.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage test --env=<env> --phase=<phase>
```

**Options:**
- `--env=<env>`: Environment (required)
- `--phase=<phase>`: Test phase: `pre-deployment` or `post-deployment` (required)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage test --env=test --phase=pre-deployment
/fractary-faber-cloud:infra-manage test --env=test --phase=post-deployment
```

**Pre-deployment tests:**
- Security scans (Checkov, tfsec)
- Cost estimation
- Compliance checks

**Post-deployment tests:**
- Resource verification
- Health checks
- Integration tests

#### preview-changes

Generate Terraform execution plan.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage preview-changes --env=<env>
```

**Options:**
- `--env=<env>`: Environment (required)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage preview-changes --env=test
/fractary-faber-cloud:infra-manage preview-changes --env=prod
```

**Shows:**
- Resources to add (+)
- Resources to change (~)
- Resources to destroy (-)

#### deploy

Execute infrastructure deployment.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage deploy --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--skip-tests`: Skip pre-deployment tests (not recommended)
- `--skip-preview`: Skip preview step (not recommended)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage deploy --env=test
/fractary-faber-cloud:infra-manage deploy --env=prod
```

**Workflow:**
1. Pre-deployment tests
2. Preview changes
3. Request approval
4. Execute deployment
5. Post-deployment tests
6. Update documentation

**Production:**
- Extra confirmations required
- Cannot skip with flags
- Type "yes" to confirm

#### show-resources

Display deployed resources.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage show-resources --env=<env>
```

**Options:**
- `--env=<env>`: Environment (required)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage show-resources --env=test
/fractary-faber-cloud:infra-manage show-resources --env=prod
```

**Shows:**
- Resource type and name
- ARN/ID
- AWS Console link
- Deployment timestamp

#### debug

Analyze and troubleshoot errors.

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage debug --error="<error>" [options]
```

**Options:**
- `--error="<text>"`: Error message (required)
- `--operation=<op>`: Operation that failed (optional)
- `--env=<env>`: Environment (optional)

**Examples:**
```bash
/fractary-faber-cloud:infra-manage debug --error="AccessDenied: s3:PutObject"
/fractary-faber-cloud:infra-manage debug --error="<full error>" --operation=deploy --env=test
```

**Provides:**
- Error categorization
- Root cause analysis
- Solution proposals
- Automation availability

---

## Operations Commands

### /fractary-faber-cloud:ops-manage

**Description:** Manage runtime operations

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage <command> [options]
```

#### check-health

Check health of deployed services.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage check-health --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--service=<name>`: Specific service (optional)

**Examples:**
```bash
/fractary-faber-cloud:ops-manage check-health --env=prod
/fractary-faber-cloud:ops-manage check-health --env=prod --service=api-lambda
```

**Checks:**
- Resource status
- CloudWatch metrics
- Error rates
- Performance
- Overall health

**Health statuses:**
- HEALTHY: All normal
- DEGRADED: Some issues
- UNHEALTHY: Critical issues

#### query-logs

Query CloudWatch logs.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--service=<name>`: Service name (optional)
- `--filter=<pattern>`: Filter pattern (optional)
- `--timeframe=<time>`: Time range (optional, default: 1h)

**Examples:**
```bash
/fractary-faber-cloud:ops-manage query-logs --env=prod --filter=ERROR
/fractary-faber-cloud:ops-manage query-logs --env=prod --service=api-lambda --filter="Database timeout"
/fractary-faber-cloud:ops-manage query-logs --env=prod --timeframe=24h
```

**Timeframe formats:**
- `1h`: Last hour
- `24h`: Last 24 hours
- `7d`: Last 7 days

#### investigate

Investigate incidents with root cause analysis.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage investigate --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--service=<name>`: Service name (optional)
- `--timeframe=<time>`: Investigation window (optional, default: 2h)

**Examples:**
```bash
/fractary-faber-cloud:ops-manage investigate --env=prod
/fractary-faber-cloud:ops-manage investigate --env=prod --service=api-lambda --timeframe=4h
```

**Provides:**
- Timeline of events
- Error patterns
- Event correlation
- Root cause analysis
- Remediation recommendations

#### analyze-performance

Analyze performance metrics.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage analyze-performance --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--service=<name>`: Service name (optional)
- `--timeframe=<time>`: Analysis window (optional, default: 24h)

**Examples:**
```bash
/fractary-faber-cloud:ops-manage analyze-performance --env=prod
/fractary-faber-cloud:ops-manage analyze-performance --env=prod --service=api-lambda
```

**Analyzes:**
- Request rates
- Error rates
- Latency percentiles
- Throughput
- Trends

#### remediate

Apply remediations to fix issues.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage remediate --env=<env> --service=<name> --action=<action>
```

**Options:**
- `--env=<env>`: Environment (required)
- `--service=<name>`: Service name (required)
- `--action=<action>`: Remediation action (required)

**Actions:**
- `restart`: Restart service
- `scale`: Scale resources
- `rollback`: Rollback to previous version

**Examples:**
```bash
/fractary-faber-cloud:ops-manage remediate --env=prod --service=api-lambda --action=restart
/fractary-faber-cloud:ops-manage remediate --env=prod --service=ecs-service --action=scale
```

**Production:**
- Impact assessment shown
- Confirmation required
- Verification after remediation
- Action documented

#### audit

Audit costs, security, or compliance.

**Syntax:**
```bash
/fractary-faber-cloud:ops-manage audit --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--focus=<area>`: Audit focus (optional, default: all)

**Focus areas:**
- `cost`: Cost analysis and optimization
- `security`: Security posture assessment
- `compliance`: Compliance validation
- `all`: All areas

**Examples:**
```bash
/fractary-faber-cloud:ops-manage audit --env=test --focus=cost
/fractary-faber-cloud:ops-manage audit --env=prod --focus=security
/fractary-faber-cloud:ops-manage audit --env=prod
```

**Cost audit provides:**
- Monthly spending
- Cost breakdown
- Top cost drivers
- Optimization recommendations
- Potential savings

**Security audit provides:**
- Vulnerabilities
- Access controls
- Encryption status
- Compliance status
- Recommendations

---

## Configuration Command

### /fractary-faber-cloud:init

**Description:** Initialize plugin configuration

**Syntax:**
```bash
/fractary-faber-cloud:init --provider=<provider> --iac=<tool> [options]
```

**Options:**
- `--provider=<name>`: Cloud provider (required, currently: `aws`)
- `--iac=<tool>`: IaC tool (required, currently: `terraform`)
- `--env=<env>`: Default environment (optional, default: `test`)

**Examples:**
```bash
/fractary-faber-cloud:init --provider=aws --iac=terraform
/fractary-faber-cloud:init --provider=aws --iac=terraform --env=test
```

**Creates:**
- Configuration file at `.fractary/plugins/faber-cloud/config/devops.json`
- Directory structure
- Auto-discovers project settings

**Auto-discovery:**
- Project name from Git
- AWS profiles from credentials
- Terraform directory location
- AWS account and region

---

## Quick Reference

### Most Common Commands

**Deploy:**
```bash
/fractary-faber-cloud:director "deploy to test"
```

**Check health:**
```bash
/fractary-faber-cloud:director "check health"
```

**Investigate:**
```bash
/fractary-faber-cloud:director "investigate errors"
```

**Show resources:**
```bash
/fractary-faber-cloud:director "show resources"
```

**Analyze costs:**
```bash
/fractary-faber-cloud:director "analyze costs"
```

### Environment Flags

All commands support `--env` flag:
- `--env=test`: Test environment
- `--env=prod`: Production environment
- `--env=staging`: Staging environment (if configured)

### Common Options

- `--skip-tests`: Skip pre-deployment tests
- `--skip-preview`: Skip preview step
- `--service=<name>`: Target specific service
- `--filter=<pattern>`: Filter logs
- `--timeframe=<time>`: Time range for queries

---

## See Also

- [Agents Reference](agents.md)
- [Skills Reference](skills.md)
- [User Guide](../guides/user-guide.md)
- [Troubleshooting](../guides/troubleshooting.md)
