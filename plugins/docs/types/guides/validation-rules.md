# Guides Documentation Validation Rules

## Frontmatter Validation

### Required Fields
- `title` - Document title
- `fractary_doc_type` - Must be "guides"
- `status` - draft, published, deprecated
- `version` - Semver pattern

### Optional Fields
- `tags`, `author`, `created`, `updated`

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
- Must conform to types/guides/schema.json
- All required fields from schema must be present

## Quality Checks

- No broken links
- No orphaned code blocks
- Consistent formatting
- Proper markdown syntax
- Up-to-date version numbers
