---
name: fractary-faber-cloud:infra-manage
description: Manage infrastructure lifecycle - routes to infra-manager agent for architecture, deployment, and resource management
argument-hint: architect [--feature <description>] | engineer | validate | preview | deploy --env=<env> | show-resources [--env <env>] | status
tags: [devops, infrastructure, deployment, management]
examples:
  - trigger: "/fractary-faber-cloud:infra-manage deploy --env=test"
    action: "Invoke infra-manager agent to deploy infrastructure to test"
  - trigger: "/fractary-faber-cloud:infra-manage architect --feature='user uploads'"
    action: "Invoke infra-manager agent to design infrastructure"
---

# fractary-faber-cloud:infra-manage

# ⚠️  DELEGATION NOTICE

**This command now delegates to simplified faber-cloud commands.**

**Current (still works):**
```bash
/fractary-faber-cloud:infra-manage deploy --env=test
```

**Recommended (use simplified commands):**
```bash
/fractary-faber-cloud:architect "S3 bucket for uploads"
/fractary-faber-cloud:engineer user-uploads
/fractary-faber-cloud:validate --env=test
/fractary-faber-cloud:test --env=test
/fractary-faber-cloud:preview --env=test
/fractary-faber-cloud:deploy --env=test
/fractary-faber-cloud:status --env=test
/fractary-faber-cloud:resources --env=test
/fractary-faber-cloud:debug --error="AccessDenied"
```

**Migration Timeline:**
- **Now:** Both old and new commands work (delegation in place)
- **faber-cloud v2.0.0:** This command will be removed
- **Support period:** 6 months after v2.0.0 release

---

Manages infrastructure lifecycle operations including design, engineering, validation, preview, and deployment.

<CRITICAL_RULES>
**YOU MUST:**
- Delegate to simplified commands immediately
- Map old operations to new commands
- Show deprecation warning to user
- Do NOT perform any work yourself

**THIS COMMAND IS A DELEGATION LAYER ONLY.**
All work is done by the new simplified commands.
</CRITICAL_RULES>

<ROUTING>
Parse user input and delegate to simplified commands:

**Operation Mapping:**
- `architect` → `/fractary-faber-cloud:architect`
- `engineer` → `/fractary-faber-cloud:engineer`
- `validate-config` → `/fractary-faber-cloud:validate`
- `validate` → `/fractary-faber-cloud:validate`
- `test-changes` → `/fractary-faber-cloud:test`
- `test` → `/fractary-faber-cloud:test`
- `preview-changes` → `/fractary-faber-cloud:preview`
- `preview` → `/fractary-faber-cloud:preview`
- `deploy` → `/fractary-faber-cloud:deploy`
- `show-resources` → `/fractary-faber-cloud:resources`
- `check-status` → `/fractary-faber-cloud:status`
- `status` → `/fractary-faber-cloud:status`
- `debug` → `/fractary-faber-cloud:debug`

**Delegation Process:**
1. Show deprecation warning
2. Parse operation and arguments
3. Map to appropriate simplified command
4. Invoke simplified command via SlashCommand
5. Return results to user

```bash
# Example: /fractary-faber-cloud:infra-manage deploy --env=test

# Step 1: Show deprecation warning
"⚠️ NOTE: This command is deprecated. Please use /fractary-faber-cloud:deploy instead."

# Step 2: Delegate to simplified command
Invoke: /fractary-faber-cloud:deploy --env=test
```

**DO NOT:**
- Invoke infra-manager directly (use simplified commands)
- Read files yourself
- Execute commands yourself
- Try to solve the problem yourself
</ROUTING>

<EXAMPLES>
<example>
User: /fractary-faber-cloud:infra-manage deploy --env=test
Action: Invoke infra-manager agent with: "deploy --env=test"
</example>

<example>
User: /fractary-faber-cloud:infra-manage architect --feature="user uploads"
Action: Invoke infra-manager agent with: "architect --feature='user uploads'"
</example>

<example>
User: /fractary-faber-cloud:infra-manage show-resources --env=prod
Action: Invoke infra-manager agent with: "show-resources --env=prod"
</example>

<example>
User: /fractary-faber-cloud:infra-manage validate
Action: Invoke infra-manager agent with: "validate"
</example>
</EXAMPLES>

## Available Operations

- **architect**: Design infrastructure solutions
- **engineer**: Generate IaC code from designs
- **validate**: Validate configuration and code
- **preview**: Preview infrastructure changes
- **deploy**: Deploy infrastructure to environment
- **show-resources**: Display deployed resources
- **status**: Show configuration and deployment status

## Usage Examples

```bash
# Design infrastructure
/fractary-faber-cloud:infra-manage architect --feature="S3 bucket for user uploads"

# Generate Terraform code
/fractary-faber-cloud:infra-manage engineer --design="user-uploads.md"

# Validate configuration
/fractary-faber-cloud:infra-manage validate --env=test

# Preview changes
/fractary-faber-cloud:infra-manage preview --env=test

# Deploy to test
/fractary-faber-cloud:infra-manage deploy --env=test

# Deploy to production (requires confirmation)
/fractary-faber-cloud:infra-manage deploy --env=prod

# Show deployed resources
/fractary-faber-cloud:infra-manage show-resources --env=test

# Check status
/fractary-faber-cloud:infra-manage status
```
