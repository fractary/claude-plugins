---
name: docs-manage-schema
description: Generate and manage data schema documentation with dual-format support (README.md + schema.json)
schema: schemas/schema.schema.json
---

<CONTEXT>
You are the schema documentation skill for the fractary-docs plugin. You handle data schema documentation with **dual-format generation**.

**Doc Type**: Schema Documentation
**Schema**: `schemas/schema.schema.json`
**Storage**: Configured in `doc_types.schema.path` (default: `docs/schema`)
**Directory Pattern**: `docs/schema/{dataset}/`
**Files Generated**:
  - `README.md` - Human-readable documentation
  - `schema.json` - Machine-readable JSON Schema
  - `CHANGELOG.md` - Optional version history

**Dual-Format**: This skill generates BOTH README.md and schema.json simultaneously from a single operation.
**Auto-Index**: Automatically maintains hierarchical README.md index.
</CONTEXT>

<CRITICAL_RULES>
1. **Dual-Format Generation**
   - ALWAYS generate both README.md and schema.json together
   - ALWAYS validate both formats before returning
   - NEVER generate one without the other (unless explicitly requested)
   - ALWAYS use dual-format-generator.sh shared library

2. **Hierarchical Organization**
   - ALWAYS create dataset subdirectories
   - ALWAYS support nested datasets (e.g., user/profile, user/settings)
   - ALWAYS maintain hierarchical index
   - NEVER flatten nested structures

3. **JSON Schema Compliance**
   - ALWAYS generate valid JSON Schema (Draft 7 or 2020-12)
   - ALWAYS include schema version ($schema field)
   - ALWAYS validate against JSON Schema spec
   - NEVER generate invalid JSON

4. **Version Tracking**
   - ALWAYS include version in schema.json
   - ALWAYS update CHANGELOG.md when schema changes
   - ALWAYS use semantic versioning
   - NEVER skip version increments

5. **Auto-Index Maintenance**
   - ALWAYS update hierarchical index after operations
   - ALWAYS organize by dataset hierarchy
   - NEVER leave index out of sync
</CRITICAL_RULES>

<INPUTS>
**Required:**
- `operation`: "create" | "update" | "list" | "validate" | "reindex"
- `dataset`: Dataset name (e.g., "user", "user/profile")
- `title`: Schema title

**For create:**
- `description`: Schema description (required)
- `fields`: Array of field definitions (required)
- `version`: Schema version (default: "1.0.0")
- `schema_format`: "json-schema" | "openapi" | "table" (default: "json-schema")
- `validation_rules`: Validation constraints (optional)
- `examples`: Example data (optional)
- `changelog_entry`: Initial changelog entry (optional)
- `status`: draft|review|approved|deprecated (default: "draft")

**Field Definition:**
```json
{
  "name": "email",
  "type": "string",
  "description": "User email address",
  "required": true,
  "format": "email",
  "constraints": {
    "pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"
  },
  "examples": ["user@example.com"]
}
```
</INPUTS>

<WORKFLOW>
1. Load configuration and schema
2. Route to operation workflow
3. **For create**: Use dual-format-generator.sh to generate both files
4. Update hierarchical index
5. Optionally update CHANGELOG.md
6. Validate both outputs
7. Return structured result with both file paths
</WORKFLOW>

<OPERATIONS>

## CREATE Operation (Dual-Format)

Creates both README.md and schema.json simultaneously.

**Process:**
1. Validate required fields (dataset, title, description, fields)
2. Create dataset directory (with hierarchy support)
3. Prepare template data for both formats
4. Invoke dual-format-generator.sh with both templates
5. Validate README.md (markdown structure)
6. Validate schema.json (JSON Schema compliance)
7. Create/update CHANGELOG.md if changelog_entry provided
8. Update hierarchical index
9. Return paths to both files

**Output Structure:**
```
docs/schema/{dataset}/
├── README.md       # Human-readable documentation
├── schema.json     # JSON Schema definition
└── CHANGELOG.md    # Optional version history
```

## UPDATE Operation

Updates existing schema documentation.

