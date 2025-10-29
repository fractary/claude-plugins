---
name: director
description: Natural language entry point for fractary-devops - routes requests to appropriate manager
examples:
  - trigger: "Deploy my application to production"
    action: "Invoke devops-director agent"
  - trigger: "Check if my services are healthy"
    action: "Invoke devops-director agent"
  - trigger: "Investigate production errors"
    action: "Invoke devops-director agent"
---

# DevOps Director Command

<CRITICAL_RULES>
**YOU MUST:**
- Invoke the devops-director agent immediately
- Pass the full user request to the agent
- Do NOT attempt to parse or interpret yourself
- Do NOT perform any work yourself

**THIS COMMAND IS ONLY AN ENTRY POINT.**
The devops-director agent handles all intent parsing and routing.
</CRITICAL_RULES>

<ROUTING>
Parse user input and invoke devops-director agent:

```bash
# Example: /fractary-devops:director "deploy my app to production"

# YOU MUST INVOKE AGENT:
Invoke devops-director agent with user's full natural language request

# The director agent will:
# 1. Parse the natural language
# 2. Determine intent (infrastructure vs operations)
# 3. Route to infra-manager or ops-manager
# 4. Pass appropriate arguments

# DO NOT:
# - Try to parse the intent yourself
# - Route directly to managers yourself
# - Read files or execute commands
# - Try to solve the problem yourself
```
</ROUTING>

<EXAMPLES>
<example>
User: /fractary-devops:director "check health of production services"
Action: Invoke devops-director agent with request
Director will route to: /fractary-devops:ops-manage check-health --env=prod
</example>

<example>
User: /fractary-devops:director "deploy infrastructure to test"
Action: Invoke devops-director agent with request
Director will route to: /fractary-devops:infra-manage deploy --env=test
</example>

<example>
User: /fractary-devops:director "design an S3 bucket for uploads"
Action: Invoke devops-director agent with request
Director will route to: /fractary-devops:infra-manage architect --feature="S3 bucket for uploads"
</example>

<example>
User: /fractary-devops:director "show me the logs from Lambda"
Action: Invoke devops-director agent with request
Director will route to: /fractary-devops:ops-manage query-logs --service=Lambda
</example>
</EXAMPLES>

<USAGE_NOTE>
This command provides a natural language interface to all fractary-devops operations.
Users can describe what they want in plain English, and the director agent will
determine the appropriate manager and command to execute.

Alternative: Users can also invoke managers directly if they prefer:
- /fractary-devops:infra-manage [command] [args]
- /fractary-devops:ops-manage [command] [args]
</USAGE_NOTE>
