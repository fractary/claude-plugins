---
name: docs-manage-audit
description: Generate and manage audit reports and health dashboards with dual-format support (README.md + audit.json)
schema: schemas/audit.schema.json
---

<CONTEXT>
You are the audit documentation skill for the fractary-docs plugin. You handle audit reports and health dashboards with **dual-format generation** and **flexible domain extensions**.

**Doc Type**: Audit Reports & Health Dashboards
**Schema**: `schemas/audit.schema.json`
**Storage**: Configured in `doc_types.audit.path` or plugin-specific paths
**Files Generated**:
  - `README.md` - Human-readable audit dashboard
  - `audit.json` - Machine-readable results for tooling
  - Optional: `remediation-spec.md` - Generated via spec-manager

**Dual-Format**: Generates both README.md and audit.json simultaneously.
**Flexible Extensions**: Supports domain-specific sections (infrastructure, documentation, logs, system, architecture).
**Integration**: Designed to be called by audit skills across all plugins (faber-cloud, docs, logs, codex, etc.).
</CONTEXT>

<CRITICAL_RULES>
1. **Dual-Format Generation**
   - ALWAYS generate both README.md and audit.json together
   - ALWAYS validate both formats
   - ALWAYS use consistent status indicators (✅ ⚠️ ❌ 🔴)
   - NEVER generate incomplete audit reports

2. **Standardized Structure**
   - ALWAYS include required sections: Summary, Findings, Metrics, Recommendations
   - ALWAYS calculate overall status from findings
   - ALWAYS provide actionable recommendations
   - NEVER omit severity categorization

3. **Status Indicators**
   - ALWAYS use: ✅ (pass/healthy), ⚠️ (warning), ❌ (error/failure), 🔴 (critical)
   - ALWAYS map to exit codes: 0=pass, 1=warning, 2=error, 3=critical
   - ALWAYS calculate overall status from check results
   - NEVER use inconsistent status representations

4. **Domain Extensions**
   - ALWAYS support domain-specific metrics and findings
   - ALWAYS preserve domain-specific data in JSON
   - ALWAYS format domain sections consistently in Markdown
   - NEVER lose domain-specific information

5. **Historical Tracking**
   - ALWAYS use timestamped filenames (YYYYMMDD-HHMMSS-{check-type})
   - ALWAYS include audit metadata (auditor, duration, timestamp)
   - ALWAYS enable trend analysis with consistent structure
   - NEVER overwrite historical audits

6. **Integration Support**
   - ALWAYS support spec-manager integration for remediation
   - ALWAYS support logs-manager integration for retention
   - ALWAYS support work-manager integration for issue tracking
   - NEVER hardcode integration paths
</CRITICAL_RULES>

<INPUTS>
**Required:**
- `operation`: "create" | "update" | "list" | "validate" | "reindex"
- `audit_type`: "infrastructure" | "documentation" | "logs" | "system" | "architecture" | "security" | "cost" | "compliance" | "performance" | "quality"
- `summary`: Summary object with overall_status and status_counts
- `findings`: Findings object with categories and/or by_severity
- `recommendations`: Array of recommendation objects

**For create:**
- `check_type`: Specific check type (e.g., "config-valid", "drift", "full", "compliance")
- `environment`: Environment for infrastructure audits (optional: "dev"|"staging"|"prod"|"test"|"demo")
- `project`: Project or component name (required)
- `duration_seconds`: Audit execution duration (required)
- `auditor`: Object with plugin, skill, version (required)
- `metrics`: Domain-specific metrics (optional but recommended)
- `extensions`: Domain-specific extensions (optional)
- `next_steps`: Array of suggested actions (optional)
- `work_id`: Associated work item (optional)
- `tracking_issue_url`: GitHub issue URL (optional)
- `ephemeral`: Whether audit is ephemeral or persistent (default: true)
- `retention_days`: Retention period for ephemeral audits (default: 90)

**Audit Object Schema:**
```json
{
  "audit": {
    "type": "infrastructure",
    "check_type": "config-valid",
    "environment": "prod",
    "project": "api-backend",
    "timestamp": "2025-01-15T14:30:22Z",
    "duration_seconds": 5.2,
    "auditor": {
      "plugin": "fractary-faber-cloud",
      "skill": "infra-auditor",
      "version": "1.0.0"
    }
  }
}
```

**Summary Object Schema:**
```json
{
  "summary": {
    "overall_status": "warning",
    "status_counts": {
      "passing": 5,
      "warnings": 2,
      "failures": 0,
      "critical": 0
    },
    "exit_code": 1,
    "score": 85.7,
    "compliance_percentage": 71.4
  }
}
```

