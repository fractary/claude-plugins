# Fractary faber-cloud Plugin

**Version:** 2.3.1

Comprehensive cloud infrastructure lifecycle management plugin for Claude Code.

Focus: Infrastructure architecture, engineering, deployment, and lifecycle management (FABER framework for cloud).


---

## What's New in v2.3.0 (SPEC-00030)

**Infrastructure Adoption & Migration**: Comprehensive support for adopting existing infrastructure into faber-cloud

- `adopt` - Discover and adopt existing infrastructure with automated analysis
  - Discovers Terraform structure (flat, modular, multi-environment)
  - Identifies AWS profiles and environments
  - Catalogs custom scripts and agents
  - Generates faber-cloud configuration automatically
  - Assesses complexity and migration timeline
  - Creates comprehensive migration reports

**Enhanced Environment Validation** (SPEC-00030-02):
- Multi-signal validation (AWS profile, state file, workspace, directory)
- Prevents cross-environment deployments
- Production safety through multiple validation layers
- Configurable validation rules per template

**Lifecycle Hook System** (SPEC-00030-01, SPEC-00034):
- Pre/post hooks at 6 lifecycle points (plan, deploy, destroy)
- **Script hooks** for shell commands and build steps
- **Skill hooks** for reusable Claude Code skills (NEW in v2.3.1)
- Custom logic injection (build, validate, notify, backup)
- Structured interfaces (WorkflowContext/WorkflowResult)
- Critical vs non-critical hooks with failure handling
- Template variables for environment-aware scripts
- 13+ real-world examples including skill hooks

**Migration from Custom Agents**:
- Capability mapping from custom scripts to faber-cloud features
- Hook integration guide for preserving custom logic
- Step-by-step migration checklist
- Rollback procedures and risk assessment
- Comprehensive troubleshooting guide

**Configuration Templates**:
- Flat: Simple single-directory structure
- Modular: Shared modules for code reuse
- Multi-Environment: Per-environment directories with promotion paths
- Auto-selection based on discovered structure

**Documentation Suite**:
- [Migration from Custom Agents](docs/guides/MIGRATION-FROM-CUSTOM-AGENTS.md) - Complete migration guide
- [Hook System](docs/guides/HOOKS.md) - Lifecycle hooks with 11+ examples
- [Configuration Templates](docs/guides/CONFIGURATION-TEMPLATES.md) - Template reference
- [Troubleshooting](docs/guides/TROUBLESHOOTING.md) - Comprehensive issue resolution

---

## What's New in v2.4.0 - FABER Workflow Integration

