---
log_type: workflow
title: "{{title}}"
workflow_id: {{workflow_id}}
{{#work_item_id}}
work_item_id: {{work_item_id}}
{{/work_item_id}}
timestamp: {{timestamp}}
status: {{status}}
{{#phase}}
phase: {{phase}}
{{/phase}}
{{#step}}
step: {{step}}
{{/step}}
{{#workflow_type}}
workflow_type: {{workflow_type}}
{{/workflow_type}}
---

# Workflow Execution: {{title}}

**Workflow ID**: `{{workflow_id}}`
{{#work_item_id}}
**Work Item**: #{{work_item_id}}
{{/work_item_id}}
**Started**: {{timestamp}}
**Status**: {{status}}
{{#phase}}
**Current Phase**: {{phase}}
{{/phase}}
{{#step}}
**Current Step**: {{step}}
{{/step}}

---

## Execution Summary

{{#context}}
### Context
- **Project**: {{context.project}}
{{#context.repository}}
- **Repository**: {{context.repository}}
{{/context.repository}}
{{#context.branch}}
- **Branch**: {{context.branch}}
{{/context.branch}}
{{#context.commit}}
- **Commit**: `{{context.commit}}`
{{/context.commit}}
{{#context.environment}}
- **Environment**: {{context.environment}}
{{/context.environment}}
{{#context.triggered_by}}
- **Triggered By**: {{context.triggered_by}}
{{/context.triggered_by}}
{{/context}}

{{#metrics}}
### Performance Metrics
{{#metrics.total_duration_ms}}
- **Total Duration**: {{metrics.total_duration_ms}}ms
{{/metrics.total_duration_ms}}
{{#metrics.operations_count}}
- **Operations**: {{metrics.operations_count}}
{{/metrics.operations_count}}
{{#metrics.success_rate}}
- **Success Rate**: {{metrics.success_rate}}%
{{/metrics.success_rate}}
{{/metrics}}

---

{{#operations}}
## Operations Timeline

{{#operations}}
### {{timestamp}} - {{operation}}

**Phase**: {{phase}} {{#step}}→ {{step}}{{/step}}
**Target**: {{target}}
**Status**: {{status}}
{{#duration_ms}}
**Duration**: {{duration_ms}}ms
{{/duration_ms}}

{{#output}}
**Output**:
```
{{output}}
```
{{/output}}

{{/operations}}

{{/operations}}
---

{{#decisions}}
## Decisions Made

{{#decisions}}
### {{timestamp}} - {{decision}}

{{#rationale}}
**Rationale**: {{rationale}}
{{/rationale}}

{{#alternatives_considered}}
**Alternatives Considered**:
{{#alternatives_considered}}
- {{.}}
{{/alternatives_considered}}
{{/alternatives_considered}}

{{/decisions}}

{{/decisions}}
---

{{#artifacts}}
## Artifacts Created

{{#artifacts}}
- **{{type}}**: `{{path}}`
  {{#size_bytes}}- Size: {{size_bytes}} bytes{{/size_bytes}}
  {{#created_at}}- Created: {{created_at}}{{/created_at}}
  {{#checksum}}- Checksum: `{{checksum}}`{{/checksum}}
{{/artifacts}}

{{/artifacts}}
---

{{#upstream_dependencies}}
## Upstream Dependencies

{{#upstream_dependencies}}
- **{{type}}** ({{workflow_id}}): {{status}} at {{timestamp}}
{{/upstream_dependencies}}

{{/upstream_dependencies}}
{{#downstream_impacts}}
## Downstream Impacts

{{#downstream_impacts}}
### {{system}}
**Impact**: {{impact_type}}
{{#action_required}}
**Action Required**: {{action_required}}
{{/action_required}}

{{/downstream_impacts}}

{{/downstream_impacts}}
---

{{#error_summary}}
## Error Summary

{{#error_summary.total_errors}}
**Total Errors**: {{error_summary.total_errors}}
{{/error_summary.total_errors}}

{{#error_summary.error_types}}
**Error Types**:
{{#error_summary.error_types}}
- {{.}}
{{/error_summary.error_types}}
{{/error_summary.error_types}}

{{#error_summary.critical_errors}}
**Critical Errors**:
{{#error_summary.critical_errors}}
- {{.}}
{{/error_summary.critical_errors}}
{{/error_summary.critical_errors}}

{{/error_summary}}
---

{{#next_steps}}
## Next Steps

{{#next_steps}}
- {{.}}
{{/next_steps}}

{{/next_steps}}
---

**Log ID**: `{{workflow_id}}`
**Generated**: {{timestamp}}
{{#status}}
**Final Status**: {{status}}
{{/status}}
