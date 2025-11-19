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

### Simplified Commands (Recommended)

**Phase 1 Update:** Direct action-based commands for better UX.

#### /fractary-faber-cloud:architect

Design infrastructure solutions from requirements.

**Syntax:**
```bash
/fractary-faber-cloud:architect "<description>"
```

**Examples:**
```bash
/fractary-faber-cloud:architect "S3 bucket for user uploads"
/fractary-faber-cloud:architect "API service with RDS database"
```

**Output:**
- Design document at `.fractary/plugins/faber-cloud/designs/<feature>.md`
- Includes: resources, security, cost estimate, implementation plan

#### /fractary-faber-cloud:engineer

Generate Terraform code from design documents.

**Syntax:**
```bash
/fractary-faber-cloud:engineer <design-name>
```

**Examples:**
```bash
/fractary-faber-cloud:engineer s3-bucket
/fractary-faber-cloud:engineer api-service
```

**Output:**
- `infrastructure/terraform/main.tf`
- `infrastructure/terraform/variables.tf`
- `infrastructure/terraform/outputs.tf`

#### /fractary-faber-cloud:validate

Validate Terraform configuration.

**Syntax:**
```bash
/fractary-faber-cloud:validate [--env=<env>]
```

**Options:**
- `--env=<env>`: Environment to validate (optional)

**Examples:**
```bash
/fractary-faber-cloud:validate
/fractary-faber-cloud:validate --env=test
```

**Checks:**
- Terraform syntax
- Configuration correctness
- Security settings
- Naming conventions
- Required tags

#### /fractary-faber-cloud:test

Run pre or post-deployment tests.

**Syntax:**
```bash
/fractary-faber-cloud:test [--env=<env>] [--phase=<phase>]
```

**Options:**
- `--env=<env>`: Environment (optional)
- `--phase=<phase>`: Test phase: `pre-deployment` or `post-deployment` (optional)

**Examples:**
```bash
/fractary-faber-cloud:test --env=test --phase=pre-deployment
/fractary-faber-cloud:test --env=test --phase=post-deployment
```

**Pre-deployment tests:**
- Security scans (Checkov, tfsec)
- Cost estimation
- Compliance checks

**Post-deployment tests:**
- Resource verification
- Health checks
- Integration tests

#### /fractary-faber-cloud:deploy-plan

Generate Terraform execution plan.

**Syntax:**
```bash
/fractary-faber-cloud:deploy-plan --env=<env>
```

**Options:**
- `--env=<env>`: Environment (required)

**Examples:**
```bash
/fractary-faber-cloud:deploy-plan --env=test
/fractary-faber-cloud:deploy-plan --env=prod
```

**Shows:**
- Resources to add (+)
- Resources to change (~)
- Resources to destroy (-)

#### /fractary-faber-cloud:deploy

Execute infrastructure deployment.

**Syntax:**
```bash
/fractary-faber-cloud:deploy --env=<env> [options]
```

**Options:**
- `--env=<env>`: Environment (required)
- `--skip-tests`: Skip pre-deployment tests (not recommended)
- `--skip-preview`: Skip preview step (not recommended)

**Examples:**
```bash
/fractary-faber-cloud:deploy --env=test
/fractary-faber-cloud:deploy --env=prod
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

#### /fractary-faber-cloud:status

Check configuration and deployment status.

**Syntax:**
```bash
/fractary-faber-cloud:status [--env=<env>]
```

**Options:**
- `--env=<env>`: Environment (optional)

**Examples:**
```bash
/fractary-faber-cloud:status
/fractary-faber-cloud:status --env=prod
```

**Shows:**
- Configuration status
- Deployment status
- Resource counts
- Last deployment

#### /fractary-faber-cloud:list

Display deployed resources.

**Syntax:**
```bash
/fractary-faber-cloud:list --env=<env>
```

**Options:**
- `--env=<env>`: Environment (required)

**Examples:**
```bash
/fractary-faber-cloud:list --env=test
/fractary-faber-cloud:list --env=prod
```

**Shows:**
- Resource type and name
- ARN/ID
- AWS Console link
- Deployment timestamp

#### /fractary-faber-cloud:debug

Analyze and troubleshoot errors.

**Syntax:**
```bash
/fractary-faber-cloud:debug [--error="<error>"] [--operation=<op>]
```

**Options:**
- `--error="<text>"`: Error message (optional)
- `--operation=<op>`: Operation that failed (optional)

**Examples:**
```bash
/fractary-faber-cloud:debug --error="AccessDenied: s3:PutObject"
/fractary-faber-cloud:debug --operation=deploy
```

**Provides:**
- Error categorization
- Root cause analysis
- Solution proposals
- Automation availability

---

### /fractary-faber-cloud:infra-manage (Deprecated)

**⚠️ DEPRECATED:** This command now delegates to the simplified commands above.

**Migration:**
- Old: `/fractary-faber-cloud:infra-manage deploy --env=test`
- New: `/fractary-faber-cloud:deploy --env=test`

**Description:** Manage infrastructure lifecycle

**Syntax:**
```bash
/fractary-faber-cloud:infra-manage <command> [options]
```

#### architect (deprecated)

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

**Note:** All operations delegated to simplified commands. See above for the new command syntax.

**Support Timeline:**
- Current version: Both old and new work
- faber-cloud v2.0.0: This command will be removed
- Migration period: 6 months

---

## Operations Commands

**⚠️ Phase 2 Update:** Operations monitoring has moved to the `helm-cloud` plugin.

**New commands:**
- `/fractary-helm-cloud:health` - Check health of services
- `/fractary-helm-cloud:investigate` - Investigate incidents and analyze logs
- `/fractary-helm-cloud:remediate` - Apply remediations
- `/fractary-helm-cloud:audit` - Cost, security, and compliance audits

See [helm-cloud documentation](../../helm-cloud/README.md) for details.

---

### /fractary-faber-cloud:ops-manage (Deprecated)

**⚠️ DEPRECATED:** This command now delegates to helm-cloud commands.

**Migration:**
- Old: `/fractary-faber-cloud:ops-manage check-health --env=prod`
- New: `/fractary-helm-cloud:health --env=prod`

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
- Configuration file at `.fractary/plugins/faber-cloud/devops.json`
- Directory structure
- Auto-discovers project settings

**Auto-discovery:**
- Project name from Git
- AWS profiles from credentials
- Terraform directory location
- AWS account and region

---

## Quick Reference

### Most Common Commands (Phase 1 & 2 Updates)

**Infrastructure (faber-cloud):**

**Design:**
```bash
/fractary-faber-cloud:architect "S3 bucket for uploads"
```

**Deploy:**
```bash
/fractary-faber-cloud:deploy --env=test
```

**Validate:**
```bash
/fractary-faber-cloud:validate --env=test
```

**Show resources:**
```bash
/fractary-faber-cloud:list --env=test
```

**Operations (helm-cloud):**

**Check health:**
```bash
/fractary-helm-cloud:health --env=prod
```

**Investigate:**
```bash
/fractary-helm-cloud:investigate --env=prod
```

**Analyze costs:**
```bash
/fractary-helm-cloud:audit --type=cost --env=prod
```

**Natural Language (works for both):**
```bash
/fractary-faber-cloud:director "deploy to test"
/fractary-faber-cloud:director "check health"
/fractary-faber-cloud:director "investigate errors"
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
