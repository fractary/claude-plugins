# Fractary Docs Plugin

Type-agnostic documentation system with operation-specific skills and data-driven type context.

**Version**: 2.0.0 | **Architecture**: Operation-focused with 93% less code duplication

## Overview

The `fractary-docs` plugin provides a flexible, type-agnostic documentation management system. Instead of maintaining separate skills for each document type, v2.0 uses **operation-specific skills** that load type-specific behavior from data files.

### What's New in v2.0

**Architecture Transformation**:
- ✅ **93% less code duplication** - From ~7,000 to ~2,500 lines
- ✅ **Type-agnostic operations** - Single `doc-writer` handles all types
- ✅ **Data-driven behavior** - Type context in `types/{doc_type}/` directories
- ✅ **Simplified coordination** - Unified manager for all document types
- ✅ **Auto-indexing** - Configurable flat/hierarchical organization per type

**Migration from v1.x**:
- Old: 11 type-specific skills (`docs-manage-api`, `docs-manage-adr`, etc.)
- New: 4 operation skills (`doc-writer`, `doc-validator`, `doc-classifier`, `doc-lister`)
- Frontmatter change: `type:` → `fractary_doc_type:`

### Key Features

- **Operation-Specific Skills**: `doc-writer`, `doc-validator`, `doc-classifier`, `doc-lister` handle ANY doc type
- **Type Context System**: 5 files per type (schema, template, standards, validation-rules, index-config)
- **Dual-Format Support**: Generate both README.md and JSON formats simultaneously
- **Automatic Index Management**: Configurable flat or hierarchical organization
- **11 Document Types**: ADR, architecture, dataset, ETL, testing, API, guides, standards, infrastructure, audit, and generic
- **Coordination Pipeline**: Automatic write → validate → index workflow
- **Batch Operations**: Process multiple documents with parallel execution
- **Codex Integration**: Automatic frontmatter for knowledge management
- **Configuration-Driven**: Customize behavior per document type
- **Git-Friendly**: Version control integration

## Quick Start

### 1. Create Documentation

```bash
# Create API documentation
/docs:write api

# Create ADR
/docs:write adr

# Create dataset documentation
/docs:write dataset

# Batch create multiple docs
/docs:write api docs/api/**/*.md --batch
```

### 2. Validate Documentation

```bash
# Validate all documentation
/docs:validate

# Validate specific file
/docs:validate docs/api/user-api/README.md

# Validate specific type
/docs:validate --doc-type api

# Validate and fix
/docs:validate docs/ --fix
```

### 3. List Documentation

```bash
# List all documentation
/docs:list

# List API docs only
/docs:list --doc-type api

# List draft documents
/docs:list --status draft

# Output as JSON
/docs:list --format json

# Output as markdown
/docs:list --format markdown
```

### 4. Audit Documentation

```bash
# Audit all documentation
/docs:audit

# Audit specific directory
/docs:audit docs/api

# Audit specific type
/docs:audit --doc-type dataset
```

## Architecture

The plugin uses a **three-layer architecture** optimized for context efficiency:

```
┌─────────────────────────────────────────────────────────┐
│  Layer 1: Commands (Entry Points)                      │
│  /docs:write, /docs:validate, /docs:list, /docs:audit  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Layer 2: Coordination (Decision & Routing)             │
│  ┌──────────────────┐  ┌──────────────────────────┐    │
│  │ docs-manager     │  │ docs-director-skill      │    │
│  │ (single doc)     │  │ (multi-doc + parallel)   │    │
│  └──────────────────┘  └──────────────────────────┘    │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Layer 3: Operations (Type-Agnostic Execution)          │
│  ┌──────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐  │
│  │ doc-     │ │ doc-     │ │ doc-     │ │ doc-     │  │
│  │ writer   │ │ validator│ │ classifier│ │ lister   │  │
│  └──────────┘ └──────────┘ └──────────┘ └──────────┘  │
└──────────────────────┬──────────────────────────────────┘
                       │
                       ▼
┌─────────────────────────────────────────────────────────┐
│  Type Context (Data-Driven Behavior)                    │
│  types/{doc_type}/                                      │
│    ├─ schema.json           (structure validation)     │
│    ├─ template.md           (content template)         │
│    ├─ standards.md          (writing guidelines)       │
│    ├─ validation-rules.md   (quality checks)           │
│    └─ index-config.json     (index organization)       │
└─────────────────────────────────────────────────────────┘
```

### Architecture Benefits

