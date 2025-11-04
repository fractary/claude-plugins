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

# ⚠️  DELEGATION NOTICE

**This command now delegates to the helm-cloud plugin for operations monitoring.**

**Current (still works):**
```bash
/fractary-faber-cloud:ops-manage check-health --env=test
```

**Recommended (use helm-cloud directly):**
```bash
/fractary-helm-cloud:health --env=test
/fractary-helm-cloud:investigate --env=prod
/fractary-helm-cloud:remediate --issue=infra-001 --env=prod
/fractary-helm-cloud:audit --type=cost --env=prod
```

**Migration Timeline:**
- **Now:** Both old and new commands work (delegation in place)
- **faber-cloud v2.0.0:** This command will be removed
- **Support period:** 6 months after v2.0.0 release

This delegation will be removed in faber-cloud v2.0.0.

---

<CRITICAL_RULES>
**YOU MUST:**
- Delegate to helm-cloud plugin immediately
- Map old operations to new helm-cloud commands
- Show deprecation warning to user
- Do NOT perform any work yourself

**THIS COMMAND IS A DELEGATION LAYER ONLY.**
</CRITICAL_RULES>

<ROUTING>
Parse user input and delegate to helm-cloud:

**Operation Mapping:**
- `check-health` → `/fractary-helm-cloud:health`
- `query-logs` → `/fractary-helm-cloud:investigate`
- `investigate` → `/fractary-helm-cloud:investigate`
- `remediate` → `/fractary-helm-cloud:remediate`
- `audit` → `/fractary-helm-cloud:audit`

**Delegation Process:**
1. Show deprecation warning
2. Parse operation and arguments
3. Map to appropriate helm-cloud command
4. Invoke helm-cloud command via SlashCommand
5. Return results to user

```bash
# Example: /fractary-faber-cloud:ops-manage check-health --env=test

# Step 1: Show deprecation warning
"⚠️ NOTE: This command is deprecated. Please use /fractary-helm-cloud:health instead."

# Step 2: Delegate to helm-cloud
Invoke: /fractary-helm-cloud:health --env=test
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
