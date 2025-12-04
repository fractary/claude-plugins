---
name: escalate
description: Escalate an issue to FABER workflow for systematic resolution
model: claude-haiku-4-5
examples:
  - /fractary-helm:escalate infra-001
  - /fractary-helm:escalate app-002 --priority=critical
argument-hint: "<issue-id> [--priority <priority>]"
---

# Escalate Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm:escalate --env test

# Incorrect ❌
/fractary-helm:escalate --env=test
```
</ARGUMENT_SYNTAX>

Escalate an active issue to FABER workflow system for systematic resolution and tracking.

## Usage

```bash
/fractary-helm:escalate <issue-id> [options]
```

## Parameters

- `<issue-id>`: Issue ID to escalate (required)
- `--priority <priority>`: Override priority (critical, high, medium, low). Optional

## What This Does

1. Loads issue details from issue registry
2. Creates FABER work item (GitHub issue, Jira ticket, etc.)
3. Links issue to work tracker
4. Moves issue to "escalated" state
5. Returns work item link and tracking information

## Examples

**Escalate infrastructure issue:**
```
/fractary-helm:escalate infra-001
```

**Escalate with override priority:**
```
/fractary-helm:escalate app-002 --priority=critical
```

## Escalation Process

### Step 1: Load Issue
Reads issue from `plugins/helm/issues/active/{issue-id}.json`

### Step 2: Create FABER Work Item
Creates work item using fractary-work plugin:
- Title: From issue title
- Description: Detailed issue information
- Labels: Domain, severity, SLO breach
- Priority: From issue or override

### Step 3: Link Issue
Updates issue file with:
- work_item_id
- escalated_at timestamp
- escalation_status: "escalated"

### Step 4: Notify
Returns:
- Work item URL
- Work item ID
- Next steps

## Work Item Template

The created FABER work item includes:

```markdown
# {Issue Title}

**Issue ID:** {issue-id}
**Domain:** {domain}
**Environment:** {environment}
**Severity:** {severity}
**Priority Score:** {score}

## Problem

{issue_description}

**Detected At:** {timestamp}
**Age:** {duration}
**SLO Breach:** {yes/no}

## Context

**Affected Resources:**
- {resource_list}

**Metrics:**
- {relevant_metrics}

**Logs:**
{log_snippets}

## Investigation

Initial investigation via Helm:
{investigation_summary}

## Recommended Actions

{actions_from_helm}

## Links

- Helm Issue: {issue_link}
- Dashboard: /fractary-helm:dashboard
- Domain Monitor: {domain_command}

---

**Escalated from Helm:** {timestamp}
**Escalation Reason:** {reason}
```

## Output Example

```
╔════════════════════════════════════════════════════════╗
║           ISSUE ESCALATION TO FABER                    ║
╚════════════════════════════════════════════════════════╝

Issue: infra-001
Title: Lambda error rate exceeds SLO
Domain: infrastructure
Environment: prod

───────────────────────────────────────────────────────

✓ Work Item Created

Platform: GitHub Issues
Repository: my-org/my-project
Issue Number: #123
URL: https://github.com/my-org/my-project/issues/123

───────────────────────────────────────────────────────

FABER Workflow Status:

Phase: Frame (in progress)
  ↓
  Architect → Build → Evaluate → Release

Expected Timeline: 2-4 hours

───────────────────────────────────────────────────────

Next Steps:

1. FABER will investigate and design solution
2. Track progress: /fractary-faber:status
3. View work item: gh issue view 123
4. Monitor Helm: /fractary-helm:dashboard

Quick Commands:
  /fractary-faber:status           # Check FABER progress
  /fractary-helm:issues            # View other issues
  gh issue view 123                # View work item
```

## When to Escalate

Escalate issues when:
- Critical severity with no immediate fix
- SLO breach requires systematic resolution
- Issue requires code changes
- Manual remediation is insufficient
- Issue is recurring
- Cross-team coordination needed

## Escalation vs Manual Resolution

**Escalate when:**
- Root cause requires development work
- Issue needs testing and validation
- Change requires review and approval
- Documentation needed
- Long-term fix required

**Manual resolution when:**
- Quick remediation available
- Configuration change only
- Temporary fix sufficient
- Emergency response needed

## After Escalation

The escalated issue:
- Remains in Helm issue registry
- Marked as "escalated"
- Linked to FABER work item
- Tracked until resolution
- Auto-closes when FABER completes

## Integration with FABER

Helm escalation triggers:
1. **Frame Phase:** Work item fetched, classified
2. **Architect Phase:** Solution designed
3. **Build Phase:** Fix implemented
4. **Evaluate Phase:** Testing and review
5. **Release Phase:** Deployed and documented

Helm monitors FABER progress and auto-resolves issue when complete.

## Invocation

This command creates a FABER work item via fractary-work plugin.

USE SKILL: fractary-work:issue-creator with title, description, labels, and priority from issue data