| Aspect | v1.x (Type-Specific) | v2.0 (Operation-Specific) |
|--------|---------------------|--------------------------|
| **Code Duplication** | 93% duplicated | <7% duplicated |
| **Lines of Code** | ~7,000 lines | ~2,500 lines |
| **Skills per Type** | 11 type skills + 3 operation skills | 4 operation skills (universal) |
| **Adding New Type** | Create new skill (500+ lines) | Add 5 data files (~200 lines) |
| **Maintenance** | Change in 11+ places | Change in 1-4 places |
| **Context Usage** | Higher (separate skills) | Lower (shared operations) |

## Document Types

All document types use the same operation skills but with different type context:

| Type | Use Case | Index Organization |
|------|----------|-------------------|
| **api** | API endpoints and services | Hierarchical (service → version) |
| **adr** | Architecture Decision Records | Flat (by date) |
| **architecture** | System architecture docs | Hierarchical (component → layer) |
| **dataset** | Data schema and structure | Hierarchical (source → format) |
| **etl** | ETL pipelines and transformations | Hierarchical (source → target) |
| **testing** | Test plans and strategies | Hierarchical (type → scope) |
| **guides** | User and developer guides | Hierarchical (audience → topic) |
| **standards** | Development standards | Hierarchical (scope → category) |
| **infrastructure** | Infrastructure docs | Hierarchical (provider → service) |
| **audit** | Audit reports and findings | Flat (by date) |
| **_untyped** | Generic/unclassified docs | Flat |

## Type Context System

Each document type is defined by 5 files in `types/{doc_type}/`:

### 1. `schema.json`

Defines the structure and validation rules:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "API Documentation Schema",
  "properties": {
    "fractary_doc_type": {"const": "api"},
    "endpoint": {"type": "string", "pattern": "^/.*"},
    "method": {"enum": ["GET", "POST", "PUT", "DELETE", "PATCH"]},
    "service": {"type": "string"},
    "version": {"type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$"},
    "status": {"enum": ["draft", "published", "deprecated"]}
  },
  "required": ["fractary_doc_type", "endpoint", "method", "service", "version"]
}
```

### 2. `template.md`

Mustache template for generating documents:

```markdown
---
title: "{{title}}"
fractary_doc_type: api
endpoint: {{endpoint}}
method: {{method}}
service: {{service}}
version: {{version}}
status: {{status}}
date: {{date}}
---

# {{title}}

**Endpoint**: `{{method}} {{endpoint}}`
**Service**: {{service}}
**Version**: {{version}}

## Overview

{{overview}}

## Request

{{request_details}}

## Response

{{response_details}}

## Examples

{{examples}}
```

### 3. `standards.md`

Writing guidelines and best practices:

```markdown
# API Documentation Standards

## Required Sections
- Overview (purpose and high-level behavior)
- Request (parameters, headers, body schema)
- Response (status codes, body schema)
- Examples (request/response pairs)

## Naming Conventions
- Endpoint paths use kebab-case
- Service names use PascalCase
- Version follows semantic versioning

## Best Practices
- Include authentication requirements
- Document all error codes
- Provide cURL examples
- Show request/response schemas in JSON Schema format
```

### 4. `validation-rules.md`

Type-specific validation checks:

```markdown
# API Documentation Validation Rules

## Frontmatter Validation
- ✅ `endpoint` must start with `/`
- ✅ `method` must be GET, POST, PUT, DELETE, or PATCH
- ✅ `service` must be non-empty
- ✅ `version` must follow semver (x.y.z)

## Content Validation
- ✅ Must have Request section
- ✅ Must have Response section
- ✅ Must have Examples section
- ✅ Examples must include cURL or equivalent

