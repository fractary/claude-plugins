# Type-Specific Skills Architecture Guide

## Overview

As of v1.1, the fractary-docs plugin uses **type-specific skills** for document generation and management. This architectural change improves context efficiency and enables better auto-discovery.

## What Changed

### Before (v1.0): Agent-Based Routing

```
User/Agent → docs-manager agent → doc-generator skill → Document
```

**Problems**:
- Context lost at agent boundary
- Extra agent hop adds overhead
- Generic skill name limits auto-discovery

### After (v1.1): Direct Skill Invocation

```
User/Agent → doc-{type} skill → Document
```

**Benefits**:
- ✅ Context preserved throughout operation
- ✅ More efficient (no agent hop)
- ✅ Better auto-discovery (`doc-adr` clearly indicates ADR generation)
- ✅ Explicit intent in code

## Type-Specific Skills

### doc-adr
**Purpose**: Generate, update, and manage Architecture Decision Records

**Operations**:
- `generate`: Create new ADR with auto-numbering
- `update`: Update existing ADR (restricted for accepted ADRs)
- `supersede`: Mark ADR as superseded by newer ADR
- `deprecate`: Mark ADR as deprecated

**Example**:
```markdown
Use the doc-adr skill to document this architectural decision:
{
  "operation": "generate",
  "title": "Use PostgreSQL for Primary Datastore",
  "context": "We need a reliable database with ACID guarantees...",
  "decision": "We will use PostgreSQL 15 as our primary datastore...",
  "consequences": {
    "positive": ["ACID compliance", "Rich query capabilities"],
    "negative": ["Operational overhead", "Vertical scaling limits"]
  },
  "status": "proposed"
}
```

### doc-spec
**Purpose**: Generate and manage implementation specifications

**Operations**:
- `generate`: Create new specification
- `update`: Update existing specification
- `deprecate`: Mark specification as deprecated

**Example**:
```markdown
Use the doc-spec skill to create an implementation specification:
{
  "operation": "generate",
  "title": "Add CSV Export Feature",
  "work_id": "abc123",
  "summary": "Implement CSV export functionality for user data...",
  "requirements": ["Users can export profile data", "Large exports processed async"],
  "technical_approach": "Implement export service using background jobs...",
  "testing_strategy": "Unit tests for CSV generation, integration tests for API..."
}
```

### doc-runbook
**Purpose**: Generate and manage operational runbooks

**Operations**:
- `generate`: Create new runbook
- `update`: Update existing runbook
- `archive`: Archive outdated runbook

### doc-api
**Purpose**: Generate and manage API documentation

**Operations**:
- `generate`: Create new API documentation
- `update`: Update existing API documentation

### doc-deployment
**Purpose**: Generate deployment records

**Operations**:
- `generate`: Create deployment record
- `update`: Update deployment status

## Configuration System

The new architecture uses a three-layer configuration system:

### Layer 1: Schema (plugins/docs/schemas/{type}.schema.json)

Defines structure, rules, and defaults for each doc type.

```json
{
  "type": "adr",
  "display_name": "Architecture Decision Record",
  "file_naming": {
    "pattern": "ADR-{number}-{slug}.md",
    "auto_number": true
  },
  "storage": {
    "default_path": "docs/architecture/adrs"
  },
  "structure": {
    "required_sections": ["Status", "Context", "Decision", "Consequences"]
  },
  "status": {
    "allowed_values": ["proposed", "accepted", "deprecated", "superseded"]
  }
}
```

### Layer 2: Plugin Config (config/config.example.json)

Plugin-level defaults and settings.

```json
{
  "doc_types": {
    "adr": {
      "enabled": true,
      "path": "docs/architecture/adrs",
      "auto_number": true
    }
  },
  "frontmatter": {
    "codex_sync": true,
    "default_fields": {
      "author": "Claude Code"
    }
  }
}
```

### Layer 3: Project Config (.fractary/plugins/docs/config.json)

Project-specific overrides.

```json
{
  "doc_types": {
    "adr": {
      "path": "docs/decisions",
      "auto_number": true
    },
    "spec": {
      "path": ".faber/specs",
      "link_to_work_items": true
    }
  }
}
```

**Resolution**: Schema defaults → Plugin config → Project config (last wins)

## Commands (Backwards Compatible)

Existing commands still work but now route directly to type-specific skills:

```bash
# Generate ADR (routes to doc-adr skill)
/fractary-docs:generate adr "Use PostgreSQL for Data Store"

# Update ADR (routes to doc-adr skill)
/fractary-docs:update docs/architecture/adrs/ADR-005-use-postgresql.md --status accepted

# Validate (routes to doc-validator skill)
/fractary-docs:validate docs/architecture/adrs/

# Link operations (routes to doc-linker skill)
/fractary-docs:link index
```

