# Schema Documentation Guide

This guide covers everything you need to know about documenting data schemas, APIs, and data dictionaries using the fractary-docs plugin.

## Table of Contents

- [Overview](#overview)
- [When to Use Schema Documentation](#when-to-use-schema-documentation)
- [Supported Schema Formats](#supported-schema-formats)
- [Baseline Standards](#baseline-standards)
- [Generating Schema Documentation](#generating-schema-documentation)
- [Schema Template Structure](#schema-template-structure)
- [Front Matter Fields](#front-matter-fields)
- [Required Sections](#required-sections)
- [Validation Rules](#validation-rules)
- [Customization & Extension](#customization--extension)
- [Best Practices](#best-practices)
- [Examples](#examples)
- [Integration Patterns](#integration-patterns)

## Overview

Schema documentation provides a human-readable specification for data structures, APIs, databases, and message formats. The fractary-docs plugin supports schema documentation with:

- **Multiple formats**: JSON Schema, OpenAPI, GraphQL, Database, Event schemas, and more
- **Baseline standards**: Required sections, validation rules, front matter schema
- **Project customization**: Extend with custom validation, naming conventions, code generation
- **Codex integration**: Automatic knowledge management and cross-referencing
- **Validation**: Completeness checks, format validation, custom project rules

## When to Use Schema Documentation

Use schema documentation for:

### Data APIs
- REST API request/response schemas
- GraphQL type definitions
- gRPC Protocol Buffer definitions
- SOAP/XML schemas

### Data Storage
- Database table schemas (SQL DDL)
- NoSQL collection schemas (MongoDB, DynamoDB)
- Document structures
- Data warehouse schemas

### Data Exchange
- Event/message schemas (Kafka, RabbitMQ, SQS)
- Import/export file formats (CSV, JSON, XML)
- Integration payload formats
- Webhook schemas

### Data Contracts
- Microservice interface contracts
- Domain model definitions
- Data product schemas
- External system integration contracts

## Supported Schema Formats

The fractary-docs plugin supports multiple schema formats via the `schema_format` front matter field:

| Format | Description | Specification |
|--------|-------------|---------------|
| **json-schema** | JSON Schema specification | JSON Schema Draft 2020-12, Draft 7, etc. |
| **openapi** | OpenAPI/Swagger schemas | OpenAPI 3.x, Swagger 2.0 |
| **graphql** | GraphQL type definitions | GraphQL Specification |
| **avro** | Apache Avro schemas | Avro 1.x |
| **protobuf** | Protocol Buffers | proto2, proto3 |
| **database** | Database schemas (SQL DDL) | PostgreSQL, MySQL, etc. |
| **event** | Event/message schemas | Kafka, RabbitMQ, CloudEvents |
| **custom** | Project-specific formats | Any custom format |

## Baseline Standards

All schema documentation must meet these baseline requirements:

### Required Sections

1. **Overview**: Purpose, scope, and context
2. **Schema Format**: Format type and specification version
3. **Fields**: Complete field definitions with types and constraints
4. **Examples**: Valid usage examples
5. **Validation Rules**: Data validation requirements

### Front Matter Fields

**Required**:
- `title`: Schema name
- `type`: "schema"
- `date`: Creation date (YYYY-MM-DD)

**Recommended**:
- `version`: Schema version (semantic versioning)
- `schema_format`: Format type (json-schema, openapi, etc.)
- `namespace`: Schema namespace/package
- `status`: Lifecycle status (draft, review, approved, deprecated)
- `author`: Author/team
- `tags`: Categorization tags
- `related`: Links to related documentation

**Optional**:
- `dialect`: Format specification version/dialect
- `entities`: List of primary entities defined

### Validation

Baseline validation checks:
- Required sections present
- Front matter completeness
- Markdown quality (via markdownlint)
- Link integrity (internal and optional external)

## Generating Schema Documentation

### Basic Generation

```bash
# Minimal schema documentation
/fractary-docs:generate schema "User API Schema"

# With version and format
/fractary-docs:generate schema "User API Schema" \
  --version "1.0.0" \
  --schema-format "json-schema"

# Full specification
/fractary-docs:generate schema "Product Catalog Schema" \
  --version "2.1.0" \
  --schema-format "database" \
  --namespace "ecommerce.catalog" \
  --status "approved"
```

### Output Location

By default, schema documentation is generated in:
- **Path**: `docs/api/schemas/`
- **Filename**: Derived from title (e.g., "User API Schema" → `user-api-schema.md`)

Configure in `.fractary/plugins/docs/config.json`:

```json
{
  "output_paths": {
    "schemas": "docs/schemas"
  }
}
```

## Schema Template Structure

The schema template (`schema.md.template`) provides comprehensive structure:

```markdown
# Schema: {{title}}

**Version**: {{version}}
**Format**: {{schema_format}}
**Namespace**: {{namespace}}

## Overview
[Purpose and scope]

## Schema Format
[Format specification details]

## Data Model
[Overall data model description]

## Entities
[Entity definitions]

## Fields
[Detailed field specifications]

## Relationships
[Entity relationships]

## Validation Rules
[Business and technical validation]

## Constraints
[Schema-level constraints]

## Indexes
[Database indexes for performance]

## Examples
[Usage examples: minimal, complete, invalid]

## Compatibility
[Version compatibility information]

## Migration Guide
[How to migrate between versions]

## Versioning
[Version history and changelog]

## Code Generation
[How to generate code from this schema]

## Governance
[Approval and change management]
```

## Front Matter Fields

### Schema-Specific Fields

#### version (string)

**Description**: Schema version using semantic versioning

**Format**: `MAJOR.MINOR.PATCH`

**Examples**:
- `"1.0.0"` - Initial release
- `"2.1.3"` - MAJOR.MINOR.PATCH

**Versioning Rules**:
- **MAJOR**: Breaking changes (removed fields, changed types, new required fields)
- **MINOR**: New optional fields, new enum values
- **PATCH**: Documentation updates, constraint clarifications

#### schema_format (string)

**Description**: Schema format specification type

**Valid Values**: `json-schema`, `openapi`, `graphql`, `avro`, `protobuf`, `database`, `event`, `custom`

**Example**: `"json-schema"`

#### namespace (string)

**Description**: Schema namespace, package, or module path

**Format**: Depends on schema format
- JSON Schema: URI or reverse domain (e.g., `"com.example.api.user"`)
- GraphQL: Module name (e.g., `"@example/api-schema"`)
- Database: Schema name (e.g., `"public"`, `"ecommerce"`)
- Proto: Package (e.g., `"example.api.v1"`)

**Example**: `"com.example.api.user"`

#### dialect (string)

**Description**: Format specification version or dialect

**Examples**:
- JSON Schema: `"https://json-schema.org/draft/2020-12/schema"`
- OpenAPI: `"3.1.0"`
- GraphQL: `"June 2018"`
- Proto: `"proto3"`

#### entities (array of strings)

**Description**: List of primary entities/models defined in this schema

**Format**: Array of entity names

**Example**: `["User", "Profile", "Preferences"]`

**Use**: Enables quick discovery of what data structures are documented

### Complete Front Matter Example

```yaml
---
title: "User Service API Schema"
type: schema
status: approved
version: "2.1.0"
schema_format: "json-schema"
namespace: "com.example.api.user"
dialect: "https://json-schema.org/draft/2020-12/schema"
date: "2025-01-15"
updated: "2025-01-20"
author: "API Team"
entities: ["User", "Profile", "Preferences", "Session"]
tags: [api, schema, user, json-schema, v2, authentication]
related:
  - "/docs/api/user-api-spec.md"
  - "/docs/architecture/designs/user-service.md"
  - "/docs/architecture/adrs/ADR-012-user-schema-v2.md"
codex_sync: true
generated: true
---
```

## Required Sections

### Overview

**Purpose**: High-level description of the schema

**Should Include**:
- What data this schema describes
- Why this schema exists (use case)
- Scope (what's included, what's not)
- Relationship to other schemas

**Example**:
```markdown
## Overview

This schema defines the data structure for user profiles in the Example API v2. It includes user identity, profile information, preferences, and session management.

### Purpose

Provide a consistent data contract for user-related operations across all microservices in the Example platform.

### Scope

**Includes**:
- Core user identity (email, username, ID)
- Profile metadata (name, avatar, bio)
- User preferences and settings
- Session tracking

**Excludes**:
- Authentication credentials (see Auth Service Schema)
- Payment information (see Billing Service Schema)
- User activity logs (see Analytics Schema)
```

### Schema Format

**Purpose**: Specify the schema format and version

**Should Include**:
- Format type (JSON Schema, OpenAPI, etc.)
- Specification version/dialect
- Format-specific details
- Why this format was chosen

**Example**:
```markdown
## Schema Format

**Type**: JSON Schema
**Specification**: [JSON Schema Draft 2020-12](https://json-schema.org/draft/2020-12/schema)
**Dialect**: `https://json-schema.org/draft/2020-12/schema`

JSON Schema was chosen for its:
- Strong validation capabilities
- Code generation support across multiple languages
- Industry-standard tooling ecosystem
- Compatibility with OpenAPI
```

### Fields

**Purpose**: Complete specification of all fields/properties

**Should Include** (for each field):
- Field name and path
- Data type and format
- Required vs optional
- Constraints (min/max, pattern, enum, etc.)
- Description (what it represents)
- Business rules
- Examples (valid values)
- Relationships (foreign keys, references)

**Example**:
```markdown
## Fields

### User.id

| Property | Value |
|----------|-------|
| **Type** | string |
| **Format** | uuid |
| **Required** | Yes |
| **Pattern** | `^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$` |

Unique identifier for the user, assigned at creation time. Uses UUIDv4 format for global uniqueness across distributed systems.

**Examples**:
- `550e8400-e29b-41d4-a716-446655440000`
- `7c9e6679-7425-40de-944b-e07fc1f90ae7`

**Business Rules**:
- Immutable after creation
- Used as primary key in database
- Referenced by other services via foreign key

---

### User.email

| Property | Value |
|----------|-------|
| **Type** | string |
| **Format** | email |
| **Required** | Yes |
| **Max Length** | 255 |
| **Pattern** | RFC 5322 compliant |

User's email address, used for login and communication.

**Examples**:
- `user@example.com`
- `john.doe+test@company.co.uk`

**Constraints**:
- Must be unique across all users
- Must be verified before activation
- Case-insensitive for uniqueness check

**Business Rules**:
- Cannot be changed more than once per 30 days
- Changing email requires re-verification
- Previous emails are retained for audit trail
```

### Examples

**Purpose**: Demonstrate valid and invalid usage

**Should Include**:
- Minimal valid example (required fields only)
- Complete example (all fields populated)
- Invalid examples with explanations
- Edge cases

**Example**:
```markdown
## Examples

### Minimal Valid User

Minimum required fields for a valid user:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "username": "johndoe",
  "created_at": "2025-01-15T10:30:00Z"
}
```

### Complete User Example

All fields populated:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "username": "johndoe",
  "profile": {
    "full_name": "John Doe",
    "avatar_url": "https://cdn.example.com/avatars/johndoe.jpg",
    "bio": "Software engineer and open source contributor",
    "location": "San Francisco, CA"
  },
  "preferences": {
    "theme": "dark",
    "language": "en-US",
    "notifications_enabled": true
  },
  "created_at": "2025-01-15T10:30:00Z",
  "updated_at": "2025-01-20T14:22:10Z",
  "email_verified": true,
  "is_active": true
}
```

### Invalid Examples

**Missing Required Field**:
```json
{
  "email": "user@example.com"
}
```
**Error**: Missing required field: `id`, `username`, `created_at`

**Invalid Email Format**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "not-an-email",
  "username": "johndoe"
}
```
**Error**: Field `email` must be valid email format (RFC 5322)

**Username Too Short**:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "email": "user@example.com",
  "username": "ab"
}
```
**Error**: Field `username` must be at least 3 characters (got: 2)
```

### Validation Rules

**Purpose**: Document all validation requirements

**Should Include**:
- Technical validation (type, format, range)
- Business validation (business rules)
- Cross-field validation (dependencies)
- Error messages for each rule
- Examples of valid and invalid data

**Example**:
```markdown
## Validation Rules

### Technical Validation

#### Email Format Validation

**Rule**: Email must match RFC 5322 format

**Error Message**: "Invalid email format. Expected: user@example.com"

**Valid**:
- `user@example.com`
- `john.doe+tag@company.co.uk`

**Invalid**:
- `not-an-email`
- `@example.com`
- `user@`

#### UUID Format Validation

**Rule**: ID must be valid UUIDv4

**Error Message**: "Invalid UUID format. Expected: 8-4-4-4-12 hexadecimal format"

**Valid**: `550e8400-e29b-41d4-a716-446655440000`
**Invalid**: `123-456-789`

### Business Validation

#### Unique Email Constraint

**Rule**: Email must be unique across all users (case-insensitive)

**Error Message**: "Email already registered. Please use a different email or login."

**Severity**: Error

#### Username Availability

**Rule**: Username must be unique and not in reserved list

**Reserved Usernames**: `admin`, `root`, `system`, `support`, `api`

**Error Message**: "Username unavailable. Please choose a different username."

### Cross-Field Validation

#### Email Verification Required for Activation

**Rule**: `email_verified` must be `true` if `is_active` is `true`

**Error Message**: "Cannot activate user without verified email. Please verify email first."

**Valid**:
- `email_verified: true, is_active: true`
- `email_verified: false, is_active: false`

**Invalid**:
- `email_verified: false, is_active: true`
```

## Validation Rules

Baseline validation checks all schema documentation for:

### Completeness
- All required sections present
- All required front matter fields populated
- Each field has type, description, and examples
- Validation rules documented

### Format Consistency
- Schema format matches declared format
- Examples conform to schema rules
- Field types are valid for schema format

### Quality
- Markdown syntax correct (markdownlint)
- Links valid (internal references)
- No broken cross-references

## Customization & Extension

The fractary-docs plugin is designed for extensibility. Projects can extend baseline standards with custom requirements.

### Extension Points

1. **Custom validation scripts** (`validation.custom_rules_script`)
2. **Project standards document** (`validation.project_standards_doc`)
3. **Additional required sections** (`validation.required_sections.schema`)
4. **Hooks** (pre_validate, post_generate, post_update)

### Example: Project-Specific Requirements

See `examples/schema-standards/` for a complete reference implementation including:

**Custom Standards** (`PROJECT-SCHEMA-STANDARDS.md`):
- Naming conventions (PascalCase entities, camelCase fields)
- Additional field requirements (business rules, PII annotations)
- Versioning requirements (semantic versioning, migration guides)
- Code generation requirements
- Security annotations for sensitive fields

**Custom Validation** (`validate-schema-docs.sh`):
- Enforce naming conventions
- Check field completeness
- Validate version format
- Verify code generation section
- Count minimum examples (3+)
- Detect PII fields and check for security annotations

**Hooks**:
- `pre-validate.sh`: Run custom validation before baseline checks
- `post-generate.sh`: Auto-generate code from schemas, update indexes

### Configuration for Customization

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
        "Code Generation",
        "Security"
      ]
    }
  },
  "hooks": {
    "pre_validate": "./.fractary/plugins/docs/hooks/pre-validate.sh",
    "post_generate": "./.fractary/plugins/docs/hooks/post-generate.sh"
  }
}
```

## Best Practices

### 1. Use Semantic Versioning

Version schemas using MAJOR.MINOR.PATCH:
- **MAJOR**: Breaking changes (removed fields, type changes, new required fields)
- **MINOR**: Backward-compatible additions (new optional fields)
- **PATCH**: Documentation clarifications, no schema changes

### 2. Document All Fields Completely

Every field should have:
- Type and format
- Required/optional status
- All constraints
- Clear description
- At least one example
- Business rules (if any)

### 3. Provide Multiple Examples

Include at least:
- Minimal valid example (required fields only)
- Complete example (all fields)
- Invalid example with error explanation

### 4. Link to Related Documentation

Use `related` front matter field to link:
- API specifications that use this schema
- Design documents explaining the data model
- ADRs documenting schema decisions
- Migration guides for version changes

### 5. Version Control Everything

Commit schema documentation to version control:
- Track schema evolution over time
- Review schema changes in pull requests
- Maintain history of breaking changes

### 6. Automate Code Generation

Use post-generate hooks to auto-generate code:
- Type definitions (TypeScript, Go, Java)
- Validators (JSON Schema validators)
- Documentation (Swagger UI, Redoc)
- Tests (schema validation tests)

### 7. Document Security Considerations

Annotate fields containing sensitive data:
- PII (personally identifiable information)
- Encryption requirements
- Access control rules
- Retention policies

### 8. Keep Examples Synchronized

Ensure examples stay valid:
- Validate examples against schema in CI/CD
- Update examples when schema changes
- Test examples in automated tests

## Examples

### JSON Schema Example

See complete example in `examples/schemas/json-schema-example.md`

Key characteristics:
- Uses JSON Schema Draft 2020-12
- Documents all properties with `$ref` references
- Includes `additionalProperties: false` for strictness
- Provides JSON examples validated against schema

### OpenAPI Schema Example

See complete example in `examples/schemas/openapi-schema-example.md`

Key characteristics:
- Uses OpenAPI 3.1 components/schemas
- Documents request and response schemas
- Includes discriminator for polymorphism
- Links to API spec using these schemas

### Database Schema Example

See complete example in `examples/schemas/database-schema-example.md`

Key characteristics:
- Documents table DDL (CREATE TABLE statements)
- Specifies indexes and constraints
- Shows relationships with foreign keys
- Includes migration scripts

### GraphQL Schema Example

See complete example in `examples/schemas/graphql-schema-example.md`

Key characteristics:
- Documents GraphQL type definitions
- Shows interfaces and unions
- Includes resolver hints
- Documents queries and mutations using these types

## Integration Patterns

### Pattern 1: Schema-First API Development

```markdown
1. Define schema in schema documentation
2. Generate code from schema (post-generate hook)
3. Implement API using generated types
4. Generate API spec from implementation
5. Link schema → API spec in related docs
```

### Pattern 2: Database Schema Evolution

```markdown
1. Document new schema version
2. Generate migration SQL (post-generate hook)
3. Review migration in PR
4. Apply migration to staging
5. Validate with schema validator
6. Deploy to production
7. Update documentation with migration notes
```

### Pattern 3: Event Schema Registry

```markdown
1. Document event schemas in docs/events/schemas/
2. Post-generate hook publishes to schema registry
3. Producers validate events against registry
4. Consumers generate types from registry
5. Schema evolution tracked in documentation
```

### Pattern 4: Multi-Language Code Generation

```markdown
Post-generate hook generates code for all languages:
- TypeScript: quicktype
- Python: datamodel-codegen
- Go: go-jsonschema
- Java: jsonschema2pojo

All generated code committed to repo for review.
```

## Troubleshooting

### Validation Fails: "Missing required section"

**Problem**: Schema documentation missing required section

**Solution**: Add the missing section. Check `validation.required_sections.schema` in config to see all required sections.

### Custom Validation Script Not Running

**Problem**: Project-specific validation not executing

**Solution**:
1. Check script path in config: `validation.custom_rules_script`
2. Verify script has execute permissions: `chmod +x script.sh`
3. Check script returns valid JSON
4. Review script exit codes (0 = success, 1 = error)

### Examples Don't Match Schema

**Problem**: Examples fail validation against schema

**Solution**:
1. Add schema validation to post-generate hook
2. Use schema validation tools (ajv for JSON Schema, etc.)
3. Keep examples simple and focused
4. Test examples in automated tests

## References

- [Front Matter Schema](../skills/doc-generator/docs/frontmatter-schema.md)
- [Validation Rules](../skills/doc-validator/docs/validation-rules.md)
- [Template Guide](../skills/doc-generator/docs/template-guide.md)
- [Example Implementation](../examples/schema-standards/)

## Support

For questions about schema documentation:
- Review baseline validation rules in `validation-rules.md`
- Review schema template in `templates/schema.md.template`
- Review example implementation in `examples/schema-standards/`
- Consult project-specific standards document (if configured)
