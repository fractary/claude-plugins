# Project-Specific Schema Documentation Standards

This is an example of project-specific schema documentation standards that extend the baseline fractary-docs schema standards.

## Purpose

This document defines **additional** schema documentation requirements beyond the baseline fractary-docs standards for this project. All schema documentation must meet both:

1. **Baseline standards** (from fractary-docs plugin)
2. **Project-specific standards** (this document)

## Additional Requirements

### 1. Naming Conventions

All schema entities and fields must follow these naming conventions:

**Entities**:
- Use `PascalCase` for entity names
- Singular form (e.g., `User`, not `Users`)
- Maximum 50 characters
- No abbreviations unless industry-standard (e.g., `HTTP`, `API`)

**Fields**:
- Use `camelCase` for JSON schemas
- Use `snake_case` for database schemas
- Boolean fields must start with `is_`, `has_`, or `can_`
- Date fields must end with `_at` or `_date`
- Foreign keys must end with `_id`

### 2. Field Documentation

Every field must include:

1. **Type**: Data type with format specification
2. **Description**: Clear explanation (minimum 10 characters)
3. **Constraints**: All applicable constraints (required, min/max, pattern, etc.)
4. **Example**: At least one valid example value
5. **Business rules**: Any business logic that applies

**Additional for required fields**:
- Explain WHY the field is required
- Document default behavior if not provided (for optional fields)

**Additional for enum fields**:
- Document all allowed values
- Explain when to use each value
- Note any deprecated values

### 3. Validation Rules

Schema documentation must include:

1. **Technical validation**: Type, format, range constraints
2. **Business validation**: Business rule enforcement
3. **Cross-field validation**: Dependencies between fields
4. **Error messages**: Specific error messages for each validation rule
5. **Examples**: Both valid and invalid examples for each rule

### 4. Versioning Requirements

All schemas must include:

1. **Semantic versioning**: MAJOR.MINOR.PATCH
2. **Changelog**: Documented changes between versions
3. **Breaking changes**: Clearly marked and explained
4. **Migration guide**: For breaking changes (MAJOR version bumps)
5. **Deprecation notices**: Minimum 2 versions before removal
6. **Backward compatibility**: Strategy for handling old versions

**Version bump rules**:
- **MAJOR**: Breaking changes (removed fields, changed types, new required fields)
- **MINOR**: New optional fields, new enum values
- **PATCH**: Documentation updates, constraint clarifications

### 5. Code Generation

Schema documentation must include code generation details:

1. **Supported languages**: List of languages with generators
2. **Generator commands**: Exact commands to generate code
3. **Output paths**: Where generated code is placed
4. **Validation**: How to validate generated code matches schema

### 6. Examples

Schemas must include:

1. **Minimal valid example**: Smallest valid instance
2. **Complete example**: All fields populated
3. **Invalid examples**: Common mistakes with error explanations
4. **Edge cases**: Boundary conditions

Minimum: 3 examples (minimal, complete, invalid)

### 7. Security Annotations

Fields containing sensitive data must be annotated:

1. **PII fields**: Marked with `pii: true`
2. **Encrypted fields**: Encryption method documented
3. **Masked fields**: Masking rules documented
4. **Access control**: Who can read/write the field

### 8. Performance Considerations

Schemas must document:

1. **Indexed fields**: Fields with database indexes
2. **Query patterns**: Common query patterns for optimization
3. **Size limits**: Maximum sizes for collections/arrays
4. **Caching**: Fields used in cache keys

## Validation Script

This project uses a custom validation script to enforce these standards:

```bash
./.fractary/plugins/docs/scripts/validate-schema-docs.sh <schema-doc.md>
```

The script checks:
- Naming convention compliance
- Field documentation completeness
- Version format and changelog presence
- Code generation section exists
- Required number of examples
- Security annotations on PII fields

## Configuration

Enable custom validation in `.fractary/plugins/docs/config.json`:

```json
{
  "validation": {
    "custom_rules_script": "./.fractary/plugins/docs/scripts/validate-schema-docs.sh",
    "project_standards_doc": "./docs/standards/PROJECT-SCHEMA-STANDARDS.md"
  }
}
```

## Hooks

This project uses validation hooks:

**Pre-validate hook** (`.fractary/plugins/docs/hooks/pre-validate.sh`):
```bash
#!/usr/bin/env bash
# Run custom schema validation before standard validation
if [[ "$DOC_TYPE" == "schema" ]]; then
  ./.fractary/plugins/docs/scripts/validate-schema-docs.sh "$FILE_PATH"
fi
```

**Post-generate hook** (`.fractary/plugins/docs/hooks/post-generate.sh`):
```bash
#!/usr/bin/env bash
# Auto-generate code from schema after generating schema docs
if [[ "$DOC_TYPE" == "schema" ]]; then
  echo "Generating code from schema..."
  # Extract schema format and run appropriate generator
  FORMAT=$(grep "^schema_format:" "$FILE_PATH" | cut -d' ' -f2)
  if [[ "$FORMAT" == "json-schema" ]]; then
    # Run JSON Schema code generator
    echo "Running JSON Schema code generator..."
  fi
fi
```

## Reference Schema Example

See `/docs/api/schemas/user-schema.md` for a complete example meeting all requirements.

## Review Checklist

Before approving schema documentation, verify:

- [ ] Naming conventions followed (PascalCase entities, camelCase/snake_case fields)
- [ ] All fields have complete documentation (type, description, constraints, example, business rules)
- [ ] Validation rules include technical + business rules with error messages
- [ ] Semantic versioning with changelog and migration guide
- [ ] Code generation section complete with all supported languages
- [ ] Minimum 3 examples (minimal, complete, invalid)
- [ ] PII fields annotated with security details
- [ ] Performance considerations documented
- [ ] Custom validation script passes
- [ ] Front matter includes all required schema-specific fields

## Exceptions

Projects may request exceptions to these standards via:

1. Document exception in ADR
2. Add exception annotation to schema documentation
3. Update validation script to allow specific exceptions

Example exception annotation:
```markdown
## Standards Exceptions

**Exception**: Field naming uses PascalCase instead of camelCase
**Reason**: Legacy API compatibility (ADR-042)
**Approved by**: Architecture team
**Date**: 2025-01-15
```

## Questions

For questions about these standards, contact the API team or consult ADR-XXX.
