# Fractary DevOps Plugin

**Version:** 1.0.0 (Phase 4 Complete)

Comprehensive DevOps automation for Claude Code - infrastructure lifecycle, testing, debugging, and runtime operations.

## Overview

The Fractary DevOps plugin provides end-to-end DevOps automation from infrastructure design through production operations. It features natural language commands, intelligent error debugging with learning, comprehensive testing, and runtime monitoring.

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
/fractary-devops:init --provider=aws --iac=terraform
```

This creates `.fractary/plugins/devops/config/devops.json` with your project configuration.

### 2. Deploy Infrastructure

Using natural language:
```bash
/fractary-devops:director "deploy my infrastructure to test"
```

Or direct command:
```bash
/fractary-devops:infra-manage deploy --env=test
```

### 3. Monitor Operations

Check health of deployed services:
```bash
/fractary-devops:director "check health of my services"
```

Or direct command:
```bash
/fractary-devops:ops-manage check-health --env=test
```

## Commands

### Natural Language Entry Point

#### /fractary-devops:director

Route natural language requests to appropriate operations:

```bash
# Infrastructure examples
/fractary-devops:director "design an S3 bucket for user uploads"
/fractary-devops:director "deploy to production"
/fractary-devops:director "validate my terraform configuration"

# Operations examples
/fractary-devops:director "check if production is healthy"
/fractary-devops:director "investigate errors in API service"
/fractary-devops:director "show me the logs from Lambda"
/fractary-devops:director "analyze costs for test environment"
```

### Infrastructure Commands

#### /fractary-devops:infra-manage

Manage infrastructure lifecycle:

```bash
# Design infrastructure
/fractary-devops:infra-manage architect --feature="API service with database"

# Generate Terraform code
/fractary-devops:infra-manage engineer --design=api-service.md

# Validate configuration
/fractary-devops:infra-manage validate-config --env=test

# Run tests (security, cost, compliance)
/fractary-devops:infra-manage test --env=test --phase=pre-deployment

# Preview changes
/fractary-devops:infra-manage preview-changes --env=test

# Deploy infrastructure
/fractary-devops:infra-manage deploy --env=test

# Show deployed resources
/fractary-devops:infra-manage show-resources --env=test

# Debug errors
/fractary-devops:infra-manage debug --error="<error message>"
```

### Operations Commands

#### /fractary-devops:ops-manage

Manage runtime operations:

```bash
# Check health
/fractary-devops:ops-manage check-health --env=prod

# Query logs
/fractary-devops:ops-manage query-logs --env=prod --service=api-lambda --filter=ERROR

# Investigate incidents
/fractary-devops:ops-manage investigate --env=prod --service=api-lambda --timeframe=2h

# Analyze performance
/fractary-devops:ops-manage analyze-performance --env=prod --service=api-lambda

# Apply remediation
/fractary-devops:ops-manage remediate --env=prod --service=api-lambda --action=restart

# Audit costs/security
/fractary-devops:ops-manage audit --env=test --focus=cost
```

### Configuration Command

#### /fractary-devops:init

Initialize plugin configuration:

```bash
/fractary-devops:init --provider=aws --iac=terraform
/fractary-devops:init --provider=aws --iac=terraform --env=test
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

Configuration file: `.fractary/plugins/devops/config/devops.json`

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

```bash
# 1. Design infrastructure
/fractary-devops:director "design an API service with RDS database"
# → Creates design document

# 2. Generate Terraform code
/fractary-devops:director "implement the API service design"
# → Generates main.tf, variables.tf, outputs.tf

# 3. Deploy to test
/fractary-devops:director "deploy to test environment"
# → Security scans (Checkov, tfsec)
# → Cost estimation
# → Preview changes
# → User approval
# → Execute deployment
# → Post-deployment verification
# → Health checks
# → Registry updated
# → DEPLOYED.md generated

# 4. Monitor health
/fractary-devops:director "check health of test services"
# → CloudWatch metrics
# → Status report

# If errors occur:
# → infra-debugger analyzes
# → Solution proposed
# → Automated fix if possible
# → Retry deployment
```

### Incident Response Workflow

```bash
# 1. Detect issue
/fractary-devops:director "check health of production"
# → Identifies degraded Lambda

# 2. Investigate
/fractary-devops:director "investigate API Lambda errors"
# → Queries CloudWatch logs
# → Correlates events
# → Identifies root cause: Database connections exhausted

# 3. Remediate
/fractary-devops:director "restart API Lambda in production"
# → Impact assessment
# → User confirmation (production)
# → Restart service
# → Verify health
# → Document remediation

# 4. Audit and optimize
/fractary-devops:director "analyze costs for production"
# → Cost breakdown
# → Optimization recommendations
# → Potential savings identified
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

Location: `.fractary/plugins/devops/test-reports/{env}/`

Format: JSON with detailed findings, severity levels, recommendations

## Documentation

### Auto-Generated Documentation

**Resource Registry:**
- Machine-readable JSON
- Complete resource metadata
- Location: `.fractary/plugins/devops/deployments/{env}/registry.json`

**DEPLOYED.md:**
- Human-readable Markdown
- Organized by resource type
- AWS Console links
- Location: `.fractary/plugins/devops/deployments/{env}/DEPLOYED.md`

**Issue Log:**
- Historical error database
- Solution success rates
- Location: `.fractary/plugins/devops/deployments/issue-log.json`

**IAM Audit Trail:**
- Complete permission history
- Timestamps and reasons
- Location: `.fractary/plugins/devops/deployments/iam-audit.json`

### User Guides

- [Getting Started](docs/guides/getting-started.md)
- [User Guide](docs/guides/user-guide.md)
- [Troubleshooting](docs/guides/troubleshooting.md)

### Reference Documentation

- [Commands Reference](docs/reference/commands.md)
- [Agents Reference](docs/reference/agents.md)
- [Skills Reference](docs/reference/skills.md)

### Architecture Documentation

- [Architecture Overview](ARCHITECTURE.md)
- [Detailed Architecture](docs/specs/fractary-devops-architecture.md)
- [Implementation Phases](docs/specs/fractary-devops-implementation-phases.md)

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
# Plugin is in: claude-plugins/plugins/fractary-devops/
```

### Manual Installation

1. Download from GitHub
2. Extract to `~/.claude-code/plugins/fractary-devops/`
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
| `/devops:deploy test` | `/fractary-devops:infra-manage deploy --env=test` | `/fractary-devops:director "deploy to test"` |
| `/devops:validate` | `/fractary-devops:infra-manage validate-config` | `/fractary-devops:director "validate configuration"` |
| `/devops:status test` | `/fractary-devops:infra-manage show-resources --env=test` | `/fractary-devops:director "show test resources"` |

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