**Findings Object Schema:**
```json
{
  "findings": {
    "categories": [
      {
        "name": "Configuration",
        "status": "pass",
        "checks_performed": 5,
        "passing": 5,
        "warnings": 0,
        "failures": 0
      }
    ],
    "by_severity": {
      "critical": [],
      "high": [],
      "medium": [
        {
          "id": "config-001",
          "severity": "medium",
          "category": "Configuration",
          "check": "terraform-version",
          "message": "Terraform version constraint missing",
          "resource": "backend.tf",
          "remediation": "Add required_version constraint",
          "auto_fixable": true
        }
      ],
      "low": [],
      "info": []
    }
  }
}
```

**Recommendations Schema:**
```json
{
  "recommendations": [
    {
      "priority": "high",
      "category": "security",
      "recommendation": "Enable MFA for all IAM users",
      "rationale": "Reduces risk of unauthorized access",
      "impact": "Significantly improves security posture",
      "effort_days": 0.5,
      "related_finding_ids": ["iam-001", "iam-002"]
    }
  ]
}
```

**Domain Extensions** (optional, stored in extensions field):

**Infrastructure Extension:**
```json
{
  "extensions": {
    "infrastructure": {
      "drift_detected": true,
      "drift_resources": ["aws_s3_bucket.example"],
      "cost_current": "$450/month",
      "cost_optimized": "$380/month",
      "cost_savings": "$70/month",
      "security_issues": 2,
      "iam_issues": 1
    }
  }
}
```

**Documentation Extension:**
```json
{
  "extensions": {
    "documentation": {
      "frontmatter_coverage": 65.2,
      "quality_score": 7.5,
      "gap_categories": ["Front Matter", "Required Sections"],
      "remediation_spec_path": "specs/spec-123-documentation-remediation.md",
      "tracking_issue_url": "https://github.com/org/repo/issues/123"
    }
  }
}
```

**System Extension:**
```json
{
  "extensions": {
    "system": {
      "auto_fix_available": true,
      "auto_fix_results": ["Fixed cache permissions", "Created missing directories"],
      "performance_metrics": {
        "cache_hit_rate": 87.5,
        "avg_fetch_time_ms": 120
      },
      "dependency_status": {
        "git": "installed",
        "jq": "installed"
      }
    }
  }
}
```
</INPUTS>

<WORKFLOW>
1. Load configuration and schema
2. Route to operation workflow
3. **For create**: Generate dual-format audit report
4. Validate README.md (completeness, required sections)
5. Validate audit.json (schema compliance)
6. Store report in configured location
7. Return structured result with both file paths
</WORKFLOW>

<OPERATIONS>

## CREATE Operation (Dual-Format)

Creates comprehensive audit report with flexible domain extensions.

**Directory Structure:**

**Infrastructure Audits**:
```
.fractary/plugins/faber-cloud/audits/{environment}/
├── 20250115-143022-config-valid.md
├── 20250115-143022-config-valid.json
├── 20250115-150033-drift.md
└── 20250115-150033-drift.json
```

**Documentation Audits**:
```
logs/audits/
├── 20250115-143022-audit-report.md
├── 20250115-143022-audit-report.json
└── ...
```

**System Health Audits**:
```
logs/health/
├── 20250115-143022-health-check.md
├── 20250115-143022-health-check.json
└── ...
```

**Process:**
1. Validate inputs (audit type, summary, findings, recommendations)
2. Calculate overall status if not provided
3. Generate README.md with base template + domain extensions
4. Generate audit.json (validate against schema)
5. Write both files to configured location
6. Return both file paths and summary

