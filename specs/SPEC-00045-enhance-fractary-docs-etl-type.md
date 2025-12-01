---
spec_id: SPEC-00045
title: Enhance fractary-docs `etl` Doc Type for General ETL Jobs
status: proposed
created: 2025-12-01
updated: 2025-12-01
target_project: fractary-docs (external plugin)
related_specs: [SPEC-00046]
tags: [documentation, fractary-docs, etl, enhancement]
---

# SPEC-00045: Enhance fractary-docs `etl` Doc Type for General ETL Jobs

## Executive Summary

**Goal**: Enhance the fractary-docs `etl` documentation type to support **general ETL jobs** (AWS Glue, custom scripts, standalone pipelines) in addition to the current focus on orchestration tools (Airflow, dbt, Step Functions).

**Target Project**: fractary-docs plugin (external project)

**Related**: SPEC-00046 (Corthion implementation using enhanced `etl` type)

**Impact**: Makes `etl` doc type applicable to broader range of ETL platforms and use cases

## Problem Statement

### Current State

The fractary-docs `etl` doc type (v1.0) is optimized for **orchestration workflows**:
- Airflow DAGs
- dbt models
- AWS Step Functions
- Orchestrated multi-step pipelines

**Template Focus**:
- SQL-based transformations
- Schedule and dependencies
- Workflow monitoring
- DAG/pipeline orchestration

### Gap Analysis

The current `etl` type has **9 critical gaps** for general ETL jobs:

1. **No Platform Configuration Section** - Missing dedicated section for platform-specific settings (Glue workers, runtime params, custom config)
2. **SQL-Only Transformations** - Template assumes SQL snippets, doesn't support code-based transformations (PySpark, Python, Scala)
3. **No Data Enrichment Section** - Missing documentation for lookup tables, label mappings, derived fields
4. **No Schema Documentation Links** - No reference to separate schema docs (different audience: consumers vs maintainers)
5. **Deployment Not Covered** - Infrastructure deployment procedures not well documented
6. **No Local Development** - Missing guidance on running/testing locally
7. **Source Path Incomplete** - Shows cached/local path but not origin URL and organization
8. **Destination Path Generic** - Needs explicit final output location (not just type)
9. **Version Tracking Limited** - No clear version/timestamp/environment documentation

### Use Case Example

**Corthion ETL System** (122 AWS Glue jobs):
- Platform: AWS Glue (not orchestration tool)
- Transformations: PySpark code (not SQL)
- Enrichment: Label mappings for coded fields
- Source: Government datasets (origin) cached to S3 (local)
- Destination: Specific S3 parquet paths with partitioning
- Audience: Pipeline maintainers (engineers, AI agents)

**Current `etl` template doesn't fit this use case well.**

## Proposed Solution

### Overview

Add **4 new template sections** and **enhance 3 existing sections** to make `etl` type work for general ETL jobs while maintaining backward compatibility with orchestration tools.

**Principles**:
- ✅ Backward compatible (existing orchestration tool docs still work)
- ✅ General purpose (platform-agnostic where possible)
- ✅ Extensible (easy to add platform-specific details)
- ✅ Clear audience separation (pipeline maintainers vs data consumers)

### New Template Sections

#### 1. Platform Configuration

**Location**: After "Overview" section

**Purpose**: Document platform-specific runtime configuration

**Template**:
```markdown
## Platform Configuration

{{#platform_config}}
- **Platform**: {{platform_type}}
- **Runtime Version**: {{runtime_version}}
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
- **Custom Configuration**: {{custom_config}}
{{/custom_config}}
{{/platform_config}}
```

**Example Usage**:
```markdown
## Platform Configuration

- **Platform**: AWS Glue 5.0
- **Runtime Version**: Python 3.10, Spark 3.5
- **Workers**: 2 x G.1X (4 vCPU, 16GB RAM each)
- **Timeout**: 60 minutes
- **Custom Configuration**:
  - `--enable-glue-datacatalog`: true
  - `--extra-py-files`: s3://bucket/common.zip
```

#### 2. Data Enrichment

**Location**: After "Transformations" section

**Purpose**: Document lookup tables, label mappings, and derived field logic

