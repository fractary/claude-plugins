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

Manages infrastructure lifecycle operations including design, engineering, validation, preview, and deployment.

<CRITICAL_RULES>
**YOU MUST:**
- Invoke the infra-manager agent immediately
- Pass all arguments to the agent
- Do NOT perform any work yourself

**THIS COMMAND IS ONLY AN ENTRY POINT.**
All work is done by the infra-manager agent and its skills.
</CRITICAL_RULES>

<ROUTING>
Parse user input and invoke infra-manager agent with all arguments:

```bash
# Parse the command
# Example: /fractary-faber-cloud:infra-manage deploy --env=test

# YOU MUST INVOKE AGENT:
# Use the SlashCommand tool to invoke the agent:
# The agent frontmatter should handle the routing

# Extract the operation and arguments
OPERATION="deploy"  # or architect, engineer, validate, preview, show-resources, status
ARGUMENTS="--env=test"

# Invoke the infra-manager agent
# Claude will automatically load the agent based on description matching
```

**DO NOT:**
- Read files yourself
- Execute commands yourself
- Try to solve the problem yourself
- Invoke skills directly (agent handles that)
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
