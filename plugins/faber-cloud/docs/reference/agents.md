# Agents Reference

Complete reference for all fractary-faber-cloud agents.

## Overview

Agents are workflow orchestrators that coordinate skill invocations to accomplish complete workflows. The plugin has three agents:

1. **devops-director** - Natural language router (Phase 4)
2. **infra-manager** - Infrastructure lifecycle orchestrator (Phase 1)
3. **ops-manager** - Runtime operations orchestrator (Phase 3)

---

## devops-director

**Phase:** 4 (Natural Language & Polish)

**Purpose:** Parse natural language requests and route to appropriate manager

### Responsibilities

- Parse user's natural language input
- Identify keywords and determine intent
- Categorize as infrastructure or operations
- Detect environment (test/prod)
- Map to specific commands
- Route to infra-manager or ops-manager

### Intent Categories

**Infrastructure Intent:**
- Keywords: design, architect, create, build, generate, implement, deploy, validate, preview, terraform
- Routes to: infra-manager
- Examples: "deploy to test", "design S3 bucket", "validate configuration"

**Operations Intent:**
- Keywords: monitor, check, health, status, logs, investigate, debug, fix, remediate, restart, audit
- Routes to: ops-manager
- Examples: "check health", "investigate errors", "show logs", "analyze costs"

### Usage

```bash
/fractary-faber-cloud:director "<natural language request>"
```

### Examples

```bash
# Infrastructure
/fractary-faber-cloud:director "deploy my infrastructure to test"
# Routes to: /fractary-faber-cloud:infra-manage deploy --env test

/fractary-faber-cloud:director "design an S3 bucket"
# Routes to: /fractary-faber-cloud:infra-manage architect --feature "S3 bucket"

# Operations
/fractary-faber-cloud:director "check if production is healthy"
# Routes to: /fractary-faber-cloud:ops-manage check-health --env prod

/fractary-faber-cloud:director "investigate API errors"
# Routes to: /fractary-faber-cloud:ops-manage investigate --service=API
```

### Ambiguity Handling

When intent is unclear, director asks for clarification:

```
Your request could mean:
1. Check health of services (ops-manager)
2. Validate configuration (infra-manager)
Choose one: (1/2)
```

### File

`agents/devops-director.md`

---

## infra-manager

**Phase:** 1 (Core Infrastructure)

**Purpose:** Own complete infrastructure lifecycle from design through deployment

### Responsibilities

- Orchestrate infrastructure workflow
- Coordinate skill invocations
- Handle skill results
- Manage production confirmations
- Delegate errors to debugger

### Workflow

```
architect → engineer → validate → test → deploy-plan → deploy-apply → (debug if needed)
```

### Commands Handled

- `architect`: Design infrastructure solutions
- `engineer`: Generate Terraform code
- `validate-config`: Validate configurations
- `test-changes`: Run tests (pre/post)
- `preview-changes`: Generate execution plans
- `deploy`: Execute deployments
- `show-resources`: Display deployed resources
- `check-status`: Show infrastructure status
- `debug`: Troubleshoot errors

### Skills Delegated To

- **infra-architect**: Design solutions
- **infra-engineer**: Generate IaC code
- **infra-validator**: Validate configurations
- **infra-tester**: Run security/cost/verification tests
- **infra-previewer**: Generate plans
- **infra-deployer**: Execute deployments
- **infra-permission-manager**: Manage IAM permissions
- **infra-debugger**: Analyze errors

### Production Safety

- Requires explicit confirmation for prod
- Cannot skip with flags
- Shows detailed impact assessment
- Multiple validation levels
- Complete audit trail

### Usage

```bash
/fractary-faber-cloud:infra-manage <command> [options]
```

### Examples

```bash
# Design
/fractary-faber-cloud:infra-manage architect --feature="API service"

# Deploy
/fractary-faber-cloud:infra-manage deploy --env test

# Debug
/fractary-faber-cloud:infra-manage debug --error="<error message>"
```

### File

`agents/infra-manager.md`

---

## ops-manager

**Phase:** 3 (Runtime Operations)

**Purpose:** Own complete operations workflow from monitoring through remediation

### Responsibilities

- Orchestrate operations workflow
- Coordinate monitoring and investigation
- Handle incident response
- Manage remediation actions
- Perform audits

### Workflow

```
monitor → investigate → respond → audit
```

### Commands Handled

- `check-health`: Monitor resource health
- `query-logs`: Search CloudWatch logs
- `investigate`: Investigate incidents
- `analyze-performance`: Performance analysis
- `remediate`: Apply remediations
- `audit`: Cost/security/compliance audits

### Skills Delegated To

- **ops-monitor**: Health checks and metrics
- **ops-investigator**: Log analysis and investigation
- **ops-responder**: Remediation actions
- **ops-auditor**: Cost/security/compliance auditing

### Production Safety

- Impact assessment before remediations
- Confirmation required for production
- Verification after actions
- Complete action documentation

### Usage

```bash
/fractary-faber-cloud:ops-manage <command> [options]
```

### Examples

```bash
# Health check
/fractary-faber-cloud:ops-manage check-health --env prod

# Investigate
/fractary-faber-cloud:ops-manage investigate --service=api-lambda

# Remediate
/fractary-faber-cloud:ops-manage remediate --env prod --service=api-lambda --action=restart

# Audit
/fractary-faber-cloud:ops-manage audit --env test --focus=cost
```

### File

`agents/ops-manager.md`

---

## Agent Patterns

### Workflow Ownership

Each agent owns a complete domain workflow:
- **infra-manager**: Infrastructure (architect → deploy)
- **ops-manager**: Operations (monitor → remediate)
- **devops-director**: Routing (parse → route)

### Delegation

Agents NEVER do work themselves. They always delegate to skills:

```
User → Director → Manager → Skills → Handlers
```

### Error Handling

When skills fail:
1. Agent catches the error
2. Agent may invoke debugger skill
3. Agent presents options to user
4. Agent retries or stops based on user choice

### State Management

Agents manage workflow state:
- Track which step is current
- Remember previous results
- Pass context between skills
- Maintain production flags

### Critical Rules

All agents enforce:
- Production safety (multiple confirmations)
- Profile separation (correct AWS profile)
- Environment scoping (test vs prod)
- Audit logging (complete trail)

---

## Comparison

| Feature | devops-director | infra-manager | ops-manager |
|---------|----------------|---------------|-------------|
| **Purpose** | Route requests | Infrastructure | Operations |
| **Workflow** | Parse → Route | Design → Deploy | Monitor → Remediate |
| **Commands** | 1 (director) | 8 commands | 6 commands |
| **Skills** | 0 (routes only) | 8 skills | 4 skills |
| **Phase** | 4 | 1 | 3 |
| **Production** | Passes flags | Multiple confirms | Impact assess |

---

## Usage Patterns

### Natural Language (Recommended)

```bash
# User speaks naturally
/fractary-faber-cloud:director "deploy to production"

# Director parses and routes
→ infra-manager with deploy command

# Manager orchestrates
→ Skills execute deployment
```

### Direct Invocation

```bash
# Skip director, go straight to manager
/fractary-faber-cloud:infra-manage deploy --env prod

# Manager orchestrates
→ Skills execute deployment
```

Both approaches work identically. Natural language is easier.

---

## See Also

- [Commands Reference](commands.md)
- [Skills Reference](skills.md)
- [Architecture](../architecture/ARCHITECTURE.md)
- [User Guide](../guides/user-guide.md)
