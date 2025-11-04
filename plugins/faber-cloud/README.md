# Fractary faber-cloud Plugin

**Version:** 2.2.0

Comprehensive cloud infrastructure lifecycle management plugin for Claude Code.

Focus: Infrastructure architecture, engineering, deployment, and lifecycle management (FABER framework for cloud).

> **📋 Note**: This README contains examples using old command names from v2.1. See [Migration from v2.1](#migration-from-v21) for command name changes. A comprehensive documentation update is in progress.

---

## What's New in v2.2.0 (SPEC-0013)

**Command Reorganization**: Commands renamed for clarity and FABER phase alignment
- `architect` (was `design` - aligns with FABER Architect phase)
- `engineer` (was `configure` - better describes IaC generation)
- `deploy-execute` (was `deploy-apply` - clearer intent)
- `deploy-destroy` (was `teardown` - parallel naming with deploy-execute)
- `list` (was `resources` - simpler, more intuitive)

**New Commands**:
- `audit` - Infrastructure observability without modification (corthos pattern)
  - Fast targeted checks: config-valid, iam-health, drift, cost, security
  - Comprehensive full audit
  - Pre/post-deployment verification
  - Non-destructive, safe for production

**Continuing from v2.1.0**:
- `init` - Plugin configuration wizard
- `deploy-plan` - Preview deployment changes
- `validate` - Terraform syntax validation
- `test` - Security scans and cost estimation
- `manage` - Unified management interface

**Enhanced Automation**:
- **Automated error fixing** with `--complete` flag on debug command
- **IAM permission audit system** with complete traceability
- **Environment safety validation** prevents multi-environment bugs

**Architecture Clarity**:
- Removed all "devops" naming for clear focus on infrastructure lifecycle
- Configuration: `devops.json` → `faber-cloud.json` (backward compatible in v2.1.x)
- All skills updated: `devops-common` → `cloud-common`

---

## Migration from v2.1

**Command Name Changes (v2.2.0 - SPEC-0013):**
- `/fractary-faber-cloud:design` → `/fractary-faber-cloud:architect`
- `/fractary-faber-cloud:configure` → `/fractary-faber-cloud:engineer`
- `/fractary-faber-cloud:deploy-apply` → `/fractary-faber-cloud:deploy-execute`
- `/fractary-faber-cloud:teardown` → `/fractary-faber-cloud:deploy-destroy`
- `/fractary-faber-cloud:resources` → `/fractary-faber-cloud:list`

**New Command:**
- `/fractary-faber-cloud:audit` - Infrastructure health and drift detection

**No Breaking Changes**: Old command names supported with deprecation warnings until v3.0

---

## Overview

The Fractary FABER Cloud plugin (v2.0.0) provides infrastructure lifecycle management following the FABER workflow:

- **Frame:** Understand requirements and context
- **Architect:** Design infrastructure solutions
- **Build:** Generate Terraform/IaC code
- **Evaluate:** Test security, cost, and compliance
- **Release:** Deploy to AWS/cloud

**What's included:**
- Infrastructure design and architecture
- Terraform code generation
- Security scanning and cost estimation
- Deployment automation
- Intelligent error debugging

**What's NOT included (use helm-cloud instead):**
- Health monitoring
- Log analysis and investigation
- Incident remediation
- Cost/security auditing of running systems

### Key Features

**Infrastructure Management:**
- Design infrastructure solutions from natural language requirements
- Generate Terraform IaC code automatically
- Validate, test, preview, and deploy with safety checks
- Auto-fix permission errors via intelligent delegation
- Track all deployed resources with AWS Console links

**Testing & Debugging:**
- Pre-deployment security scans (Checkov, tfsec)
- Cost estimation with budget validation
- Post-deployment verification tests
- Intelligent error categorization and solution matching
- Learning system that improves over time

**Runtime Operations:**
- Health monitoring with CloudWatch metrics
- Log analysis and incident investigation
- Automated remediation (restart, scale services)
- Cost optimization recommendations
- Security and compliance auditing

**Natural Language Interface:**
- Plain English commands via devops-director
- Automatic intent parsing and routing
- Context-aware command mapping

## Quick Start

### 1. Initialize Plugin

```bash
# In your project directory
/fractary-faber-cloud:init --provider=aws --iac=terraform
```

This creates `.fractary/plugins/faber-cloud/config/faber-cloud.json` with your project configuration.

### 2. Deploy Infrastructure

Using natural language:
```bash
/fractary-faber-cloud:director "deploy my infrastructure to test"
```

Or direct command:
```bash
/fractary-faber-cloud:infra-manage deploy --env=test
```

### 3. Monitor Operations

Check health of deployed services:
```bash
/fractary-faber-cloud:director "check health of my services"
```

Or direct command:
```bash
/fractary-faber-cloud:ops-manage check-health --env=test
```

## Commands

### Natural Language Entry Point

#### /fractary-faber-cloud:director

Route natural language requests to appropriate operations:

```bash
# Infrastructure examples
/fractary-faber-cloud:director "design an S3 bucket for user uploads"
/fractary-faber-cloud:director "deploy to production"
/fractary-faber-cloud:director "validate my terraform configuration"

# Operations examples
/fractary-faber-cloud:director "check if production is healthy"
/fractary-faber-cloud:director "investigate errors in API service"
/fractary-faber-cloud:director "show me the logs from Lambda"
/fractary-faber-cloud:director "analyze costs for test environment"
```

### Infrastructure Commands (Simplified)

**New direct commands (Phase 1):**

```bash
# Design infrastructure
/fractary-faber-cloud:architect "API service with database"

# Generate Terraform code
/fractary-faber-cloud:engineer api-service

# Validate configuration
/fractary-faber-cloud:validate --env=test

# Run tests (security, cost, compliance)
/fractary-faber-cloud:test --env=test --phase=pre-deployment

# Preview changes
/fractary-faber-cloud:preview --env=test

# Deploy infrastructure
/fractary-faber-cloud:deploy --env=test

# Check status
/fractary-faber-cloud:status --env=test

# Show deployed resources
/fractary-faber-cloud:resources --env=test

# Debug errors
/fractary-faber-cloud:debug --error="<error message>"
```

**Legacy command (deprecated but still works):**
```bash
/fractary-faber-cloud:infra-manage deploy --env=test
# Shows deprecation warning, delegates to /fractary-faber-cloud:deploy
```

### Operations Commands

**⚠️ REMOVED in v2.0.0 - Use helm-cloud plugin:**

Operations monitoring has been completely removed from faber-cloud. Use the `helm-cloud` plugin instead:

```bash
# Check health
/fractary-helm-cloud:health --env=prod

# Investigate incidents
/fractary-helm-cloud:investigate --env=prod

# Apply remediation
/fractary-helm-cloud:remediate --env=prod --service=api-lambda --action=restart

# Audit costs/security
/fractary-helm-cloud:audit --type=cost --env=test

# Unified dashboard (all domains)
/fractary-helm:dashboard
```

See [helm-cloud documentation](../helm-cloud/docs/README.md) for details.

**Breaking change:**
```bash
# NO LONGER WORKS in v2.0.0
/fractary-faber-cloud:ops-manage check-health --env=prod
# Error: Command not found

# Use instead:
/fractary-helm-cloud:health --env=prod
```

### Configuration Command

#### /fractary-faber-cloud:init

Initialize plugin configuration:

```bash
/fractary-faber-cloud:init --provider=aws --iac=terraform
/fractary-faber-cloud:init --provider=aws --iac=terraform --env=test
```

## Architecture

### Component Hierarchy

```
Natural Language
  ↓
devops-director (intent parsing & routing)
  ↓
┌─────────────────────┬─────────────────────┐
│  infra-manager      │  ops-manager        │
│  (infrastructure)   │  (operations)       │
└─────────────────────┴─────────────────────┘
  ↓                     ↓
Skills (execution)    Skills (execution)
  ↓                     ↓
Handlers (providers)  Handlers (CloudWatch)
```

### Agents

**devops-director:**
- Natural language router
- Parses intent (infrastructure vs operations)
- Routes to infra-manager or ops-manager

**infra-manager:**
- Infrastructure lifecycle orchestration
- Workflow: design → engineer → validate → test → preview → deploy
- Delegates to infrastructure skills

**ops-manager:**
- Runtime operations orchestration
- Workflow: monitor → investigate → respond → audit
- Delegates to operations skills

### Skills

**Infrastructure Skills (Phase 1):**
- infra-architect: Design solutions
- infra-engineer: Generate Terraform code
- infra-validator: Validate configurations
- infra-previewer: Generate deployment plans
- infra-deployer: Execute deployments
- infra-permission-manager: Manage IAM permissions

**Testing & Debugging Skills (Phase 2):**
- infra-tester: Security scans, cost estimation, verification
- infra-debugger: Error analysis and solution matching

**Operations Skills (Phase 3):**
- ops-monitor: Health checks and metrics
- ops-investigator: Log analysis and incident investigation
- ops-responder: Incident remediation
- ops-auditor: Cost, security, compliance auditing

**Handler Skills:**
- handler-hosting-aws: AWS operations (deploy, verify, CloudWatch)
- handler-iac-terraform: Terraform operations (init, plan, apply)

### Data Flows

**Resource Tracking:**
```
Deploy → Update Registry → Generate DEPLOYED.md → Console URLs
```

**Error Learning:**
```
Error → Categorize → Search Issue Log → Propose Solution → Log Outcome
```

**Health Monitoring:**
```
Check Status → Query CloudWatch → Analyze Metrics → Report Health
```

## Configuration

Configuration file: `.fractary/plugins/faber-cloud/config/devops.json`

### Example Configuration

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
        "var_file_pattern": "{environment}.tfvars"
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
      "cost_threshold": 100
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
- `{project}` - Project name
- `{subsystem}` - Subsystem name
- `{environment}` - Current environment (test/prod)
- `{resource}` - Resource name
- `{organization}` - Organization name

Example: `{project}-{subsystem}-{environment}-{resource}` → `my-project-core-test-database`

## Complete Workflow Example

### End-to-End Infrastructure Deployment

**Using simplified commands (Phase 1):**

```bash
# 1. Design infrastructure
/fractary-faber-cloud:architect "API service with RDS database"
# → Creates design document

# 2. Generate Terraform code
/fractary-faber-cloud:engineer api-service
# → Generates main.tf, variables.tf, outputs.tf

# 3. Validate and test
/fractary-faber-cloud:validate --env=test
/fractary-faber-cloud:test --env=test --phase=pre-deployment
# → Security scans, cost estimation

# 4. Preview changes
/fractary-faber-cloud:preview --env=test
# → Shows what will be created/changed

# 5. Deploy to test
/fractary-faber-cloud:deploy --env=test
# → User approval
# → Execute deployment
# → Post-deployment verification
# → Registry updated
# → DEPLOYED.md generated

# 6. Monitor health (using helm-cloud - Phase 2)
/fractary-helm-cloud:health --env=test
# → CloudWatch metrics
# → Status report

# If errors occur:
/fractary-faber-cloud:debug --error="<error message>"
# → infra-debugger analyzes
# → Solution proposed
# → Automated fix if possible
```

**Using natural language:**

```bash
/fractary-faber-cloud:director "design an API service with RDS database"
/fractary-faber-cloud:director "implement the API service design"
/fractary-faber-cloud:director "deploy to test environment"
/fractary-faber-cloud:director "check health of test services"
```

### Incident Response Workflow

**Using helm-cloud commands (Phase 2):**

```bash
# 1. Detect issue
/fractary-helm-cloud:health --env=prod
# → Identifies degraded Lambda

# 2. Investigate
/fractary-helm-cloud:investigate --env=prod --service=api-lambda
# → Queries CloudWatch logs
# → Correlates events
# → Identifies root cause

# 3. Remediate
/fractary-helm-cloud:remediate --env=prod --service=api-lambda --action=restart
# → Impact assessment
# → User confirmation (production)
# → Restart service
# → Verify health
# → Document remediation

# 4. Audit and optimize
/fractary-helm-cloud:audit --type=cost --env=prod
# → Cost breakdown
# → Optimization recommendations
# → Potential savings identified
```

**Using natural language:**

```bash
/fractary-faber-cloud:director "check health of production"
/fractary-faber-cloud:director "investigate API Lambda errors"
/fractary-faber-cloud:director "restart API Lambda in production"
/fractary-faber-cloud:director "analyze costs for production"
```

## Safety Features

### Production Protection

**Multiple levels of confirmation:**
- Command level: Checks for prod flag
- Manager level: Requires explicit confirmation
- Skill level: Validates environment
- Handler level: Profile separation enforcement

**Production deployments:**
- Always show full preview
- Require typed "yes" confirmation
- Cannot skip with `--auto-approve`
- Extra validation steps

### Permission Management

**AWS Profile Strategy:**
- `{project}-discover-deploy`: IAM management only (temporary use)
- `{project}-test-deploy`: Test deployments (no IAM permissions)
- `{project}-prod-deploy`: Production deployments (no IAM permissions)

**Principle of Least Privilege:**
- Add only specific permissions needed
- Document reason for each permission
- Track all changes in IAM audit trail
- Regular permission reviews

### Error Handling

**Automatic Recovery:**
- Permission errors → Auto-grant via discover profile
- State errors → Guided resolution
- Configuration errors → Clear fix instructions

**Learning System:**
- Errors normalized and logged
- Solutions ranked by success rate
- Recurring issues solved faster
- Continuous improvement

## Testing

### Pre-Deployment Tests

Automatic before deployment:
- Security scans (Checkov, tfsec)
- Cost estimation with budget validation
- Terraform syntax validation
- Naming convention compliance
- Tagging compliance
- Configuration best practices

### Post-Deployment Tests

Automatic after deployment:
- Resource existence verification
- Resource configuration validation
- Security posture checks
- Integration testing
- Health checks
- Monitoring setup verification

### Test Reports

Location: `.fractary/plugins/faber-cloud/test-reports/{env}/`

Format: JSON with detailed findings, severity levels, recommendations

## Documentation

### Auto-Generated Documentation

**Resource Registry:**
- Machine-readable JSON
- Complete resource metadata
- Location: `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`

**DEPLOYED.md:**
- Human-readable Markdown
- Organized by resource type
- AWS Console links
- Location: `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`

**Issue Log:**
- Historical error database
- Solution success rates
- Location: `.fractary/plugins/faber-cloud/deployments/issue-log.json`

**IAM Audit Trail:**
- Complete permission history
- Timestamps and reasons
- Location: `.fractary/plugins/faber-cloud/deployments/iam-audit.json`

### User Guides

- [Getting Started](docs/guides/getting-started.md)
- [User Guide](docs/guides/user-guide.md)
- [Troubleshooting](docs/guides/troubleshooting.md)

### Reference Documentation

- [Commands Reference](docs/reference/commands.md)
- [Agents Reference](docs/reference/agents.md)
- [Skills Reference](docs/reference/skills.md)

### Architecture Documentation

- [Architecture Overview](docs/architecture/ARCHITECTURE.md)
- [Detailed Architecture](docs/specs/fractary-faber-cloud-architecture.md)
- [Implementation Phases](docs/specs/fractary-faber-cloud-implementation-phases.md)

## Performance

**Standard Operations:**
- Health check (10 resources): ~20-35 seconds
- Pre-deployment tests: ~10-25 seconds
- Post-deployment tests: ~15-40 seconds
- Deployment (5 resources): ~2-5 minutes
- Error debugging: ~2-5 seconds

**Optimization:**
- Minimal context per skill invocation
- Workflow files loaded on-demand
- CloudWatch queries optimized
- Caching for frequently-used data

## Requirements

**Required:**
- Claude Code >= 1.0.0
- AWS CLI (for AWS provider)
- Terraform (for Terraform IaC)
- jq (for JSON processing)

**Optional (for testing):**
- Checkov (security scanning)
- tfsec (Terraform security)

**Planned Support:**
- GCP (handler-hosting-gcp)
- Pulumi (handler-iac-pulumi)

## Installation

### Via Git Clone

```bash
cd ~/.claude-code/plugins/
git clone https://github.com/fractary/claude-plugins.git
# Plugin is in: claude-plugins/plugins/fractary-faber-cloud/
```

### Manual Installation

1. Download from GitHub
2. Extract to `~/.claude-code/plugins/fractary-faber-cloud/`
3. Restart Claude Code or reload plugins

## Version History

**1.0.0 (Phase 4 Complete):**
- Natural language interface (devops-director)
- Complete documentation suite
- Error handling improvements
- Production safety enhancements
- Performance optimization

**0.3.0 (Phase 3 Complete):**
- Runtime operations (ops-manager)
- Health monitoring (ops-monitor)
- Incident investigation (ops-investigator)
- Remediation (ops-responder)
- Cost/security auditing (ops-auditor)
- CloudWatch integration

**0.2.0 (Phase 2 Complete):**
- Testing (infra-tester)
- Debugging with learning (infra-debugger)
- Issue log system
- Pre and post-deployment tests
- Security scanning integration
- Cost estimation

**0.1.0 (Phase 1 Complete):**
- Infrastructure management (infra-manager)
- Design (infra-architect)
- Code generation (infra-engineer)
- Validation (infra-validator)
- Preview (infra-previewer)
- Deployment (infra-deployer)
- Permission management (infra-permission-manager)
- AWS + Terraform support

### Deprecated Commands (v1.0.0)

**Old commands and agents** from the pre-Phase architecture have been deprecated and archived in `.archive/pre-phase-architecture/`. All functionality is preserved and enhanced in the new architecture.

**Migration Guide:**

| Old Command | New Command | Natural Language |
|------------|-------------|------------------|
| `/faber-cloud:deploy test` | `/fractary-faber-cloud:infra-manage deploy --env=test` | `/fractary-faber-cloud:director "deploy to test"` |
| `/faber-cloud:validate` | `/fractary-faber-cloud:infra-manage validate-config` | `/fractary-faber-cloud:director "validate configuration"` |
| `/faber-cloud:status test` | `/fractary-faber-cloud:infra-manage show-resources --env=test` | `/fractary-faber-cloud:director "show test resources"` |

**Deprecated agents:** devops-deployer, devops-debugger, devops-permissions (superseded by infra-manager, ops-manager, and skills)

See `.archive/pre-phase-architecture/README.md` for complete migration guide and historical reference.

## Roadmap

**Phase 5: Multi-Provider Expansion:**
- GCP support (handler-hosting-gcp)
- Pulumi support (handler-iac-pulumi)
- Multi-cloud deployments

**Future Phases:**
- Azure support
- CDK and CloudFormation support
- Blue-green deployments
- Canary deployments
- CI/CD integration
- Custom metrics and dashboards

## Contributing

Contributions welcome! Please see [FRACTARY-PLUGIN-STANDARDS.md](../../FRACTARY-PLUGIN-STANDARDS.md) for development patterns.

## License

MIT License

## Support

- Issues: https://github.com/fractary/claude-plugins/issues
- Documentation: [docs/](docs/)
- Plugin Standards: [FRACTARY-PLUGIN-STANDARDS.md](../../FRACTARY-PLUGIN-STANDARDS.md)

## Credits

Created by Fractary for Claude Code.

Part of the Fractary Claude Code Plugins collection.