**Complete FABER Workflow Support** (#162): Infrastructure lifecycle orchestration using FABER framework

- **Workflow-Based Execution**: Complete Frame → Architect → Build → Evaluate → Release workflows for infrastructure
  - `infrastructure-deploy` - Standard deployment workflow (Guarded autonomy)
  - `infrastructure-audit` - Non-destructive audit and compliance (Autonomous)
  - `infrastructure-teardown` - Safe infrastructure destruction (Assist autonomy)

- **Workflow Files**: Workflows defined in separate JSON files instead of inline configuration
  - Template-copy pattern: Plugin workflows copied to project during init
  - Location: `.fractary/plugins/faber-cloud/workflows/*.json`
  - Reduces config.json size by ~70%
  - Easier customization and versioning

- **Dual-Mode Operation**:
  - **Workflow Mode**: Execute complete FABER workflow for work items
    - Example: `/fractary-faber-cloud:manage 123 --workflow infrastructure-deploy`
  - **Direct Mode**: Execute individual operations (existing behavior)
    - Example: `/fractary-faber-cloud:manage deploy-apply --env test`

- **Work Item Integration**: Associate infrastructure changes with GitHub Issues, Jira, or Linear
  - Automatic branch creation from work items
  - Specification generation and review
  - Pull request creation with deployment documentation

- **Enhanced Autonomy Control**:
  - Guarded: Pauses before deployment for approval (recommended for production)
  - Assist: Requires approval at each major step
  - Autonomous: Fully automated (audit workflows only)
  - Dry-run: Preview without making changes

**Documentation**:
- [Workflow Guide](config/workflows/README.md) - Complete workflow documentation with examples
- [Configuration Schema](config/config.schema.json) - Updated schema with workflow support

**Migration**: Existing configurations continue to work. Workflows are opt-in through `/fractary-faber-cloud:init`

---

## What's New in v2.2.0 (SPEC-00013)

**Command Reorganization**: Commands renamed for clarity and FABER phase alignment
- `architect` (was `design` - aligns with FABER Architect phase)
- `engineer` (was `configure` - better describes IaC generation)
- `deploy-apply` (matches Terraform terminology - terraform apply)
- `teardown` (clearer intent than deploy-destroy - opposite of deploy)
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
- Configuration: `devops.json` → `faber-cloud.json` → `config.json` (automatic migration)
- All skills updated: `devops-common` → `cloud-common`

---

## Migration from v2.1

**Command Name Changes (v2.2.0 - SPEC-00013):**
- `/fractary-faber-cloud:design` → `/fractary-faber-cloud:architect`
- `/fractary-faber-cloud:configure` → `/fractary-faber-cloud:engineer`
- `/fractary-faber-cloud:deploy-execute` → `/fractary-faber-cloud:deploy-apply`
- `/fractary-faber-cloud:deploy-destroy` → `/fractary-faber-cloud:teardown`
- `/fractary-faber-cloud:resources` → `/fractary-faber-cloud:list`

**New Command:**
- `/fractary-faber-cloud:audit` - Infrastructure health and drift detection

**⚠️ BREAKING CHANGE**: Old command names have been removed. Update all references to use new command names.

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

### Option A: Adopt Existing Infrastructure (Recommended for existing projects)

```bash
# Discover and adopt existing Terraform infrastructure
/fractary-faber-cloud:adopt

# This will:
# - Discover your Terraform structure
# - Identify AWS profiles and environments
# - Generate faber-cloud configuration automatically
# - Create comprehensive migration report
# - Install configuration (with your approval)
```

See [Migration from Custom Agents](docs/guides/MIGRATION-FROM-CUSTOM-AGENTS.md) for complete adoption guide.

### Option B: Initialize New Project

```bash
# In your project directory
/fractary-faber-cloud:init --provider=aws --iac=terraform
```

This creates `.fractary/plugins/faber-cloud/config.json` with your project configuration.

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
/fractary-faber-cloud:director "architect an S3 bucket for user uploads"
/fractary-faber-cloud:director "deploy to production"
/fractary-faber-cloud:director "validate my terraform configuration"

# Operations examples
/fractary-faber-cloud:director "check if production is healthy"
/fractary-faber-cloud:director "investigate errors in API service"
/fractary-faber-cloud:director "show me the logs from Lambda"
/fractary-faber-cloud:director "analyze costs for test environment"
```

### Infrastructure Commands

#### FABER Workflow Mode (NEW in v2.4.0)

Execute complete workflows for work items:

```bash
# Standard deployment workflow (Frame → Architect → Build → Evaluate → Release)
/fractary-faber-cloud:manage 123
/fractary-faber-cloud:manage 123 --workflow infrastructure-deploy

# Non-destructive audit workflow
/fractary-faber-cloud:manage 456 --workflow infrastructure-audit

# Safe infrastructure teardown workflow
/fractary-faber-cloud:manage 789 --workflow infrastructure-teardown

# Override autonomy level
/fractary-faber-cloud:manage 123 --autonomy dry-run
```

See [Workflow Guide](config/workflows/README.md) for detailed workflow documentation.

#### Direct Commands

Individual infrastructure operations:

```bash
# Initialize plugin configuration
/fractary-faber-cloud:init --provider=aws --iac=terraform

# Adopt existing infrastructure (v2.3.0)
/fractary-faber-cloud:adopt
/fractary-faber-cloud:adopt --project-root=./my-project
/fractary-faber-cloud:adopt --dry-run

# Design infrastructure architecture
/fractary-faber-cloud:architect "API service with database"

# Generate Terraform code
/fractary-faber-cloud:engineer api-service

# Validate configuration
/fractary-faber-cloud:validate --env=test

# Run tests (security, cost, compliance)
/fractary-faber-cloud:test --env=test --phase=pre-deployment

# Audit infrastructure (non-destructive)
/fractary-faber-cloud:audit --env=test --check=drift

# Preview changes
/fractary-faber-cloud:deploy-plan --env=test

# Deploy infrastructure
/fractary-faber-cloud:deploy-apply --env=test

# Check status
/fractary-faber-cloud:status --env=test

# List deployed resources
/fractary-faber-cloud:list --env=test

# Debug errors
/fractary-faber-cloud:debug --error="<error message>"
```

**Legacy command (removed in v2.2.0):**
```bash
# OLD (no longer works):
/fractary-faber-cloud:infra-manage deploy --env=test

# NEW (use instead):
/fractary-faber-cloud:deploy-apply --env=test
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
- Workflow: architect → engineer → validate → test → audit → deploy-plan → deploy-apply
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

## Hook System

### Extension Hooks

Extend faber-cloud with custom logic at lifecycle points using **script hooks** or **skill hooks**:

**Script Hooks** (traditional):
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "script",
        "path": "./scripts/build-lambda.sh",
        "required": true,
        "timeout": 300
      }
    ]
  }
}
```

**Skill Hooks** (NEW - reusable, testable):
```json
{
  "hooks": {
    "pre-deploy": [
      {
        "type": "skill",
        "name": "dataset-validator-deploy-pre",
        "required": true,
        "failureMode": "stop",
        "timeout": 300
      }
    ]
  }
}
```

**Benefits of Skill Hooks:**
- ✅ **Reusable** across projects
- ✅ **Testable** independently via `/skill skill-name`
- ✅ **Discoverable** via `/help`
- ✅ **Structured interfaces** (WorkflowContext/WorkflowResult)
- ✅ **Type-safe** with JSON schemas

**When to use each:**
- **Script hooks**: Simple operations (build, notify, backup)
- **Skill hooks**: Complex validation logic you want to test and share

**Available hook points:**
- `pre-plan` / `post-plan` - Around terraform plan
- `pre-deploy` / `post-deploy` - Around terraform apply
- `pre-destroy` / `post-destroy` - Around terraform destroy

See [Hook System Guide](docs/guides/HOOKS.md) for complete documentation and [Skill Hook Examples](docs/examples/skill-hooks/) for working examples.

## Configuration

Configuration file: `.fractary/plugins/faber-cloud/config.json`

**Migration**: Old `faber-cloud.json` files are automatically renamed to `config.json` when loaded.

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

**Using direct commands:**

```bash
# 1. Design infrastructure architecture
/fractary-faber-cloud:architect "API service with RDS database"
# → Creates design document

