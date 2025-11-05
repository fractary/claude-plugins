# Helm System Specification

**Version:** 1.0.0
**Date:** 2025-11-03
**Status:** Proposed
**Depends On:** `SPEC-0008-faber-helm-architecture.md`

---

## Table of Contents

1. [Overview](#overview)
2. [Central Helm Plugin](#central-helm-plugin)
3. [Domain Helm Plugins](#domain-helm-plugins)
4. [Monitoring Workflows](#monitoring-workflows)
5. [Issue Registry & Prioritization](#issue-registry--prioritization)
6. [Dashboard Implementation](#dashboard-implementation)
7. [Voice Interface Design](#voice-interface-design)
8. [Configuration Schema](#configuration-schema)
9. [Integration Protocols](#integration-protocols)

---

## Overview

### Purpose

Helm is the **universal operations workflow system** for monitoring, analyzing, alerting, and remediating issues across all domains in the Fractary ecosystem.

### Core Principles

1. **Continuous Monitoring** - Never stops, always watching
2. **Cross-Domain Aggregation** - Single view of entire system
3. **Intelligent Prioritization** - Surface what matters most
4. **Seamless Feedback** - Issues flow back to FABER
5. **Domain Expertise** - Specialized monitoring per domain
6. **Unified Interface** - One dashboard, voice control ready

### Architecture Pattern

**Hybrid Model:** Central orchestrator + domain-specific plugins

```
helm/                    # Central orchestrator
  ├── helm-director      # Routes to domain plugins
  ├── helm-dashboard     # Aggregates all domains
  └── helm-orchestrator  # Cross-domain operations

helm-{domain}/           # Domain-specific monitoring
  ├── agents/            # Domain orchestrators
  └── skills/            # Domain monitoring skills
```

---

## Central Helm Plugin

### Plugin Structure

```
helm/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   ├── helm-director.md        # Routes commands to domain plugins
│   ├── helm-dashboard.md       # Aggregates & visualizes metrics
│   └── helm-orchestrator.md    # Cross-domain operations
├── skills/
│   ├── aggregator/             # Collect from domain plugins
│   ├── prioritizer/            # Calculate issue priorities
│   ├── visualizer/             # Generate dashboard views
│   └── escalator/              # Create FABER work items
├── registry/
│   ├── domain-monitors.json    # List of registered Helm plugins
│   └── slo-definitions.json    # Cross-domain SLO targets
├── issues/
│   ├── active/                 # Current issues (JSON files)
│   └── resolved/               # Historical issues
└── config/
    ├── helm.example.toml       # Configuration template
    └── escalation-rules.toml   # Auto-escalation rules
```

### helm-director Agent

**Purpose:** Route commands to appropriate domain Helm plugins

**Workflow:**

```markdown
<CONTEXT>
You are the Helm Director - the central routing agent for all Helm operations.

Your purpose is to:
1. Parse user requests for monitoring/operations
2. Determine which domain plugin(s) should handle the request
3. Route to appropriate helm-{domain} plugin(s)
4. Aggregate results when multiple domains involved
5. Return unified response to user
</CONTEXT>

<INPUTS>
- User command (natural language or structured)
- Domain filter (optional: --domain=infrastructure)
- Environment filter (optional: --env=prod)
- Scope (single domain vs all domains)
</INPUTS>

<WORKFLOW>
1. Parse user request
   - Extract intent (status, health, investigate, remediate, etc.)
   - Extract filters (domain, environment, resource)
   - Determine scope (single vs multiple domains)

2. Load domain registry
   - Read: helm/registry/domain-monitors.json
   - Get list of registered helm-{domain} plugins
   - Filter by user-specified domain (if any)

3. Route to domain plugin(s)
   - For each relevant domain:
     - Invoke: helm-{domain}:{operation}
     - Pass filters and parameters
     - Collect response

4. Aggregate results (if multiple domains)
   - Combine metrics from all domains
   - Normalize formats
   - Prepare for dashboard or response

5. Return unified response
   - If single domain: return domain response directly
   - If multiple domains: aggregate and format
   - Include source attribution (which domain)
</WORKFLOW>

<COMMANDS>
## Status Queries
- /helm:status [--domain=<domain>] [--env=<env>]
  → Routes to: helm-{domain}:health for each domain

## Dashboard
- /helm:dashboard [--domain=<domain>] [--env=<env>]
  → Routes to: helm-dashboard skill

## Issues
- /helm:issues [--top N] [--domain=<domain>] [--severity=<level>]
  → Routes to: helm/issues/active/ registry

## Escalation
- /helm:escalate <issue-id>
  → Routes to: helm-escalator skill
</COMMANDS>
</WORKFLOW>

**Example Routing:**

```bash
# User: /helm:status --env=prod
helm-director:
  1. Parse: intent=status, env=prod, domain=ALL
  2. Load domain registry
  3. Invoke:
     - helm-cloud:health --env=prod
     - helm-app:health --env=prod
     - helm-content:status --env=prod
  4. Aggregate results
  5. Return unified summary
```

### helm-dashboard Agent

**Purpose:** Generate unified dashboard view across all domains

**Workflow:**

```markdown
<CONTEXT>
You are the Helm Dashboard - the unified visualization agent.

Your purpose is to:
1. Aggregate metrics from all domain Helm plugins
2. Calculate overall system health
3. Prioritize issues across domains
4. Generate human-readable dashboard
5. Support multiple output formats (text, JSON, voice)
</CONTEXT>

<INPUTS>
- Domain filter (optional)
- Environment filter (optional)
- Output format (text, json, voice)
</INPUTS>

<WORKFLOW>
1. Collect metrics from all domains
   - Invoke helm-director to query all domains
   - Retrieve: health status, metrics, active issues

2. Calculate overall health
   - Aggregate: HEALTHY / DEGRADED / UNHEALTHY
   - Rule: Overall = worst domain status
   - Track: number of healthy/degraded/unhealthy resources

3. Load and prioritize issues
   - Read: helm/issues/active/*.json
   - Calculate priority scores
   - Sort by priority (descending)
   - Group by domain

4. Generate dashboard view
   - Header: Overall status, timestamp
   - Domain summary: Status per domain
   - Top issues: Prioritized list
   - Quick actions: Available commands

5. Format output
   - Text: ASCII table/formatted text
   - JSON: Structured data
   - Voice: Natural language summary
</WORKFLOW>

<OUTPUT_TEMPLATE>
═══════════════════════════════════════════════════════════
 HELM DASHBOARD - {Environment} Overview
 Updated: {Timestamp}
═══════════════════════════════════════════════════════════

OVERALL HEALTH: {Status Icon} {Status}

┌─────────────────────────────────────────────────────────┐
│ DOMAIN SUMMARY                                          │
├─────────────────────────────────────────────────────────┤
{For each domain:}
│ {Domain} ({plugin})   {Status Icon} {Status}           │
│   • {Resource count} resources                          │
│   • {Health summary}                                    │
│   • {Key metrics}                                       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ TOP ISSUES (by priority)                                │
├─────────────────────────────────────────────────────────┤
{For each issue:}
│ {Icon} {Severity} #{Priority}                          │
│   Issue: {Title}                                        │
│   Impact: {Impact summary}                              │
│   Duration: {Time since detected}                       │
│   Action: [Investigate] [Remediate] [Escalate]         │
└─────────────────────────────────────────────────────────┘

QUICK ACTIONS:
  [Investigate All] [Auto-Remediate] [Escalate Top Issue]
  [View by Domain] [Filter Critical] [Export Report]
</OUTPUT_TEMPLATE>
</DASHBOARD>
```

### Domain Monitor Registry

**File:** `helm/registry/domain-monitors.json`

```json
{
  "version": "1.0.0",
  "updated_at": "2025-11-03T10:00:00Z",
  "monitors": [
    {
      "domain": "infrastructure",
      "plugin": "fractary-helm-cloud",
      "version": "1.0.0",
      "manager": "ops-manager",
      "capabilities": [
        "health-check",
        "metrics-query",
        "log-analysis",
        "remediation",
        "cost-audit",
        "security-audit"
      ],
      "environments": ["test", "prod"],
      "slos": {
        "p95_latency": {"target": 200, "unit": "ms"},
        "error_rate": {"target": 0.1, "unit": "%"},
        "availability": {"target": 99.9, "unit": "%"}
      },
      "escalation_channels": ["slack-ops", "pagerduty-infra"]
    },
    {
      "domain": "application",
      "plugin": "fractary-helm-app",
      "version": "1.5.0",
      "manager": "app-monitor",
      "capabilities": [
        "health-check",
        "apm",
        "error-tracking",
        "performance-analysis"
      ],
      "environments": ["test", "staging", "prod"],
      "slos": {
        "p95_response_time": {"target": 150, "unit": "ms"},
        "error_rate": {"target": 0.05, "unit": "%"},
        "availability": {"target": 99.95, "unit": "%"}
      },
      "escalation_channels": ["slack-dev", "pagerduty-app"]
    }
  ]
}
```

**Registration Process:**

When a new helm-{domain} plugin is created:

1. Plugin defines its capabilities in plugin.json
2. During initialization, plugin registers with central Helm
3. helm-director adds entry to domain-monitors.json
4. Dashboard automatically includes new domain

---

## Domain Helm Plugins

### Standard Structure (helm-cloud example)

```
helm-cloud/
├── .claude-plugin/
│   └── plugin.json
│       {
│         "name": "fractary-helm-cloud",
│         "version": "1.0.0",
│         "dependencies": {
│           "fractary-helm": "^1.0.0",
│           "fractary-faber-cloud": "^2.0.0"
│         },
│         "monitors": {
│           "domain": "infrastructure",
│           "capabilities": ["health", "logs", "metrics", "remediation"]
│         }
│       }
├── agents/
│   └── ops-manager.md
├── skills/
│   ├── ops-monitor/
│   │   ├── SKILL.md
│   │   ├── workflow/
│   │   │   ├── health-check.md
│   │   │   ├── metrics-query.md
│   │   │   └── performance-analysis.md
│   │   └── scripts/
│   │       ├── check-resource-health.sh
│   │       └── query-cloudwatch-metrics.sh
│   ├── ops-investigator/
│   │   ├── SKILL.md
│   │   └── workflow/
│   │       ├── log-analysis.md
│   │       └── incident-correlation.md
│   ├── ops-responder/
│   │   ├── SKILL.md
│   │   └── workflow/
│   │       ├── restart-service.md
│   │       ├── scale-resource.md
│   │       └── rollback.md
│   └── ops-auditor/
│       ├── SKILL.md
│       └── workflow/
│           ├── cost-analysis.md
│           ├── security-scan.md
│           └── compliance-check.md
├── config/
│   └── monitoring.example.toml
└── monitoring/
    ├── {env}/
    │   └── {timestamp}-health-check.json
    └── reports/
        └── {timestamp}-audit-report.json
```

### ops-manager Agent (helm-cloud)

```markdown
<CONTEXT>
You are the Operations Manager for cloud infrastructure - a Helm domain agent.

Your purpose is to:
1. Monitor deployed cloud infrastructure (AWS, GCP, Azure)
2. Detect performance degradation and failures
3. Investigate incidents via log analysis
4. Apply remediations (restart, scale, rollback)
5. Audit costs, security, and compliance
6. Escalate to FABER when code changes needed
</CONTEXT>

<CAPABILITIES>
## Health Monitoring (ops-monitor skill)
- check-health: Verify resource status and metrics
- query-metrics: CloudWatch/Stackdriver metrics
- analyze-performance: Trend analysis

## Incident Investigation (ops-investigator skill)
- query-logs: Search CloudWatch Logs
- investigate: Root cause analysis
- correlate: Event correlation across services

## Remediation (ops-responder skill)
- restart: Force new deployment (ECS, Lambda)
- scale: Increase/decrease capacity
- rollback: Revert to previous version

## Auditing (ops-auditor skill)
- cost: AWS Cost Explorer analysis
- security: Security Hub findings
- compliance: Config Rules evaluation
</CAPABILITIES>

<WORKFLOW>
## Health Check Workflow
1. Read deployment registry
2. For each resource:
   - Query resource status
   - Query CloudWatch metrics
   - Compare against SLOs
3. Categorize: HEALTHY / DEGRADED / UNHEALTHY
4. Generate health report
5. Register issues if degraded/unhealthy

## Incident Investigation Workflow
1. Receive incident details (resource, symptoms)
2. Query relevant logs (CloudWatch Logs)
3. Search for error patterns
4. Correlate with metrics (did CPU spike?)
5. Identify root cause
6. Suggest remediation
7. Generate incident report

## Remediation Workflow
1. Diagnose issue (what's wrong?)
2. Propose remediation (restart vs scale vs rollback)
3. Confirm with user (production safety)
4. Apply remediation via AWS CLI/SDK
5. Verify remediation success
6. Document action taken
7. Update issue status
</WORKFLOW>

<INTEGRATION_WITH_CENTRAL_HELM>
## Registration
- ops-manager registers capabilities with helm/registry/domain-monitors.json
- Provides SLO definitions for infrastructure domain

## Issue Reporting
- When degraded/unhealthy resources detected:
  - Create issue: helm/issues/active/infra-{id}.json
  - Include: severity, impact, metrics, suggested remediation

## Escalation
- When remediation requires code changes:
  - Notify helm-orchestrator
  - Provide context for FABER work item creation
</INTEGRATION_WITH_CENTRAL_HELM>
```

---

## Monitoring Workflows

### Monitor → Analyze → Alert → Remediate

#### 1. Monitor Phase

**Purpose:** Continuous health checking and metrics collection

**Workflow (ops-monitor skill):**

```markdown
<WORKFLOW>
## Health Check (runs every 5 minutes)

1. **Load deployment registry**
   ```bash
   REGISTRY=".fractary/registry/deployments.json"
   RESOURCES=$(jq -r '.deployments[] | select(.environment == env and .domain == "infrastructure") | .resources[]' $REGISTRY)
   ```

2. **For each resource:**

   **a. Query resource status (AWS API)**
   ```bash
   aws lambda get-function --function-name ${resource.name}
   aws rds describe-db-instances --db-instance-identifier ${resource.name}
   aws ecs describe-services --service ${resource.name}
   ```

   **b. Query CloudWatch metrics**
   ```bash
   aws cloudwatch get-metric-statistics \
     --namespace AWS/Lambda \
     --metric-name Invocations \
     --start-time ${5_minutes_ago} \
     --end-time ${now} \
     --period 300 \
     --statistics Sum
   ```

   **c. Calculate health status**
   ```python
   if resource_state != "ACTIVE":
       status = "UNHEALTHY"
   elif error_rate > slo_error_rate:
       status = "DEGRADED"
   elif latency_p95 > slo_latency:
       status = "DEGRADED"
   else:
       status = "HEALTHY"
   ```

3. **Generate health report**
   ```json
   {
     "timestamp": "2025-11-03T10:35:00Z",
     "environment": "prod",
     "domain": "infrastructure",
     "summary": {
       "total": 12,
       "healthy": 11,
       "degraded": 1,
       "unhealthy": 0
     },
     "resources": [
       {
         "name": "api-lambda",
         "type": "lambda",
         "status": "DEGRADED",
         "metrics": {
           "invocations": 1250,
           "errors": 65,
           "error_rate": 5.2,
           "slo_error_rate": 0.1
         },
         "issue_created": "infra-001"
       }
     ]
   }
   ```

4. **Save report**
   ```bash
   save_to: .fractary/plugins/helm-cloud/monitoring/prod/2025-11-03-10-35-health.json
   ```

5. **Register issues**
   - For each DEGRADED/UNHEALTHY resource
   - Create issue: helm/issues/active/infra-{id}.json

6. **Return to helm-director**
   - Summary: healthy/degraded/unhealthy counts
   - Top issues list
</WORKFLOW>
```

#### 2. Analyze Phase

**Purpose:** Investigate root causes of detected issues

**Workflow (ops-investigator skill):**

```markdown
<WORKFLOW>
## Incident Investigation

1. **Receive issue details**
   - Issue ID: infra-001
   - Resource: api-lambda
   - Symptom: Error rate 5.2% (SLO: 0.1%)

2. **Query relevant logs**
   ```bash
   aws logs filter-log-events \
     --log-group-name /aws/lambda/api-lambda \
     --start-time ${incident_start} \
     --filter-pattern "ERROR"
   ```

3. **Analyze error patterns**
   ```python
   errors = parse_log_events(log_events)
   patterns = group_by_pattern(errors)

   # Example output:
   {
     "DatabaseConnectionTimeout": 45 occurrences,
     "ValidationError": 15 occurrences,
     "UnauthorizedAccess": 5 occurrences
   }
   ```

4. **Correlate with metrics**
   ```python
   # Did something else spike at same time?
   check_metric("Duration")  # Lambda execution time
   check_metric("ConcurrentExecutions")  # Throttling?
   check_metric("DatabaseConnections")  # RDS connections
   ```

5. **Identify root cause**
   ```
   Root Cause: Database connection pool exhausted

   Evidence:
   - 45 DatabaseConnectionTimeout errors
   - Lambda Duration spiked from 200ms to 5000ms
   - RDS DatabaseConnections at 100/100 (max pool size)

   Contributing Factors:
   - Traffic increased 3x vs normal
   - No connection pooling implemented
   - No auto-scaling configured
   ```

6. **Suggest remediation**
   ```
   Immediate Remediation (Helm):
   - Increase RDS max_connections to 200
   - Restart Lambda to clear connection leaks

   Permanent Fix (FABER):
   - Implement connection pooling in Lambda code
   - Add auto-scaling based on connection utilization
   - Configure CloudWatch alarm for connection pool
   ```

7. **Generate incident report**
   ```json
   {
     "issue_id": "infra-001",
     "timestamp": "2025-11-03T10:40:00Z",
     "root_cause": "Database connection pool exhausted",
     "evidence": [...],
     "timeline": [
       {"time": "10:22", "event": "Traffic spike detected"},
       {"time": "10:23", "event": "Connection errors start"},
       {"time": "10:25", "event": "Error rate exceeds SLO"}
     ],
     "suggested_remediation": {
       "immediate": ["increase_rds_connections", "restart_lambda"],
       "permanent": ["implement_connection_pooling", "add_autoscaling"]
     }
   }
   ```
</WORKFLOW>
```

#### 3. Alert Phase

**Purpose:** Notify relevant parties about issues

**Workflow (helm-orchestrator):**

```markdown
<WORKFLOW>
## Alerting

1. **Evaluate alert rules**
   ```toml
   # helm/config/alert-rules.toml
   [[rules]]
   name = "critical-slo-breach"
   condition = "severity == 'critical' AND impact.slo_breach == true"
   channels = ["slack-ops", "pagerduty-oncall"]

   [[rules]]
   name = "degraded-performance"
   condition = "severity == 'high' AND status == 'DEGRADED'"
   channels = ["slack-ops"]
   ```

2. **Format alert message**
   ```
   🔴 CRITICAL: API Lambda Error Rate SLO Breach

   Environment: Production
   Resource: api-lambda (Lambda function)
   Issue: infra-001

   Impact:
   - Error rate: 5.2% (SLO: 0.1%)
   - Requests affected: 65/1250 (last 5 min)
   - Duration: 18 minutes

   Root Cause: Database connection pool exhausted

   Actions Available:
   - /helm:remediate infra-001 --action=immediate
   - /helm:investigate infra-001 --details
   - /helm:escalate infra-001 --to=faber

   Dashboard: /helm:dashboard --env=prod
   ```

3. **Send to channels**
   - Slack: Post to #ops channel
   - PagerDuty: Create incident for on-call
   - Email: Send to ops-team@example.com (if configured)

4. **Track alert state**
   - Record: helm/issues/active/infra-001.json
   - Update: last_alerted_at, alert_count
</WORKFLOW>
```

#### 4. Remediate Phase

**Purpose:** Apply fixes to restore health

**Workflow (ops-responder skill):**

```markdown
<WORKFLOW>
## Remediation

1. **Receive remediation request**
   - Issue ID: infra-001
   - Action: immediate (increase_rds_connections + restart_lambda)

2. **Diagnose issue**
   - Read: helm/issues/active/infra-001.json
   - Understand: root cause, affected resources, suggested remediation

3. **Propose remediation**
   ```
   Proposed Actions:
   1. Increase RDS max_connections from 100 to 200
   2. Restart Lambda function to clear connection leaks

   Estimated Impact:
   - Downtime: 0 seconds (rolling restart)
   - Risk: Low (increasing connections is safe)
   - Expected Recovery: 2-3 minutes
   ```

4. **Confirm with user (production safety)**
   ```
   ⚠️  PRODUCTION REMEDIATION

   Environment: prod
   Action: Increase RDS connections + Restart Lambda
   Risk: LOW

   Proceed? (yes/no)
   ```

5. **Apply remediation**

   **a. Increase RDS connections**
   ```bash
   aws rds modify-db-parameter-group \
     --db-parameter-group-name prod-params \
     --parameters "ParameterName=max_connections,ParameterValue=200" \
     --apply-immediately
   ```

   **b. Restart Lambda**
   ```bash
   # Lambda doesn't have restart, trigger config update
   aws lambda update-function-configuration \
     --function-name api-lambda \
     --description "Restarted at $(date) - connection pool fix"
   ```

6. **Verify remediation success**
   ```bash
   # Wait 2 minutes for changes to take effect
   sleep 120

   # Check error rate
   error_rate=$(query_cloudwatch_error_rate api-lambda 5m)

   if [ $error_rate -lt 0.5 ]; then
     status="SUCCESS"
   else
     status="FAILED"
   fi
   ```

7. **Document action**
   ```json
   {
     "issue_id": "infra-001",
     "remediation_id": "rem-001",
     "timestamp": "2025-11-03T10:45:00Z",
     "actions_taken": [
       {
         "action": "increase_rds_max_connections",
         "from": 100,
         "to": 200,
         "result": "SUCCESS"
       },
       {
         "action": "restart_lambda",
         "function": "api-lambda",
         "result": "SUCCESS"
       }
     ],
     "verification": {
       "error_rate_before": 5.2,
       "error_rate_after": 0.08,
       "slo_met": true,
       "status": "SUCCESS"
     }
   }
   ```

8. **Update issue status**
   - If remediation successful: status = "RESOLVED"
   - If failed: status = "REMEDIATION_FAILED", suggest escalation
   - Move: helm/issues/active/infra-001.json → helm/issues/resolved/

9. **Notify stakeholders**
   ```
   ✅ RESOLVED: API Lambda Error Rate SLO Breach

   Issue: infra-001
   Remediation: Increased RDS connections + Restarted Lambda
   Result: Error rate dropped from 5.2% to 0.08%
   Duration: 23 minutes (detected to resolved)

   Permanent fix recommended: /helm:escalate infra-001 --permanent
   ```
</WORKFLOW>
```

---

## Issue Registry & Prioritization

### Issue Schema

**File:** `helm/issues/active/{issue-id}.json`

```json
{
  "issue_id": "infra-001",
  "domain": "infrastructure",
  "environment": "prod",
  "severity": "critical",
  "priority": 245,
  "status": "active",

  "detection": {
    "detected_at": "2025-11-03T10:22:00Z",
    "detected_by": "helm-cloud:ops-monitor",
    "check_type": "health-check"
  },

  "resource": {
    "type": "lambda",
    "name": "api-lambda",
    "arn": "arn:aws:lambda:us-east-1:123456789:function:api-lambda",
    "deployment_id": "deploy-12345"
  },

  "issue": {
    "title": "API Lambda error rate SLO breach",
    "description": "Error rate 5.2% exceeds SLO target of 0.1%",
    "symptoms": [
      "High error rate (5.2%)",
      "Increased latency (P95: 5000ms)",
      "Database connection timeouts"
    ]
  },

  "impact": {
    "users_affected": "all",
    "requests_affected": 65,
    "requests_total": 1250,
    "slo_breach": true,
    "slo_metric": "error_rate",
    "slo_target": 0.1,
    "slo_current": 5.2,
    "business_impact": "API unavailable for 5% of requests"
  },

  "root_cause": {
    "identified": true,
    "cause": "Database connection pool exhausted",
    "evidence": [
      "45 DatabaseConnectionTimeout errors",
      "RDS connections at 100/100 max",
      "Lambda duration spike to 5000ms"
    ],
    "contributing_factors": [
      "Traffic spike 3x normal",
      "No connection pooling",
      "No auto-scaling"
    ]
  },

  "remediation": {
    "immediate_actions": [
      {
        "action": "increase_rds_max_connections",
        "from": 100,
        "to": 200,
        "estimated_time": "2 minutes",
        "risk": "low"
      },
      {
        "action": "restart_lambda",
        "estimated_time": "1 minute",
        "risk": "low"
      }
    ],
    "permanent_fix": {
      "requires": "code_changes",
      "description": "Implement connection pooling in Lambda",
      "estimated_effort": "4 hours",
      "faber_workflow": true
    }
  },

  "timeline": [
    {
      "timestamp": "2025-11-03T10:22:00Z",
      "event": "Traffic spike detected (+300%)"
    },
    {
      "timestamp": "2025-11-03T10:23:00Z",
      "event": "Connection errors start appearing"
    },
    {
      "timestamp": "2025-11-03T10:25:00Z",
      "event": "Error rate exceeds SLO (5.2%)"
    },
    {
      "timestamp": "2025-11-03T10:27:00Z",
      "event": "Issue registered in Helm"
    },
    {
      "timestamp": "2025-11-03T10:30:00Z",
      "event": "Root cause identified"
    }
  ],

  "escalation": {
    "escalated_to_faber": false,
    "escalation_reason": null,
    "work_item_url": null
  },

  "related_issues": [],

  "metadata": {
    "created_at": "2025-11-03T10:27:00Z",
    "updated_at": "2025-11-03T10:30:00Z",
    "alert_count": 1,
    "last_alerted_at": "2025-11-03T10:27:00Z"
  }
}
```

### Priority Calculation Algorithm

**Implementation:** `helm/skills/prioritizer/calculate-priority.py`

```python
def calculate_priority(issue):
    """Calculate issue priority score (higher = more urgent)"""

    score = 0

    # 1. Severity weight (base score)
    severity_weights = {
        "critical": 100,
        "high": 50,
        "medium": 25,
        "low": 10
    }
    score += severity_weights[issue["severity"]]

    # 2. SLO breach (double the score)
    if issue["impact"]["slo_breach"]:
        score *= 2

    # 3. User impact
    users_affected = issue["impact"]["users_affected"]
    if users_affected == "all":
        score += 50
    elif isinstance(users_affected, int):
        if users_affected > 1000:
            score += 30
        elif users_affected > 100:
            score += 10

    # 4. Duration (longer = higher priority)
    detected_at = parse_timestamp(issue["detection"]["detected_at"])
    duration_minutes = (datetime.now() - detected_at).total_seconds() / 60
    if duration_minutes > 60:
        score += 20
    elif duration_minutes > 30:
        score += 10

    # 5. Business impact keywords
    business_impact = issue["impact"].get("business_impact", "")
    if any(word in business_impact.lower() for word in ["unavailable", "down", "outage"]):
        score += 30

    # 6. Domain priority (infra issues affect everything)
    domain_weights = {
        "infrastructure": 1.5,
        "application": 1.3,
        "content": 1.0,
        "design": 0.8
    }
    score *= domain_weights.get(issue["domain"], 1.0)

    # 7. Environment weight (prod is critical)
    env_weights = {
        "prod": 2.0,
        "staging": 1.2,
        "test": 1.0
    }
    score *= env_weights.get(issue["environment"], 1.0)

    return int(score)

# Example:
# issue_infra_001:
#   severity: critical (100)
#   slo_breach: true (×2 = 200)
#   users_affected: all (+50 = 250)
#   duration: 23 min (+10 = 260)
#   business_impact: "unavailable" (+30 = 290)
#   domain: infrastructure (×1.5 = 435)
#   environment: prod (×2.0 = 870)
# Final Priority: 870
```

### Issue Lifecycle

```
┌──────────────────┐
│  Issue Detected  │
│  (ops-monitor)   │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Status: ACTIVE  │
│  Create JSON     │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Investigate     │
│  (ops-investigator) │
└────────┬─────────┘
         │
         ▼
┌──────────────────┐
│  Root Cause      │
│  Identified      │
└────────┬─────────┘
         │
    ┌────┴────┐
    │         │
    ▼         ▼
┌────────┐ ┌────────┐
│Immediate│ │Permanent│
│Fix?     │ │Fix?    │
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
┌────────┐ ┌────────┐
│Remediate│ │Escalate│
│(ops-    │ │to      │
│responder)│ │FABER   │
└───┬────┘ └───┬────┘
    │          │
    ▼          ▼
┌────────┐ ┌────────┐
│Verify  │ │Create  │
│Success │ │Work    │
│        │ │Item    │
└───┬────┘ └────────┘
    │
    ▼
┌────────────────┐
│Status: RESOLVED│
│Move to         │
│resolved/       │
└────────────────┘
```

---

## Dashboard Implementation

### Text-Based Dashboard (MVP)

**Command:** `/helm:dashboard`

**Output Format:**

```
═══════════════════════════════════════════════════════════
 HELM DASHBOARD - Production Overview
 Updated: 2025-11-03 10:45:00 UTC
═══════════════════════════════════════════════════════════

OVERALL HEALTH: ⚠️  DEGRADED

┌─────────────────────────────────────────────────────────┐
│ DOMAIN SUMMARY                                          │
├─────────────────────────────────────────────────────────┤
│ Infrastructure (helm-cloud)     ⚠️  DEGRADED            │
│   • 12 resources deployed                               │
│   • 11 healthy, 1 degraded (API Lambda)                │
│   • CloudWatch alarms: 1 warning                       │
│                                                         │
│ Applications (helm-app)         ✅ HEALTHY              │
│   • 3 services running                                  │
│   • Response times: P95 120ms                          │
│   • Error rate: 0.02% (within threshold)               │
│                                                         │
│ Content (helm-content)          ⚠️  ATTENTION           │
│   • Engagement down 5% vs yesterday                    │
│   • SEO ranking stable                                  │
│   • CDN performance: 65% cache hit (target: 80%)       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│ TOP ISSUES (by priority)                                │
├─────────────────────────────────────────────────────────┤
│ 🔴 CRITICAL #870 (infra-001)                           │
│   Issue: API Lambda error rate SLO breach              │
│   Impact: 5.2% error rate (SLO: 0.1%)                  │
│   Affected: 65/1250 requests                           │
│   Duration: 23 minutes                                  │
│   Action: [Investigate] [Remediate] [Escalate]         │
│                                                         │
│ 🟡 WARNING #245 (infra-002)                            │
│   Issue: CloudFront cache hit rate low                 │
│   Impact: Higher origin load, slower responses         │
│   Current: 65% (target: 80%)                           │
│   Action: [Investigate] [Optimize]                     │
│                                                         │
│ 🟡 WARNING #180 (content-001)                          │
│   Issue: Content engagement declining                   │
│   Impact: 5% drop in page views                        │
│   Timeframe: Last 24 hours                             │
│   Action: [View Analytics] [Escalate]                  │
└─────────────────────────────────────────────────────────┘

QUICK ACTIONS:
  /helm:investigate infra-001         - Investigate top issue
  /helm:remediate infra-001           - Apply immediate fix
  /helm:escalate infra-001            - Create FABER work item
  /helm:issues --top 10               - View more issues
  /helm:dashboard --domain=infrastructure - Filter by domain
```

### JSON Dashboard (API/Programmatic)

**Command:** `/helm:dashboard --format=json`

**Output:**

```json
{
  "timestamp": "2025-11-03T10:45:00Z",
  "environment": "prod",
  "overall_health": "DEGRADED",

  "domains": [
    {
      "domain": "infrastructure",
      "plugin": "helm-cloud",
      "status": "DEGRADED",
      "resources": {
        "total": 12,
        "healthy": 11,
        "degraded": 1,
        "unhealthy": 0
      },
      "metrics": {
        "cloudwatch_alarms": {
          "ok": 10,
          "alarm": 1,
          "insufficient_data": 1
        }
      },
      "top_issue": "infra-001"
    },
    {
      "domain": "application",
      "plugin": "helm-app",
      "status": "HEALTHY",
      "services": {
        "total": 3,
        "healthy": 3,
        "degraded": 0,
        "unhealthy": 0
      },
      "metrics": {
        "p95_response_time_ms": 120,
        "error_rate_percent": 0.02
      },
      "top_issue": null
    }
  ],

  "issues": {
    "total": 3,
    "critical": 1,
    "high": 0,
    "medium": 2,
    "low": 0,
    "top_issues": [
      {
        "issue_id": "infra-001",
        "priority": 870,
        "severity": "critical",
        "title": "API Lambda error rate SLO breach",
        "domain": "infrastructure",
        "duration_minutes": 23,
        "impact": {
          "slo_breach": true,
          "users_affected": "all"
        }
      }
    ]
  },

  "quick_actions": [
    {
      "command": "/helm:investigate infra-001",
      "description": "Investigate top issue"
    },
    {
      "command": "/helm:remediate infra-001",
      "description": "Apply immediate fix"
    },
    {
      "command": "/helm:escalate infra-001",
      "description": "Create FABER work item"
    }
  ]
}
```

### Voice Dashboard (Natural Language)

**User:** "Hey Helm, what's the status of production?"

**Helm Response (TTS-ready):**

```
Production is currently degraded. I've detected one critical issue
affecting the API Lambda function. The error rate is five point two
percent, which exceeds our SLO target of zero point one percent. This
is affecting sixty-five out of twelve hundred fifty requests and has
been ongoing for twenty-three minutes.

I've also noticed content engagement is down five percent today, and
the CloudFront cache hit rate is at sixty-five percent instead of our
target of eighty percent.

The most urgent issue is the API Lambda error rate. I've investigated
and found the root cause is database connection pool exhaustion. I can
apply an immediate fix by increasing RDS max connections and restarting
the Lambda, or we can escalate to FABER for a permanent solution.

Would you like me to apply the immediate fix, investigate further, or
create a work item for the development team?
```

---

## Voice Interface Design

### Architecture

```
┌────────────────────────────────────┐
│   Voice Input (Future)             │
│   Speech-to-Text                   │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Natural Language Understanding   │
│   Parse intent & entities          │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   helm-director                    │
│   Route to appropriate domain      │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Domain Helm Plugin(s)            │
│   Execute operation                │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   helm-dashboard                   │
│   Aggregate & format response      │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Natural Language Generation      │
│   Format for voice output          │
└──────────────┬─────────────────────┘
               │
               ▼
┌────────────────────────────────────┐
│   Voice Output (Future)            │
│   Text-to-Speech                   │
└────────────────────────────────────┘
```

### Intent Mapping

**User utterances → Helm commands**

| User Says | Intent | Command | Entities |
|-----------|--------|---------|----------|
| "What's the status?" | status_query | /helm:status | env=prod (default) |
| "Status of production" | status_query | /helm:status | env=prod |
| "How's the infrastructure?" | status_query | /helm:status | domain=infrastructure |
| "Show me the dashboard" | dashboard_view | /helm:dashboard | None |
| "What issues do we have?" | issues_list | /helm:issues | severity=all |
| "Show critical issues" | issues_list | /helm:issues | severity=critical |
| "Investigate issue one" | investigate | /helm:investigate | issue_id=infra-001 |
| "Fix the Lambda error" | remediate | /helm:remediate | resource=lambda |
| "Create a ticket for this" | escalate | /helm:escalate | context=current |

### Response Templates

**Status Query Response:**

```python
def format_status_response(status_data):
    """Format status for voice output"""

    overall = status_data["overall_health"]
    domains = status_data["domains"]
    issues = status_data["issues"]

    response = f"{get_environment_name()} is currently {overall.lower()}. "

    if overall != "HEALTHY":
        # Describe the problem
        top_issue = issues["top_issues"][0]
        response += f"I've detected {describe_severity(top_issue['severity'])} issue "
        response += f"affecting {describe_resource(top_issue['domain'], top_issue['title'])}. "
        response += describe_impact(top_issue['impact'])

        # Offer actions
        response += " Would you like me to investigate, apply a fix, or create a work item?"
    else:
        # All good
        response += "All systems are operating normally. "
        response += f"{sum(d['resources']['total'] for d in domains)} resources monitored, "
        response += f"{sum(d['resources']['healthy'] for d in domains)} healthy. "

    return response

# Example output:
# "Production is currently degraded. I've detected a critical issue
#  affecting the API Lambda function. The error rate is five point two
#  percent, exceeding our SLO. Would you like me to investigate,
#  apply a fix, or create a work item?"
```

---

## Configuration Schema

### Helm Core Configuration

**File:** `helm/config/helm.toml`

```toml
[helm]
version = "1.0.0"
environments = ["test", "staging", "prod"]

[dashboard]
refresh_interval = "5m"           # How often to update dashboard
default_environment = "prod"       # Default env if not specified
default_output = "text"            # text | json | voice

[monitoring]
health_check_interval = "5m"       # How often domains run health checks
metrics_retention_days = 30        # Keep metrics for 30 days
issue_retention_days = 90          # Keep resolved issues for 90 days

[alerting]
enabled = true
channels = ["slack-ops"]           # Default alert channels
alert_on = ["critical", "high"]    # Alert severities
throttle_minutes = 15              # Min time between alerts for same issue

[escalation]
auto_escalate = true
auto_escalate_rules = "helm/config/escalation-rules.toml"

[voice]
enabled = false                    # Future: voice interface
wake_word = "hey helm"
tts_voice = "en-US-Standard-A"
```

### Escalation Rules

**File:** `helm/config/escalation-rules.toml`

```toml
[[rules]]
name = "critical-slo-breach"
description = "Auto-escalate critical SLO breaches"
condition = """
severity == 'critical' AND
impact.slo_breach == true
"""
action = "auto_escalate"
faber = {
  priority = "high",
  labels = ["slo-breach", "auto-escalated"],
  assign_to = "on-call-team"
}

[[rules]]
name = "repeated-degradation"
description = "Escalate if issue repeats frequently"
condition = """
issue_count > 3 AND
timeframe_hours < 24
"""
action = "auto_escalate"
faber = {
  priority = "medium",
  labels = ["repeated-issue", "auto-escalated"],
  assign_to = "platform-team"
}

[[rules]]
name = "extended-outage"
description = "Escalate if issue persists > 1 hour"
condition = """
duration_minutes > 60 AND
status == 'active'
"""
action = "auto_escalate"
faber = {
  priority = "high",
  labels = ["extended-outage", "auto-escalated"],
  assign_to = "incident-commander"
}
```

### Domain Helm Configuration

**File:** `helm-cloud/config/monitoring.toml`

```toml
[helm-cloud]
domain = "infrastructure"
environments = ["test", "prod"]

[monitoring]
health_check_interval = "5m"
enabled_checks = [
  "resource_status",
  "cloudwatch_metrics",
  "cloudwatch_alarms",
  "cost_anomalies"
]

[slos]
[slos.lambda]
error_rate_percent = 0.1
p95_latency_ms = 200
availability_percent = 99.9

[slos.rds]
error_rate_percent = 0.01
connection_time_ms = 100
availability_percent = 99.95

[remediation]
auto_remediate = ["restart_lambda", "clear_cache"]
require_confirmation = ["scale_resources", "increase_capacity"]
never_auto = ["delete_resources", "modify_security_groups"]

[escalation]
channels = ["slack-ops", "pagerduty-infra"]
on_call_schedule = "pagerduty-infra-oncall"
```

---

## Integration Protocols

### FABER → Helm Handoff Protocol

**Step 1: FABER Registers Deployment**

```python
# In faber-cloud/skills/infra-deployer/
def register_deployment_with_helm():
    """Register deployment in central registry for Helm monitoring"""

    deployment = {
        "id": f"deploy-{uuid4()}",
        "domain": "infrastructure",
        "environment": config["environment"],
        "faber_plugin": "fractary-faber-cloud",
        "helm_plugin": "fractary-helm-cloud",
        "deployed_at": datetime.now().isoformat(),
        "deployed_by": f"faber-workflow-{session_id}",
        "work_item": work_item_url,
        "resources": deployed_resources,
        "monitoring": {
            "enabled": True,
            "helm_manager": "fractary-helm-cloud:ops-manager",
            "health_check_interval": "5m",
            "alert_channels": ["slack-ops"]
        }
    }

    # Append to central registry
    registry_path = ".fractary/registry/deployments.json"
    registry = read_json(registry_path)
    registry["deployments"].append(deployment)
    write_json(registry_path, registry)

    return deployment["id"]
```

**Step 2: FABER (Optionally) Runs Initial Health Check**

```python
# In faber-cloud/agents/infra-manager.md Release phase
if config["workflow"]["release"]["initial_health_check"]:
    # Invoke Helm for verification
    health_result = invoke_skill(
        "fractary-helm-cloud:ops-monitor",
        operation="health-check",
        environment=env,
        deployment_id=deployment_id,
        timeout="5m"
    )

    if health_result["status"] != "HEALTHY":
        if config["on_health_check_failure"] == "fail":
            raise DeploymentError(f"Health check failed: {health_result}")
        else:
            warn(f"Health check warning: {health_result}")
```

**Step 3: Helm Picks Up Deployment**

```python
# In helm-cloud/skills/ops-monitor/
def health_check_workflow():
    """Run health check for all registered deployments"""

    # Read central registry
    registry = read_json(".fractary/registry/deployments.json")

    # Filter to this domain and environment
    deployments = [
        d for d in registry["deployments"]
        if d["helm_plugin"] == "fractary-helm-cloud"
        and d["environment"] == current_env
        and d["monitoring"]["enabled"]
    ]

    # Check each deployment
    for deployment in deployments:
        for resource in deployment["resources"]:
            status = check_resource_health(resource)
            if status != "HEALTHY":
                register_issue(deployment, resource, status)
```

### Helm → FABER Feedback Protocol

**Step 1: Helm Creates Issue**

```python
# In helm-cloud/skills/ops-monitor/
def register_issue(deployment, resource, health_status):
    """Register issue in central Helm registry"""

    issue = {
        "issue_id": f"infra-{issue_counter}",
        "domain": deployment["domain"],
        "environment": deployment["environment"],
        "severity": calculate_severity(health_status),
        "status": "active",
        "detection": {
            "detected_at": datetime.now().isoformat(),
            "detected_by": "helm-cloud:ops-monitor"
        },
        "resource": resource,
        # ... rest of issue schema
    }

    # Save to central registry
    write_json(f"helm/issues/active/{issue['issue_id']}.json", issue)

    return issue["issue_id"]
```

**Step 2: Auto-Escalation or Manual Trigger**

```python
# In helm/skills/escalator/
def escalate_to_faber(issue_id):
    """Create FABER work item from Helm issue"""

    # Read issue
    issue = read_json(f"helm/issues/active/{issue_id}.json")

    # Create GitHub issue via work-manager
    work_item = invoke_primitive(
        "fractary-work:issue-creator",
        operation="create",
        title=f"[HELM-{issue_id}] {issue['issue']['title']}",
        body=format_issue_body(issue),
        labels=[
            "helm-escalation",
            issue["domain"],
            issue["severity"],
            f"env-{issue['environment']}"
        ],
        assignees=determine_assignees(issue),
        priority=map_priority(issue["severity"])
    )

    # Update issue with escalation info
    issue["escalation"] = {
        "escalated_to_faber": True,
        "escalated_at": datetime.now().isoformat(),
        "work_item_url": work_item["url"]
    }
    write_json(f"helm/issues/active/{issue_id}.json", issue)

    return work_item["url"]
```

**Step 3: FABER Frame Picks Up Work Item**

```python
# In faber/skills/frame/ (issue classifier)
def classify_issue(issue):
    """Classify issue and route to appropriate FABER domain plugin"""

    # Check for Helm escalation
    if "helm-escalation" in issue["labels"]:
        # Extract domain from labels
        domain_labels = [l for l in issue["labels"] if l in ["infrastructure", "application", "content"]]
        domain = domain_labels[0] if domain_labels else "unknown"

        # Map domain to FABER plugin
        domain_plugin_map = {
            "infrastructure": "fractary-faber-cloud",
            "application": "fractary-faber-app",
            "content": "fractary-faber-content"
        }

        faber_plugin = domain_plugin_map.get(domain)

        # Extract Helm issue ID from title
        helm_issue_id = extract_helm_issue_id(issue["title"])  # e.g., "infra-001"

        return {
            "faber_plugin": faber_plugin,
            "work_type": "fix",  # Helm escalations are fixes
            "helm_issue_id": helm_issue_id,
            "priority": issue["priority"]
        }
```

**Step 4: FABER Fixes Issue**

```python
# FABER workflow executes (Frame → Architect → Build → Evaluate → Release)
# Implementation changes deployed
```

**Step 5: Helm Verifies Fix**

```python
# In helm-cloud/skills/ops-monitor/
def verify_issue_resolved(issue_id):
    """Check if issue is still present after FABER deployment"""

    issue = read_json(f"helm/issues/active/{issue_id}.json")

    # Re-run health check
    resource = issue["resource"]
    current_status = check_resource_health(resource)

    if current_status == "HEALTHY":
        # Issue resolved!
        issue["status"] = "resolved"
        issue["resolved_at"] = datetime.now().isoformat()

        # Move to resolved
        move_file(
            f"helm/issues/active/{issue_id}.json",
            f"helm/issues/resolved/{issue_id}.json"
        )

        return True
    else:
        # Still not healthy
        return False
```

---

## Summary

### Helm Capabilities

**Central Helm (`helm/`):**
- Unified dashboard across all domains
- Cross-domain issue prioritization
- Voice interface support (future)
- FABER escalation orchestration

**Domain Helm Plugins (`helm-{domain}/`):**
- Domain-specific monitoring (CloudWatch, APM, analytics)
- Health checking and metrics collection
- Incident investigation and root cause analysis
- Automated and manual remediation
- Cost, security, compliance auditing

### Key Workflows

1. **Monitor:** Continuous health checks, metrics collection
2. **Analyze:** Root cause investigation, log analysis
3. **Alert:** Notify stakeholders via Slack, PagerDuty
4. **Remediate:** Apply immediate fixes, escalate to FABER

### Integration Points

- **FABER → Helm:** Deployment registration, initial health check
- **Helm → FABER:** Issue escalation, work item creation
- **Continuous Loop:** Monitor → Detect → Fix → Monitor

### Next Steps

1. **Implement:** Central Helm plugin (helm-director, helm-dashboard)
2. **Extract:** helm-cloud from faber-cloud (Phase 2 migration)
3. **Test:** End-to-end integration (FABER deploy → Helm monitor → Helm escalate → FABER fix)
4. **Extend:** Apply pattern to new domains (helm-app, helm-content)
5. **Enhance:** Voice interface, ML-based prioritization

---

**End of Document**

**See Also:**
- `SPEC-0008-faber-helm-architecture.md` - Overall vision and philosophy
- `SPEC-0010-faber-cloud-helm-migration.md` - Migration roadmap
- `helm-cloud-plugin-specification.md` - Detailed helm-cloud spec
