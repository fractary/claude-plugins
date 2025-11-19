# Skills Reference

Complete reference for all fractary-faber-cloud skills.

## Overview

Skills are single-purpose execution units that perform focused tasks. The plugin has:
- **8 Infrastructure Skills** (Phase 1)
- **2 Testing/Debugging Skills** (Phase 2)
- **4 Operations Skills** (Phase 3)
- **2 Handler Skills** (Phases 1 & 3)

---

## Infrastructure Skills (Phase 1)

### infra-architect

**Purpose:** Design infrastructure solutions from requirements

**Invoked by:** infra-manager (architect command)

**Inputs:**
- Feature description
- Target environment
- Existing infrastructure (if any)

**Process:**
1. Analyze requirements
2. Review existing infrastructure
3. Design AWS resources needed
4. Consider security and cost
5. Create design document

**Outputs:**
- Design document at `.fractary/plugins/faber-cloud/designs/<feature>.md`
- Includes: resources, security, cost estimate, implementation plan

**Example:**
```bash
/fractary-faber-cloud:infra-manage architect --feature="S3 bucket for uploads"
```

### infra-engineer

**Purpose:** Generate Terraform code from design documents

**Invoked by:** infra-manager (engineer command)

**Inputs:**
- Design document
- Configuration (naming patterns, tags)
- Target environment

**Process:**
1. Read design document
2. Generate main.tf (resources)
3. Generate variables.tf (inputs)
4. Generate outputs.tf (exports)
5. Apply naming patterns
6. Add required tags
7. Validate syntax

**Outputs:**
- `infrastructure/terraform/main.tf`
- `infrastructure/terraform/variables.tf`
- `infrastructure/terraform/outputs.tf`

**Example:**
```bash
/fractary-faber-cloud:infra-manage engineer --design=s3-bucket.md
```

### infra-validator

**Purpose:** Validate Terraform configurations

**Invoked by:** infra-manager (validate-config command)

**Inputs:**
- Terraform directory
- Environment

**Process:**
1. Run terraform validate
2. Check syntax errors
3. Verify resource configuration
4. Check security settings
5. Validate naming conventions
6. Verify required tags

**Outputs:**
- Validation report (pass/fail)
- List of issues found
- Recommendations

**Example:**
```bash
/fractary-faber-cloud:infra-manage validate-config --env test
```

### infra-previewer

**Purpose:** Generate Terraform execution plans

**Invoked by:** infra-manager (preview-changes command)

**Inputs:**
- Terraform directory
- Environment
- Variable files

**Process:**
1. Authenticate with AWS
2. Run terraform plan
3. Parse plan output
4. Categorize changes (add/change/destroy)
5. Highlight destructive changes
6. Calculate resource counts

**Outputs:**
- Execution plan
- Changes summary
- Resource counts
- Saved plan file

**Example:**
```bash
/fractary-faber-cloud:infra-manage preview-changes --env test
```

### infra-deployer

**Purpose:** Execute infrastructure deployments

**Invoked by:** infra-manager (deploy command)

**Inputs:**
- Terraform directory
- Environment
- Execution plan

**Process:**
1. Authenticate with AWS (via handler-hosting-aws)
2. Execute terraform apply (via handler-iac-terraform)
3. Verify resources created
4. Extract resource metadata
5. Update resource registry
6. Generate DEPLOYED.md
7. Run post-deployment tests

**Outputs:**
- Deployed resources
- Registry updated at `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`
- Documentation at `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`

**Handlers used:**
- handler-hosting-aws (authenticate, verify)
- handler-iac-terraform (apply)

**Example:**
```bash
/fractary-faber-cloud:infra-manage deploy --env test
```

### infra-permission-manager

**Purpose:** Manage IAM permissions for deployment users

**Invoked by:**
- infra-manager (when permission errors detected)
- infra-debugger (when proposing permission fixes)

**Inputs:**
- Missing permission
- Environment
- Reason for permission

**Process:**
1. Switch to discover profile
2. Add permission to IAM policy
3. Log in IAM audit trail
4. Verify permission granted
5. Return success

**Outputs:**
- Permission granted
- IAM audit trail updated at `.fractary/plugins/faber-cloud/deployments/iam-audit.json`

**Safety:**
- Only adds specific permissions
- Documents reason
- Complete audit trail
- Environment-scoped

**Example:**
Automatically invoked when permission errors occur during deployment.

---

## Testing & Debugging Skills (Phase 2)

### infra-tester

**Purpose:** Run pre and post-deployment tests

**Invoked by:** infra-manager (test command, or automatically during deploy)