# 2. Generate Terraform code
/fractary-faber-cloud:engineer api-service
# → Generates main.tf, variables.tf, outputs.tf

# 3. Validate and test
/fractary-faber-cloud:validate --env=test
/fractary-faber-cloud:test --env=test --phase=pre-deployment
# → Security scans, cost estimation

# 4. Audit infrastructure (optional)
/fractary-faber-cloud:audit --env=test --check=full
# → Pre-deployment health check

# 5. Preview changes
/fractary-faber-cloud:deploy-plan --env=test
# → Shows what will be created/changed

# 6. Deploy to test
/fractary-faber-cloud:deploy-apply --env=test
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
/fractary-faber-cloud:director "architect an API service with RDS database"
/fractary-faber-cloud:director "engineer the API service design"
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

**Production Safety Confirmation Protocol:**

When `require_confirmation: true` in environment configuration:
- **2-step confirmation process** before production deployments
- Question 1: Validate deployment readiness
- Question 2: Typed confirmation (must type environment name exactly)
- Deployment aborted if user declines at any step
- See [SECURITY.md](docs/SECURITY.md#production-deployment-safety) for full details

**Configuration:**
```json
{
  "environments": {
    "prod": {
      "require_confirmation": true  // Enables safety protocol
    }
  }
}
```

**Additional Safety Layers:**
- Environment validation (tfvars, workspace, state file consistency)
- Profile separation enforcement (test-deploy vs prod-deploy)
- Production-specific checks (destructive changes, high change count)
- Pre-deployment hooks for custom validation

**CI/CD Integration:**
- Set `DEVOPS_AUTO_APPROVE=true` to bypass interactive confirmation
- Should only be used with proper approval gates
- See [SECURITY.md](docs/SECURITY.md#cicd-integration) for best practices

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
- [Integration Patterns](docs/guides/INTEGRATION-PATTERNS.md) *(NEW in v2.3.1 - Best practices for adopting faber-cloud)*
- [Migration from Custom Agents](docs/guides/MIGRATION-FROM-CUSTOM-AGENTS.md) *(NEW in v2.3.0)*
- [Hook System](docs/guides/HOOKS.md) *(Updated for v2.3.1 - Skill Hooks)*
- [Configuration Templates](docs/guides/CONFIGURATION-TEMPLATES.md) *(NEW in v2.3.0)*
- [Troubleshooting](docs/guides/TROUBLESHOOTING.md) *(Updated for v2.3.0)*

### Examples

- [Skill Hook Examples](docs/examples/skill-hooks/) *(NEW in v2.3.1)*
  - Dataset validation skill
  - WorkflowContext/WorkflowResult interfaces
  - Testing and integration guide

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

**2.3.1 (SPEC-00034 Complete - Skill-Based Hooks):**
- **Skill hooks** - Invoke Claude Code skills at lifecycle points
- Structured WorkflowContext/WorkflowResult interfaces
- Backward compatible (script hooks still work)
- Example skills for dataset validation
- Complete testing suite (14/14 tests passing)

**2.3.0 (SPEC-00030 Complete - Adoption & Migration):**
- Infrastructure adoption and discovery (adopt command)
- Enhanced environment validation (multi-signal validation)
- Lifecycle hook system (6 hook types with script support)
- Configuration templates (flat, modular, multi-environment)
- Migration from custom agents (comprehensive guide)
- Comprehensive documentation suite (4 new guides)
- Complexity assessment and timeline estimation
- Migration reporting with risk analysis
- Configuration generation and validation

**2.2.0 (SPEC-00013 Complete - Command Reorganization):**
- Command renaming for FABER phase alignment
- Audit command for infrastructure observability
- Automated error fixing with --complete flag
- IAM permission audit system
- Environment safety validation

**2.1.0 (Configuration Standardization):**
- Configuration file standardized: devops.json → faber-cloud.json → config.json
- Enhanced AWS profile management
- Improved production safety features
- Automatic migration from old config names

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
- Plan/Preview (infra-planner)
- Deployment (infra-deployer)
- Permission management (infra-permission-manager)
- AWS + Terraform support

### Deprecated Commands (v1.0.0)

**Old commands and agents** from the pre-Phase architecture have been deprecated and archived in `.archive/pre-phase-architecture/`. All functionality is preserved and enhanced in the new architecture.

**Migration Guide:**

| Old Command (v1.0) | v2.1 Command | v2.2 Command (Current) |
|------------|-------------|------------------|
| `/faber-cloud:deploy test` | `/fractary-faber-cloud:deploy-execute --env=test` | `/fractary-faber-cloud:deploy-apply --env=test` |
| `/faber-cloud:validate` | `/fractary-faber-cloud:validate` | `/fractary-faber-cloud:validate` |
| `/faber-cloud:status test` | `/fractary-faber-cloud:resources --env=test` | `/fractary-faber-cloud:list --env=test` |

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