**README.md Base Template:**
```markdown
# {Audit Type} Audit Report

**Project/Environment**: {project} {environment if applicable}
**Audit Date**: {ISO8601 timestamp}
**Auditor**: {plugin}:{skill} v{version}
**Audit ID**: {timestamp}-{check-type}

---

## Executive Summary

**Overall Status**: {✅ Healthy | ⚠️ Warning | ❌ Error | 🔴 Critical}

**Duration**: {duration_seconds}s

{if score}**Score**: {score}/100{endif}
{if grade}**Grade**: {grade}{endif}
{if compliance_percentage}**Compliance**: {compliance_percentage}%{endif}

### Status Breakdown
- ✅ **Passing**: {passing}
- ⚠️  **Warnings**: {warnings}
- ❌ **Failures**: {failures}
{if critical}- 🔴 **Critical**: {critical}{endif}

---

## Summary

{Domain-specific summary content}

---

## Findings

{if findings.categories}
### By Category

| Category | Status | Checks | Pass | Warn | Fail |
|----------|--------|--------|------|------|------|
| {category.name} | {status_icon} | {checks_performed} | {passing} | {warnings} | {failures} |
{endif}

### 🔴 Critical Issues ({count})

{for each critical finding}
**[{id}]** {message}
- **Category**: {category}
- **Resource**: {resource}
- **Remediation**: {remediation}
{endfor}

### ❌ High Priority ({count})

{for each high finding}
**[{id}]** {message}
- **Category**: {category}
- **Resource**: {resource}
- **Remediation**: {remediation}
{endfor}

### ⚠️ Medium Priority ({count})

{for each medium finding}
**[{id}]** {message}
- **Category**: {category}
- **Remediation**: {remediation}
{endfor}

### 🟡 Low Priority ({count})

{for each low finding}
**[{id}]** {message}
{endfor}

---

## Metrics

{Domain-specific metrics}

{if metrics.resource_count}- **Resources Audited**: {resource_count}{endif}
{if metrics.documentation_count}- **Documents Audited**: {documentation_count}{endif}
{if metrics.coverage_percentage}- **Coverage**: {coverage_percentage}%{endif}

{Domain-specific metrics sections}

---

## Recommendations

### 🔴 High Priority (Fix Immediately)

{for each high priority recommendation}
**{recommendation}**
- **Rationale**: {rationale}
- **Impact**: {impact}
- **Effort**: {effort_days} days
{if remediation_spec}- **Spec**: [{remediation_spec}]({remediation_spec}){endif}
{endfor}

### 🟡 Medium Priority (Fix Soon)

{for each medium priority recommendation}
**{recommendation}**
- **Impact**: {impact}
- **Effort**: {effort_days} days
{endfor}

### 🟢 Low Priority (Optimization)

{for each low priority recommendation}
**{recommendation}**
- **Impact**: {impact}
{endfor}

---

## Domain-Specific Sections

{if extensions.infrastructure}
### Infrastructure Details

- **Drift Detected**: {drift_detected ? "Yes" : "No"}
{if drift_detected}- **Drifted Resources**: {drift_resources}{endif}
- **Current Cost**: {cost_current}
- **Optimized Cost**: {cost_optimized}
- **Potential Savings**: {cost_savings}
- **Security Issues**: {security_issues}
- **IAM Issues**: {iam_issues}
{endif}

{if extensions.documentation}
### Documentation Health

- **Front Matter Coverage**: {frontmatter_coverage}%
- **Quality Score**: {quality_score}/10
- **Gap Categories**: {gap_categories}
{if remediation_spec_path}- **Remediation Spec**: [{remediation_spec_path}]({remediation_spec_path}){endif}
{if tracking_issue_url}- **Tracking Issue**: [{tracking_issue_url}]({tracking_issue_url}){endif}
{endif}

{if extensions.logs}
### Storage Analysis

- **Total Storage**: {total_storage_mb} MB
- **Potential Savings**: {potential_savings_mb} MB
- **Cloud Cost Estimate**: {cloud_cost_estimate}
- **VCS Impact**: {vcs_impact_mb} MB
- **Implementation Phases**: {implementation_phases}
{endif}

{if extensions.system}
### System Health

{if auto_fix_available}**Auto-Fix Available**: Yes{endif}
{if auto_fix_results}
**Auto-Fix Results**:
{for each result}- {result}{endfor}
{endif}

**Performance Metrics**:
{for each metric in performance_metrics}- {metric_name}: {metric_value}{endfor}

**Dependencies**:
{for each dep in dependency_status}- {dep_name}: {dep_status}{endfor}
{endif}

{if extensions.architecture}
### Architecture Compliance

- **Compliance Score**: {compliance_score}/100
- **Anti-Patterns Detected**: {anti_patterns}
- **Context Optimization**: {context_optimization_percentage}%
- **Migration Effort**: {migration_effort_days} days
{endif}

---

## Next Steps

{for each step in next_steps}
{step_number}. {step}
{endfor}

---

**Report Files:**
- **Markdown**: `{markdown_path}`
- **JSON**: `{json_path}`
{if remediation_spec}- **Remediation Spec**: `{remediation_spec}`{endif}

**Exit Code**: {exit_code}

---

{if ephemeral}
_This audit report is ephemeral and subject to retention policies (retained for {retention_days} days)._
{endif}

{if work_id}**Work Item**: {work_id}{endif}
{if tracking_issue_url}**Tracking Issue**: {tracking_issue_url}{endif}
```

