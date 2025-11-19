# Fractary DevOps Plugin - Architecture

**Version:** 1.0.0
**Last Updated:** 2025-10-28

## Overview

The Fractary DevOps plugin follows a layered architecture with natural language routing, workflow-oriented managers, single-purpose skills, and provider abstraction through handlers.

## Architecture Layers

```
Layer 1: Natural Language Interface
  devops-director (intent parsing & routing)
  ↓
Layer 2: Entry Points
  Commands (/fractary-faber-cloud:*)
  ↓
Layer 3: Workflow Orchestrators
  infra-manager (infrastructure lifecycle)
  ops-manager (runtime operations)
  ↓
Layer 4: Execution Units
  Skills (infra-*, ops-*)
  ↓
Layer 5: Provider Adapters
  Handlers (handler-hosting-*, handler-iac-*)
```

## Component Responsibilities

### devops-director (Natural Language Router)

**Purpose:** Parse natural language requests and route to appropriate manager

**Workflow:**
1. Parse user's natural language request
2. Identify keywords and intent
3. Determine environment (test/prod)
4. Map to specific command
5. Route to infra-manager or ops-manager

**Examples:**
- "deploy to production" → `/fractary-faber-cloud:infra-manage deploy-apply --env=prod`
- "check health" → `/fractary-faber-cloud:ops-manage check-health`
- "investigate errors" → `/fractary-faber-cloud:ops-manage investigate`

### infra-manager (Infrastructure Lifecycle)

**Purpose:** Own complete infrastructure workflow from design through deployment

**Workflow:**
```
architect → engineer → validate → test → deploy-plan → deploy-apply → (debug if needed)
```

**Delegations:**
- architect → infra-architect skill
- engineer → infra-engineer skill
- validate → infra-validator skill
- test → infra-tester skill
- deploy-plan → infra-previewer skill
- deploy-apply → infra-deployer skill
- debug → infra-debugger skill

**Commands:** architect, engineer, validate-config, test-changes, preview-changes, deploy, show-resources, check-status, debug

### ops-manager (Runtime Operations)

**Purpose:** Own complete operations workflow from monitoring through remediation

**Workflow:**
```
monitor → investigate → respond → audit
```

**Delegations:**
- check-health → ops-monitor skill
- query-logs → ops-investigator skill
- investigate → ops-investigator skill
- analyze-performance → ops-monitor skill
- remediate → ops-responder skill
- audit → ops-auditor skill

**Commands:** check-health, query-logs, investigate, analyze-performance, remediate, audit

## Skills

### Infrastructure Skills (Phase 1)

**infra-architect:**
- Analyzes feature requirements
- Designs AWS infrastructure solutions
- Creates design documents

**infra-engineer:**
- Reads design documents
- Generates Terraform code (main.tf, variables.tf, outputs.tf)
- Applies naming patterns and tagging

**infra-validator:**
- Validates Terraform syntax
- Checks configuration correctness
- Verifies security settings

**infra-previewer:**
- Generates Terraform execution plans
- Shows resources to add/change/destroy
- Highlights destructive changes

**infra-deployer:**
- Executes Terraform deployments
- Verifies resource creation
- Updates resource registry
- Generates deployment documentation

**infra-permission-manager:**
- Manages IAM permissions
- Auto-grants missing permissions
- Environment-scoped permissions
- Complete IAM audit trail

### Testing & Debugging Skills (Phase 2)

**infra-tester:**
- Pre-deployment: Security scanning, cost estimation, compliance
- Post-deployment: Resource verification, health checks, integration tests
- Test reporting with severity categorization

**infra-debugger:**
- Error categorization (permission/config/resource/state/network/quota)
- Solution search from issue log
- Solution ranking by success rate and relevance
- Automated fix proposals

### Operations Skills (Phase 3)

**ops-monitor:**
- Health checks across all resource types
- CloudWatch metrics collection
- Performance analysis and trending
- Anomaly detection

**ops-investigator:**
- CloudWatch logs queries
- Event correlation across services
- Timeline generation for incidents
- Root cause analysis

**ops-responder:**
- Service restart (Lambda, ECS)
- Resource scaling
- Configuration updates
- Remediation verification

**ops-auditor:**
- Cost analysis with optimization recommendations
- Security posture assessment
- Compliance checking
- Historical audits

## Handlers

### handler-hosting-aws

**Purpose:** Centralize all AWS-specific operations

**Operations:**
- authenticate: Set up AWS credentials
- deploy: Deploy AWS resources
- verify: Verify deployed resources
- query: Query resource state
- delete: Remove resources
- get-resource-status: Current status of resources
- query-metrics: CloudWatch metrics
- query-logs: CloudWatch logs
- restart-service: Restart Lambda/ECS
- scale-service: Scale ECS/Lambda

**Configuration:**
```json
{
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": {
        "region": "us-east-1",
        "profiles": {
          "discover": "project-discover-deploy",
          "test": "project-test-deploy",
          "prod": "project-prod-deploy"
        }
      }
    }
  }
}
```

