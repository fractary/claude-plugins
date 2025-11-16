---
title: "{{audit_type}} Audit Report"
fractary_doc_type: audit
audit_type: {{audit_type}}
audit_id: {{audit_id}}
project: {{project}}
environment: {{environment}}
overall_status: {{overall_status}}
version: {{version}}
created: {{audit_date}}
updated: {{audit_date}}
author: {{auditor}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{audit_type}} Audit Report

**Project/Environment**: {{project}}{{#environment}} / {{environment}}{{/environment}}
**Audit Date**: {{audit_date}}
**Auditor**: {{auditor}}
**Audit ID**: {{audit_id}}

---

## Executive Summary

**Overall Status**: {{overall_status_icon}} {{overall_status}}

**Duration**: {{summary.duration_seconds}}s

{{#summary.score}}
**Score**: {{summary.score}}/100
{{/summary.score}}
{{#summary.grade}}
**Grade**: {{summary.grade}}
{{/summary.grade}}
{{#summary.compliance_percentage}}
**Compliance**: {{summary.compliance_percentage}}%
{{/summary.compliance_percentage}}

### Status Breakdown
- ✅ **Passing**: {{summary.passing}}
- ⚠️  **Warnings**: {{summary.warnings}}
- ❌ **Failures**: {{summary.failures}}
{{#summary.critical}}
- 🔴 **Critical**: {{summary.critical}}
{{/summary.critical}}

---

## Summary

{{summary.description}}

---

## Findings

{{#findings.categories}}
### By Category

| Category | Status | Checks | Pass | Warn | Fail |
|----------|--------|--------|------|------|------|
{{#findings.categories}}
| {{name}} | {{status_icon}} | {{checks_performed}} | {{passing}} | {{warnings}} | {{failures}} |
{{/findings.categories}}
{{/findings.categories}}

{{#findings.critical}}
### 🔴 Critical Issues ({{findings.critical.length}})

{{#findings.critical}}
**[{{id}}]** {{message}}
- **Category**: {{category}}
{{#resource}}
- **Resource**: `{{resource}}`
{{/resource}}
- **Remediation**: {{remediation}}

{{/findings.critical}}
{{/findings.critical}}

{{#findings.error}}
### ❌ High Priority ({{findings.error.length}})

{{#findings.error}}
**[{{id}}]** {{message}}
- **Category**: {{category}}
{{#resource}}
- **Resource**: `{{resource}}`
{{/resource}}
- **Remediation**: {{remediation}}

{{/findings.error}}
{{/findings.error}}

{{#findings.warning}}
### ⚠️ Medium Priority ({{findings.warning.length}})

{{#findings.warning}}
**[{{id}}]** {{message}}
- **Category**: {{category}}
- **Remediation**: {{remediation}}

{{/findings.warning}}
{{/findings.warning}}

{{#findings.info}}
### 🟡 Low Priority ({{findings.info.length}})

{{#findings.info}}
**[{{id}}]** {{message}}

{{/findings.info}}
{{/findings.info}}

---

## Metrics

{{#metrics.resource_count}}
- **Resources Audited**: {{metrics.resource_count}}
{{/metrics.resource_count}}
{{#metrics.documentation_count}}
- **Documents Audited**: {{metrics.documentation_count}}
{{/metrics.documentation_count}}
{{#metrics.coverage_percentage}}
- **Coverage**: {{metrics.coverage_percentage}}%
{{/metrics.coverage_percentage}}

{{#extensions.infrastructure}}
### Infrastructure Metrics
{{#extensions.infrastructure.drift_detected}}
- **Drift Detected**: {{extensions.infrastructure.drift_detected}}
{{#extensions.infrastructure.drift_resources}}
  - Drifted Resources: {{extensions.infrastructure.drift_resources.length}}
{{/extensions.infrastructure.drift_resources}}
{{/extensions.infrastructure.drift_detected}}
- **Current Cost**: {{extensions.infrastructure.cost_current}}
- **Optimized Cost**: {{extensions.infrastructure.cost_optimized}}
- **Potential Savings**: {{extensions.infrastructure.cost_savings}}
- **Security Issues**: {{extensions.infrastructure.security_issues}}
- **IAM Issues**: {{extensions.infrastructure.iam_issues}}
{{/extensions.infrastructure}}

{{#extensions.documentation}}
### Documentation Metrics
- **Frontmatter Coverage**: {{extensions.documentation.frontmatter_coverage}}%
- **Quality Score**: {{extensions.documentation.quality_score}}/10
{{#extensions.documentation.gap_categories}}
- **Gap Categories**: {{extensions.documentation.gap_categories.join(", ")}}
{{/extensions.documentation.gap_categories}}
{{/extensions.documentation}}

{{#extensions.system}}
### System Metrics
{{#extensions.system.performance_metrics}}
- **Cache Hit Rate**: {{extensions.system.performance_metrics.cache_hit_rate}}%
- **Avg Fetch Time**: {{extensions.system.performance_metrics.avg_fetch_time_ms}}ms
{{/extensions.system.performance_metrics}}
{{/extensions.system}}

---

## Recommendations

{{#recommendations.high}}
### 🔴 High Priority (Fix Immediately)

{{#recommendations.high}}
**{{recommendation}}**
- **Rationale**: {{rationale}}
- **Impact**: {{impact}}
- **Effort**: {{effort_days}} days
{{#related_finding_ids}}
- **Related Findings**: {{related_finding_ids.join(", ")}}
{{/related_finding_ids}}

{{/recommendations.high}}
{{/recommendations.high}}

{{#recommendations.medium}}
### ⚠️ Medium Priority (Address Soon)

{{#recommendations.medium}}
**{{recommendation}}**
- **Rationale**: {{rationale}}
- **Impact**: {{impact}}
- **Effort**: {{effort_days}} days

{{/recommendations.medium}}
{{/recommendations.medium}}

{{#recommendations.low}}
### 🟡 Low Priority (Nice to Have)

{{#recommendations.low}}
**{{recommendation}}**
- **Impact**: {{impact}}
- **Effort**: {{effort_days}} days

{{/recommendations.low}}
{{/recommendations.low}}

---

{{#extensions.documentation.remediation_spec_path}}
## Remediation Plan

A detailed remediation specification has been generated:
- **Spec**: [{{extensions.documentation.remediation_spec_path}}](../../../{{extensions.documentation.remediation_spec_path}})
{{#extensions.documentation.tracking_issue_url}}
- **Tracking Issue**: [GitHub Issue]({{extensions.documentation.tracking_issue_url}})
{{/extensions.documentation.tracking_issue_url}}
{{/extensions.documentation.remediation_spec_path}}

{{#extensions.system.auto_fix_available}}
## Auto-Fix Results

{{#extensions.system.auto_fix_results}}
{{#extensions.system.auto_fix_results}}
- {{.}}
{{/extensions.system.auto_fix_results}}
{{/extensions.system.auto_fix_results}}
{{/extensions.system.auto_fix_available}}

---

*Generated with fractary-docs plugin*
*Audit data: [audit.json](./{{audit_id}}.json)*
