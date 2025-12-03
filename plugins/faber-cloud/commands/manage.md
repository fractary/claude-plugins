---
name: fractary-faber-cloud:manage
description: Unified infrastructure lifecycle management - routes operations to infra-manager agent
model: claude-haiku-4-5
argument-hint: <operation> [--env <environment>] [--complete]
tags: [faber-cloud, infrastructure, deployment, management]
examples:
  - trigger: "/fractary-faber-cloud:manage deploy-apply --env test"
    action: "Deploy infrastructure to test environment"
  - trigger: "/fractary-faber-cloud:manage design \"Add monitoring\""
    action: "Design infrastructure from requirements"
  - trigger: "/fractary-faber-cloud:manage debug --complete"
    action: "Analyze and fix deployment errors with complete resolution"
---

# fractary-faber-cloud:manage


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:manage --env test

# Incorrect ❌
/fractary-faber-cloud:manage --env=test
```
</ARGUMENT_SYNTAX>

Unified command for managing complete infrastructure lifecycle through the infra-manager agent.

The manage command supports two modes of operation:

**1. WORKFLOW MODE** - Execute complete FABER workflows for work items:
```bash
/fractary-faber-cloud:manage <work-item-id> [--workflow <name>] [options]
```

**2. DIRECT MODE** - Execute individual infrastructure operations:
```bash
/fractary-faber-cloud:manage <operation> [options]
```

## Workflow Mode

Execute complete FABER workflows (Frame → Architect → Build → Evaluate → Release) for infrastructure work items:

```bash
# Use default workflow (infrastructure-deploy)
/fractary-faber-cloud:manage 123

# Use specific workflow
/fractary-faber-cloud:manage 456 --workflow infrastructure-audit
/fractary-faber-cloud:manage 789 --workflow infrastructure-teardown

# Override autonomy level
/fractary-faber-cloud:manage 123 --workflow infrastructure-deploy --autonomy dry-run
```

### Available Workflows

| Workflow | Description | Autonomy | Use Case |
|----------|-------------|----------|----------|
| `infrastructure-deploy` | Standard deployment | Guarded | New infrastructure, updates, migrations |
| `infrastructure-audit` | Non-destructive audit | Autonomous | Health checks, compliance, cost analysis |
| `infrastructure-teardown` | Safe destruction | Assist | Decommissioning, cleanup |

See `.fractary/plugins/faber-cloud/workflows/README.md` for detailed workflow documentation.

## Direct Mode Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `design "<description>"` | Design infrastructure from requirements | `manage design "Add CloudWatch monitoring"` |
| `configure` | Generate IaC configuration files | `manage configure` |
| `validate` | Validate configuration files | `manage validate` |
| `test` | Run security and cost tests | `manage test` |
| `deploy-plan` | Preview deployment changes | `manage deploy-plan` |
| `deploy-apply --env <env>` | Execute infrastructure deployment | `manage deploy-apply --env test` |
| `status [--env <env>]` | Check deployment status | `manage status` |
| `resources [--env <env>]` | Show deployed resources | `manage resources --env test` |
| `debug [--complete]` | Analyze and fix deployment errors | `manage debug --complete` |
| `teardown --env <env>` | Destroy infrastructure | `manage teardown --env test` |

## Examples

**Full lifecycle workflow:**
```bash
/fractary-faber-cloud:manage design "Add Lambda monitoring"
/fractary-faber-cloud:manage configure
/fractary-faber-cloud:manage validate
/fractary-faber-cloud:manage test
/fractary-faber-cloud:manage deploy-plan
/fractary-faber-cloud:manage deploy-apply --env test
```

**Quick deployment:**
```bash
/fractary-faber-cloud:manage deploy-apply --env test
```

**Error recovery:**
```bash
/fractary-faber-cloud:manage debug --complete
```

**Infrastructure teardown:**
```bash
/fractary-faber-cloud:manage teardown --env test
```

## Invocation

This command routes all operations to the `infra-manager` agent.

USE AGENT: infra-manager with operation and parameters from user input
