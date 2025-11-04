---
name: /fractary-faber-cloud:manage
description: Unified infrastructure lifecycle management - routes operations to infra-manager agent
argument-hint: <operation> [options]
tags: [faber-cloud, infrastructure, deployment, management]
examples:
  - trigger: "/fractary-faber-cloud:manage deploy-apply --env=test"
    action: "Deploy infrastructure to test environment"
  - trigger: "/fractary-faber-cloud:manage design \"Add monitoring\""
    action: "Design infrastructure from requirements"
---

# fractary-faber-cloud:manage

Unified command for managing complete infrastructure lifecycle through the infra-manager agent.

## Usage

```bash
/fractary-faber-cloud:manage <operation> [options]
```

## Operations

| Operation | Description | Example |
|-----------|-------------|---------|
| `design "<description>"` | Design infrastructure from requirements | `manage design "Add CloudWatch monitoring"` |
| `configure` | Generate IaC configuration files | `manage configure` |
| `validate` | Validate configuration files | `manage validate` |
| `test` | Run security and cost tests | `manage test` |
| `deploy-plan` | Preview deployment changes | `manage deploy-plan` |
| `deploy-apply --env=<env>` | Execute infrastructure deployment | `manage deploy-apply --env=test` |
| `status [--env <env>]` | Check deployment status | `manage status` |
| `resources [--env <env>]` | Show deployed resources | `manage resources --env=test` |
| `debug [--complete]` | Analyze and fix deployment errors | `manage debug --complete` |
| `teardown --env=<env>` | Destroy infrastructure | `manage teardown --env=test` |

## Examples

**Full lifecycle workflow:**
```bash
/fractary-faber-cloud:manage design "Add Lambda monitoring"
/fractary-faber-cloud:manage configure
/fractary-faber-cloud:manage validate
/fractary-faber-cloud:manage test
/fractary-faber-cloud:manage deploy-plan
/fractary-faber-cloud:manage deploy-apply --env=test
```

**Quick deployment:**
```bash
/fractary-faber-cloud:manage deploy-apply --env=test
```

**Error recovery:**
```bash
/fractary-faber-cloud:manage debug --complete
```

**Infrastructure teardown:**
```bash
/fractary-faber-cloud:manage teardown --env=test
```

## Invocation

This command routes all operations to the `infra-manager` agent.

USE AGENT: infra-manager with operation and parameters from user input