**Inputs:**
- Environment
- Test phase (pre or post)
- Terraform directory

**Process (Pre-deployment):**
1. Run Checkov security scan
2. Run tfsec Terraform security scan
3. Estimate costs
4. Validate budget threshold
5. Check naming conventions
6. Verify required tags
7. Generate test report

**Process (Post-deployment):**
1. Verify resource existence
2. Validate resource configuration
3. Check security posture
4. Run integration tests
5. Perform health checks
6. Verify monitoring setup
7. Generate test report

**Outputs:**
- Test report at `.fractary/plugins/faber-cloud/test-reports/{env}/{timestamp}-{phase}.json`
- Pass/fail status
- Detailed findings
- Recommendations

**Example:**
```bash
/fractary-faber-cloud:infra-manage test --env test --phase=pre-deployment
```

### infra-debugger

**Purpose:** Analyze errors and propose solutions

**Invoked by:**
- infra-manager (when deployment fails)
- Manual invocation via debug command

**Inputs:**
- Error message
- Operation that failed
- Environment
- Context

**Process:**
1. Categorize error (permission/config/resource/state/network/quota)
2. Normalize error message
3. Generate issue ID
4. Search issue log for matching errors
5. Rank solutions by success rate
6. Validate solution applicability
7. Propose best solution
8. Determine if automatable

**Outputs:**
- Error category
- Issue ID
- Proposed solutions (ranked)
- Automation capability (yes/no)
- Delegation recommendation

**Error categories:**
1. Permission (auto-fixable)
2. Configuration (manual fix)
3. Resource (resolution required)
4. State (guided resolution)
5. Network (retry)
6. Quota (manual resolution)

**Learning system:**
- Logs all errors
- Tracks solution success rates
- Updates after each resolution
- Improves over time

**Example:**
```bash
/fractary-faber-cloud:infra-manage debug --error="AccessDenied: s3:PutObject"
```

---

## Operations Skills (Phase 3)

### ops-monitor

**Purpose:** Monitor health and collect metrics

**Invoked by:** ops-manager (check-health, analyze-performance commands)

**Inputs:**
- Environment
- Service name (optional)

**Process:**
1. Load resource registry
2. Query resource status (via handler-hosting-aws)
3. Query CloudWatch metrics (via handler-hosting-aws)
4. Calculate health scores
5. Detect anomalies
6. Categorize health (HEALTHY/DEGRADED/UNHEALTHY)
7. Generate report

**Metrics collected:**
- Lambda: invocations, errors, duration, throttles
- RDS: CPU, connections, memory
- ECS: CPU, memory, task count
- API Gateway: requests, errors, latency
- S3: size, objects

**Outputs:**
- Health report at `.fractary/plugins/faber-cloud/monitoring/{env}/{timestamp}-health-check.json`
- Overall status
- Per-resource health
- Metrics summaries
- Recommendations

**Example:**
```bash
/fractary-faber-cloud:ops-manage check-health --env prod
```

### ops-investigator

**Purpose:** Investigate incidents and analyze logs

**Invoked by:** ops-manager (query-logs, investigate commands)

**Inputs:**
- Environment
- Service name
- Time range
- Filter pattern

**Process:**
1. Query CloudWatch logs (via handler-hosting-aws)
2. Filter for error patterns
3. Correlate events across services
4. Generate timeline
5. Identify root cause
6. Collect evidence
7. Generate incident report

**Outputs:**
- Incident report at `.fractary/plugins/faber-cloud/incidents/{env}/{timestamp}-incident.json`
- Timeline of events
- Error patterns
- Root cause analysis
- Affected resources
- Remediation recommendations

**Example:**
```bash
/fractary-faber-cloud:ops-manage investigate --env prod --service=api-lambda
```

### ops-responder

**Purpose:** Apply remediations to resolve issues

**Invoked by:** ops-manager (remediate command)

**Inputs:**
- Environment
- Service name
- Remediation action

**Process:**
1. Assess impact
2. Request confirmation (if production)
3. Apply remediation (via handler-hosting-aws)
4. Verify action completed
5. Check health after remediation
6. Document action
7. Log in remediation history

**Actions:**
- `restart`: Restart Lambda or ECS service
- `scale`: Scale ECS tasks or Lambda concurrency
- `rollback`: Rollback to previous version

**Outputs:**
- Remediation success/failure
- Verification results
- Action documented at `.fractary/plugins/faber-cloud/remediations/{env}/remediation-log.json`

**Safety:**
- Production requires confirmation
- Impact assessment before action
- Verification after action
- Complete documentation

