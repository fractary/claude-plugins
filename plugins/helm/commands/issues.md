---
name: issues
description: List and manage active issues across all domains with priority ranking
examples:
  - /fractary-helm:issues
  - /fractary-helm:issues --critical
  - /fractary-helm:issues --domain infrastructure
  - /fractary-helm:issues --top 10
argument-hint: "[--critical|--high|--medium|--low] [--domain <domain>] [--env <environment>] [--top <n>]"
---

# Issues Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm:issues --env test

# Incorrect ❌
/fractary-helm:issues --env=test
```
</ARGUMENT_SYNTAX>

List, filter, and prioritize active issues across all monitored domains.

## Usage

```bash
/fractary-helm:issues [options]
```

## Parameters

- `--critical`: Show only critical severity issues
- `--high`: Show only high severity issues
- `--medium`: Show only medium severity issues
- `--low`: Show only low severity issues
- `--domain <domain>`: Filter by domain (infrastructure, application, all). Default: all
- `--env <environment>`: Filter by environment (test, prod, all). Default: all
- `--top <n>`: Limit to top N issues by priority. Default: all

## What This Does

1. Loads all active issues from issue registry
2. Applies filters (severity, domain, environment)
3. Calculates priority scores
4. Sorts by priority descending
5. Returns formatted issue list with action commands

## Priority Calculation

Issues are prioritized using:

```
Priority Score = (Severity × Domain Weight) + (SLO Breach × 2) + (Age in hours)
```

Where:
- Severity: CRITICAL=10, HIGH=7, MEDIUM=5, LOW=2
- Domain Weight: From domain registry (infrastructure=1.0, etc.)
- SLO Breach: +2 if SLO breached
- Age: Hours since detection

## Examples

**All issues:**
```
/fractary-helm:issues
```

**Critical issues only:**
```
/fractary-helm:issues --critical
```

**Infrastructure issues:**
```
/fractary-helm:issues --domain infrastructure
```

**Top 5 issues:**
```
/fractary-helm:issues --top 5
```

**Production critical issues:**
```
/fractary-helm:issues --critical --env prod
```

## Output Format

```
╔════════════════════════════════════════════════════════╗
║                 ACTIVE ISSUES (12)                     ║
╚════════════════════════════════════════════════════════╝

🔴 CRITICAL  [infra/prod] Lambda error rate exceeds SLO
   ID: infra-001
   Priority: 12.5 | SLO Breach | 45m old
   Detected: 2025-11-03 19:15:00
   → Investigate: /fractary-helm-cloud:investigate --service=lambda
   → Escalate: /fractary-helm:escalate infra-001

🟠 HIGH      [app/prod] API response time degraded
   ID: app-002
   Priority: 9.2 | 30m old
   Detected: 2025-11-03 19:30:00
   → Remediate: /fractary-helm-app:remediate --service=api

🟡 MEDIUM    [infra/test] S3 bucket over quota
   ID: infra-003
   Priority: 6.1 | 2h old
   Detected: 2025-11-03 18:00:00
   → Audit: /fractary-helm-cloud:audit --type=storage

───────────────────────────────────────────────────────

Summary:
  Critical: 1
  High: 1
  Medium: 1
  Low: 0

By Domain:
  Infrastructure: 2
  Application: 1

Quick Commands:
  /fractary-helm:issues --critical     # Critical only
  /fractary-helm:escalate <issue-id>   # Escalate to FABER
  /fractary-helm:dashboard              # Dashboard view
```

## Issue Details

Each issue includes:
- **Severity**: CRITICAL, HIGH, MEDIUM, LOW with icon
- **Domain/Environment**: Where the issue occurred
- **Title**: Brief description
- **ID**: Unique identifier
- **Priority Score**: Calculated priority
- **SLO Breach**: If SLO was breached
- **Age**: Time since detection
- **Detected At**: Timestamp
- **Action Command**: Direct command to address issue
- **Escalation**: Command to escalate to FABER

## Severity Icons

- 🔴 CRITICAL
- 🟠 HIGH
- 🟡 MEDIUM
- 🟢 LOW

## When to Use

List issues:
- During incident response
- Daily/shift handoffs
- Status meetings
- Before deployments
- Prioritizing work
- Escalation decisions

## Next Steps

After viewing issues:
- Investigate specific issue: Use provided command
- Escalate to FABER: `/fractary-helm:escalate <issue-id>`
- View dashboard: `/fractary-helm:dashboard`
- Check domain health: `/fractary-helm:status --domain <domain>`

## Invocation

This command invokes the `helm-dashboard` agent with issue listing mode.

USE AGENT: helm-dashboard with operation=list-issues, severity filter from flags, domain from --domain, environment from --env, and limit from --top parameters
