# ETL Documentation Standards

## Required Conventions

### 1. Pipeline Definition
- ALWAYS document source, transformations, and destination
- ALWAYS include data lineage (upstream/downstream datasets)
- ALWAYS document transformation logic
- NEVER omit error handling procedures

### 2. Schedule & Dependencies
- ALWAYS document execution frequency and schedule
- ALWAYS list all job dependencies
- ALWAYS include retry and backoff strategies
- ALWAYS document SLA requirements

### 3. Data Quality
- ALWAYS include validation rules
- ALWAYS document quality checks and thresholds
- ALWAYS specify data quality metrics
- ALWAYS document how failures are handled

### 4. Monitoring
- ALWAYS document key metrics to monitor
- ALWAYS include alerting configuration
- ALWAYS provide troubleshooting guides
- ALWAYS link to dashboards and logs

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

## Deployment Documentation

SHOULD document infrastructure deployment procedures:
- Infrastructure tool (Terraform, CloudFormation, etc.)
- Configuration file locations
- Deployment steps
- Rollback procedures
- Local development instructions

## Best Practices

- Keep transformation logic versioned and documented
- Document performance characteristics and resource requirements
- Include code references to pipeline implementation
- Maintain data lineage diagrams
- Document cost implications and optimization opportunities
- Separate pipeline documentation (for maintainers) from schema documentation (for consumers)