## docs-manager Agent (Multi-Document Workflows)

The docs-manager agent now focuses on **multi-document orchestration**:

### When to Use docs-manager

✅ **Release documentation workflow**:
```markdown
Use the @agent-fractary-docs:docs-manager agent for release documentation:
{
  "operation": "release-workflow",
  "version": "2.0.0",
  "changes": [...],
  "deployment_notes": [...]
}
```

Orchestrates:
1. doc-changelog skill → Update CHANGELOG.md
2. doc-deployment skill → Create deployment record
3. doc-release-notes skill → Generate release notes
4. doc-linker skill → Update docs index

✅ **Architecture suite workflow**:
```markdown
Use the @agent-fractary-docs:docs-manager agent for architecture suite:
{
  "operation": "architecture-suite",
  "decision_title": "Migrate to Microservices",
  "spec_title": "Microservices Migration Specification"
}
```

Orchestrates:
1. doc-adr skill → Generate ADR
2. doc-spec skill → Generate implementation spec
3. doc-architecture skill → Create architecture diagram
4. doc-updater skill → Update README
5. doc-linker skill → Cross-link all documents

### When NOT to Use docs-manager

❌ **Single ADR** → Use `doc-adr` skill directly
❌ **Single spec** → Use `doc-spec` skill directly
❌ **Single validation** → Use `doc-validator` skill directly

## Usage from Other Plugins

### From FABER Architect Phase

**Before (v1.0)**:
```markdown
Use the @agent-fractary-docs:docs-manager agent to generate ADR:
{
  "operation": "generate",
  "doc_type": "adr",
  "parameters": {...}
}
```

**After (v1.1)**:
```markdown
Use the doc-adr skill to document this architectural decision:
{
  "operation": "generate",
  "title": "...",
  "context": "...",
  "decision": "...",
  "consequences": {...}
}
```

**Benefits**:
- All architect context (work item, decisions, rationale) flows directly to skill
- No need to serialize everything into JSON parameters
- More natural invocation pattern

### From FABER Release Phase

Use docs-manager for multi-document release workflow:

```markdown
Use the @agent-fractary-docs:docs-manager agent for release documentation:
{
  "operation": "release-workflow",
  "version": "2.0.0"
}
```

## Shared Infrastructure

Type-specific skills share common infrastructure:

### Shared Library (_shared/lib/)

- `schema-loader.sh` - Load doc type schemas
- `config-resolver.sh` - Merge schema + configs

### Shared Scripts (_shared/scripts/)

- `slugify.sh` - Convert titles to URL-friendly slugs
- `find-next-number.sh` - Find next sequential number (for ADRs)
- `render-template.sh` - Mustache template rendering (to be implemented)
- `add-frontmatter.sh` - YAML frontmatter injection (to be implemented)
- `validate-doc.sh` - Structure validation (to be implemented)

Scripts stay OUT of LLM context for efficiency.

## Migration Guide

### For Plugin Developers

1. **Update agent invocations**:
   - Replace `@agent-fractary-docs:docs-manager` → Direct skill invocation
   - Example: `doc-adr skill` instead of `docs-manager agent with operation=generate`

2. **Update to new config structure**:
   - Add `doc_types` section to your config
   - Move path overrides to `doc_types.{type}.path`

3. **Test with new architecture**:
   - Verify context flows correctly
   - Check that auto-discovery works

### For Users

No changes required! Commands work the same:

```bash
/fractary-docs:generate adr "My Decision"
/fractary-docs:update docs/architecture/adrs/ADR-001.md --status accepted
/fractary-docs:validate docs/
```

## Future Enhancements

1. **Additional Type-Specific Skills**:
   - `doc-changelog` - Changelog management
   - `doc-release-notes` - Release notes generation
   - `doc-architecture` - Architecture diagrams
   - `doc-troubleshooting` - Troubleshooting guides

2. **Enhanced Validation**:
   - Schema-driven validation rules
   - Custom validation scripts
   - Project-specific standards

3. **Template System**:
   - Mustache template rendering in scripts
   - Project-level template customization
   - Template inheritance

4. **Workflow Automation**:
   - Pre/post generation hooks
   - Automatic cross-linking
   - Documentation graphs

## Resources

- **Schemas**: `plugins/docs/schemas/`
- **Type Skills**: `plugins/docs/skills/doc-{type}/`
- **Shared Infrastructure**: `plugins/docs/skills/_shared/`
- **Configuration Example**: `plugins/docs/config/config.example.json`
- **Plugin Standards**: `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`

## Questions?

- Check existing implementations in `plugins/docs/skills/doc-adr/`
- Review schemas in `plugins/docs/schemas/`
- See usage examples in this guide
- Refer to updated command docs in `plugins/docs/commands/`
