---
title: "Infrastructure: {{resource_name}}"
fractary_doc_type: infrastructure
environment: {{environment}}
status: {{status}}
version: {{version}}
created: {{created}}
updated: {{updated}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# Infrastructure: {{resource_name}}

**Environment**: {{environment}}
**Version**: {{version}}
**Status**: {{status}}
**Last Updated**: {{updated}}

## Overview

{{description}}

## Architecture Decisions

{{#architecture_decisions}}
### {{title}}
**Decision**: {{decision}}
**Rationale**: {{rationale}}

{{#alternatives_considered}}
**Alternatives Considered**:
{{#alternatives_considered}}
- {{.}}
{{/alternatives_considered}}
{{/alternatives_considered}}

{{#consequences}}
**Consequences**:
{{#consequences}}
- {{type}} {{description}}
{{/consequences}}
{{/consequences}}

{{/architecture_decisions}}

## Resource Inventory

| Resource Type | Name | ARN | Console Link |
|--------------|------|-----|--------------|
{{#resource_inventory}}
| {{type}} | {{name}} | `{{arn}}` | [View]({{console_url}}) |
{{/resource_inventory}}

### Dependencies

```mermaid
graph LR
{{#dependencies}}
  {{from}} --> {{to}}
{{/dependencies}}
```

### Outputs

{{#outputs}}
- **{{name}}**: `{{value}}`
{{/outputs}}

## Operational Procedures

{{#operational_procedures}}
### {{title}}

**Severity**: {{severity}}
**Estimated Time**: {{estimated_time}}
**Downtime**: {{estimated_downtime}}

{{#prerequisites}}
**Prerequisites**:
{{#prerequisites}}
- {{.}}
{{/prerequisites}}
{{/prerequisites}}

**Steps**:
{{#steps}}
{{step}}. {{action}}
   ```bash
   {{command}}
   ```
   Expected: {{expected_result}}

{{/steps}}

{{#rollback}}
**Rollback**:
{{#rollback}}
- {{.}}
{{/rollback}}
{{/rollback}}

{{#validation}}
**Validation**:
{{#validation}}
- {{.}}
{{/validation}}
{{/validation}}

{{/operational_procedures}}

## Monitoring & Alerting

### Key Metrics

| Metric | Description | Warning | Critical |
|--------|-------------|---------|----------|
{{#monitoring.key_metrics}}
| {{name}} | {{description}} | {{threshold.warning}} | {{threshold.critical}} |
{{/monitoring.key_metrics}}

### Alarms

{{#monitoring.alarms}}
- **{{name}}**: {{metric}} > {{threshold}}
{{/monitoring.alarms}}

### Dashboards

{{#monitoring.dashboards}}
- [{{name}}]({{url}})
{{/monitoring.dashboards}}

### Logs

{{#monitoring.logs}}
**CloudWatch Log Groups**:
{{#log_groups}}
- `{{.}}`
{{/log_groups}}

**Retention**: {{retention_days}} days
{{/monitoring.logs}}

## Troubleshooting

{{#troubleshooting}}
### {{symptom}}

**Diagnosis**: {{diagnosis}}

**Solution**: {{solution}}

**Prevention**: {{prevention}}

{{/troubleshooting}}

## Disaster Recovery

**Recovery Time Objective (RTO)**: {{disaster_recovery.rto}}
**Recovery Point Objective (RPO)**: {{disaster_recovery.rpo}}

{{#disaster_recovery.backup_strategy}}
### Backup Strategy

- **Frequency**: {{frequency}}
- **Retention**: {{retention}}
- **Location**: `{{location}}`
{{/disaster_recovery.backup_strategy}}

{{#disaster_recovery.recovery_procedures}}
### Recovery Procedures

{{#disaster_recovery.recovery_procedures}}
- {{.}}
{{/disaster_recovery.recovery_procedures}}
{{/disaster_recovery.recovery_procedures}}

## Cost Optimization

**Monthly Estimate**: {{cost_optimization.monthly_estimate}}

{{#cost_optimization.breakdown}}
**Breakdown**:
{{#cost_optimization.breakdown}}
- {{resource}}: {{cost}}
{{/cost_optimization.breakdown}}
{{/cost_optimization.breakdown}}

{{#cost_optimization.optimization_opportunities}}
**Optimization Opportunities**:
{{#cost_optimization.optimization_opportunities}}
- {{.}}
{{/cost_optimization.optimization_opportunities}}
{{/cost_optimization.optimization_opportunities}}

## Contacts

{{#contacts}}
- **On-Call**: {{on_call}}
- **Team**: {{team}}
- **Escalation**: {{escalation}}
{{/contacts}}

## References

{{#references}}
- [{{title}}]({{url}}) - {{type}}
{{/references}}

---

*Generated with fractary-docs plugin*
*Infrastructure specification: [infrastructure.json](./infrastructure.json)*