**Example:**
```bash
/fractary-faber-cloud:ops-manage remediate --env prod --service=api-lambda --action=restart
```

### ops-auditor

**Purpose:** Audit costs, security, and compliance

**Invoked by:** ops-manager (audit command)

**Inputs:**
- Environment
- Audit focus (cost/security/compliance)

**Process (Cost):**
1. Query cost data from AWS
2. Calculate monthly spending
3. Break down by resource
4. Identify top cost drivers
5. Analyze trends
6. Generate optimization recommendations
7. Calculate potential savings

**Process (Security):**
1. Assess runtime security posture
2. Identify vulnerabilities
3. Check encryption status
4. Review access controls
5. Validate compliance
6. Generate recommendations

**Process (Compliance):**
1. Check configuration compliance
2. Verify naming conventions
3. Validate required tags
4. Check security groups
5. Review IAM policies
6. Generate compliance report

**Outputs:**
- Audit report at `logs/infrastructure/audits/{env}/{timestamp}-audit.json`
- Findings with severity
- Prioritized recommendations
- Potential savings (for cost)

**Example:**
```bash
/fractary-faber-cloud:ops-manage audit --env test --focus=cost
```

---

## Handler Skills

### handler-hosting-aws

**Purpose:** Centralize all AWS-specific operations

**Phase:** 1 (extended in Phase 3)

**Operations:**
- `authenticate`: Set up AWS credentials
- `deploy`: Deploy resources
- `verify`: Verify deployed resources
- `query`: Query resource state
- `delete`: Remove resources
- `get-resource-status`: Get current status (Phase 3)
- `query-metrics`: Query CloudWatch metrics (Phase 3)
- `query-logs`: Query CloudWatch logs (Phase 3)
- `restart-service`: Restart Lambda/ECS (Phase 3)
- `scale-service`: Scale resources (Phase 3)

**Invoked by:**
- Infrastructure skills (deploy, verify operations)
- Operations skills (monitoring, remediation)

**Configuration:**
```json
{
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {...}
      }
    }
  }
}
```

### handler-iac-terraform

**Purpose:** Centralize all Terraform-specific operations

**Phase:** 1

**Operations:**
- `init`: Initialize Terraform
- `validate`: Validate configuration
- `plan`: Generate execution plan
- `apply`: Apply changes
- `destroy`: Destroy resources

**Invoked by:**
- infra-validator (validate)
- infra-previewer (plan)
- infra-deployer (init, apply)

**Configuration:**
```json
{
  "handlers": {
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform"
      }
    }
  }
}
```

---

## Skill Patterns

### Single Purpose

Each skill does one thing well:
- ✅ infra-architect: Design only
- ✅ infra-deployer: Deploy only
- ❌ infra-everything: Too broad

### Workflow Steps

Skills read workflow from files:
```
skills/skill-name/
├── SKILL.md              # Main definition
└── workflow/
    ├── step-1.md         # Detailed steps
    └── step-2.md
```

### Handler Delegation

Skills delegate to handlers for provider operations:
```
infra-deployer
  ↓
handler-hosting-aws (authenticate)
  ↓
handler-iac-terraform (apply)
```

### Documentation

Skills document their own work:
- infra-architect creates design docs
- infra-deployer updates registry
- infra-permission-manager logs audit trail

### Error Handling

Skills return errors to manager:
```
Skill encounters error
  ↓
Returns to manager
  ↓
Manager invokes debugger
  ↓
Debugger proposes solution
```

---

## Quick Reference

| Skill | Purpose | Manager | Phase |
|-------|---------|---------|-------|
| infra-architect | Design | infra-manager | 1 |
| infra-engineer | Generate code | infra-manager | 1 |
| infra-validator | Validate | infra-manager | 1 |
| infra-previewer | Preview | infra-manager | 1 |
| infra-deployer | Deploy | infra-manager | 1 |
| infra-permission-manager | IAM | infra-manager | 1 |
| infra-tester | Test | infra-manager | 2 |
| infra-debugger | Debug | infra-manager | 2 |
| ops-monitor | Monitor | ops-manager | 3 |
| ops-investigator | Investigate | ops-manager | 3 |
| ops-responder | Remediate | ops-manager | 3 |
| ops-auditor | Audit | ops-manager | 3 |
| handler-hosting-aws | AWS ops | All | 1, 3 |
| handler-iac-terraform | Terraform | Infrastructure | 1 |

---

## See Also

- [Commands Reference](commands.md)
- [Agents Reference](agents.md)
- [Architecture](../architecture/ARCHITECTURE.md)
- [User Guide](../guides/user-guide.md)