### handler-iac-terraform

**Purpose:** Centralize all Terraform-specific operations

**Operations:**
- init: Initialize Terraform
- validate: Validate configuration
- plan: Generate execution plan
- apply: Apply changes
- destroy: Destroy resources

**Configuration:**
```json
{
  "handlers": {
    "iac": {
      "active": "terraform",
      "terraform": {
        "directory": "./infrastructure/terraform",
        "var_file_pattern": "{environment}.tfvars"
      }
    }
  }
}
```

## Data Flows

### Infrastructure Deployment Flow

```
User request
  ↓
devops-director (parse intent)
  ↓
infra-manager (orchestrate workflow)
  ↓
┌─────────────────────────────────────────┐
│ 1. infra-tester (pre-deployment)        │
│    - Security scans                     │
│    - Cost estimation                    │
│    - Compliance checks                  │
└─────────────────────────────────────────┘
  ↓ (if PASS)
┌─────────────────────────────────────────┐
│ 2. infra-previewer                      │
│    - Generate terraform plan            │
│    → handler-iac-terraform (plan)       │
└─────────────────────────────────────────┘
  ↓ (user approves)
┌─────────────────────────────────────────┐
│ 3. infra-deployer                       │
│    → handler-hosting-aws (authenticate) │
│    → handler-iac-terraform (apply)      │
│    → handler-hosting-aws (verify)       │
│    - Update registry                    │
│    - Generate DEPLOYED.md               │
└─────────────────────────────────────────┘
  ↓ (if success)
┌─────────────────────────────────────────┐
│ 4. infra-tester (post-deployment)       │
│    - Resource verification              │
│    - Health checks                      │
│    - Integration tests                  │
└─────────────────────────────────────────┘
```

### Error Debugging Flow

```
Deployment fails
  ↓
infra-manager catches error
  ↓
┌─────────────────────────────────────────┐
│ infra-debugger                          │
│  1. Categorize error                    │
│  2. Normalize error message             │
│  3. Search issue log                    │
│  4. Rank solutions by success rate      │
│  5. Propose best solution               │
└─────────────────────────────────────────┘
  ↓
If permission error & automated:
┌─────────────────────────────────────────┐
│ infra-permission-manager                │
│  1. Switch to discover profile          │
│  2. Grant missing permission            │
│  3. Log in IAM audit trail              │
│  4. Return to infra-manager             │
└─────────────────────────────────────────┘
  ↓
infra-manager retries deployment
```

### Operations Monitoring Flow

```
User request
  ↓
devops-director (parse intent)
  ↓
ops-manager (orchestrate workflow)
  ↓
┌─────────────────────────────────────────┐
│ ops-monitor                             │
│  1. Load resource registry              │
│  2. Query resource status               │
│     → handler-hosting-aws               │
│  3. Query CloudWatch metrics            │
│     → handler-hosting-aws               │
│  4. Analyze health                      │
│  5. Generate report                     │
└─────────────────────────────────────────┘
  ↓
ops-manager returns results to user
```

## Documentation Systems

### Resource Registry

**Location:** `.fractary/plugins/faber-cloud/deployments/{env}/registry.json`

**Purpose:** Machine-readable registry of all deployed resources

**Contents:**
- Resource ARNs and IDs
- Resource types and names
- AWS Console URLs
- Deployment timestamps
- Configuration metadata

### DEPLOYED.md

**Location:** `.fractary/plugins/faber-cloud/deployments/{env}/DEPLOYED.md`

**Purpose:** Human-readable deployment documentation

**Contents:**
- Resources organized by type
- Console links for quick access
- Deployment history
- Current status

### Issue Log

**Location:** `.fractary/plugins/faber-cloud/deployments/issue-log.json`

**Purpose:** Historical error database for learning

**Contents:**
- Normalized error patterns
- Multiple solutions per issue
- Success rate tracking
- Resolution history
- Automation capabilities

### IAM Audit Trail

**Location:** `.fractary/plugins/faber-cloud/deployments/iam-audit.json`

**Purpose:** Complete history of IAM permission changes

**Contents:**
- Timestamp of each change
- Permissions added
- Reason for addition
- Original error that triggered addition
- Who/what added the permission

## Configuration-Driven Behavior

All behavior determined by single config file:

`.fractary/plugins/faber-cloud/devops.json`

**Pattern Substitution:**
- `{project}` - Project name
- `{subsystem}` - Subsystem name
- `{environment}` - Current environment
- `{resource}` - Resource name
- `{organization}` - Organization name

**Handler Selection:**
```json
{
  "handlers": {
    "hosting": {"active": "aws"},
    "iac": {"active": "terraform"}
  }
}
```

Skills read config and invoke: `handler-hosting-${hosting.active}` and `handler-iac-${iac.active}`

## Safety Features

### Defense in Depth

**Production Safety Enforced At:**
1. Command level: Check for prod flag
2. Director level: Pass prod flag to manager
3. Manager level: Require confirmation for prod
4. Skill level: Validate environment is prod
5. Handler level: Use correct AWS profile