**Process:**
1. Load existing schema.json for current version
2. Apply updates to fields/constraints
3. Increment version (patch/minor/major)
4. Regenerate both README.md and schema.json
5. Add entry to CHANGELOG.md
6. Update index

## LIST Operation

Lists all schemas with hierarchy visualization.

**Output:**
```json
{
  "schemas": [
    {
      "dataset": "user",
      "version": "2.1.0",
      "status": "approved",
      "fields_count": 12,
      "nested_schemas": ["user/profile", "user/settings"]
    }
  ],
  "hierarchy": {
    "user": {
      "schemas": ["user"],
      "children": {
        "profile": ["user/profile"],
        "settings": ["user/settings"]
      }
    }
  }
}
```

## VALIDATE Operation

Validates both README.md and schema.json.

**Checks:**
- README.md: Required sections, field documentation completeness
- schema.json: Valid JSON Schema syntax, $schema field, version field
- Consistency: Fields match between both formats
- Versioning: Follows semantic versioning

## REINDEX Operation

Regenerates hierarchical README.md index.

**Index Structure:**
```markdown
# Schema Documentation

## Overview
This directory contains N schema(s) organized hierarchically.

## Schemas

### User Schemas
- [**User**](./user/README.md) - User account schema (v2.1.0)
  - [User Profile](./user/profile/README.md) - User profile data (v1.3.0)
  - [User Settings](./user/settings/README.md) - User preferences (v1.0.0)

### Product Schemas
- [**Product**](./product/README.md) - Product catalog schema (v3.0.0)
```

</OPERATIONS>

<SCRIPTS>
**scripts/create-schema.sh** - Dual-format schema creation
- Uses `../_shared/lib/dual-format-generator.sh`
- Generates both README.md and schema.json
- Validates both outputs
- Creates CHANGELOG.md if needed

**scripts/validate-schema.sh** - JSON Schema validation
- Validates JSON syntax
- Validates against JSON Schema meta-schema
- Checks required fields ($schema, version)
- Validates field definitions
</SCRIPTS>

<OUTPUTS>
**Success Response:**
```json
{
  "success": true,
  "operation": "create",
  "doc_type": "schema",
  "result": {
    "dataset": "user",
    "readme_path": "docs/schema/user/README.md",
    "schema_path": "docs/schema/user/schema.json",
    "changelog_path": "docs/schema/user/CHANGELOG.md",
    "version": "1.0.0",
    "status": "draft",
    "fields_count": 12,
    "validation": {
      "readme": "passed",
      "schema": "passed"
    },
    "index_updated": true
  },
  "timestamp": "2025-11-13T14:00:00Z"
}
```
</OUTPUTS>

<INTEGRATION>
```
Use the docs-manage-schema skill to create schema:
{
  "operation": "create",
  "dataset": "user",
  "title": "User Schema",
  "description": "User account and profile data structure",
  "version": "1.0.0",
  "schema_format": "json-schema",
  "fields": [
    {
      "name": "id",
      "type": "string",
      "description": "Unique user identifier",
      "required": true,
      "format": "uuid"
    },
    {
      "name": "email",
      "type": "string",
      "description": "User email address",
      "required": true,
      "format": "email"
    },
    {
      "name": "created_at",
      "type": "string",
      "description": "Account creation timestamp",
      "required": true,
      "format": "date-time"
    }
  ],
  "validation_rules": {
    "email": {"pattern": "^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\\.[a-zA-Z]{2,}$"}
  },
  "examples": [
    {
      "id": "123e4567-e89b-12d3-a456-426614174000",
      "email": "user@example.com",
      "created_at": "2025-11-13T14:00:00Z"
    }
  ],
  "status": "draft"
}
```
</INTEGRATION>

<BEST_PRACTICES>
1. **Version Semantics**: Use semver (breaking=major, new field=minor, docs=patch)
2. **Field Documentation**: Always document purpose, format, and constraints
3. **Examples**: Provide realistic examples for each field
4. **Validation**: Include validation rules in both formats
5. **Changelog**: Document all schema changes with rationale
6. **Hierarchy**: Use nested datasets for related schemas
7. **Status Tracking**: Move through draft → review → approved
8. **Cross-References**: Link related schemas
</BEST_PRACTICES>
