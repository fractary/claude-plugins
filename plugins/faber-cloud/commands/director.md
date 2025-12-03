---
name: fractary-faber-cloud:director
description: Natural language entry point for fractary-faber-cloud - routes requests to appropriate commands
model: claude-haiku-4-5
argument-hint: '"<natural-language-request>"'
examples:
  - trigger: "Deploy my infrastructure to production"
    action: "Invoke cloud-director agent"
  - trigger: "Design an S3 bucket for uploads"
    action: "Invoke cloud-director agent"
  - trigger: "Validate my Terraform configuration"
    action: "Invoke cloud-director agent"
---

# Cloud Director Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes
- **Boolean flags**: No value needed, just include the flag

### Examples

```bash
# Correct ✅
/fractary-faber-cloud:director --env test

# Incorrect ❌
/fractary-faber-cloud:director --env=test
```
</ARGUMENT_SYNTAX>

<CRITICAL_RULES>
**YOU MUST:**
- Invoke the cloud-director agent immediately
- Pass the full user request to the agent
- Do NOT attempt to parse or interpret yourself
- Do NOT perform any work yourself

**THIS COMMAND IS ONLY AN ENTRY POINT.**
The cloud-director agent handles all intent parsing and routing.
</CRITICAL_RULES>

<ROUTING>
Parse user input and invoke cloud-director agent:

```bash
# Example: /fractary-faber-cloud:director "deploy my infrastructure to production"

# YOU MUST INVOKE AGENT:
Invoke cloud-director agent with user's full natural language request

# The director agent will:
# 1. Parse the natural language
# 2. Determine the appropriate infrastructure command
# 3. Route to infra-manager with correct operation
# 4. Pass appropriate arguments

# DO NOT:
# - Try to parse the intent yourself
# - Route directly to infra-manager yourself
# - Read files or execute commands
# - Try to solve the problem yourself
```
</ROUTING>

<EXAMPLES>
<example>
User: /fractary-faber-cloud:director "deploy infrastructure to test"
Action: Invoke cloud-director agent with request
Director will route to: /fractary-faber-cloud:deploy-apply --env test
</example>

<example>
User: /fractary-faber-cloud:director "design an S3 bucket for uploads"
Action: Invoke cloud-director agent with request
Director will route to: /fractary-faber-cloud:architect "S3 bucket for uploads"
</example>

<example>
User: /fractary-faber-cloud:director "validate my configuration"
Action: Invoke cloud-director agent with request
Director will route to: /fractary-faber-cloud:validate
</example>

<example>
User: /fractary-faber-cloud:director "show me deployed resources in production"
Action: Invoke cloud-director agent with request
Director will route to: /fractary-faber-cloud:list --env prod
</example>
</EXAMPLES>

<USAGE_NOTE>
This command provides a natural language interface to all fractary-faber-cloud infrastructure operations.
Users can describe what they want in plain English, and the director agent will
determine the appropriate command to execute.

Alternative: Users can also invoke commands directly if they prefer:
- /fractary-faber-cloud:architect [description]
- /fractary-faber-cloud:engineer
- /fractary-faber-cloud:validate
- /fractary-faber-cloud:deploy-plan --env <env>
- /fractary-faber-cloud:deploy-apply --env <env>
- /fractary-faber-cloud:teardown --env <env>
- /fractary-faber-cloud:list --env <env>
- /fractary-faber-cloud:status --env <env>
- /fractary-faber-cloud:debug

Note: For runtime operations monitoring, use fractary-helm-cloud plugin:
- /fractary-helm-cloud:health --env <env>
- /fractary-helm-cloud:investigate
- /fractary-helm-cloud:remediate
- /fractary-helm-cloud:audit
</USAGE_NOTE>
