# ETL Documentation Validation Rules

## Frontmatter Validation

### Required Fields
- `title` - Document title
- `fractary_doc_type` - Must be "etl"
- `status` - draft, published, deprecated
- `version` - Semver pattern

### Optional Fields
- `tags`, `author`, `created`, `updated`
- `loader_version` - ETL job code version
- `environment` - Deployment environment

## Structure Validation

### Required Sections
Based on type-specific template structure.
Must include all sections marked as required in template.

### Optional Sections
May include additional sections as needed.

## Content Validation

### General Rules
- All sections must have non-empty content
- Code blocks must have language specified
- Links must be valid (internal links resolve)
- Tables must have headers

### Type-Specific Rules
- Validate against schema.json if dual-format
- Check required fields are present and non-empty
- Verify data types match expected types
- Ensure cross-references are valid

## Schema Validation

### JSON File (if dual-format)
- Corresponding .json file must exist
- Must be valid JSON
- Must conform to types/etl/schema.json
- All required fields from schema must be present

## Quality Checks

- No broken links
- No orphaned code blocks
- Consistent formatting
- Proper markdown syntax
- Up-to-date version numbers

## Enhanced Validation Rules (v1.1)

The following validation rules were added to support general ETL jobs:

### platform_config_recommended
- **Severity**: warning
- **Message**: Platform configuration section recommended for all ETL jobs
- **Description**: All ETL documentation SHOULD include platform configuration details such as platform type, runtime version, worker configuration, memory, and timeout settings.

### source_origin_recommended
- **Severity**: warning
- **Message**: Source should include both origin (organization/URL) and cached path
- **Description**: For external data sources, documentation SHOULD include the originating organization and URL in addition to the cached/local path.

### destination_path_explicit
- **Severity**: warning
- **Message**: Destination should include explicit output path
- **Description**: Destination documentation SHOULD include an explicit final output path, not just a generic location.

### transformation_language_specified
- **Severity**: info
- **Message**: Transformation code blocks should specify language
- **Description**: When including code snippets in transformations, the programming language (sql, python, pyspark, scala, etc.) SHOULD be specified.

### enrichment_documented
- **Severity**: info
- **Message**: Data enrichment processes should be documented if applicable
- **Description**: When ETL includes data enrichment (lookup tables, label mappings, derived fields), these processes SHOULD be documented.

### related_docs_linked
- **Severity**: warning
- **Message**: Should link to schema documentation (separate audience)
- **Description**: ETL pipeline documentation serves maintainers, while schema documentation serves data consumers. These SHOULD be linked but separate.

## Severity Levels

- **error**: Validation fails, document cannot be generated
- **warning**: Validation passes with warning, should be addressed
- **info**: Informational suggestion, optional improvement