**Template**:
```markdown
## Data Enrichment

{{#enrichment}}
### Lookup Tables
{{#lookup_tables}}
- **{{name}}**: {{description}}
  - Source: {{source}}
  - Join Key: {{join_key}}
{{/lookup_tables}}

### Label Mappings
{{#label_mappings}}
- **{{field}}**: {{mapping_count}} codes → labels
  - Source: {{source_file}}
  - Pattern: {{pattern}}
{{/label_mappings}}

### Derived Fields
{{#derived_fields}}
- **{{field}}**: {{derivation_logic}}
{{/derived_fields}}
{{/enrichment}}
```

**Example Usage**:
```markdown
## Data Enrichment

### Label Mappings
- **control**: 3 codes → labels
  - Source: labels.json
  - Pattern: control_label
  - Example: "1" → "Public"
- **iclevel**: 4 codes → labels
  - Source: labels.json
  - Pattern: iclevel_label
  - Example: "1" → "Four or more years"

### Derived Fields
- **is_public**: Derived from control field (control == "1")
- **enrollment_category**: Categorizes by enrollment size (small/medium/large)
```

#### 3. Deployment

**Location**: Before "Monitoring" section

**Purpose**: Document infrastructure deployment procedures

**Template**:
```markdown
## Deployment

{{#deployment}}
### Infrastructure
- **Tool**: {{infrastructure_tool}}
- **Configuration**: {{config_location}}

### Deployment Procedure
{{#steps}}
{{step}}. {{description}}
{{/steps}}

### Rollback Procedure
{{rollback_procedure}}
{{/deployment}}
```

**Example Usage**:
```markdown
## Deployment

### Infrastructure
- **Tool**: Terraform
- **Configuration**: `src/datasets/ipeds/hd/terraform.tf`

### Deployment Procedure
1. Review Terraform plan: `terraform plan`
2. Apply infrastructure changes: `terraform apply`
3. Verify Glue job created: `aws glue get-job --job-name corthion-ipeds-hd-etl`
4. Test with sample data in test environment

### Rollback Procedure
Revert to previous Terraform state: `terraform apply -target=module.ipeds_hd_glue_job -auto-approve`
```

#### 4. Related Documentation

**Location**: End of document (before footer)

**Purpose**: Link to schema docs, data dictionaries, specs, architecture

**Template**:
```markdown
## Related Documentation

{{#related_docs}}
{{#schema_doc_link}}
- **Schema Documentation**: [{{schema_doc_name}}]({{schema_doc_link}})
{{/schema_doc_link}}
{{#data_dict_link}}
- **Data Dictionary**: [{{data_dict_name}}]({{data_dict_link}})
{{/data_dict_link}}
{{#specs.length}}
- **Specifications**: {{#specs}}[{{name}}]({{link}}){{^last}}, {{/last}}{{/specs}}
{{/specs.length}}
{{#architecture}}
- **Architecture**: [{{arch_name}}]({{arch_link}})
{{/architecture}}
{{/related_docs}}
```

**Example Usage**:
```markdown
## Related Documentation

- **Schema Documentation**: [IPEDS HD Schema](./SCHEMA.md)
- **Data Dictionary**: [IPEDS HD Data Dictionary](https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx)
- **Specifications**: [SPEC-00017](../../specs/SPEC-00017-dataset-management-standardization.md)
- **Architecture**: [Flat Columnar Architecture](../../docs/architecture/ADR/ADR-00001-flat-columnar-architecture.md)
```

### Enhanced Existing Sections

#### 1. Transformations Section

**Current**: SQL-only, no pattern documentation

**Enhanced**: Support code-based transformations, document patterns

**New Template**:
```markdown
### Transformations

{{#transformation_pattern}}
**Pattern**: {{pattern_name}} - {{pattern_description}}
{{/transformation_pattern}}

{{#pipeline_definition.transformations}}
{{step}}. **{{operation}}** - {{description}}
{{#logic}}
   ```{{language}}
   {{logic}}
   ```
{{/logic}}
{{#pattern_details}}
   - **Approach**: {{approach}}
   - **Key Functions**: {{functions}}
{{/pattern_details}}
{{/pipeline_definition.transformations}}
```

