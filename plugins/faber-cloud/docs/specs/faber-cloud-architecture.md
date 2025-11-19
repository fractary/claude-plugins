# Fractary DevOps Plugin - Architecture

**Version:** 1.0.0
**Status:** Specification
**Last Updated:** 2025-10-28

---

## Table of Contents

1. [Architecture Principles](#architecture-principles)
2. [Component Hierarchy](#component-hierarchy)
3. [Manager Responsibilities](#manager-responsibilities)
4. [Skill Organization](#skill-organization)
5. [Handler System](#handler-system)
6. [Workflow Orchestration](#workflow-orchestration)
7. [Data Flow](#data-flow)
8. [Integration Patterns](#integration-patterns)

---

## Architecture Principles

### 1. Workflow-Oriented Managers

**Principle:** Each manager owns a complete domain workflow from start to finish.

**Rationale:**
- Context flows naturally within workflow
- No coordination overhead between managers
- Clear ownership and responsibility
- Natural mental model

**Example:**
```
infra-manager owns: Design → Engineer → Validate → Test → Preview → Deploy → Debug
ops-manager owns: Monitor → Detect → Investigate → Diagnose → Respond → Remediate
```

### 2. Single-Purpose Skills

**Principle:** Each skill performs one focused task.

**Rationale:**
- Clear, testable units
- Reusable across workflows
- Easy to understand and maintain
- Minimal context per invocation

**Example:**
```
infra-architect: Design infrastructure solutions
infra-deployer: Execute deployments
NOT: infra-everything: Do all infrastructure work
```

### 3. Handler Abstraction

**Principle:** Provider/tool-specific logic isolated in handler skills.

**Rationale:**
- Core skills remain provider-agnostic
- Easy to add new providers/tools
- DRY - no duplication across skills
- Clear interface boundaries

**Example:**
```
infra-deployer (provider-agnostic)
  ↓
handler-hosting-aws (AWS-specific)
handler-hosting-gcp (GCP-specific)
```

### 4. Configuration-Driven Behavior

**Principle:** Single config file determines all runtime behavior.

**Rationale:**
- No code changes to switch providers
- Easy project setup
- Consistent patterns across projects
- Clear configuration surface

### 5. Documentation Atomicity

**Principle:** Skills document their own work as final step.

**Rationale:**
- Documentation always current
- Survives partial workflow failures
- No separate documentation step
- Skills have context to document

### 6. Defense in Depth

**Principle:** Critical rules enforced at multiple levels.

**Rationale:**
- Production safety (never deploy without confirmation)
- Permission separation (never use wrong AWS profile)
- Redundant checks prevent catastrophic errors
- Clear error messages at first violation

**Example - Production Safety:**
```
Command: Checks for prod flag
Director: Routes with prod flag
Manager: Requires confirmation for prod
Skill: Validates environment is prod
```

---

## Component Hierarchy

### Layer 1: Entry Points

**Commands** (`/fractary-faber-cloud:*`)
- Lightweight entry points
- Parse arguments
- Immediately invoke appropriate agent
- NEVER do work directly

**Director** (`devops-director`)
- Natural language router
- Parses intent
- Routes to infra-manager or ops-manager
- NEVER invokes skills directly
- NEVER does work directly

### Layer 2: Workflow Orchestrators

**Managers** (`infra-manager`, `ops-manager`)
- Own complete domain workflows
- Coordinate skill invocations
- Handle skill results
- Manage workflow state
- NEVER do work directly (delegate to skills)

### Layer 3: Execution Units

**Skills** (`infra-*`, `ops-*`)
- Perform focused tasks
- Read workflow steps from files
- Invoke handler skills for provider operations
- Document their work
- Return results to manager

### Layer 4: Provider/Tool Adapters

**Handler Skills** (`handler-hosting-*`, `handler-iac-*`)
- Centralize provider/tool-specific logic
- Execute actual cloud operations
- Abstract provider differences
- Invoked by execution skills

---

## Manager Responsibilities

### infra-manager - Infrastructure Lifecycle

**Domain:** Infrastructure from design through deployment

**Workflow:**
```
1. Design      → infra-architect
2. Engineer    → infra-engineer
3. Validate    → infra-validator
4. Test        → infra-tester
5. Preview     → infra-previewer
6. Deploy      → infra-deployer
7. Debug       → infra-debugger (if errors)
```

**Commands Handled:**
- `architect`: Design infrastructure solutions
- `engineer`: Implement IaC code
- `validate-config`: Validate configurations
- `test-changes`: Run security scans, cost estimates
- `preview-changes`: Generate deployment preview
- `deploy`: Execute deployment
- `show-resources`: Display deployed resources
- `check-status`: Show infrastructure status

**Routing Logic:**
```xml
<COMMAND_ROUTING>
  <ARCHITECT>
  Trigger: architect, design, create architecture
  Skills: infra-architect
  </ARCHITECT>

  <DEPLOY>
  Trigger: deploy, apply, launch
  Skills: infra-previewer → infra-deployer
  Conditional: Preview first unless --skip-preview
  </DEPLOY>

  <VALIDATE>
  Trigger: validate, check, verify config
  Skills: infra-validator
  </VALIDATE>
</COMMAND_ROUTING>
```

### ops-manager - Runtime Operations

**Domain:** Runtime system operations from monitoring through remediation

**Workflow:**
```
1. Monitor       → ops-monitor
2. Investigate   → ops-investigator
3. Respond       → ops-responder
4. Audit         → ops-auditor
```

**Commands Handled:**
- `check-health`: Check system health
- `query-logs`: Query application logs
- `investigate`: Investigate incidents
- `remediate`: Apply remediations
- `analyze-performance`: Performance analysis

**Routing Logic:**
```xml
<COMMAND_ROUTING>
  <HEALTH_CHECK>
  Trigger: health, check, status, alive
  Skills: ops-monitor
  </HEALTH_CHECK>

  <INVESTIGATE>
  Trigger: investigate, debug, analyze, logs
  Skills: ops-investigator
  </INVESTIGATE>

  <REMEDIATE>
  Trigger: fix, remediate, respond, resolve
  Skills: ops-responder
  </REMEDIATE>
</COMMAND_ROUTING>
```

---

## Skill Organization

### Infrastructure Skills

```
skills/
├── infra-architect/           # Design solutions
│   ├── SKILL.md
│   ├── workflow/
│   │   ├── analyze-requirements.md
│   │   ├── review-existing.md
│   │   ├── design-solution.md
│   │   └── document-design.md
│   ├── docs/
│   │   ├── design-principles.md
│   │   └── security-checklist.md
│   └── templates/
│       └── design-doc.md.template
│
├── infra-engineer/            # Implement IaC
│   ├── SKILL.md
│   ├── workflow/
│   │   ├── read-design.md
│   │   ├── generate-code.md
│   │   ├── apply-patterns.md
│   │   └── validate-implementation.md
│   └── docs/
│
├── infra-validator/           # Validate configs
├── infra-tester/              # Test security/cost
├── infra-previewer/           # Preview changes
├── infra-deployer/            # Execute deployment
├── infra-permission-manager/  # Manage IAM
└── infra-debugger/            # Analyze errors
```

### Operations Skills

```
skills/
├── ops-monitor/               # Monitor health
├── ops-investigator/          # Investigate issues
├── ops-responder/             # Respond to incidents
└── ops-auditor/               # Audit security/cost
```

### Handler Skills

```
skills/
├── handler-hosting-aws/       # AWS hosting operations
│   ├── SKILL.md
│   ├── workflow/
│   │   ├── authenticate.md
│   │   ├── deploy-resource.md
│   │   └── verify-resource.md
│   ├── docs/
│   │   └── best-practices.md
│   └── scripts/
│       ├── auth.sh
│       ├── deploy.sh
│       └── verify.sh
│
├── handler-hosting-gcp/       # GCP hosting operations
├── handler-iac-terraform/     # Terraform operations
└── handler-iac-pulumi/        # Pulumi operations
```

---

## Handler System

### Handler Types

**Four handler categories:**

```
handlers/
├── hosting/          # Cloud hosting providers
│   ├── aws/
│   ├── gcp/
│   └── azure/
│
├── iac/              # Infrastructure-as-Code tools
│   ├── terraform/
│   ├── pulumi/
│   └── cdk/
│
├── source-control/   # Version control systems
│   ├── github/
│   └── gitlab/
│
└── issue-tracker/    # Issue tracking systems
    ├── github/
    ├── jira/
    └── linear/
```

### Handler Skill Interface

**Each handler skill implements standard operations:**

**handler-hosting-*:**
- `authenticate`: Set up cloud credentials
- `deploy`: Deploy cloud resources
- `verify`: Verify deployed resources
- `query`: Query resource state
- `delete`: Remove resources

**handler-iac-*:**
- `init`: Initialize IaC tool
- `validate`: Validate IaC syntax
- `plan`: Generate execution plan
- `apply`: Apply changes
- `destroy`: Destroy resources

**Configuration mirrors structure:**
```json
{
  "handlers": {
    "hosting": {
      "active": "aws",
      "aws": { ... },
      "gcp": { ... }
    },
    "iac": {
      "active": "terraform",
      "terraform": { ... },
      "pulumi": { ... }
    }
  }
}
```

### Handler Invocation Pattern

**Skills invoke handlers through standard interface:**

```markdown
<EXECUTE_DEPLOYMENT>
Determine which handlers to use:

hosting_handler = config.handlers.hosting.active
iac_handler = config.handlers.iac.active

Step 1: Authenticate with hosting
  **USE SKILL: handler-hosting-${hosting_handler}**
  Operation: authenticate
  Arguments: ${environment}

Step 2: Execute deployment via IaC
  **USE SKILL: handler-iac-${iac_handler}**
  Operation: apply
  Arguments: ${environment}

Step 3: Verify with hosting
  **USE SKILL: handler-hosting-${hosting_handler}**
  Operation: verify
  Arguments: ${environment} ${resources}
</EXECUTE_DEPLOYMENT>
```

---

## Workflow Orchestration

### Standard Deployment Workflow

```
User: /fractary-faber-cloud:infra-manage deploy-apply --env=test
  ↓
infra-manage command
  ↓
infra-manager agent
  ↓
┌─────────────────────────────────────────────┐
│ Step 1: infra-previewer                     │
│   └─ handler-iac-terraform (plan)           │
│   └─ Returns: Preview of changes            │
└─────────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────────┐
│ Manager: Show preview, request approval     │
│   └─ User approves                           │
└─────────────────────────────────────────────┘
  ↓
┌─────────────────────────────────────────────┐
│ Step 2: infra-deployer                      │
│   ├─ handler-hosting-aws (authenticate)     │
│   ├─ handler-iac-terraform (apply)          │
│   ├─ handler-hosting-aws (verify)           │
│   └─ Returns: Deployed resources            │
└─────────────────────────────────────────────┘
  ↓
Manager: Report success to user
```

### Error Handling Workflow

```
infra-deployer encounters error
  ↓
┌─────────────────────────────────────────────┐
│ infra-debugger                              │
│   ├─ Categorize error (permission/config)   │
│   ├─ Search issue log for solutions         │
│   └─ Returns: Error category, proposed fix  │
└─────────────────────────────────────────────┘
  ↓
If permission error:
┌─────────────────────────────────────────────┐
│ infra-permission-manager                    │
│   ├─ Switch to discover-deploy profile      │
│   ├─ Grant missing permission               │
│   ├─ Log in IAM audit                       │
│   └─ Returns: Permission granted            │
└─────────────────────────────────────────────┘
  ↓
infra-manager: Retry deployment
```

---

## Data Flow

### Configuration Loading

```
Skill starts
  ↓
Read: .fractary/plugins/faber-cloud/devops.json
  ↓
Extract relevant configuration:
  - hosting_handler = config.handlers.hosting.active
  - iac_handler = config.handlers.iac.active
  - project = config.project.name
  - environment = input parameter
  ↓
Use configuration to determine:
  - Which handler skills to invoke
  - Which AWS profile to use
  - Resource naming patterns
  - Environment-specific settings
```

### Resource Registry Flow

```
infra-deployer deploys resources
  ↓
Extract deployed resource metadata:
  - Resource type (S3, Lambda, etc.)
  - Resource ID/ARN
  - Resource configuration
  - AWS Console URL
  ↓
Update registry:
  Execute: ../devops-common/scripts/update-registry.sh
  ↓
Registry updated:
  .fractary/plugins/faber-cloud/deployments/${env}/registry.json
  ↓
Documentation generated:
  .fractary/plugins/faber-cloud/deployments/${env}/DEPLOYED.md
```

### Issue Log Flow

```
infra-debugger analyzes error
  ↓
Search issue log:
  .fractary/plugins/faber-cloud/deployments/issue-log.json
  ↓
Match against historical errors
  ↓
Propose solution based on past successes
  ↓
If solution approved and successful:
  ↓
Log resolution:
  Execute: ../devops-common/scripts/log-resolution.sh
  ↓
Issue log updated with new solution
```

---

## Integration Patterns

### Manager → Skill Integration

**Manager invokes skill:**
```bash
# Manager determines which skill to invoke
skill_name="infra-deployer"
environment="test"

# Manager invokes skill
Use skill ${skill_name} with arguments "${environment}"

# Skill executes and returns results
# Manager handles results
```

### Skill → Handler Integration

**Skill invokes handler skill:**
```bash
# Skill determines which handler to use
hosting_handler=$(jq -r '.handlers.hosting.active' config.json)

# Skill invokes handler skill
**USE SKILL: handler-hosting-${hosting_handler}**
Operation: authenticate
Arguments: ${environment}

# Handler executes AWS-specific logic
# Handler returns results to skill
```

### Cross-Skill Communication

**Skills communicate through manager:**
```
infra-deployer encounters error
  ↓
Returns error to infra-manager
  ↓
infra-manager invokes infra-debugger
  ↓
infra-debugger analyzes, proposes solution
  ↓
Returns proposal to infra-manager
  ↓
infra-manager invokes infra-permission-manager
  ↓
infra-permission-manager grants permission
  ↓
Returns success to infra-manager
  ↓
infra-manager retries infra-deployer
```

**NOT:**
```
❌ infra-deployer directly invokes infra-debugger
❌ Skills communicate directly
❌ Skills share state directly
```

---

## Directory Structure

```
plugins/fractary-faber-cloud/
├── plugin.json                   # Plugin metadata
├── README.md                     # User documentation
├── ARCHITECTURE.md               # Architecture overview
│
├── agents/
│   ├── infra-manager.md          # Infrastructure manager
│   └── cloud-director.md         # Natural language router
│
├── commands/
│   ├── init.md                   # Initialize config
│   ├── architect.md              # Design infrastructure architecture
│   ├── engineer.md               # Generate IaC code
│   ├── validate.md               # Validate configuration
│   ├── test.md                   # Security and cost tests
│   ├── audit.md                  # Audit infrastructure health
│   ├── deploy-plan.md            # Preview deployment
│   ├── deploy-apply.md           # Apply deployment
│   ├── teardown.md               # Teardown infrastructure
│   ├── list.md                   # List resources
│   ├── status.md                 # Check status
│   ├── debug.md                  # Debug issues
│   ├── manage.md                 # Unified management
│   └── director.md               # Natural language entry
│
├── skills/
│   ├── devops-common/            # Shared utilities
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── config-loader.sh
│   │       ├── update-registry.sh
│   │       └── update-docs.sh
│   │
│   ├── infra-architect/          # Infrastructure skills
│   ├── infra-engineer/
│   ├── infra-validator/
│   ├── infra-tester/
│   ├── infra-previewer/
│   ├── infra-deployer/
│   ├── infra-permission-manager/
│   ├── infra-debugger/
│   │
│   ├── ops-monitor/              # Operations skills
│   ├── ops-investigator/
│   ├── ops-responder/
│   ├── ops-auditor/
│   │
│   ├── handler-hosting-aws/      # Handler skills
│   ├── handler-hosting-gcp/
│   ├── handler-iac-terraform/
│   └── handler-iac-pulumi/
│
└── docs/
    ├── specs/                    # Specifications
    ├── guides/                   # User guides
    └── reference/                # Reference docs
```

---

## Next Steps

1. Review [Configuration](fractary-faber-cloud-configuration.md) for config file structure
2. Review [Handlers](fractary-faber-cloud-handlers.md) for handler implementation details
3. Review [Permissions](fractary-faber-cloud-permissions.md) for permission management strategy
4. Review [Documentation](fractary-faber-cloud-documentation.md) for documentation systems
5. Review [Implementation Phases](fractary-faber-cloud-implementation-phases.md) for build plan
