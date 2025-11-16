---
title: "{{etl_name}}"
fractary_doc_type: etl
etl_type: {{etl_type}}
status: {{status}}
version: {{version}}
created: {{created}}
updated: {{updated}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{etl_name}} ETL Documentation

**Version**: {{version}}
**ETL Type**: {{etl_type}}
**Last Updated**: {{updated}}

---

## Overview

{{description}}

## Pipeline Definition

### Source
- **Type**: {{pipeline_definition.source.type}}
- **Location**: `{{pipeline_definition.source.location}}`
{{#pipeline_definition.source.format}}
- **Format**: {{pipeline_definition.source.format}}
{{/pipeline_definition.source.format}}
{{#pipeline_definition.source.schema_reference}}
- **Dataset**: [{{pipeline_definition.source.schema_reference}}]({{pipeline_definition.source.schema_link}})
{{/pipeline_definition.source.schema_reference}}

### Transformations

{{#pipeline_definition.transformations}}
{{step}}. **{{operation}}** - {{logic_description}}
{{#logic}}
   ```sql
   {{logic}}
   ```
{{/logic}}

{{/pipeline_definition.transformations}}

### Destination
- **Type**: {{pipeline_definition.destination.type}}
- **Location**: `{{pipeline_definition.destination.location}}`
- **Write Mode**: {{pipeline_definition.destination.write_mode}}
{{#pipeline_definition.destination.schema_reference}}
- **Dataset**: [{{pipeline_definition.destination.schema_reference}}]({{pipeline_definition.destination.schema_link}})
{{/pipeline_definition.destination.schema_reference}}

## Schedule & Dependencies

{{#schedule}}
- **Frequency**: {{frequency}}
{{#cron}}
- **Cron**: `{{cron}}`{{#timezone}} ({{timezone}}){{/timezone}}
{{/cron}}
{{#dependencies}}
- **Dependencies**:
{{#dependencies}}
  - {{.}}
{{/dependencies}}
{{/dependencies}}
{{/schedule}}

## Data Quality

{{#data_quality}}
### Validation Rules
{{#validation_rules}}
- {{rule}} (severity: {{severity}})
{{/validation_rules}}

### Quality Checks
{{#quality_checks}}
- **{{name}}**: {{threshold}}{{#unit}}{{unit}}{{/unit}}
{{/quality_checks}}
{{/data_quality}}

## Error Handling

{{#error_handling}}
{{#retry_policy}}
- **Max Retries**: {{max_retries}}
- **Backoff Strategy**: {{backoff_strategy}}
{{/retry_policy}}
{{#alerts}}
- **Alerts**: {{channels}}
{{/alerts}}
{{#failure_procedure}}
- **Failure Procedure**: {{failure_procedure}}
{{/failure_procedure}}
{{/error_handling}}

## Performance & SLAs

{{#performance}}
- **Avg Runtime**: {{avg_runtime}}
- **Data Volume**: {{data_volume_per_run}}
{{#resource_requirements}}
- **Resources**: {{workers}} workers, {{memory_gb}}GB memory
{{/resource_requirements}}
{{#sla}}
- **SLA**: {{sla}}
{{/sla}}
{{/performance}}

## Monitoring

{{#monitoring}}
### Metrics
{{#metrics}}
- {{.}}
{{/metrics}}

{{#dashboards}}
### Dashboards
{{#dashboards}}
- [{{name}}]({{url}})
{{/dashboards}}
{{/dashboards}}

{{#logs}}
### Logs
- **Location**: `{{location}}`
- **Retention**: {{retention}}
{{/logs}}
{{/monitoring}}

## Code References

{{#code_references}}
- **Repository**: {{repository}}
- **Main File**: `{{main_file}}`
{{#branch}}
- **Branch**: {{branch}}
{{/branch}}
{{/code_references}}

## Data Lineage

{{#lineage}}
### Upstream Datasets
{{#upstream_datasets}}
- [{{.}}]({{link}})
{{/upstream_datasets}}

### Downstream Datasets
{{#downstream_datasets}}
- [{{.}}]({{link}})
{{/downstream_datasets}}
{{/lineage}}

---

*Generated with fractary-docs plugin*
*ETL specification: [etl.json](./etl.json)*