**Example Usage**:
```markdown
### Transformations

**Pattern**: Flat Columnar Transformation - Preserves source field names, adds label enrichment columns

1. **Read Raw Data** - Load CSV from S3 raw path
   ```python
   df = raw_manager.read_csv_from_s3(
       dataset="ipeds",
       table="hd",
       version="2024"
   )
   ```

2. **Enrich with Labels** - Add human-readable labels for coded fields
   - **Approach**: Left join label mappings to create {field}_label columns
   - **Key Functions**: `transform_to_flat_format()`, `enrich_labels()`

3. **Add Metadata** - Add dataset/version/source/timestamp fields
   - **Approach**: Add computed columns using Spark F.lit()
   - **Key Functions**: `add_metadata_fields()`
```

#### 2. Source Section

**Current**: Shows location only

**Enhanced**: Show BOTH origin (organization/URL) AND cached/local path

**New Template**:
```markdown
### Source Data

{{#pipeline_definition.source}}
**Origin**:
- **Organization**: {{organization}}
- **URL**: {{origin_url}}
- **Update Frequency**: {{update_frequency}}

**Local/Cached Path**:
- **Type**: {{type}}
- **Location**: `{{location}}`
- **Format**: {{format}}
{{#partitioning}}
- **Partitioning**: {{partitioning}}
{{/partitioning}}
{{#version}}
- **Version**: {{version}}
{{/version}}
{{/pipeline_definition.source}}
```

**Example Usage**:
```markdown
### Source Data

**Origin**:
- **Organization**: National Center for Education Statistics (NCES)
- **URL**: https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx
- **Update Frequency**: Annual (October)

**Local/Cached Path**:
- **Type**: S3
- **Location**: `s3://test.etl.corthion.ai/raw/ipeds/hd/version=2024/hd2024.csv`
- **Format**: CSV
- **Version**: 2024
```

#### 3. Destination Section

**Current**: Type and write mode only

**Enhanced**: Add explicit final output path, partitioning, compression

**New Template**:
```markdown
### Destination

