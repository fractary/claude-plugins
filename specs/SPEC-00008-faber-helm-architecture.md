# FABER & Helm: Complementary Systems Architecture

**Version:** 1.0.0
**Date:** 2025-11-03
**Status:** Proposed

---

## Executive Summary

FABER and Helm are **complementary systems** in the Fractary ecosystem, addressing fundamentally different aspects of the creation-to-operations lifecycle:

- **FABER** (Frame → Architect → Build → Evaluate → Release) - The universal **creation workflow**
- **Helm** (Monitor → Analyze → Alert → Remediate) - The universal **operations workflow**

This document defines the architectural vision for how these systems work together, their boundaries, integration points, and the path forward for implementation.

---

## Table of Contents

1. [Vision & Philosophy](#vision--philosophy)
2. [System Boundaries](#system-boundaries)
3. [Architecture Overview](#architecture-overview)
4. [Integration Model](#integration-model)
5. [Universal Pattern](#universal-pattern)
6. [Centralized Dashboard Vision](#centralized-dashboard-vision)
7. [Industry Alignment](#industry-alignment)
8. [Tool Ecosystem Position](#tool-ecosystem-position)

---

## Vision & Philosophy

### The Fundamental Separation

**Creation vs. Operations**

Every domain—software engineering, infrastructure management, content creation, design systems—has two distinct lifecycle phases:

1. **Creation Lifecycle** (FABER)
   - **Purpose:** Bring something new into existence
   - **Nature:** One-time workflow per work item
   - **Phases:** Frame → Architect → Build → Evaluate → Release
   - **Completion:** When the thing is deployed/published
   - **Example (Infrastructure):** Design VPC → Generate Terraform → Validate → Test → Deploy
   - **Example (Software):** Fetch issue → Design solution → Code → Test → Create PR
   - **Example (Content):** Draft outline → Write → Edit → Review → Publish

2. **Operations Lifecycle** (Helm)
   - **Purpose:** Keep existing things healthy and performing
   - **Nature:** Continuous, ongoing monitoring
   - **Phases:** Monitor → Analyze → Alert → Remediate
   - **Completion:** Never (runs continuously)
   - **Example (Infrastructure):** Monitor CloudWatch → Detect high latency → Alert → Scale resources
   - **Example (Software):** Monitor APM → Detect error spike → Alert → Rollback deployment
   - **Example (Content):** Monitor analytics → Detect low engagement → Alert → Optimize content

### Why Separate?

**Different Mental Models:**
- FABER: "How do we **build** this?"
- Helm: "How **healthy** is what we built?"

**Different Temporality:**
- FABER: Finite workflow with clear completion
- Helm: Infinite monitoring with continuous feedback

**Different Success Criteria:**
- FABER: Did we successfully create and ship?
- Helm: Is it performing well in production?

**Different Failure Modes:**
- FABER: Tests fail, code doesn't build, deployment errors
- Helm: Latency spikes, error rates increase, costs balloon

### The Virtuous Cycle

```
┌─────────────────────────────────────────┐
│          FABER (Creation)               │
│  Frame → Architect → Build              │
│  → Evaluate → Release                   │
└──────────────┬──────────────────────────┘
               │
               │ Deploys/Publishes
               ▼
         [Production]
               │
               │ Helm takes over
               ▼
┌─────────────────────────────────────────┐
│           Helm (Operations)             │
│  Monitor → Analyze → Alert              │
│  → Remediate                            │
└──────────────┬──────────────────────────┘
               │
               │ Detects issues
               ▼
      [Create work item]
               │
               │ Feeds back to FABER
               ▼
┌─────────────────────────────────────────┐
│          FABER (Creation)               │
│  New workflow to fix issue              │
└─────────────────────────────────────────┘
```

**This creates a continuous improvement cycle:**
- Build things (FABER)
- Monitor things (Helm)
- Learn from issues (Helm)
- Fix/improve things (FABER)
- Repeat

---

## System Boundaries

### What FABER Owns

**Scope: Creation Workflows**

✅ **FABER is responsible for:**
- Fetching work items (Frame)
- Designing solutions (Architect)
- Implementing solutions (Build)
- Pre-release validation (Evaluate)
  - Unit tests, integration tests
  - Code quality, linting
  - Security scans, cost estimates
  - Spec compliance verification
- Deploying/publishing (Release)
  - Create pull requests
  - Merge code (if autonomous)
  - Deploy infrastructure
  - Publish content
  - **Optional:** Initial post-deployment health check

❌ **FABER is NOT responsible for:**
- Continuous monitoring in production
- Production performance analytics
- Incident investigation and response
- Cost/security auditing (ongoing)
- Usage analytics and engagement metrics

**FABER completes when:**
- Work item is closed
- Deployment is successful
- (Optional) Initial health check passes
- Artifacts are published

### What Helm Owns

**Scope: Operations Workflows**

✅ **Helm is responsible for:**
- Continuous health monitoring
- Performance metrics and analytics
- Log aggregation and analysis
- Incident detection and alerting
- Root cause investigation
- Automated and manual remediation
- Cost analysis and optimization
- Security posture monitoring
- Compliance auditing
- Usage analytics and engagement tracking

❌ **Helm is NOT responsible for:**
- Creating new things (that's FABER)
- Designing solutions (that's FABER Architect)
- Implementing fixes (that's FABER Build)
- Pre-release testing (that's FABER Evaluate)

**Helm runs continuously:**
- No completion criteria
- Always monitoring
- Always ready to detect and respond
- Feeds issues back to FABER when fixes needed

### The Boundary: Where FABER Ends and Helm Begins

**Clear Handoff Point:**

```
FABER Release Phase:
1. Deploy infrastructure / Merge PR / Publish content
2. (Optional) Run initial health check (5-10 minutes)
3. Verify deployment succeeded
4. Register deployment with Helm
5. Close work item
6. FABER workflow completes ✅

Helm Takes Over:
1. Receive deployment registration
2. Begin continuous monitoring
3. Collect baseline metrics
4. Monitor for anomalies
5. Alert on issues
6. Investigate incidents
7. Remediate when possible
8. Escalate to FABER when code changes needed
```

**Example: Infrastructure Deployment**

| Phase | FABER or Helm? | What Happens |
|-------|----------------|--------------|
| Design VPC | FABER (Architect) | Generate Terraform code |
| Validate syntax | FABER (Evaluate) | `terraform validate` |
| Security scan | FABER (Evaluate) | Checkov, tfsec |
| Cost estimate | FABER (Evaluate) | `terraform plan` cost analysis |
| Deploy to AWS | FABER (Release) | `terraform apply` |
| **Verify resources exist** | **FABER (Release)** | **One-time check: resources created?** |
| **Continuous health monitoring** | **Helm** | **Ongoing: Are resources healthy?** |
| Detect high latency | Helm | CloudWatch metrics show P95 > SLO |
| Investigate cause | Helm | Query logs, correlate events |
| Apply remediation | Helm | Scale resources, restart services |
| Code change needed | Helm → FABER | Create issue → FABER workflow |

**The line:** FABER verifies deployment **succeeded**. Helm monitors **ongoing health**.

---

## Architecture Overview

### Hybrid Model: Domain Plugins + Central Orchestrator

```
                    ┌─────────────────────────────────┐
                    │      HELM (Central)             │
                    │      helm/                      │
                    ├─────────────────────────────────┤
                    │  • helm-director                │
                    │    (routes to domain plugins)   │
                    │  • helm-dashboard               │
                    │    (unified view)               │
                    │  • helm-orchestrator            │
                    │    (cross-domain operations)    │
                    └────────────┬────────────────────┘
                                 │
                    ┌────────────┴────────────┬─────────────┐
                    ▼                         ▼             ▼
          ┌──────────────────┐     ┌──────────────┐  ┌──────────────┐
          │  helm-cloud      │     │  helm-app    │  │ helm-content │
          ├──────────────────┤     ├──────────────┤  ├──────────────┤
          │  Infrastructure  │     │ Applications │  │   Content    │
          │   Monitoring     │     │  Monitoring  │  │  Analytics   │
          └────────┬─────────┘     └──────┬───────┘  └──────┬───────┘
                   │ monitors              │ monitors        │ monitors
                   ▼                       ▼                 ▼
          ┌──────────────────┐     ┌──────────────┐  ┌──────────────┐
          │  faber-cloud     │     │  faber-app   │  │faber-content │
          ├──────────────────┤     ├──────────────┤  ├──────────────┤
          │  Infrastructure  │     │ Application  │  │   Content    │
          │    Creation      │     │   Creation   │  │   Creation   │
          └──────────────────┘     └──────────────┘  └──────────────┘
```

### Component Responsibilities

#### Central Helm (`helm/`)

**Purpose:** Unified orchestration and dashboard across all domains

**Components:**
- **helm-director** - Routes requests to domain Helm plugins
- **helm-dashboard** - Aggregates metrics from all domains
- **helm-orchestrator** - Cross-domain operations and prioritization

**Capabilities:**
- Unified status dashboard
- Cross-domain issue prioritization
- Voice interface support
- Feedback loop to FABER (create work items)
- Central issue registry

**Commands:**
```bash
/helm:dashboard                # Unified view of all systems
/helm:status                   # Text summary across all domains
/helm:issues --top 5           # Top prioritized issues
/helm:escalate <issue-id>      # Create FABER work item
```

#### Domain Helm Plugins (`helm-cloud/`, `helm-app/`, etc.)

**Purpose:** Domain-specific monitoring expertise

**Pattern (infrastructure example):**
```
helm-cloud/
├── agents/
│   └── ops-manager.md         # Cloud operations orchestrator
└── skills/
    ├── ops-monitor/           # Health checks, metrics
    ├── ops-investigator/      # Log analysis, incidents
    ├── ops-responder/         # Remediation actions
    └── ops-auditor/           # Cost, security, compliance
```

**Capabilities:**
- Domain-specific metrics collection
- Specialized monitoring logic
- Domain-specific remediation actions
- Integration with domain tools (CloudWatch, APM, etc.)

**Commands:**
```bash
/helm-cloud:health --env=prod
/helm-app:errors --since=1h
/helm-content:engagement --period=7d
```

#### Domain FABER Plugins (`faber-cloud/`, `faber-app/`, etc.)

**Purpose:** Domain-specific creation workflows

**Pattern (infrastructure example):**
```
faber-cloud/
├── agents/
│   └── infra-manager.md       # Infrastructure lifecycle
└── skills/
    ├── infra-architect/       # Design solutions
    ├── infra-engineer/        # Generate IaC code
    ├── infra-validator/       # Validate configs
    ├── infra-tester/          # Security scans, tests
    ├── infra-previewer/       # Preview changes
    └── infra-deployer/        # Execute deployment
```

**Capabilities:**
- Domain-specific creation workflows
- FABER phase implementations (Frame → Architect → Build → Evaluate → Release)
- Domain expertise (Terraform for infrastructure, React for apps, etc.)

**Commands:**
```bash
/faber-cloud:architect <description>
/faber-cloud:deploy --env=prod
/faber-app:build
/faber-content:publish
```

---

## Integration Model

### 1. FABER → Helm Handoff

**Trigger:** FABER Release phase completes

**Process:**
1. FABER deploys/publishes
2. FABER (optionally) runs initial health check via Helm
3. FABER registers deployment in central registry
4. FABER completes and closes work item
5. Helm automatically picks up registered deployment
6. Helm begins continuous monitoring

**Central Deployment Registry:**

```
.fractary/registry/deployments.json
```

```json
{
  "deployments": [
    {
      "id": "deploy-12345",
      "domain": "infrastructure",
      "environment": "prod",
      "faber_plugin": "fractary-faber-cloud",
      "helm_plugin": "fractary-helm-cloud",
      "deployed_at": "2025-11-03T10:30:00Z",
      "deployed_by": "faber-workflow-abc",
      "work_item": "https://github.com/org/repo/issues/123",
      "resources": [
        {"type": "lambda", "name": "api-handler", "arn": "arn:aws:lambda:..."},
        {"type": "s3", "name": "uploads", "arn": "arn:aws:s3:::..."}
      ],
      "monitoring": {
        "enabled": true,
        "helm_manager": "fractary-helm-cloud:ops-manager",
        "health_check_interval": "5m",
        "alert_channels": ["slack-ops"]
      }
    }
  ]
}
```

**FABER Release Configuration:**

```toml
# .faber.config.toml
[workflow.release]
register_deployment = true            # Register with Helm
initial_health_check = true           # Invoke Helm for verification
health_check_timeout = "5m"           # Wait up to 5 minutes
on_health_check_failure = "fail"      # Fail workflow if unhealthy
```

### 2. Helm → FABER Feedback Loop

**Trigger:** Helm detects issue requiring code changes

**Process:**
1. Helm detects critical issue
2. Helm registers issue in central registry
3. User or auto-escalation triggers work item creation
4. Helm creates GitHub issue via work-manager
5. Issue includes domain routing metadata
6. FABER Frame picks up new work item
7. Issue classifier determines domain (infrastructure, app, etc.)
8. Routes to appropriate FABER domain plugin
9. FABER workflow fixes issue
10. Post-deployment, Helm verifies fix
11. Helm closes issue

**Issue Escalation:**

```bash
# Helm detects Lambda throttling
helm-cloud:ops-monitor → detects issue → registers

# User escalates (or auto-escalation rule triggers)
/helm:escalate infra-001

# Helm creates GitHub issue
work-manager:create-issue
  title: "[HELM-infra-001] API Lambda throttling in us-east-1"
  labels: [helm-escalation, infrastructure, critical]
  body: |
    ## Helm Issue Details
    - Issue ID: infra-001
    - Domain: infrastructure
    - Detected: ops-monitor health check
    - Impact: P95 latency 450ms (SLO: 200ms)

    ## Suggested Remediation
    - Increase Lambda reserved concurrency to 1500
    - Implement request queuing

# FABER Frame picks up issue
issue-classifier:
  - Labels → domain = infrastructure
  - Routes to → faber-cloud

# FABER workflow executes
faber-cloud:infra-manager
  Frame → Architect → Build → Evaluate → Release

# Helm verifies fix
helm-cloud:ops-monitor health-check
  → Issue resolved → Update status
```

**Auto-Escalation Rules:**

```toml
# helm/config/escalation-rules.toml
[[rules]]
name = "critical-slo-breach"
condition = "severity == 'critical' AND impact.slo_breach == true"
action = "auto_escalate"
faber_priority = "high"
assignee = "on-call-team"

[[rules]]
name = "repeated-degradation"
condition = "issue_count > 3 AND timeframe < '24h'"
action = "auto_escalate"
faber_priority = "medium"
```

### 3. Continuous Monitoring Loop

**Helm runs independently and continuously:**

```
While (true):
  1. Query domain Helm plugins for metrics
  2. Aggregate results
  3. Update dashboard
  4. Check alert rules
  5. Detect anomalies
  6. Investigate issues
  7. Apply auto-remediation (if configured)
  8. Escalate to FABER (if code changes needed)
  9. Sleep (interval)
  10. Repeat
```

**Domain Helm Plugin Workflow:**

```
ops-monitor (runs every 5 minutes):
  1. Read deployment registry
  2. For each resource:
     - Query health status (AWS API, APM, etc.)
     - Query metrics (CloudWatch, Datadog, etc.)
     - Compare against SLOs
  3. Categorize: HEALTHY / DEGRADED / UNHEALTHY
  4. Save health report
  5. Return status to central Helm
```

---

## Universal Pattern

### Standard Plugin Structure for Every Domain

**For any domain X (infrastructure, application, content, design, etc.):**

#### FABER Plugin: `faber-{domain}/`

**Purpose:** Create things in this domain

**Structure:**
```
faber-{domain}/
├── .claude-plugin/
│   └── plugin.json            # Dependencies: fractary-faber
├── agents/
│   └── {domain}-manager.md    # FABER workflow orchestrator
├── skills/
│   ├── {domain}-architect/    # Design phase
│   ├── {domain}-engineer/     # Build phase
│   ├── {domain}-validator/    # Evaluate phase (validation)
│   ├── {domain}-tester/       # Evaluate phase (testing)
│   └── {domain}-deployer/     # Release phase
└── config/
    └── {domain}.example.toml  # Configuration template
```

**Commands:**
```bash
/faber-{domain}:architect <description>
/faber-{domain}:build
/faber-{domain}:validate
/faber-{domain}:deploy --env=<env>
```

#### Helm Plugin: `helm-{domain}/`

**Purpose:** Monitor things in this domain

**Structure:**
```
helm-{domain}/
├── .claude-plugin/
│   └── plugin.json            # Dependencies: fractary-helm, fractary-faber-{domain}
├── agents/
│   └── {domain}-monitor.md    # Helm workflow orchestrator
├── skills/
│   ├── {domain}-health/       # Monitor phase
│   ├── {domain}-investigator/ # Analyze phase
│   ├── {domain}-responder/    # Remediate phase
│   └── {domain}-auditor/      # Audit phase
└── config/
    └── monitoring.example.toml # Monitoring configuration
```

**Commands:**
```bash
/helm-{domain}:health --env=<env>
/helm-{domain}:investigate <issue>
/helm-{domain}:remediate <action>
/helm-{domain}:audit --type=<cost|security|compliance>
```

### Examples Across Domains

#### Infrastructure (Cloud)

**faber-cloud:** Design → Generate Terraform → Validate → Deploy infrastructure
**helm-cloud:** Monitor CloudWatch → Investigate logs → Remediate (scale, restart) → Audit costs/security

**Technologies:** Terraform, AWS, CloudWatch, Cost Explorer

#### Application (Software)

**faber-app:** Design → Code → Test → Deploy application
**helm-app:** Monitor APM → Investigate errors → Remediate (rollback, scale) → Audit performance

**Technologies:** React/Node, Jest, GitHub Actions, Datadog/Sentry

#### Content (Publishing)

**faber-content:** Draft → Write → Edit → Publish content
**helm-content:** Monitor analytics → Investigate low engagement → Remediate (optimize) → Audit SEO

**Technologies:** Markdown, CMS, Google Analytics, SEO tools

#### Design (Design Systems)

**faber-design:** Design → Build component → Review → Release to system
**helm-design:** Monitor usage → Investigate adoption → Remediate (improve DX) → Audit accessibility

**Technologies:** Figma, React, Storybook, Bundle analyzer

### Consistency Across Domains

**Every domain follows the same pattern:**

1. **FABER plugin** handles creation (5 phases)
2. **Helm plugin** handles monitoring (4 phases)
3. **Central Helm** aggregates across all domains
4. **Shared registry** tracks all deployments
5. **Feedback loop** routes issues to appropriate FABER plugin

**This creates predictability:**
- Developers know where creation logic lives
- Operators know where monitoring logic lives
- New domains follow established patterns
- Tools compose naturally

---

## Centralized Dashboard Vision

### The Helm Dashboard: One View for Everything

**Vision:** A single interface to monitor the entire system across all domains

**Capabilities:**

1. **Unified Status View**
   ```
   ═══════════════════════════════════════════════════════════
    HELM DASHBOARD - Production Overview
   ═══════════════════════════════════════════════════════════

   OVERALL HEALTH: ⚠️  DEGRADED

   Infrastructure (helm-cloud)     ⚠️  DEGRADED
     • 12 resources, 11 healthy, 1 degraded
     • CloudWatch alarms: 1 warning

   Applications (helm-app)         ✅ HEALTHY
     • 3 services running
     • Response times: P95 120ms
     • Error rate: 0.02%

   Content (helm-content)          ⚠️  ATTENTION
     • Engagement down 5% vs yesterday
     • SEO ranking stable

   TOP ISSUES:
   🔴 #1 API Lambda throttling (infra)
   🟡 #2 CloudFront cache hit rate low (infra)
   🟡 #3 Content engagement declining (content)
   ```

2. **Cross-Domain Issue Prioritization**
   - Aggregate issues from all domains
   - Calculate priority based on:
     - Severity (critical > high > medium > low)
     - SLO breach (double weight)
     - User impact (all users > 1000 users > 100 users)
     - Duration (longer = higher priority)
     - Domain criticality (infrastructure affects everything)
   - Surface top N issues
   - One-click escalation to FABER

3. **Voice Interface**
   ```
   User: "Hey Helm, what's the status of production?"

   Helm: "Production is degraded. API latency is elevated at 450
          milliseconds, which is above the SLO target of 200. This is
          affecting approximately 1,200 requests per minute and has been
          ongoing for 23 minutes. I've also detected content engagement
          is down 5% today. Would you like me to investigate the API
          latency issue?"

   User: "Yes, investigate"

   Helm: "Investigating... The root cause is Lambda concurrent execution
          limit reached. I can remediate by increasing reserved concurrency
          to 1500, or escalate to FABER for a more permanent solution
          like implementing request queuing. What would you prefer?"
   ```

4. **Intelligent Alerting**
   - Learn from historical patterns
   - Reduce alert fatigue
   - Route alerts to appropriate teams
   - Suggest remediations based on past successes

5. **Multi-Channel Access**
   - CLI: `/helm:dashboard`
   - Web UI: Future browser-based dashboard
   - Voice: Natural language queries
   - API: Programmatic access for integrations
   - Mobile: Future mobile app notifications

### Implementation Architecture

```
┌────────────────────────────────────────────────┐
│          Voice/NLU Interface                   │
│   "Hey Helm, production status"               │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│          helm-director                         │
│   Parse: status + production                  │
│   Route: all domains, env=prod                │
└───────────────────┬────────────────────────────┘
                    │
        ┌───────────┼───────────┬────────────────┐
        │           │           │                │
        ▼           ▼           ▼                ▼
┌──────────┐  ┌──────────┐ ┌──────────┐  ┌──────────┐
│helm-cloud│  │helm-app  │ │helm-     │  │helm-     │
│:health   │  │:health   │ │content:  │  │design:   │
│          │  │          │ │status    │  │status    │
└────┬─────┘  └────┬─────┘ └────┬─────┘  └────┬─────┘
     │             │            │              │
     │ {metrics}   │ {metrics}  │ {metrics}    │ {metrics}
     │             │            │              │
     └─────────────┴────────────┴──────────────┘
                   │
                   ▼
┌────────────────────────────────────────────────┐
│          helm-dashboard                        │
│   • Aggregate metrics                         │
│   • Calculate priorities                      │
│   • Detect anomalies                          │
│   • Generate summary                          │
└───────────────────┬────────────────────────────┘
                    │
                    ▼
┌────────────────────────────────────────────────┐
│          Response Formatter                    │
│   • Text summary                              │
│   • Dashboard view                            │
│   • Voice response                            │
└────────────────────────────────────────────────┘
```

---

## Industry Alignment

### Proven Patterns from Industry Leaders

#### Kubernetes Ecosystem

**Pattern:** Central control plane + domain-specific operators

```
Kubernetes Control Plane
    ├── Core controllers (built-in)
    └── Custom operators (domain-specific)
        ├── Database operators (PostgreSQL, MySQL)
        ├── ML operators (Kubeflow, TensorFlow)
        └── Service mesh operators (Istio, Linkerd)
```

**How FABER/Helm aligns:**
- Kubernetes control plane ≈ Helm central orchestrator
- Custom operators ≈ Domain Helm plugins (helm-cloud, helm-app)
- CRDs (Custom Resources) ≈ Domain deployment registries

**Key insight:** Central orchestration with domain-specific extensions is proven at massive scale.

#### Prometheus + Grafana

**Pattern:** Central collection + domain-specific exporters

```
Prometheus (central metrics storage)
    └── Pulls from exporters
        ├── node-exporter (infrastructure)
        ├── postgres-exporter (database)
        └── app-exporter (application)

Grafana (central visualization)
    └── Queries Prometheus
    └── Dashboards aggregate all domains
```

**How FABER/Helm aligns:**
- Prometheus ≈ Helm central registry
- Exporters ≈ Domain Helm plugins
- Grafana ≈ helm-dashboard

**Key insight:** Centralized aggregation with domain-specific metric collection is the industry standard.

#### Datadog Platform

**Pattern:** Single platform, multi-domain monitoring

```
Datadog Platform
    ├── Infrastructure monitoring
    ├── APM (application performance)
    ├── Log management
    ├── Real user monitoring
    └── Synthetic monitoring

Unified Dashboard
    └── Aggregates all domains
```

**How FABER/Helm aligns:**
- Datadog Platform ≈ Central Helm
- Domain monitoring ≈ Domain Helm plugins
- Unified Dashboard ≈ helm-dashboard

**Key insight:** Users want ONE place to see everything, not separate tools per domain.

### Why These Patterns Work

1. **Separation of Concerns**
   - Central system handles orchestration and aggregation
   - Domain systems handle specialized logic

2. **Composability**
   - Add new domains without changing central system
   - Domains can evolve independently

3. **Single Pane of Glass**
   - Users want unified view
   - Cross-domain insights are valuable
   - Context switching is expensive

4. **Proven at Scale**
   - Kubernetes: Millions of deployments
   - Prometheus: CNCF graduated project
   - Datadog: $2B+ revenue, enterprise scale

**FABER/Helm follows these proven patterns.**

---

## Tool Ecosystem Position

### The Fractary Toolchain

From the tool philosophy document:

> **Five tools addressing fundamental challenges in agentic AI:**
>
> 1. **Forge** (future) - Maker's workbench for authoring primitives and bundles
> 2. **Caster** (future) - Distribution and packaging to registries
> 3. **Codex** - Memory fabric solving the agent memory problem
> 4. **FABER** - Universal maker workflow orchestration
> 5. **Helm** - Runtime monitoring, evaluation, and governance

### The Flow

```
Forge makes → FABER moves → Caster ships → Codex remembers → Helm guards
```

**Detailed:**

1. **Forge:** Authoring new primitives, skills, plugins
   - Create new FABER domain plugins
   - Create new Helm domain plugins
   - Author reusable skills

2. **FABER:** Execute creation workflows
   - Frame → Architect → Build → Evaluate → Release
   - Domain-specific implementations
   - Completes when shipped

3. **Caster:** Distribute and promote
   - Publish to plugin registry
   - Version management
   - Lifecycle promotion (dev → staging → prod)

4. **Codex:** Remember and learn
   - Store creation artifacts
   - Remember successful patterns
   - Learn from past workflows

5. **Helm:** Guard and monitor
   - Monitor what FABER created
   - Ensure things stay healthy
   - Escalate issues back to FABER

### Integration Points

**FABER ↔ Codex:**
- FABER stores artifacts in Codex
- FABER retrieves past patterns from Codex
- Codex provides memory across workflows

**FABER ↔ Helm:**
- FABER hands off to Helm at Release
- Helm escalates issues back to FABER
- Feedback loop creates continuous improvement

**Helm ↔ Codex:**
- Helm stores monitoring data in Codex
- Helm learns from historical patterns
- Codex enables anomaly detection

**All tools ↔ Caster:**
- Caster distributes plugins for FABER, Helm, etc.
- Version management across toolchain
- Unified distribution mechanism

### Division of Responsibilities

| Tool | Responsibility | When |
|------|----------------|------|
| **Forge** | Authoring primitives | When creating new capabilities |
| **FABER** | Creating things | When building/shipping |
| **Caster** | Distributing things | When publishing/promoting |
| **Codex** | Remembering things | Always (memory layer) |
| **Helm** | Guarding things | Always (continuous monitoring) |

**Clear separation:**
- Creation = FABER
- Operations = Helm
- Memory = Codex
- Distribution = Caster
- Authoring = Forge

---

## Summary

### Key Principles

1. **FABER and Helm are complementary, not competing**
   - FABER creates, Helm monitors
   - Both are essential
   - Together they form a complete lifecycle

2. **Clear boundaries prevent confusion**
   - FABER ends at deployment/publication
   - Helm begins with continuous monitoring
   - Handoff is explicit and registered

3. **Feedback loop enables improvement**
   - Helm detects issues
   - Helm creates work items
   - FABER fixes issues
   - Continuous improvement cycle

4. **Universal pattern scales across domains**
   - Every domain: faber-X + helm-X
   - Consistent structure
   - Predictable behavior

5. **Centralized dashboard provides visibility**
   - One view for everything
   - Cross-domain prioritization
   - Voice interface for efficiency

6. **Industry-aligned architecture**
   - Proven patterns (Kubernetes, Prometheus, Datadog)
   - Battle-tested at scale
   - Best practices encoded

### Next Steps

1. **Read:** `SPEC-00007-helm-system-specification.md` for detailed Helm design
2. **Read:** `SPEC-00010-faber-cloud-helm-migration.md` for implementation roadmap
3. **Implement:** Phase 1 (Command Reorganization)
4. **Implement:** Phase 2 (Extract helm-cloud)
5. **Implement:** Phase 3 (Central Helm orchestrator)

### Vision Realized

When fully implemented, you will have:

- **Unified dashboard** showing all systems across all domains
- **Voice interface** for natural language queries ("Helm, status of production?")
- **Intelligent prioritization** surfacing the most important issues
- **Seamless feedback** from monitoring to fixes
- **Scalable architecture** ready for any number of new domains
- **Industry-proven patterns** ensuring long-term success

**FABER creates. Helm guards. Together, they enable continuous delivery and continuous improvement.**

---

**End of Document**