## Link Validation
- ✅ Related API endpoints must exist
- ✅ Service documentation must be linked
```

### 5. `index-config.json`

Index generation configuration:

```json
{
  "index_file": "docs/api/README.md",
  "organization": "hierarchical",
  "group_by": ["service", "version"],
  "sort_by": "endpoint",
  "sort_order": "asc",
  "entry_template": "- [**{{method}} {{endpoint}}**]({{relative_path}}) - {{title}}",
  "section_template": "## {{group_name}}"
}
```

**Index organization modes**:
- **flat**: Simple list sorted by `sort_by` field
- **hierarchical**: Multi-level grouping using `group_by` array

**Template variables**: All frontmatter fields plus:
- `{{relative_path}}` - Relative path to document
- `{{filename}}` - File name
- `{{group_name}}` - Current group value (hierarchical only)
- `{{description_short}}` - Truncated description (100 chars)

## Operations

### Write Operation (doc-writer)

Create or update documentation with automatic validation and indexing.

**Single document**:
```bash
/docs:write api
```

**Batch operation**:
```bash
/docs:write api docs/api/**/*.md --batch
```

**Pipeline**:
1. Classify doc_type (if not provided)
2. Load type context (5 files)
3. Render template with context
4. Validate document (unless `--skip-validation`)
5. Update index (unless `--skip-index`)

### Validate Operation (doc-validator)

Validate documentation against schema and quality rules.

**Validation checks**:
- Frontmatter structure (JSON Schema validation)
- Required sections (per standards.md)
- Custom rules (per validation-rules.md)
- Link validity (internal references)
- Markdown linting (optional)

**Example**:
```bash
/docs:validate docs/api/user-login/README.md
```

### Classify Operation (doc-classifier)

Auto-detect document type from path or content.

**Classification methods**:
1. **Path-based**: `docs/{doc_type}/` → detect from directory
2. **Content-based**: Read frontmatter `fractary_doc_type` field
3. **Fallback**: `_untyped` if unable to determine

**Example**:
```bash
# Automatically detects "api" from path
/docs:write docs/api/new-endpoint/README.md
```

### List Operation (doc-lister)

List and filter documentation with various output formats.

**Output formats**:
- **table**: ASCII table (default)
- **json**: Structured JSON
- **markdown**: Formatted markdown with links

**Filters**:
- `--doc-type <type>`: Filter by document type
- `--status <status>`: Filter by status (draft, published, deprecated)
- `--limit <n>`: Limit results

**Example**:
```bash
/docs:list --doc-type api --status published --format markdown
```

### Audit Operation (docs-director)

Analyze documentation across project to identify issues and gaps.

**Analysis**:
- Count documents by type and status
- Identify missing indices
- Find validation issues
- Detect missing `fractary_doc_type` fields

**Output**:
```
═══════════════════════════════════════
DOCUMENTATION AUDIT REPORT
═══════════════════════════════════════

Summary:
  Total Documents: 156
  Document Types: 8
  Missing Indices: 2
  Validation Issues: 5

By Type:
  api             45 documents
  adr             32 documents
  dataset         18 documents
  ...

Issues Found:
  ⚠️  docs/api/deprecated/: Missing index
  ❌ docs/dataset/metrics.md: Missing fractary_doc_type
```

## Coordination Skills

### docs-manager-skill (Single Document)

Orchestrates write → validate → index pipeline for single documents.

**Operations**:
- `write`: Create/update document with validation and indexing
- `validate`: Validate single document
- `index`: Update index for document's directory

**Example invocation**:
```
Use the @agent-fractary-docs:docs-manager agent with:
{
  "operation": "write",
  "file_path": "docs/api/user-login/README.md",
  "doc_type": "api",
  "context": {
    "title": "User Login",
    "endpoint": "/api/auth/login",
    "method": "POST",
    "service": "AuthService",
    "version": "1.0.0"
  }
}
```

### docs-director-skill (Multi-Document)

Handles batch operations with pattern matching and parallel execution.

**Operations**:
- `write-batch`: Create/update multiple documents in parallel
- `validate-batch`: Validate multiple documents
- `audit-docs`: Analyze documentation across project

**Parallel execution**:
- Concurrent processing (configurable max 10)
- File locking for safe concurrent access
- Aggregated results reporting

**Example**:
```bash
/docs:write api docs/api/**/README.md --batch
```

## Agent Invocation

Use declarative invocation to interact with the docs-manager agent:

```
Use the @agent-fractary-docs:docs-manager agent to write API documentation:
{
  "operation": "write",
  "doc_type": "api",
  "parameters": {
    "title": "User Login Endpoint",
    "endpoint": "/api/auth/login",
    "method": "POST",
    "service": "AuthService",
    "version": "1.0.0",
    "status": "draft",
    "overview": "Authenticates users with email/password credentials",
    "request_details": "...",
    "response_details": "...",
    "examples": "..."
  },
  "options": {
    "validate_after": true,
    "update_index": true
  }
}
```

## Adding New Document Types

To add a new document type (e.g., `changelog`):

### 1. Create type directory

```bash
mkdir -p plugins/docs/types/changelog
```

### 2. Create 5 type context files

**schema.json**:
```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "fractary_doc_type": {"const": "changelog"},
    "version": {"type": "string", "pattern": "^\\d+\\.\\d+\\.\\d+$"},
    "release_date": {"type": "string", "format": "date"},
    "status": {"enum": ["draft", "released"]}
  },
  "required": ["fractary_doc_type", "version", "release_date"]
}
```

**template.md**:
```markdown
---
title: "{{title}}"
fractary_doc_type: changelog
version: {{version}}
release_date: {{release_date}}
status: {{status}}
---

