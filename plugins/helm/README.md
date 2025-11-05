# Fractary Helm - Central Orchestrator

**Version:** 1.0.0
**Purpose:** Unified monitoring, dashboard, and issue management across all domain-specific Helm plugins

---

## Overview

Helm is the central orchestration layer for the Fractary operations monitoring ecosystem. It provides a unified interface for monitoring health, investigating issues, and managing incidents across all domains (infrastructure, application, content, data, etc.).

### What is Helm?

**Helm** is the universal operations workflow system in the Fractary ecosystem:
- **FABER** creates things (Frame → Architect → Build → Evaluate → Release)
- **Helm** monitors things (Monitor → Analyze → Alert → Remediate)

**Central Helm** orchestrates domain-specific Helm plugins:
- `helm-cloud` - Infrastructure monitoring
- `helm-app` - Application monitoring (planned)
- `helm-content` - Content delivery monitoring (planned)
- `helm-data` - Data pipeline monitoring (planned)

---

## Quick Start

### View Unified Dashboard

```bash
/fractary-helm:dashboard
```

Shows health across all monitored domains with prioritized issues and recommended actions.

### Check System Status

```bash
/fractary-helm:status
```

Quick health check across all domains.

### List Active Issues

```bash
/fractary-helm:issues
```

View all active issues prioritized across domains.

### Escalate to FABER

```bash
/fractary-helm:escalate infra-001
```

Create FABER work item for systematic resolution.

---

## Architecture

### Three-Layer Design

```
┌─────────────────────────────────────────────────────┐
│         Central Helm (this plugin)                  │
│                                                     │
│  • helm-director: Routes to domain plugins          │
│  • helm-dashboard: Aggregates and displays          │
│  • Issue registry: Tracks across domains            │
│  • Commands: Unified interface                      │
└─────────────────────────────────────────────────────┘
                         ↓
        ┌────────────────┴────────────────┐
        ↓                                  ↓
┌──────────────────┐             ┌──────────────────┐
│   helm-cloud     │             │    helm-app      │
│ (infrastructure) │             │  (application)   │
│                  │             │    [planned]     │
│  Domain-specific │             │                  │
│  monitoring      │             │                  │
└──────────────────┘             └──────────────────┘
```

### Key Components

#### 1. helm-director Agent
- **Purpose:** Route commands to domain plugins
- **Responsibilities:**
  - Load domain registry
  - Parse user requests
  - Route to appropriate domain(s)
  - Aggregate responses
- **Tools:** SlashCommand, Read

#### 2. helm-dashboard Agent
- **Purpose:** Generate unified dashboards
- **Responsibilities:**
  - Collect health from all domains
  - Calculate overall system health
  - Load and prioritize issues
  - Format output (text/JSON/voice)
- **Tools:** SlashCommand, Read

#### 3. Domain Registry
- **Location:** `registry/domain-monitors.json`
- **Purpose:** Central registry of domain plugins
- **Contents:**
  - Active domain monitors
  - Plugin commands
  - Capabilities
  - Priority weights

#### 4. Issue Registry
- **Location:** `issues/active/` and `issues/resolved/`
- **Purpose:** Cross-domain issue tracking
- **Features:**
  - Priority calculation
  - SLO breach tracking
  - FABER escalation linking

---

## Commands

### /fractary-helm:dashboard

Show unified dashboard with health, issues, and recommendations.

**Usage:**
```bash
/fractary-helm:dashboard [options]
```

**Options:**
- `--format=<text|json|voice>`: Output format (default: text)
- `--env=<environment>`: Filter by environment (default: all)
- `--domain=<domain>`: Filter by domain (default: all)
- `--issues=<n>`: Number of issues to show (default: 5)

**Examples:**
```bash
/fractary-helm:dashboard
/fractary-helm:dashboard --format=json
/fractary-helm:dashboard --env=prod
/fractary-helm:dashboard --domain=infrastructure
```

### /fractary-helm:status

Check health and status across domains.

**Usage:**
```bash
/fractary-helm:status [options]
```

**Options:**
- `--domain=<domain>`: Specific domain or all (default: all)
- `--env=<environment>`: Filter by environment (default: all)

