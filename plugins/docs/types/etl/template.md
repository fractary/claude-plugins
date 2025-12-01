---
title: "{{etl_name}}"
fractary_doc_type: etl
etl_type: {{etl_type}}
status: {{status}}
version: {{version}}
{{#loader_version}}
loader_version: {{loader_version}}
{{/loader_version}}
{{#environment}}
environment: {{environment}}
{{/environment}}
created: {{created}}
updated: {{updated}}
author: {{author}}
tags: {{#tags}}{{.}}, {{/tags}}
codex_sync: true
generated: true
---

# {{etl_name}} ETL Documentation

**Version**: {{version}}
{{#loader_version}}
**Loader Version**: {{loader_version}}
{{/loader_version}}
**ETL Type**: {{etl_type}}
{{#environment}}
**Environment**: {{environment}}
{{/environment}}
**Last Updated**: {{updated}}

---

## Overview

{{description}}

{{#platform_config}}
## Platform Configuration

- **Platform**: {{platform_type}}
{{#runtime_version}}
- **Runtime Version**: {{runtime_version}}
{{/runtime_version}}
{{#workers}}
- **Workers**: {{worker_count}} x {{worker_type}}
{{/workers}}
{{#memory_gb}}
- **Memory**: {{memory_gb}}GB
{{/memory_gb}}
{{#timeout_minutes}}
- **Timeout**: {{timeout_minutes}} minutes
{{/timeout_minutes}}
{{#custom_config}}
- **Custom Configuration**:
{{#custom_config}}
  - `{{key}}`: {{value}}
{{/custom_config}}
{{/custom_config}}
{{/platform_config}}

## Pipeline Definition

### Source

{{#pipeline_definition.source}}
{{#organization}}
**Origin**:
- **Organization**: {{organization}}
{{#origin_url}}
- **URL**: {{origin_url}}
{{/origin_url}}
{{#update_frequency}}
- **Update Frequency**: {{update_frequency}}
{{/update_frequency}}

**Local/Cached Path**:
{{/organization}}
- **Type**: {{type}}
- **Location**: `{{location}}`
{{#format}}
- **Format**: {{format}}
{{/format}}
{{#version}}
- **Version**: {{version}}
{{/version}}
{{#schema_reference}}
- **Dataset**: [{{schema_reference}}]({{schema_link}})
{{/schema_reference}}
{{/pipeline_definition.source}}

### Transformations

{{#transformation_pattern}}
**Pattern**: {{pattern_name}} - {{pattern_description}}

{{/transformation_pattern}}
{{#pipeline_definition.transformations}}
{{step}}. **{{operation}}** - {{description}}
{{#logic}}
   ```{{#language}}{{language}}{{/language}}{{^language}}sql{{/language}}
   {{logic}}
   ```
{{/logic}}
{{#pattern_details}}
   - **Approach**: {{approach}}
   - **Key Functions**: {{functions}}
{{/pattern_details}}

{{/pipeline_definition.transformations}}

### Destination

{{#pipeline_definition.destination}}
- **Type**: {{type}}
{{#output_path}}
- **Final Output Path**: `{{output_path}}`
{{/output_path}}
{{^output_path}}
- **Location**: `{{location}}`
{{/output_path}}
{{#format}}
- **Format**: {{format}}
{{/format}}
- **Write Mode**: {{write_mode}}
{{#partitioning_scheme}}
- **Partitioning**: {{partitioning_scheme}}
{{/partitioning_scheme}}
{{#compression}}
- **Compression**: {{compression}}
{{/compression}}
{{#schema_reference}}
- **Dataset**: [{{schema_reference}}]({{schema_link}})
{{/schema_reference}}
{{/pipeline_definition.destination}}

{{#enrichment}}
## Data Enrichment

{{#lookup_tables}}
### Lookup Tables
{{#lookup_tables}}
- **{{name}}**: {{description}}
  - Source: {{source}}
{{#join_key}}
  - Join Key: {{join_key}}
{{/join_key}}
{{/lookup_tables}}

{{/lookup_tables}}
{{#label_mappings}}
### Label Mappings
{{#label_mappings}}
- **{{field}}**: {{mapping_count}} codes → labels
  - Source: {{source_file}}
{{#pattern}}
  - Pattern: {{pattern}}
{{/pattern}}
{{#example}}
  - Example: {{example}}
{{/example}}
{{/label_mappings}}

{{/label_mappings}}
{{#derived_fields}}
### Derived Fields
{{#derived_fields}}
- **{{field}}**: {{derivation_logic}}
{{/derived_fields}}
{{/derived_fields}}
{{/enrichment}}

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
- **{{check_name}}**: {{threshold}}{{#check_type}} ({{check_type}}){{/check_type}}
{{/quality_checks}}
{{/data_quality}}

## Error Handling

{{#error_handling}}
{{#retry_policy}}
- **Max Retries**: {{max_retries}}
- **Backoff Strategy**: {{backoff}}
{{/retry_policy}}
{{#alerts}}
- **Alerts**: {{#channels}}{{.}}{{^last}}, {{/last}}{{/channels}}
{{/alerts}}
{{#failure_procedures}}
- **Failure Procedure**: {{failure_procedures}}
{{/failure_procedures}}
{{/error_handling}}

## Performance & SLAs

{{#performance}}
- **Avg Runtime**: {{avg_runtime}}
- **Data Volume**: {{data_volume_per_run}}
{{#resource_requirements}}
- **Resources**: {{workers}} workers, {{memory_gb}}GB memory
{{/resource_requirements}}
{{#sla}}
- **SLA**: Max {{max_duration}}, Availability {{availability_target}}
{{/sla}}
{{/performance}}

{{#deployment}}
## Deployment

### Infrastructure
- **Tool**: {{infrastructure_tool}}
{{#config_location}}
- **Configuration**: `{{config_location}}`
{{/config_location}}

{{#steps}}
### Deployment Procedure
{{#steps}}
{{step}}. {{description}}
{{#command}}
   ```bash
   {{command}}
   ```
{{/command}}
{{/steps}}
{{/steps}}

{{#rollback_procedure}}
### Rollback Procedure
{{rollback_procedure}}
{{/rollback_procedure}}

{{#local_development}}
### Local Development
{{#setup_steps}}
**Setup**:
{{#setup_steps}}
- {{.}}
{{/setup_steps}}
{{/setup_steps}}
{{#run_command}}
**Run**: `{{run_command}}`
{{/run_command}}
{{#test_command}}
**Test**: `{{test_command}}`
{{/test_command}}
{{/local_development}}
{{/deployment}}

## Monitoring

{{#monitoring}}
### Metrics
{{#metrics}}
- {{.}}
{{/metrics}}

{{#dashboards}}
### Dashboards
{{#dashboards}}
- {{.}}
{{/dashboards}}
{{/dashboards}}

{{#logs}}
### Logs
- **Location**: `{{log_group}}`
{{#retention_days}}
- **Retention**: {{retention_days}} days
{{/retention_days}}
{{/logs}}
{{/monitoring}}

## Code References

{{#code_references}}
- **Repository**: {{repository}}
- **Main File**: `{{main_file}}`
{{#version}}
- **Version**: {{version}}
{{/version}}
{{#config_files}}
- **Config Files**:
{{#config_files}}
  - `{{.}}`
{{/config_files}}
{{/config_files}}
{{/code_references}}

## Data Lineage

{{#lineage}}
### Upstream Datasets
{{#upstream_datasets}}
- {{.}}
{{/upstream_datasets}}

### Downstream Datasets
{{#downstream_datasets}}
- {{.}}
{{/downstream_datasets}}
{{#lineage_graph_url}}

[View Lineage Graph]({{lineage_graph_url}})
{{/lineage_graph_url}}
{{/lineage}}

{{#related_docs}}
## Related Documentation

{{#schema_doc_link}}
- **Schema Documentation**: [{{schema_doc_name}}]({{schema_doc_link}})
{{/schema_doc_link}}
{{#data_dict_link}}
- **Data Dictionary**: [{{data_dict_name}}]({{data_dict_link}})
{{/data_dict_link}}
{{#specs.0}}
- **Specifications**: {{#specs}}[{{name}}]({{link}}){{^last}}, {{/last}}{{/specs}}
{{/specs.0}}
{{#architecture}}
- **Architecture**: [{{arch_name}}]({{arch_link}})
{{/architecture}}
{{/related_docs}}

---

*Generated with fractary-docs plugin*
*ETL specification: [etl.json](./etl.json)*
