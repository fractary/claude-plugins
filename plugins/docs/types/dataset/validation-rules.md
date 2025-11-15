# Dataset Documentation Validation Rules

## Frontmatter Validation

### Required Fields
- `title` - Dataset name
- `fractary_doc_type` - Must be "dataset"
- `status` - draft, published, deprecated
- `version` - Semver

### Optional Fields
- `owner`, `tags`, `created`, `updated`

## Structure Validation

### Required Sections
- `## Overview` - Dataset description
- `## Schema` - Field definitions table
- `## Metadata` - Size, update frequency, owner
- `## Access Patterns` - How to query
- `## Data Quality` - Quality metrics

### Optional Sections
- `## Governance`
- `## Lineage`
- `## Known Issues`

## Content Validation

### Schema Section
- Must have table with columns: Field, Type, Description
- Each field must have type and description
- Required fields must be marked

### Metadata Section
- Must document data size
- Must document update frequency
- Must document owner/team

### Access Patterns Section
- Must include at least one query example
- Must document access method (SQL, API, etc.)
- Must document permissions required

### Data Quality Section
- Must include quality metrics or standards
- Should document validation rules
- Should document known quality issues

## Schema File Validation (if dual-format)

- `dataset.json` must exist
- Must be valid JSON
- Must conform to schema.json