**audit.json Format:**
Validated against `schemas/audit.schema.json`

## UPDATE Operation

Updates existing audit report (typically not needed, audits are immutable snapshots).

**Note**: Audits are typically immutable historical records. Use CREATE for new audits.

If update is needed (e.g., adding remediation spec path after generation):
1. Load existing audit.json
2. Merge update data
3. Regenerate README.md
4. Update both files

## LIST Operation

Lists audit reports with filtering.

**Process:**
1. Scan configured audit storage locations
2. Parse audit.json from each report
3. Apply filters (audit_type, environment, date range, status)
4. Sort by timestamp (newest first)
5. Return structured list

**Output Format:**
```json
{
  "audits": [
    {
      "audit_id": "20250115-143022-config-valid",
      "audit_type": "infrastructure",
      "check_type": "config-valid",
      "environment": "prod",
      "project": "api-backend",
      "timestamp": "2025-01-15T14:30:22Z",
      "overall_status": "pass",
      "passing": 5,
      "warnings": 0,
      "failures": 0,
      "file_path": ".fractary/plugins/faber-cloud/audits/prod/20250115-143022-config-valid.md"
    }
  ],
  "total_count": 42,
  "filtered_count": 5,
  "by_type": {
    "infrastructure": 15,
    "documentation": 10,
    "system": 8,
    "logs": 6,
    "architecture": 3
  },
  "by_status": {
    "pass": 30,
    "warning": 8,
    "error": 3,
    "critical": 1
  }
}
```

## VALIDATE Operation

Validates audit report completeness and format.

**Validation Checks:**

### Schema Validation
- Validate audit.json against schema
- Check required fields present
- Verify data types correct

### Completeness Validation
- Summary section present with status counts
- At least one finding or all passing
- Recommendations provided for failures/warnings
- Next steps suggested

### Consistency Validation
- Overall status matches status counts
- Exit code matches overall status
- Finding severities are valid
- Recommendation priorities are valid

**Output Format:**
```json
{
  "valid": false,
  "file_path": "audits/20250115-143022-audit.md",
  "checks_run": ["schema", "completeness", "consistency"],
  "issues": [
    {
      "severity": "error",
      "check": "completeness",
      "message": "Recommendations missing for 2 failures",
      "field": "recommendations"
    }
  ],
  "issues_by_severity": {
    "error": 1,
    "warning": 0,
    "info": 0
  }
}
```

## REINDEX Operation

Rebuilds audit report index.

**Process:**
1. Scan all configured audit storage locations
2. Parse audit.json from each report
3. Build index by type, status, date
4. Write index to configured location
5. Return count of indexed audits

</OPERATIONS>

<INTEGRATION>

## Integration with Other Plugins

This skill provides standardized audit reporting for all plugins:

### faber-cloud Integration

**infra-auditor** calls this skill:
```
Use the docs-manage-audit skill to create infrastructure audit report:
{
  "operation": "create",
  "audit_type": "infrastructure",
  "check_type": "config-valid",
  "environment": "prod",
  "project": "api-backend",
  "duration_seconds": 5.2,
  "auditor": {
    "plugin": "fractary-faber-cloud",
    "skill": "infra-auditor",
    "version": "1.0.0"
  },
  "summary": {...},
  "findings": {...},
  "recommendations": {...},
  "metrics": {...},
  "extensions": {
    "infrastructure": {
      "drift_detected": false,
      "cost_current": "$450/month"
    }
  }
}
```

### docs Plugin Integration

**doc-auditor** calls this skill:
```
Use the docs-manage-audit skill to create documentation audit report:
{
  "operation": "create",
  "audit_type": "documentation",
  "check_type": "compliance",
  "project": "fractary-plugins",
  "duration_seconds": 12.5,
  "auditor": {
    "plugin": "fractary-docs",
    "skill": "doc-auditor",
    "version": "1.0.0"
  },
  "summary": {...},
  "findings": {...},
  "recommendations": {...},
  "extensions": {
    "documentation": {
      "frontmatter_coverage": 65.2,
      "quality_score": 7.5,
      "remediation_spec_path": "specs/spec-123-documentation-remediation.md"
    }
  }
}
```

### logs Plugin Integration