**Examples:**
```bash
/fractary-helm:status
/fractary-helm:status --domain=infrastructure
/fractary-helm:status --env=prod
```

### /fractary-helm:issues

List and prioritize active issues.

**Usage:**
```bash
/fractary-helm:issues [options]
```

**Options:**
- `--critical|--high|--medium|--low`: Filter by severity
- `--domain=<domain>`: Filter by domain (default: all)
- `--env=<environment>`: Filter by environment (default: all)
- `--top <n>`: Limit to top N issues (default: all)

**Examples:**
```bash
/fractary-helm:issues
/fractary-helm:issues --critical
/fractary-helm:issues --domain=infrastructure
/fractary-helm:issues --top 10
```

### /fractary-helm:escalate

Escalate issue to FABER for systematic resolution.

**Usage:**
```bash
/fractary-helm:escalate <issue-id> [options]
```

**Options:**
- `--priority=<priority>`: Override priority (optional)

**Examples:**
```bash
/fractary-helm:escalate infra-001
/fractary-helm:escalate app-002 --priority=critical
```

---

## Dashboard Output

### Text Format (Default)

```
╔════════════════════════════════════════════════════════╗
║               HELM UNIFIED DASHBOARD                   ║
╚════════════════════════════════════════════════════════╝

Overall Health: HEALTHY ✓
───────────────────────────────────────────────────────

Domain Health:
  ✓ Infrastructure:  HEALTHY

Active Domains: 1/1
Last Updated: 2025-11-03 21:00:00

───────────────────────────────────────────────────────

Top Issues (0):

No active issues 🎉

───────────────────────────────────────────────────────

Quick Commands:
  /fractary-helm:dashboard --refresh  # Refresh dashboard
  /fractary-helm:issues               # View all issues
```

### JSON Format

```json
{
  "dashboard": {
    "generated_at": "2025-11-03T21:00:00Z",
    "overall_health": "HEALTHY",
    "domains": {
      "infrastructure": {
        "status": "HEALTHY",
        "plugin": "fractary-helm-cloud"
      }
    },
    "summary": {
      "total_domains": 1,
      "healthy": 1,
      "degraded": 0,
      "unhealthy": 0
    },
    "top_issues": []
  }
}
```

### Voice Format

```
Helm dashboard. Overall health is healthy.

Infrastructure is healthy.

No active issues. System is operating normally.

End of dashboard.
```

---

## Issue Prioritization

Issues are prioritized using a scoring algorithm:

```
Priority Score = (Severity × Domain Weight) + (SLO Breach × 2) + (Age in hours)
```

**Severity Weights:**
- CRITICAL: 10
- HIGH: 7
- MEDIUM: 5
- LOW: 2

**Domain Weights:**
- Infrastructure: 1.0
- Application: 0.9 (when added)
- Content: 0.8 (when added)
- Data: 0.7 (when added)

**SLO Breach:** +2 points if SLO breached

**Age:** Hours since detection

---

## Adding New Domain Monitors

To add a new domain monitor:

### Step 1: Create Domain Plugin

Create your domain plugin with standard commands:
- `/fractary-helm-{domain}:health`
- `/fractary-helm-{domain}:investigate`
- `/fractary-helm-{domain}:remediate`
- `/fractary-helm-{domain}:audit`

### Step 2: Register in Domain Registry

Add entry to `plugins/helm/registry/domain-monitors.json`:

```json
{
  "domain": "application",
  "plugin": "fractary-helm-app",
  "manager": "ops-manager",
  "capabilities": ["health", "logs", "metrics", "remediation"],
  "environments": ["test", "prod"],
  "priority_weight": 0.9,
  "commands": {
    "health": "/fractary-helm-app:health",
    "investigate": "/fractary-helm-app:investigate",
    "remediate": "/fractary-helm-app:remediate",
    "audit": "/fractary-helm-app:audit"
  },
  "status": "active"
}
```

### Step 3: Test Integration

```bash
# Test direct command
/fractary-helm-app:health --env=test

# Verify appears in unified dashboard
/fractary-helm:dashboard

# Verify issues prioritization
/fractary-helm:issues
```

