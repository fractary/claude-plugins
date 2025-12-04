---
name: dashboard
description: Show unified Helm dashboard with health, issues, and recommendations across all domains
model: claude-haiku-4-5
examples:
  - /fractary-helm:dashboard
  - /fractary-helm:dashboard --format=json
  - /fractary-helm:dashboard --env prod
argument-hint: "[--format=<text|json|voice>] [--env <environment>] [--domain <domain>] [--issues=<n>]"
---

# Dashboard Command


<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the standard space-separated syntax:
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in double quotes

### Examples

```bash
# Correct ✅
/fractary-helm:dashboard --env test

# Incorrect ❌
/fractary-helm:dashboard --env=test
```
</ARGUMENT_SYNTAX>

Show a unified dashboard with system health, top issues, and recommended actions across all monitored domains.

## Usage

```bash
/fractary-helm:dashboard [options]
```

## Parameters

- `--format=<format>`: Output format (text, json, voice). Default: text
- `--env <environment>`: Filter by environment (test, prod, all). Default: all
- `--domain <domain>`: Filter by domain (infrastructure, application, all). Default: all
- `--issues=<n>`: Number of top issues to show. Default: 5

## What This Does

1. Queries health from all active domain monitors
2. Calculates overall system health
3. Loads and prioritizes active issues
4. Generates unified dashboard view
5. Provides quick action commands

## Examples

**Basic dashboard:**
```
/fractary-helm:dashboard
```

**Production-only dashboard:**
```
/fractary-helm:dashboard --env prod
```

**JSON output for programmatic use:**
```
/fractary-helm:dashboard --format=json
```

**Voice-ready output:**
```
/fractary-helm:dashboard --format=voice
```

**Infrastructure-only:**
```
/fractary-helm:dashboard --domain infrastructure
```

## Dashboard Sections

### Overall Health
- Aggregated health across all domains
- HEALTHY, DEGRADED, or UNHEALTHY
- Summary counts (healthy/degraded/unhealthy domains)

### Domain Health
- Per-domain health status
- Icons: ✓ (healthy), ⚠ (degraded), ✗ (unhealthy)
- Issue counts per domain
- Last check timestamps

### Top Issues
- Prioritized list of active issues
- Severity, domain, title
- SLO breach indicators
- Age/duration
- Quick action commands

### Recommended Actions
- 3-5 actionable next steps
- Based on current system state
- Prioritized by impact

### Quick Commands
- Helpful commands for common tasks
- Context-aware based on dashboard state

## Output Formats

### Text (Default)
ASCII art dashboard with colors and icons. Human-readable format for terminal display.

### JSON
Structured data format for:
- API integrations
- Programmatic access
- Dashboard storage
- Trend analysis

### Voice
Optimized for text-to-speech:
- No special characters
- Natural language flow
- Clear pronunciation
- Concise summaries

## When to Use

Use the dashboard:
- At start of day/shift
- During incident response
- For system overview
- Before deployments
- In status meetings
- For health checks

## Next Steps

After viewing dashboard:
- Investigate critical issues: `/helm:issues --critical`
- Check specific domain: `/helm:status --domain infrastructure`
- Escalate issues: `/helm:escalate <issue-id>`
- Refresh: `/fractary-helm:dashboard --refresh`

## Invocation

This command invokes the `helm-dashboard` agent.

USE AGENT: helm-dashboard with format from --format, environment from --env, domain from --domain, and issues count from --issues parameters