# {{title}}

## Version {{version}} - {{release_date}}

### Added
{{added}}

### Changed
{{changed}}

### Fixed
{{fixed}}

### Deprecated
{{deprecated}}
```

**standards.md**:
```markdown
# Changelog Standards

## Format
Follow Keep a Changelog format (keepachangelog.com)

## Sections
- Added (new features)
- Changed (changes to existing)
- Fixed (bug fixes)
- Deprecated (soon-to-be removed)
- Removed (removed features)
- Security (security fixes)

## Versioning
Use semantic versioning (semver.org)
```

**validation-rules.md**:
```markdown
# Changelog Validation Rules

## Frontmatter
- version must follow semver
- release_date must be valid date

## Content
- Must have at least one of: Added, Changed, Fixed
- Each section must have bullet points
- Links to issues/PRs encouraged
```

**index-config.json**:
```json
{
  "index_file": "docs/changelog/README.md",
  "organization": "flat",
  "group_by": [],
  "sort_by": "version",
  "sort_order": "desc",
  "entry_template": "- [**{{version}}**]({{relative_path}}) - {{release_date}}",
  "section_template": "## {{group_name}}"
}
```

### 3. Use immediately

```bash
/docs:write changelog
```

No skill changes needed! The operation skills automatically load the new type context.

## Migration from v1.x

### Frontmatter Field Change

**v1.x** (deprecated):
```yaml
---
type: api
---
```

**v2.0** (current):
```yaml
---
fractary_doc_type: api
---
```

### Command Changes

**v1.x**:
```bash
/fractary-docs:generate api "..."
/fractary-docs:manage-api "..."
```

**v2.0**:
```bash
/docs:write api
/docs:validate --doc-type api
```

### Skill Changes

**v1.x**: Type-specific skills
- `docs-manage-api` (500+ lines)
- `docs-manage-adr` (500+ lines)
- `docs-manage-architecture` (500+ lines)
- ... (11 skills total)

**v2.0**: Operation skills
- `doc-writer` (universal)
- `doc-validator` (universal)
- `doc-classifier` (universal)
- `doc-lister` (universal)

## Configuration

Configuration is stored in `.fractary/plugins/docs/config.json` (project) or `~/.config/fractary/docs/config.json` (global).

### Example Configuration

```json
{
  "schema_version": "2.0",
  "output_paths": {
    "documentation": "docs",
    "api": "docs/api",
    "adr": "docs/architecture/adrs",
    "dataset": "docs/datasets",
    "etl": "docs/etl",
    "testing": "docs/testing"
  },
  "validation": {
    "auto_validate": true,
    "lint_markdown": true,
    "check_links": true
  },
  "indexing": {
    "auto_update": true,
    "parallel_execution": true,
    "max_concurrent": 10
  },
  "frontmatter": {
    "codex_sync": true,
    "default_status": "draft"
  }
}
```

## Frontmatter Schema

All documents use this standard frontmatter format:

```yaml
---
title: "Document Title"
fractary_doc_type: api
status: draft
date: 2025-01-15
updated: 2025-01-16
author: Claude Code
tags: [api, authentication]
version: 1.0.0
codex_sync: true
# Type-specific fields (e.g., for API docs):
endpoint: /api/auth/login
method: POST
service: AuthService
---
```

**Standard fields**:
- `title`: Document title (required)
- `fractary_doc_type`: Document type (required)
- `status`: draft | published | deprecated (required)
- `date`: Creation date (auto-generated)
- `updated`: Last update date (auto-maintained)
- `version`: Semantic version (required for some types)
- `author`: Author name
- `tags`: Array of tags for categorization
- `codex_sync`: Enable codex synchronization

**Type-specific fields**: Defined in each type's `schema.json`

## Commands

- `/docs:write <doc_type>` - Create or update documentation
- `/docs:validate [path]` - Validate documentation
- `/docs:list [options]` - List and filter documentation
- `/docs:audit [directory]` - Audit documentation quality

See individual command files in `commands/` for detailed usage.

## Integration

### With fractary-codex

All documents include `codex_sync: true` in frontmatter, enabling automatic synchronization with the codex knowledge base.

### With FABER Workflows

FABER workflows use docs plugin for:
- Specifications (Architect phase)
- Test reports (Evaluate phase)
- Deployment records (Release phase)

### With fractary-repo

Documentation changes can be automatically committed using fractary-repo plugin integration.

## Best Practices

1. **Always use `fractary_doc_type`**: Required field (not `type`)
2. **Let classification happen**: Path-based detection works for `docs/{doc_type}/`
3. **Use batch operations**: Process multiple docs efficiently with `--batch`
4. **Leverage auto-indexing**: Indices update automatically after write operations
5. **Validate before commit**: Catch errors early
6. **Follow type standards**: Read `types/{doc_type}/standards.md` for guidelines
7. **Use hierarchical indices**: Configure in `index-config.json` for better organization
8. **Version control everything**: All docs and indices should be in git
9. **Keep type context updated**: Modify 5 files to change type behavior
10. **Use semantic versioning**: For schema, API, and other versioned docs

## Troubleshooting

### "Missing fractary_doc_type field"

Ensure frontmatter includes:
```yaml
fractary_doc_type: api
```

Not `type: api` (deprecated v1.x format).

### "Type context not found"

Verify the type directory exists:
```bash
ls plugins/docs/types/{doc_type}/
# Should show: schema.json, template.md, standards.md, validation-rules.md, index-config.json
```

### Validation failing

Check specific errors and ensure document follows type standards:
```bash
cat plugins/docs/types/{doc_type}/standards.md
cat plugins/docs/types/{doc_type}/validation-rules.md
```

### Index not updating

Verify `index-config.json` exists and is valid JSON:
```bash
cat plugins/docs/types/{doc_type}/index-config.json | jq .
```

## File Structure

```
plugins/docs/
├── .claude-plugin/
│   └── plugin.json                    # Plugin manifest (v2.0.0)
├── agents/
│   └── docs-manager.md                # Main coordination agent
├── skills/
│   ├── doc-writer/                    # CREATE + UPDATE operation
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── write-doc.sh
│   │       ├── render-template.sh
│   │       └── version-bump.sh
│   ├── doc-validator/                 # VALIDATE operation
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── validate-frontmatter.sh
│   │       └── validate-structure.sh
│   ├── doc-classifier/                # CLASSIFY operation
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── classify-by-path.sh
│   │       └── classify-by-content.sh
│   ├── doc-lister/                    # LIST operation
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       └── list-docs.sh
│   ├── docs-manager-skill/            # Single-doc coordinator
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── coordinate-write.sh
│   │       ├── coordinate-validate.sh
│   │       └── coordinate-index.sh
│   ├── docs-director-skill/           # Multi-doc coordinator
│   │   ├── SKILL.md
│   │   └── scripts/
│   │       ├── batch-write.sh
│   │       ├── audit-docs.sh
│   │       └── pattern-expand.sh
│   └── _shared/
│       └── lib/
│           ├── index-updater.sh       # README.md index generation
│           └── dual-format-generator.sh # README + JSON generation
├── types/                             # Type context (data-driven)
│   ├── api/
│   │   ├── schema.json
│   │   ├── template.md
│   │   ├── standards.md
│   │   ├── validation-rules.md
│   │   └── index-config.json
│   ├── adr/
│   ├── architecture/
│   ├── dataset/
│   ├── etl/
│   ├── testing/
│   ├── guides/
│   ├── standards/
│   ├── infrastructure/
│   ├── audit/
│   └── _untyped/
└── commands/
    ├── write.md                       # /docs:write
    ├── validate.md                    # /docs:validate
    ├── list.md                        # /docs:list
    └── audit.md                       # /docs:audit
```

## Version

**2.0.0** - Architecture refactor (operation-specific skills with data-driven type context)

**Breaking changes from 1.x**:
- Frontmatter field: `type:` → `fractary_doc_type:`
- Commands: `/fractary-docs:*` → `/docs:*`
- Skills: Type-specific → Operation-specific

## Contributing

To contribute:

1. **Add new document type**: Create 5 files in `types/{doc_type}/`
2. **Enhance operation**: Modify operation skill (doc-writer, doc-validator, etc.)
3. **Improve coordination**: Update manager or director skills
4. **Test thoroughly**: Validate against all 11 existing types

## See Also

- **[SPEC-docs-plugin-refactor.md](../../docs/specs/SPEC-docs-plugin-refactor.md)** - Detailed architecture specification
- **[CLAUDE.md](../../CLAUDE.md)** - Plugin development standards
- **[fractary-codex](../codex/)** - Knowledge management integration
- **[fractary-repo](../repo/)** - Source control integration

---

For more information:
- Plugin manifest: `.claude-plugin/plugin.json`
- Agent specification: `agents/docs-manager.md`
- Operation skills: `skills/doc-*/`
- Type context: `types/*/`
- Commands: `commands/*.md`
