---
name: fractary-faber-cloud:ops-manage
description: Runtime operations management - routes to ops-manager agent for monitoring, log analysis, incident response, and auditing
argument-hint: check-health --env=<env> [--service <name>] | query-logs --env=<env> [--service <name>] [--filter <pattern>] | audit [--env <env>] [--focus <area>]
examples:
  - trigger: "check health of test environment"
    action: "Invoke ops-manager agent with health check operation"
  - trigger: "query logs for errors in production"
    action: "Invoke ops-manager agent with log query operation"
  - trigger: "investigate incident in api service"
    action: "Invoke ops-manager agent with incident investigation"
---

# Operations Management Command

<CRITICAL_RULES>
**YOU MUST:**
- Invoke the ops-manager agent immediately
- Pass all arguments to the agent
- Do NOT perform any work yourself

**THIS COMMAND IS ONLY AN ENTRY POINT.**
</CRITICAL_RULES>

<ROUTING>
Parse user input and invoke agent:

```bash
# Example: /fractary-faber-cloud:ops-manage check-health --env=test

# YOU MUST INVOKE AGENT:
Invoke ops-manager with parsed arguments

# DO NOT:
# - Read files yourself
# - Execute commands yourself
# - Try to solve the problem yourself
```
</ROUTING>

<EXAMPLES>
<example>
User: /fractary-faber-cloud:ops-manage check-health --env=test
Action: Invoke ops-manager with: check-health --env=test
</example>

<example>
User: /fractary-faber-cloud:ops-manage query-logs --env=prod --service=api --filter=ERROR
Action: Invoke ops-manager with: query-logs --env=prod --service=api --filter=ERROR
</example>

<example>
User: /fractary-faber-cloud:ops-manage audit --env=test --focus=cost
Action: Invoke ops-manager with: audit --env=test --focus=cost
</example>
</EXAMPLES>
