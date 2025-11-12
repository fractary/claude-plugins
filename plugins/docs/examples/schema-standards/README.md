# Schema Documentation Standards - Example Implementation

This directory contains a **reference implementation** showing how projects can extend the fractary-docs baseline schema standards with project-specific requirements and validation.

## What This Demonstrates

This example shows how to:

1. **Define project-specific standards** that build on baseline fractary-docs schema standards
2. **Create custom validation scripts** to enforce project-specific rules
3. **Use hooks** to integrate custom validation into the docs workflow
4. **Configure the docs plugin** to use custom standards and validation

## Files

```
examples/schema-standards/
├── README.md                        # This file
├── PROJECT-SCHEMA-STANDARDS.md      # Example project-specific standards document
├── validate-schema-docs.sh          # Example custom validation script
├── hooks/
│   ├── pre-validate.sh              # Example pre-validation hook
│   └── post-generate.sh             # Example post-generation hook
└── example-config.json              # Example plugin configuration
```

## How It Works

### 1. Baseline + Project-Specific Standards

**Baseline standards** (from fractary-docs):
- Required sections: Overview, Schema Format, Fields, Examples, Validation Rules
- Front matter schema with required fields (title, type, date)
- Standard validation rules for markdown, front matter, structure, links

**Project-specific standards** (from `PROJECT-SCHEMA-STANDARDS.md`):
- Naming conventions (PascalCase entities, camelCase/snake_case fields)
- Additional field documentation requirements (business rules, examples)
- Versioning requirements (semantic versioning, changelog, migration guide)
- Code generation section requirements
- Minimum number of examples (3+)
- Security annotations for PII fields
- Performance considerations documentation

### 2. Custom Validation Script

The `validate-schema-docs.sh` script enforces project-specific standards:

```bash
#!/usr/bin/env bash
# Validates:
# - Naming conventions (PascalCase entities, camelCase/snake_case fields)
# - Field documentation completeness
# - Semantic versioning format
# - Code generation section exists
# - Minimum 3 examples
# - Security annotations on PII fields
# - Schema format in allowed list
# - Required sections exist

./validate-schema-docs.sh docs/api/schemas/user-schema.md
```

**Output**: JSON with errors, warnings, and info issues

### 3. Hooks Integration

**Pre-validate hook** (`hooks/pre-validate.sh`):
```bash
#!/usr/bin/env bash
# Runs BEFORE standard validation
# Enforces project-specific rules before baseline validation

if [[ "$DOC_TYPE" == "schema" ]]; then
  echo "Running project-specific schema validation..."
  ./.fractary/plugins/docs/scripts/validate-schema-docs.sh "$FILE_PATH"
fi
```

**Post-generate hook** (`hooks/post-generate.sh`):
```bash
#!/usr/bin/env bash
# Runs AFTER document generation
# Can auto-generate code from schemas, update indexes, etc.

if [[ "$DOC_TYPE" == "schema" ]]; then
  echo "Auto-generating code from schema..."
  # Extract schema format and run appropriate generator
fi
```

### 4. Plugin Configuration

Configure the docs plugin in `.fractary/plugins/docs/config.json`:

```json
{
  "validation": {
    "custom_rules_script": "./.fractary/plugins/docs/scripts/validate-schema-docs.sh",
    "project_standards_doc": "./docs/standards/PROJECT-SCHEMA-STANDARDS.md"
  },
  "hooks": {
    "pre_validate": "./.fractary/plugins/docs/hooks/pre-validate.sh",
    "post_generate": "./.fractary/plugins/docs/hooks/post-generate.sh"
  }
}
```

## Setup Instructions

### Step 1: Copy Example Files

```bash
# Copy project-specific standards document
cp examples/schema-standards/PROJECT-SCHEMA-STANDARDS.md \
   docs/standards/

# Copy custom validation script
mkdir -p .fractary/plugins/docs/scripts
cp examples/schema-standards/validate-schema-docs.sh \
   .fractary/plugins/docs/scripts/
chmod +x .fractary/plugins/docs/scripts/validate-schema-docs.sh

# Copy hooks
mkdir -p .fractary/plugins/docs/hooks
cp examples/schema-standards/hooks/*.sh \
   .fractary/plugins/docs/hooks/
chmod +x .fractary/plugins/docs/hooks/*.sh
```

### Step 2: Update Plugin Configuration

Edit `.fractary/plugins/docs/config.json`:

```json
{
  "validation": {
    "custom_rules_script": "./.fractary/plugins/docs/scripts/validate-schema-docs.sh",
    "project_standards_doc": "./docs/standards/PROJECT-SCHEMA-STANDARDS.md",
    "required_sections": {
      "schema": [
        "Overview",
        "Schema Format",
        "Fields",
        "Examples",
        "Validation Rules",
        "Versioning",
        "Code Generation"
      ]
    }
  },
  "hooks": {
    "pre_validate": "./.fractary/plugins/docs/hooks/pre-validate.sh",
    "post_generate": "./.fractary/plugins/docs/hooks/post-generate.sh"
  }
}
```

### Step 3: Customize for Your Project

Edit the files to match your project's needs:

1. **Modify standards** (`docs/standards/PROJECT-SCHEMA-STANDARDS.md`):
   - Change naming conventions (e.g., snake_case vs camelCase)
   - Add/remove required sections
   - Define your schema formats
   - Set your versioning policy

2. **Modify validation script** (`.fractary/plugins/docs/scripts/validate-schema-docs.sh`):
   - Add checks for your specific requirements
   - Adjust severity levels (error vs warning)
   - Add validation for your schema format specifics

3. **Customize hooks** (`.fractary/plugins/docs/hooks/*.sh`):
   - Add code generation integration
   - Add automated testing of schemas
   - Add automatic index updates