**That's it!** No code changes to helm/ required.

---

## Integration with FABER

Helm issues can be escalated to FABER for systematic resolution:

```
Issue Detected (helm-cloud)
  ↓
Logged to Helm registry
  ↓
User escalates: /fractary-helm:escalate infra-001
  ↓
FABER Work Item Created
  ↓
FABER Workflow: Frame → Architect → Build → Evaluate → Release
  ↓
Issue Resolved
  ↓
Helm registry updated
```

---

## Configuration

### Domain Registry

Location: `plugins/helm/registry/domain-monitors.json`

Contains:
- Active domain monitors
- Plugin information
- Command mappings
- Priority weights
- Planned domains

### Issue Registry

Location: `plugins/helm/issues/active/*.json`

Each issue file contains:
```json
{
  "id": "infra-001",
  "domain": "infrastructure",
  "severity": "CRITICAL",
  "title": "Lambda error rate exceeds SLO",
  "description": "Error rate: 5.2%, SLO: 0.1%",
  "slo_breach": true,
  "detected_at": "2025-11-03T20:00:00Z",
  "environment": "prod",
  "affected_resources": ["api-lambda"],
  "metrics": {},
  "work_item_id": null
}
```

---

## Workflow Examples

### Daily Health Check

```bash
# Morning routine
/fractary-helm:dashboard

# Check any issues
/fractary-helm:issues --critical

# Investigate if needed
/fractary-helm-cloud:investigate --service=<name>
```

### Incident Response

```bash
# Alert received
/fractary-helm:dashboard

# Identify issue
/fractary-helm:issues --critical

# Investigate
/fractary-helm-cloud:investigate --service=<name>

# Remediate if possible
/fractary-helm-cloud:remediate --service=<name> --action=restart

# Escalate if needed
/fractary-helm:escalate <issue-id>
```

### Pre-Deployment Check

```bash
# Before deploying
/fractary-helm:status --env=prod

# Ensure healthy
/fractary-helm:issues --env=prod

# Deploy if all green
/fractary-faber-cloud:deploy --env=prod
```

---

## Extensibility

### Current Domains
- ✅ Infrastructure (helm-cloud)

### Planned Domains
- 📋 Application (helm-app)
- 📋 Content (helm-content)
- 📋 Data (helm-data)

### Future Features
- Real-time metrics streaming
- Advanced ML anomaly detection
- Custom SLO definitions
- Alert routing policies
- External integrations (Datadog, New Relic, etc.)
- Voice interface (Alexa, Google Home)

---

## Benefits

### Unified Monitoring
- Single dashboard for all domains
- Cross-domain issue visibility
- Consistent command patterns

### Intelligent Prioritization
- Cross-domain priority ranking
- SLO breach detection
- Actionable recommendations

### Seamless Escalation
- Direct FABER integration
- Systematic resolution pathway
- Issue lifecycle tracking

### Easy Extensibility
- New domains trivial to add
- No coupling between domains
- Registry-based configuration

---

## See Also

- [helm-cloud Plugin](../helm-cloud/README.md) - Infrastructure monitoring
- [SPEC-0010 Implementation Phase 3](../../docs/specs/implementation/SPEC-0010-implementation-phase3.md)
- [FABER Architecture](../../docs/specs/SPEC-0002-faber-architecture.md)

---

## Contributing

To add a new domain monitor:
1. Create domain plugin following helm-cloud pattern
2. Implement standard commands (health, investigate, remediate, audit)
3. Register in domain-monitors.json
4. Test integration with unified dashboard

---

## Version History

**1.0.0 (Phase 3 Complete):**
- Central Helm orchestrator created
- helm-director routing agent
- helm-dashboard aggregation agent
- Unified commands (dashboard, status, issues, escalate)
- Domain registry system
- Issue prioritization algorithm
- FABER escalation integration

---

## License

MIT License

## Support

- Issues: https://github.com/fractary/claude-plugins/issues
- Documentation: [docs/](docs/)

---

## Credits

Created by Fractary for Claude Code.

Part of the Fractary Claude Code Plugins collection.