{{#pipeline_definition.destination}}
- **Type**: {{type}}
- **Final Output Path**: `{{output_path}}`
- **Format**: {{format}}
- **Write Mode**: {{write_mode}}
{{#partitioning}}
- **Partitioning**: {{partitioning_scheme}}
{{/partitioning}}
{{#compression}}
- **Compression**: {{compression}}
{{/compression}}
{{/pipeline_definition.destination}}
```

**Example Usage**:
```markdown
### Destination

- **Type**: S3
- **Final Output Path**: `s3://test.etl.corthion.ai/curated/ipeds/hd/version=2024/`
- **Format**: Parquet
- **Write Mode**: Overwrite
- **Partitioning**: By version
- **Compression**: Snappy
```

### Schema Changes

Add new properties to `types/etl/schema.json`:

```json
{
  "properties": {
    "platform_config": {
      "type": "object",
      "description": "Platform-specific configuration (Glue, dbt, Airflow, etc.)",
      "properties": {
        "platform_type": {
          "type": "string",
          "description": "ETL platform (glue, dbt, airflow, custom, etc.)"
        },
        "runtime_version": {
          "type": "string",
          "description": "Runtime/engine version (e.g., 'Python 3.10, Spark 3.5')"
        },
        "workers": {
          "type": "object",
          "properties": {
            "worker_count": {"type": "integer"},
            "worker_type": {"type": "string"}
          }
        },
        "memory_gb": {
          "type": "number",
          "description": "Memory allocation in GB"
        },
        "timeout_minutes": {
          "type": "integer",
          "description": "Job timeout in minutes"
        },
        "custom_config": {
          "type": "object",
          "description": "Platform-specific configuration parameters"
        }
      }
    },
    "enrichment": {
      "type": "object",
      "description": "Data enrichment processes (lookups, labels, derived fields)",
      "properties": {
        "lookup_tables": {
          "type": "array",
          "description": "Reference data lookup tables",
          "items": {
            "type": "object",
            "properties": {
              "name": {"type": "string"},
              "description": {"type": "string"},
              "source": {"type": "string"},
              "join_key": {"type": "string"}
            }
          }
        },
        "label_mappings": {
          "type": "array",
          "description": "Code-to-label mappings for categorical fields",
          "items": {
            "type": "object",
            "properties": {
              "field": {"type": "string"},
              "mapping_count": {"type": "integer"},
              "source_file": {"type": "string"},
              "pattern": {"type": "string"}
            }
          }
        },
        "derived_fields": {
          "type": "array",
          "description": "Fields derived from source data",
          "items": {
            "type": "object",
            "properties": {
              "field": {"type": "string"},
              "derivation_logic": {"type": "string"}
            }
          }
        }
      }
    },
    "deployment": {
      "type": "object",
      "description": "Deployment procedures and infrastructure",
      "properties": {
        "infrastructure_tool": {
          "type": "string",
          "description": "Infrastructure as code tool (terraform, cloudformation, etc.)"
        },
        "config_location": {
          "type": "string",
          "description": "Path to infrastructure configuration files"
        },
        "steps": {
          "type": "array",
          "description": "Deployment steps",
          "items": {
            "type": "object",
            "properties": {
              "step": {"type": "integer"},
              "description": {"type": "string"}
            }
          }
        },
        "rollback_procedure": {
          "type": "string",
          "description": "How to rollback a failed deployment"
        }
      }
    },
    "related_docs": {
      "type": "object",
      "description": "Links to related documentation (schema, specs, architecture)",
      "properties": {
        "schema_doc_name": {"type": "string"},
        "schema_doc_link": {"type": "string"},
        "data_dict_name": {"type": "string"},
        "data_dict_link": {"type": "string"},
        "specs": {
          "type": "array",
          "items": {
            "type": "object",
            "properties": {
              "name": {"type": "string"},
              "link": {"type": "string"}
            }
          }
        },
        "architecture": {
          "type": "object",
          "properties": {
            "arch_name": {"type": "string"},
            "arch_link": {"type": "string"}
          }
        }
      }
    },
    "transformation_pattern": {
      "type": "object",
      "description": "High-level transformation pattern/approach",
      "properties": {
        "pattern_name": {"type": "string"},
        "pattern_description": {"type": "string"}
      }
    },
    "loader_version": {
      "type": "string",
      "description": "Version of the ETL loader/job itself"
    },
    "environment": {
      "type": "string",
      "description": "Deployment environment (test, prod, etc.)",
      "enum": ["test", "staging", "production", "development"]
    }
  }
}
```

**Enhanced Source Properties**:
```json
{
  "pipeline_definition": {
    "properties": {
      "source": {
        "properties": {
          "organization": {
            "type": "string",
            "description": "Organization providing the source data"
          },
          "origin_url": {
            "type": "string",
            "description": "URL where source data originates"
          },
          "update_frequency": {
            "type": "string",
            "description": "How often source data is updated"
          },
          "version": {
            "type": "string",
            "description": "Version/year of the source data (e.g., '2024', 'v1.2.0')"
          }
        }
      }
    }
  }
}
```

**Enhanced Destination Properties**:
```json
{
  "pipeline_definition": {
    "properties": {
      "destination": {
        "properties": {
          "output_path": {
            "type": "string",
            "description": "Explicit final output path/location"
          },
          "partitioning_scheme": {
            "type": "string",
            "description": "Partitioning strategy (by date, version, etc.)"
          },
          "compression": {
            "type": "string",
            "description": "Compression algorithm (snappy, gzip, etc.)"
          }
        }
      }
    }
  }
}
```

**Enhanced Transformation Properties**:
```json
{
  "pipeline_definition": {
    "properties": {
      "transformations": {
        "items": {
          "properties": {
            "language": {
              "type": "string",
              "description": "Code language (python, sql, scala, etc.)",
              "enum": ["sql", "python", "scala", "java", "r", "custom"]
            },
            "pattern_details": {
              "type": "object",
              "properties": {
                "approach": {"type": "string"},
                "functions": {"type": "string"}
              }
            }
          }
        }
      }
    }
  }
}
```

### Standards Updates

Add to `types/etl/standards.md`:

```markdown
## Platform Configuration Requirements

All ETL documentation SHOULD include platform configuration details:
- Platform type and version
- Resource allocation (workers, memory)
- Timeout settings
- Platform-specific configuration

**Note**: Required for AWS Glue, Databricks, and other configurable platforms. Optional for simple Lambda or script-based ETLs.

## Data Enrichment Documentation

When ETL includes data enrichment:
- SHOULD document all lookup tables (source, join keys)
- SHOULD document label/code mappings (field names, source files)
- SHOULD document derived field logic

## Source and Destination Paths

**Source Documentation**:
- SHOULD include origin (organization, URL) for external data sources
- MUST include cached/local path
- SHOULD include update frequency

**Destination Documentation**:
- SHOULD include explicit output path
- MUST include format and write mode
- SHOULD include partitioning and compression

## Related Documentation Links

ETL pipeline documentation serves **pipeline maintainers**.
Schema documentation serves **data consumers**.

SHOULD link to schema documentation (separate file/system) to avoid duplication.

## Version and Environment Tracking

All ETL documentation SHOULD include:
- Loader/job version (`loader_version`) - version of the ETL code/job itself
- Target environment (`environment`) - deployment environment (test, staging, production)
- Last updated timestamp (`updated`) - when documentation was last modified

**Version Semantics Clarification**:
- `version` - Document/spec version (semantic versioning for the documentation)
- `loader_version` - ETL job code version (tracks the actual deployed code version)

Both should be updated independently: `version` when the documentation changes, `loader_version` when the ETL code is redeployed.
```

### Validation Rules

Add to `types/etl/validation-rules.json`:

```json
{
  "rules": [
    {
      "name": "platform_config_required",
      "severity": "warning",
      "message": "Platform configuration section recommended for all ETL jobs"
    },
    {
      "name": "source_origin_required",
      "severity": "warning",
      "message": "Source should include both origin (organization/URL) and cached path"
    },
    {
      "name": "destination_path_explicit",
      "severity": "warning",
      "message": "Destination should include explicit output path"
    },
    {
      "name": "transformation_language_specified",
      "severity": "info",
      "message": "Transformation code blocks should specify language"
    },
    {
      "name": "enrichment_documented",
      "severity": "info",
      "message": "Data enrichment processes should be documented if applicable"
    },
    {
      "name": "related_docs_linked",
      "severity": "warning",
      "message": "Should link to schema documentation (separate audience)"
    }
  ]
}
```

## Implementation Details

### Files to Modify

**fractary-docs plugin** (`~/.claude/plugins/marketplaces/fractary/plugins/docs/`):

1. **`types/etl/template.md`**
   - Add 4 new sections (Platform Configuration, Data Enrichment, Deployment, Related Documentation)
   - Enhance 3 existing sections (Transformations, Source, Destination)
   - Add version/environment tracking to frontmatter and Overview

2. **`types/etl/schema.json`**
   - Add 4 new property groups (platform_config, enrichment, deployment, related_docs)
   - Add transformation_pattern, loader_version, environment properties
   - Enhance source properties (organization, origin_url, update_frequency)
   - Enhance destination properties (output_path, partitioning_scheme, compression)
   - Enhance transformation properties (language, pattern_details)

3. **`types/etl/standards.md`**
   - Add platform configuration requirements
   - Add data enrichment documentation standards
   - Add source/destination path requirements
   - Add related documentation linking standards
   - Add version/environment tracking requirements

4. **`types/etl/validation-rules.json`**
   - Add 6 new validation rules

### Backward Compatibility

**All changes are backward compatible**:
- New sections use `{{#section}}` conditionals (only render if data provided)
- Existing orchestration tool docs continue to work
- No breaking changes to existing schema properties
- New properties are optional

**Migration Path**:
- Existing `etl` type documentation continues to work
- New fields optional (validate with warnings, not errors)
- Gradual adoption as projects update documentation

## Testing Strategy

### Test Cases

1. **Orchestration Tool (Airflow DAG)**
   - Verify existing template still works
   - Verify new sections don't break when omitted
   - Verify backward compatibility

2. **AWS Glue Job**
   - Test all new sections with Glue-specific data
   - Verify platform configuration renders correctly
   - Verify PySpark transformations display properly

3. **Custom ETL Script**
   - Test with minimal required fields
   - Test with all optional fields
   - Verify validation rules work

4. **dbt Model**
   - Verify existing dbt docs still render
   - Test with new enrichment section
   - Verify SQL transformations work

### Validation

- All 6 validation rules trigger appropriately
- Schema validation passes for all test cases
- Template renders without errors
- Markdown output is well-formatted

## Success Metrics

- ✅ 4 new template sections added
- ✅ 3 existing sections enhanced
- ✅ 4 new property groups in schema
- ✅ Enhanced properties in source/destination/transformations
- ✅ Standards updated with new requirements
- ✅ 6 validation rules added
- ✅ 100% backward compatible
- ✅ Tested with 4 different ETL platform types

## Migration and Rollout

### Phase 1: Implementation (Week 1)
1. Update template.md with new sections
2. Update schema.json with new properties
3. Update standards.md with new requirements
4. Update validation-rules.json
5. Internal testing with sample data

### Phase 2: Testing (Week 1-2)
1. Test with existing orchestration tool docs (backward compatibility)
2. Test with AWS Glue job docs (new use case)
3. Test with custom ETL script docs
4. Test with dbt model docs
5. Fix any issues found

### Phase 3: Documentation (Week 2)
1. Update fractary-docs plugin README
2. Add migration guide for existing users
3. Add examples for each platform type
4. Update changelog

### Phase 4: Release (Week 2)
1. Version bump (v1.1.0 - minor version for new features)
2. Release notes
3. Announce to plugin users
4. Monitor feedback

## Dependencies

**None** - This is a standalone enhancement to fractary-docs plugin

**Downstream Projects**:
- Corthion (etl.corthion.ai) will use enhanced `etl` type via SPEC-00046
- Other projects using AWS Glue, custom ETL scripts will benefit

## Related Specifications

- **SPEC-00046**: Revamp `/corthion-loader-document` (uses enhanced `etl` type)

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Breaking changes to existing docs | High | 100% backward compatible design, extensive testing |
| New sections don't render properly | Medium | Conditional rendering, test with all platforms |
| Schema validation too strict | Medium | Use warnings not errors for new fields |
| Adoption slow | Low | Clear examples, migration guide |

## Appendix: Example Output

### AWS Glue Job Documentation

```markdown
---
fractary_doc_type: etl
etl_type: glue
platform: AWS Glue
version: 1.0.0
loader_version: 2024.11.0
environment: test
last_updated: 2025-12-01T10:00:00Z
---

# IPEDS HD ETL Pipeline

**Version**: 1.0.0
**Loader Version**: 2024.11.0
**Platform**: AWS Glue 5.0
**Last Updated**: 2025-12-01

## Overview

Transforms IPEDS Institutional Characteristics raw data into curated Parquet format with label enrichment and flat columnar schema.

## Platform Configuration

- **Platform**: AWS Glue 5.0
- **Runtime Version**: Python 3.10, Spark 3.5
- **Workers**: 2 x G.1X (4 vCPU, 16GB RAM each)
- **Timeout**: 60 minutes
- **Custom Configuration**:
  - `--enable-glue-datacatalog`: true
  - `--extra-py-files`: s3://bucket/common.zip

## Pipeline Definition

### Source Data

**Origin**:
- **Organization**: National Center for Education Statistics (NCES)
- **URL**: https://nces.ed.gov/ipeds/datacenter/DataFiles.aspx
- **Update Frequency**: Annual (October)

**Local/Cached Path**:
- **Type**: S3
- **Location**: `s3://test.etl.corthion.ai/raw/ipeds/hd/version=2024/hd2024.csv`
- **Format**: CSV
- **Version**: 2024

### Transformations

**Pattern**: Flat Columnar Transformation - Preserves source field names, adds label enrichment

1. **Read Raw Data** - Load CSV from S3
2. **Enrich with Labels** - Add human-readable labels for coded fields
3. **Add Metadata** - Add dataset/version/source/timestamp

### Destination

- **Type**: S3
- **Final Output Path**: `s3://test.etl.corthion.ai/curated/ipeds/hd/version=2024/`
- **Format**: Parquet
- **Write Mode**: Overwrite
- **Partitioning**: By version
- **Compression**: Snappy

## Data Enrichment

### Label Mappings
- **control**: 3 codes → labels (labels.json)
- **iclevel**: 4 codes → labels (labels.json)
- **locale**: 13 codes → labels (labels.json)

## Data Quality

### Validation Rules
- Row count between 1,000 and 10,000 (severity: error)
- Primary key uniqueness (severity: error)

## Deployment

### Infrastructure
- **Tool**: Terraform
- **Configuration**: `src/datasets/ipeds/hd/terraform.tf`

### Deployment Procedure
1. Review plan: `terraform plan`
2. Apply: `terraform apply`
3. Verify job created

## Related Documentation

- **Schema Documentation**: [IPEDS HD Schema](./SCHEMA.md)
- **Data Dictionary**: [NCES IPEDS Data Dictionary](https://nces.ed.gov/ipeds/)
- **Architecture**: [Flat Columnar Architecture](../../docs/architecture/ADR-00001.md)
```

---

**End of SPEC-00045**