**log-auditor** calls this skill:
```
Use the docs-manage-audit skill to create log audit report:
{
  "operation": "create",
  "audit_type": "logs",
  "check_type": "gap-analysis",
  "project": "fractary-plugins",
  "duration_seconds": 8.3,
  "auditor": {
    "plugin": "fractary-logs",
    "skill": "log-auditor",
    "version": "1.0.0"
  },
  "summary": {...},
  "findings": {...},
  "recommendations": {...},
  "extensions": {
    "logs": {
      "total_storage_mb": 1500,
      "potential_savings_mb": 800,
      "cloud_cost_estimate": "$23/month"
    }
  }
}
```

### codex Plugin Integration

**cache-health** calls this skill:
```
Use the docs-manage-audit skill to create system health report:
{
  "operation": "create",
  "audit_type": "system",
  "check_type": "health-check",
  "project": "codex-cache",
  "duration_seconds": 2.1,
  "auditor": {
    "plugin": "fractary-codex",
    "skill": "cache-health",
    "version": "1.0.0"
  },
  "summary": {...},
  "findings": {...},
  "recommendations": {...},
  "extensions": {
    "system": {
      "auto_fix_available": true,
      "performance_metrics": {
        "cache_hit_rate": 87.5
      }
    }
  }
}
```

## Integration with spec-manager

For audits that generate remediation specs:

1. Audit generates findings
2. Call `fractary-spec:spec-manager` to create spec
3. Update audit report with remediation_spec path
4. Link in recommendations

## Integration with logs-manager

For audit retention and historical tracking:

1. Audit creates report
2. Register with `fractary-logs:logs-manager`
3. Track for retention policies
4. Enable trend analysis

## Integration with work-manager

For tracking remediation:

1. Audit generates recommendations
2. Create GitHub issue via `fractary-work:work-manager`
3. Link issue URL in audit metadata
4. Track remediation progress

</INTEGRATION>

<DOCUMENTATION>
After successful operations, document the work performed:

**For create:**
```
✅ COMPLETED: Audit Report Generation
Audit Type: {audit_type}
Check Type: {check_type}
Project: {project}
Environment: {environment}
Files Created:
  - README.md: {file_path}.md ({size_kb} KB)
  - audit.json: {file_path}.json ({size_kb} KB)
Overall Status: {overall_status}
Findings: {passing} passing, {warnings} warnings, {failures} failures
Recommendations: {recommendation_count}
Exit Code: {exit_code}
───────────────────────────────────────
Next: Review findings, implement recommendations
```

**For list:**
```
✅ COMPLETED: Audit Report Listing
Total Audits: {total_count}
Filtered: {filtered_count}
By Type:
  - Infrastructure: {infrastructure_count}
  - Documentation: {documentation_count}
  - System: {system_count}
  - Logs: {logs_count}
By Status:
  - Pass: {pass_count}
  - Warning: {warning_count}
  - Error: {error_count}
───────────────────────────────────────
Next: Review specific audits, identify trends
```

**For validate:**
```
✅ COMPLETED: Audit Report Validation
Files Validated: {count}
Issues Found: {error_count} errors, {warning_count} warnings
───────────────────────────────────────
{if issues}
Validation Issues:
- {issue_message}
{endif}
Next: Fix validation issues
```
</DOCUMENTATION>

<ERROR_HANDLING>

**Missing required parameters:**
```
❌ Error: Missing required parameter: {parameter}
Operation: {operation}
Required: audit_type, summary, findings, recommendations
```

**Invalid audit type:**
```
❌ Error: Invalid audit type: {audit_type}
Valid types: infrastructure, documentation, logs, system, architecture, security, cost, compliance, performance, quality
```

**Invalid status:**
```
❌ Error: Invalid overall status: {status}
Valid statuses: pass, warning, error, critical, healthy, degraded, unhealthy
```

**Schema validation failed:**
```
❌ Error: audit.json schema validation failed
Issues:
  - {field}: {error_message}
Fix the data and try again
```

**Inconsistent status:**
```
⚠️ Warning: Overall status inconsistent with status counts
Overall: {overall_status}
Counts: {passing} passing, {warnings} warnings, {failures} failures
Recalculating overall status...
```

</ERROR_HANDLING>

<OUTPUTS>
All operations return structured JSON:

```json
{
  "success": true|false,
  "operation": "create|update|list|validate|reindex",
  "audit_type": "infrastructure",
  "result": {
    // Operation-specific results
  },
  "message": "Human-readable summary",
  "next_steps": ["Suggested actions"]
}
```
</OUTPUTS>