## Usage Examples

### Generate Schema Documentation

```bash
# Generate new schema doc
/fractary-docs:generate schema "User API Schema" \
  --version "1.0.0" \
  --schema-format "json-schema" \
  --namespace "com.example.api.user"

# Post-generate hook runs automatically
# - Auto-generates code from schema
# - Updates documentation index
```

### Validate Schema Documentation

```bash
# Validate single schema doc
/fractary-docs:validate docs/api/schemas/user-schema.md

# Validation runs in this order:
# 1. Pre-validate hook (custom project-specific validation)
# 2. Standard fractary-docs validation (markdown, front matter, structure, links)
# 3. Post-validate hook (if configured)
```

### Update Schema Documentation

```bash
# Update existing schema
/fractary-docs:update docs/api/schemas/user-schema.md \
  --section "Fields" \
  --content "New field documentation..."

# Post-update hook can trigger:
# - Code regeneration
# - Version bump
# - Changelog update
```

## Extending This Example

### Add Format-Specific Validation

For JSON Schema:
```bash
# Add to validate-schema-docs.sh
if [[ "$SCHEMA_FORMAT" == "json-schema" ]]; then
  # Validate JSON Schema draft version
  DIALECT=$(extract_frontmatter "dialect")
  if [[ -z "$DIALECT" ]]; then
    add_issue "error" "json_schema" "JSON Schema requires dialect field"
  fi

  # Validate actual schema definitions are valid JSON Schema
  # Extract JSON blocks and validate with ajv or similar
fi
```

For OpenAPI:
```bash
# Add to validate-schema-docs.sh
if [[ "$SCHEMA_FORMAT" == "openapi" ]]; then
  # Check OpenAPI version documented
  # Validate schema components section exists
  # Check for required OpenAPI-specific fields
fi
```

### Add Code Generation

```bash
# Add to post-generate.sh
if [[ "$SCHEMA_FORMAT" == "json-schema" ]]; then
  # Generate TypeScript types
  npx quicktype "$FILE_PATH" -o "src/types/$(basename "$FILE_PATH" .md).ts"

  # Generate Python models
  datamodel-codegen --input "$FILE_PATH" --output "src/models/$(basename "$FILE_PATH" .md).py"

  # Generate Go structs
  # ... etc
fi
```

### Add Schema Testing

```bash
# Add to post-validate.sh
if [[ "$DOC_TYPE" == "schema" ]]; then
  # Run schema tests
  # - Generate test data from examples
  # - Validate examples against schema
  # - Run round-trip tests
fi
```

## Common Patterns

### Pattern 1: Multi-Format Schema Support

Support multiple schema formats in same project:

```bash
# In validation script
case "$SCHEMA_FORMAT" in
  json-schema)
    validate_json_schema
    ;;
  openapi)
    validate_openapi
    ;;
  graphql)
    validate_graphql
    ;;
  database)
    validate_database_schema
    ;;
esac
```

### Pattern 2: Automated Code Generation

Generate code automatically when schema changes:

```bash
# In post-generate.sh
if [[ "$DOC_TYPE" == "schema" ]]; then
  CHANGED=$(git diff --name-only HEAD | grep "$FILE_PATH" || true)

  if [[ -n "$CHANGED" ]]; then
    echo "Schema changed, regenerating code..."
    ./scripts/generate-code-from-schemas.sh
    git add generated/
  fi
fi
```

### Pattern 3: Schema Versioning

Automatically bump version and update changelog:

```bash
# In pre-update.sh
if [[ "$DOC_TYPE" == "schema" ]]; then
  CURRENT_VERSION=$(extract_frontmatter "version")

  # Determine if breaking change
  if is_breaking_change; then
    NEW_VERSION=$(bump_major "$CURRENT_VERSION")
    echo "Breaking change detected, bumping to $NEW_VERSION"

    # Update changelog
    add_to_changelog "$NEW_VERSION" "Breaking changes"
  fi
fi
```

## Best Practices

### 1. Start Simple

Begin with minimal project-specific requirements and add complexity as needed:

```markdown
# Initial PROJECT-SCHEMA-STANDARDS.md
1. Naming conventions (your style)
2. Required sections (baseline + 1-2 more)
3. Versioning (semantic versioning)
```

### 2. Document Everything

Every project-specific requirement should include:
- **Why**: Reason for the requirement
- **How**: How to implement it
- **Examples**: Good and bad examples
- **Validation**: How it's enforced

### 3. Validate Incrementally

Build up validation checks gradually:

```bash
# Phase 1: Check naming conventions
# Phase 2: Add field completeness checks
# Phase 3: Add version format checks
# Phase 4: Add security checks
# Phase 5: Add performance checks
```

### 4. Use Info/Warning Before Error

Start with `info` or `warning` severity, promote to `error` once team is compliant:

```bash
# Week 1-2: info (educate)
add_issue "info" "naming" "Consider using PascalCase for entities"

# Week 3-4: warning (encourage)
add_issue "warning" "naming" "Entities should use PascalCase"

# Week 5+: error (enforce)
add_issue "error" "naming" "Entities must use PascalCase"
```

### 5. Provide Escape Hatches

Allow exceptions when justified:

```markdown
## Standards Exceptions

Projects can document exceptions with:
- Reason (business/technical justification)
- Approval (who approved, when)
- Scope (which schemas, which fields)
```

## Support

For questions about this example:
- Review baseline standards in `plugins/docs/skills/doc-validator/docs/validation-rules.md`
- Review front matter schema in `plugins/docs/skills/doc-generator/docs/frontmatter-schema.md`
- Consult the fractary-docs plugin README

## License

This example is provided as reference implementation for the fractary-docs plugin.