### AWS Profile Separation

**Three profiles enforced:**
- `{project}-discover-deploy`: IAM management only (temporary)
- `{project}-test-deploy`: Test deployments (no IAM permissions)
- `{project}-prod-deploy`: Production deployments (no IAM permissions)

**Validation:**
- Skills check current profile matches expected profile
- Handler verifies profile before any AWS operation
- Error if wrong profile detected

### Permission Management

**Principle of Least Privilege:**
- Start with minimal permissions
- Add specific permissions as needed
- Document reason for each permission
- Track all changes in audit trail
- Regular permission reviews

## Error Handling

### Error Categories

1. **Permission Errors:** Auto-fixable via infra-permission-manager
2. **Configuration Errors:** Manual fix required (clear instructions provided)
3. **Resource Errors:** Manual resolution (options presented)
4. **State Errors:** Guided resolution (backend issues)
5. **Network Errors:** Retry logic with backoff
6. **Quota Errors:** Manual resolution (increase limits)

### Learning System

**How it learns:**
1. Error normalized (remove variable identifiers)
2. Error logged with context
3. Solution attempted and outcome recorded
4. Success rate updated
5. Future occurrences use highest success rate solution

**Improvement over time:**
- First occurrence: No solution available
- Second occurrence: One solution from history
- Third+ occurrence: Multiple solutions ranked by success rate

## Performance Characteristics

**Target Performance:**
- Health check (10 resources): <30 seconds
- Pre-deployment tests: <30 seconds
- Post-deployment tests: <45 seconds
- Deployment (5 resources): <5 minutes
- Error debugging: <10 seconds

**Optimization Strategies:**
- Minimal context per skill invocation
- Workflow files loaded on-demand
- CloudWatch queries optimized with filters
- Caching for frequently-accessed config
- Parallel operations where possible

## Extensibility

### Adding New Provider

1. Create `handler-hosting-{provider}` skill
2. Implement standard operations interface
3. Update configuration schema
4. All existing skills work automatically

### Adding New IaC Tool

1. Create `handler-iac-{tool}` skill
2. Implement standard operations interface
3. Update configuration schema
4. All existing skills work automatically

## File Structure

```
plugins/fractary-faber-cloud/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── cloud-director.md         (Phase 4)
│   └── infra-manager.md          (Phase 1)
├── commands/
│   ├── director.md               (Phase 4)
│   ├── init.md                   (Phase 1)
│   ├── architect.md              (Phase 1)
│   ├── engineer.md               (Phase 1)
│   ├── validate.md               (Phase 1)
│   ├── test.md                   (Phase 2)
│   ├── audit.md                  (SPEC-00013)
│   ├── deploy-plan.md            (Phase 1)
│   ├── deploy-apply.md           (Phase 1)
│   ├── teardown.md               (Phase 2)
│   ├── list.md                   (Phase 1)
│   ├── status.md                 (Phase 1)
│   ├── debug.md                  (Phase 2)
│   └── manage.md                 (Phase 1)
├── skills/
│   ├── devops-common/            (Phase 1)
│   ├── infra-architect/          (Phase 1)
│   ├── infra-engineer/           (Phase 1)
│   ├── infra-validator/          (Phase 1)
│   ├── infra-previewer/          (Phase 1)
│   ├── infra-deployer/           (Phase 1)
│   ├── infra-permission-manager/ (Phase 1)
│   ├── infra-tester/             (Phase 2)
│   ├── infra-debugger/           (Phase 2)
│   ├── ops-monitor/              (Phase 3)
│   ├── ops-investigator/         (Phase 3)
│   ├── ops-responder/            (Phase 3)
│   ├── ops-auditor/              (Phase 3)
│   ├── handler-hosting-aws/      (Phase 1 & 3)
│   └── handler-iac-terraform/    (Phase 1)
├── docs/
│   ├── guides/                   (Phase 4)
│   ├── reference/                (Phase 4)
│   └── specs/                    (All phases)
├── README.md                     (Phase 4)
├── ARCHITECTURE.md               (Phase 4)
├── PHASE-1-COMPLETE.md
├── PHASE-2-COMPLETE.md
├── PHASE-3-COMPLETE.md
└── PHASE-4-COMPLETE.md
```

## Standards Compliance

This plugin follows [FRACTARY-PLUGIN-STANDARDS.md](../../FRACTARY-PLUGIN-STANDARDS.md):

- ✅ Workflow-oriented managers
- ✅ Single-purpose skills
- ✅ Handler abstraction
- ✅ Configuration-driven behavior
- ✅ Documentation atomicity
- ✅ Defense in depth
- ✅ XML markup standards
- ✅ Clear completion criteria

## Next Steps

For detailed information:
- User guides: [docs/guides/](docs/guides/)
- Reference docs: [docs/reference/](docs/reference/)
- Specifications: [docs/specs/](docs/specs/)
- Plugin standards: [FRACTARY-PLUGIN-STANDARDS.md](../../FRACTARY-PLUGIN-STANDARDS.md)
