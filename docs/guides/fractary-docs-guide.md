# Fractary Docs Plugin - User Guide

Complete guide to living documentation management with the fractary-docs plugin.

## Overview

The fractary-docs plugin manages **living documentation** - documentation that evolves with your project and should always reflect current state. Unlike specs (which are ephemeral and archived), docs stay in git and sync with codex for knowledge management.

### Key Concepts

**Living Documentation**: Documentation that is continuously updated to reflect current system state. Examples: architecture docs, API references, runbooks, ADRs.

**Template-Based Generation**: 10+ document templates for consistent structure and formatting.

**Front Matter**: YAML metadata enabling codex integration, categorization, and cross-referencing.

**Structure Preservation**: Update sections without breaking document structure or formatting.

### Document Lifecycle

```
Generate → Update → Validate → Commit → Sync with Codex
   ↓         ↓          ↓          ↓            ↓
Create    Modify    Check     Version      Searchable
from      sections  quality   control      knowledge
template  precisely checks                 base
```

## Quick Start

### 1. Initialize

```bash
/fractary-docs:init
```

Creates:
- `.fractary/plugins/docs/config.json` - Configuration
- `/docs` directory structure
- Initial `INDEX.md` for navigation

### 2. Generate Your First Doc

**Architecture Decision Record (ADR)**:
```bash
/fractary-docs:generate adr "Use PostgreSQL for data storage"
```

**Design Document**:
```bash
/fractary-docs:generate design "User Authentication System" --status draft
```

**Runbook**:
```bash
/fractary-docs:generate runbook "Database Failover Procedure"
```

### 3. Update Existing Doc

```bash
/fractary-docs:update docs/architecture/adrs/ADR-001.md \
  --section "Status" \
  --content "Accepted"
```

### 4. Validate Quality

```bash
/fractary-docs:validate docs/
```

Checks:
- Markdown syntax
- Front matter completeness
- Required sections present
- Link validity

### 5. Manage Cross-References

```bash
# Generate documentation index
/fractary-docs:link index

# Check for broken links
/fractary-docs:link check

# Generate relationship graph
/fractary-docs:link graph
```

## Document Templates

### Architecture Decision Record (ADR)

**When to use**: Recording significant architectural decisions

**Template includes**:
- Status (proposed, accepted, rejected, deprecated, superseded)
- Context (what problem are we solving?)
- Decision (what did we decide?)
- Consequences (positive and negative impacts)

**Example**:
```
Use @agent-fractary-docs:docs-manager to generate ADR:
{
  "operation": "generate",
  "doc_type": "adr",
  "parameters": {
    "title": "Use PostgreSQL for Data Storage",
    "number": "001",
    "status": "proposed",
    "context": "We need a reliable database with ACID guarantees...",
    "decision": "We will use PostgreSQL 15 as our primary data store",
    "consequences": {
      "positive": ["Strong ACID", "Rich queries", "Mature ecosystem"],
      "negative": ["Operational overhead", "Learning curve"]
    }
  }
}
```

**Output**: `docs/architecture/adrs/ADR-001-use-postgresql.md`

---

### Design Document

**When to use**: Designing new systems or features

**Template includes**:
- Overview (high-level description)
- Goals and non-goals
- Architecture (components, interactions)
- Implementation details
- Alternatives considered
- Testing strategy

**Example**:
```
Use @agent-fractary-docs:docs-manager to generate design:
{
  "operation": "generate",
  "doc_type": "design",
  "parameters": {
    "title": "Rate Limiting System",
    "overview": "Implement rate limiting to prevent API abuse",
    "goals": ["Protect service", "Fair usage", "Simple configuration"],
    "architecture": "Token bucket algorithm with Redis backend..."
  }
}
```

**Output**: `docs/architecture/designs/rate-limiting-system.md`

---

### Runbook

**When to use**: Operational procedures and emergency responses

**Template includes**:
- Purpose
- Prerequisites
- Step-by-step instructions
- Rollback procedure
- Troubleshooting
- Success criteria

**Example**:
```
Use @agent-fractary-docs:docs-manager to generate runbook:
{
  "operation": "generate",
  "doc_type": "runbook",
  "parameters": {
    "title": "Database Failover",
    "purpose": "Steps to failover primary database to replica",
    "prerequisites": ["Access to AWS Console", "Database credentials"],
    "steps": [
      "1. Check replica lag",
      "2. Promote replica to primary",
      "3. Update DNS",
      "4. Verify application connectivity"
    ]
  }
}
```

**Output**: `docs/operations/runbooks/database-failover.md`

---

### API Specification

**When to use**: Documenting REST APIs, GraphQL schemas

**Template includes**:
- Overview
- Authentication
- Endpoints (method, path, parameters)
- Request/response examples
- Error codes
- Rate limits

---

### Test Report

**When to use**: Documenting test execution results

**Template includes**:
- Summary (pass/fail counts)
- Test environment
- Test cases with results
- Coverage metrics
- Issues found
- Recommendations

---

### Deployment Record

**When to use**: Recording production deployments

**Template includes**:
- Deployment metadata (version, date, duration)
- Infrastructure changes
- Deployment steps
- Verification checks
- Issues and resolutions
- Rollback plan

---

### Additional Templates

- **Changelog**: Version history with breaking changes
- **Architecture Overview**: System-level architecture
- **Troubleshooting Guide**: Common issues and solutions
- **Postmortem**: Incident analysis and learnings

See `plugins/docs/skills/doc-generator/templates/` for all templates.

## Updating Documentation

### Update Specific Section

```
Use @agent-fractary-docs:docs-manager to update section:
{
  "operation": "update",
  "file_path": "docs/architecture/database.md",
  "section": "Performance",
  "content": "Updated with caching layer results..."
}
```

Finds section by heading, replaces content, preserves structure.

### Append New Section

```
Use @agent-fractary-docs:docs-manager to append section:
{
  "operation": "update",
  "file_path": "docs/guides/setup.md",
  "append_section": "Troubleshooting",
  "content": "## Troubleshooting\n\n### Issue: Connection timeout..."
}
```

Adds new section at end of document.

### Update Front Matter

```
Use @agent-fractary-docs:docs-manager to update metadata:
{
  "operation": "update",
  "file_path": "docs/api/user-service.md",
  "metadata": {
    "status": "approved",
    "updated": "2025-01-15"
  }
}
```

Updates YAML front matter without touching content.

### Pattern-Based Replacement

```
Use @agent-fractary-docs:docs-manager to replace content:
{
  "operation": "update",
  "file_path": "docs/config.md",
  "find": "v1.2.0",
  "replace": "v1.3.0"
}
```

Replaces all occurrences of pattern.

## Front Matter Schema

All documents include front matter for metadata and codex integration:

```yaml
---
title: "ADR-001: Use PostgreSQL"
type: adr
status: accepted
date: 2025-01-15
updated: 2025-01-15
author: Claude Code
tags: [database, architecture, postgresql]
related:
  - /docs/architecture/designs/database-schema.md
  - /docs/operations/runbooks/database-failover.md
codex_sync: true
generated: true
---
```

### Standard Fields

- **title**: Document title (required)
- **type**: Document type (adr, design, runbook, etc.)
- **status**: Document status (draft, review, approved, deprecated)
- **date**: Creation date
- **updated**: Last update date (auto-maintained)
- **author**: Author name
- **tags**: Array of tags for categorization
- **related**: Array of related document paths (for cross-referencing)
- **codex_sync**: Enable/disable codex synchronization (default: true)
- **generated**: Indicates auto-generated document

### Custom Fields

Add project-specific fields in configuration:

```json
{
  "frontmatter": {
    "default_fields": {
      "project": "my-project",
      "team": "platform",
      "review_required": true
    }
  }
}
```

## Validation

### Validation Checks

**Markdown Linting**:
- Consistent heading levels
- Proper list formatting
- Valid code blocks
- Link syntax

**Front Matter Validation**:
- Required fields present
- Valid YAML syntax
- Correct field types
- Date formats

**Structure Validation**:
- Required sections per doc type
- Heading hierarchy
- Minimum content length

**Link Validation**:
- Internal links resolve
- External links accessible
- No broken references

### Running Validation

**Validate all docs**:
```bash
/fractary-docs:validate docs/
```

**Validate specific file**:
```bash
/fractary-docs:validate docs/architecture/adrs/ADR-001.md
```

**Auto-fix issues**:
```bash
/fractary-docs:validate docs/ --fix
```

Fixes:
- Trailing whitespace
- Inconsistent line endings
- Duplicate blank lines
- Simple markdown issues

**Validation report**:
```
Validating: docs/architecture/adrs/ADR-001.md
  ✓ Markdown syntax valid
  ✓ Front matter complete
  ✓ Required sections present
  ⚠ Link broken: /docs/old-design.md
  ⚠ Status should be lowercase

Summary: 3 passed, 2 warnings, 0 errors
```

## Cross-Reference Management

### Creating Index

```bash
/fractary-docs:link index
```

Generates `docs/INDEX.md`:
```markdown
# Documentation Index

## Architecture
- [ADR-001: Use PostgreSQL](architecture/adrs/ADR-001.md)
- [Database Design](architecture/designs/database.md)

## Operations
- [Database Failover](operations/runbooks/database-failover.md)
```

Auto-updates when docs added/removed.

### Checking Links

```bash
/fractary-docs:link check
```

Finds:
- Broken internal links
- Missing referenced docs
- Orphaned documents
- Circular references

### Fixing Links

```bash
/fractary-docs:link check --fix
```

Auto-fixes:
- Update references after file moves
- Fix casing issues
- Resolve relative paths
- Update index

### Generating Relationship Graph

```bash
/fractary-docs:link graph
```

Generates visualization of document relationships based on `related` field in front matter.

## Configuration

Edit `.fractary/plugins/docs/config.json`:

```json
{
  "schema_version": "1.0",
  "output_paths": {
    "documentation": "docs",
    "adrs": "docs/architecture/adrs",
    "designs": "docs/architecture/designs",
    "runbooks": "docs/operations/runbooks",
    "api_docs": "docs/api",
    "guides": "docs/guides"
  },
  "templates": {
    "custom_template_dir": null,
    "use_project_templates": true
  },
  "frontmatter": {
    "always_include": true,
    "codex_sync": true,
    "default_fields": {
      "author": "Claude Code",
      "generated": true
    }
  },
  "validation": {
    "lint_on_generate": true,
    "required_sections": {
      "adr": ["Status", "Context", "Decision", "Consequences"],
      "design": ["Overview", "Architecture"],
      "runbook": ["Purpose", "Steps"]
    }
  },
  "linking": {
    "auto_update_index": true,
    "check_broken_links": true
  }
}
```

### Customization Options

**Output Paths**: Change where docs are stored
**Templates**: Use custom templates
**Front Matter**: Set default fields
**Validation**: Configure quality checks
**Linking**: Auto-index and link checking

## Integration with Codex

All docs with `codex_sync: true` are indexed by fractary-codex plugin for:
- Semantic search across documentation
- Context-aware suggestions
- Cross-project knowledge sharing
- Historical reference

No additional configuration needed - front matter enables automatic sync.

## Best Practices

### 1. Choose Right Template

- ADR for decisions
- Design for systems
- Runbook for procedures
- API docs for endpoints
- Test report for QA
- Deployment for releases

### 2. Maintain Front Matter

- Always include required fields
- Update `updated` field when modifying
- Add relevant `tags` for discovery
- Link `related` documents
- Keep `status` current

### 3. Follow Naming Conventions

- ADRs: `ADR-NNN-short-title.md`
- Designs: `design-feature-name.md`
- Runbooks: `runbook-process.md`
- Lowercase, hyphens not underscores

### 4. Keep Docs Current

- Update when implementation changes
- Deprecate outdated docs (don't delete)
- Regular review cycle (quarterly)
- Assign ownership

### 5. Validate Regularly

- Before committing
- In CI/CD pipeline
- Weekly audits
- Fix warnings promptly

### 6. Cross-Reference

- Link related docs
- Update index regularly
- Use consistent link paths
- Document dependencies

## Troubleshooting

### Configuration not found

Run `/fractary-docs:init` to create default config.

### Validation fails

Check specific errors and use `--fix` flag for auto-fixable issues.

### Template not found

Verify doc_type is correct. Available types: adr, design, runbook, api-spec, test-report, deployment, changelog, architecture, troubleshooting, postmortem.

### Broken links

Run `/fractary-docs:link check --fix` to auto-repair.

### Permission denied

Ensure docs directory writable: `chmod -R u+w docs/`

### Section not found (during update)

Check section heading matches exactly (case-sensitive).

## Examples

See `plugins/docs/samples/` for complete example documentation sets demonstrating:
- Proper front matter
- Cross-referencing
- All document types
- Validation compliance

## Further Reading

- Plugin README: `plugins/docs/README.md`
- Template guide: `plugins/docs/skills/doc-generator/docs/template-guide.md`
- Validation rules: `plugins/docs/skills/doc-validator/docs/validation-rules.md`
- Linking conventions: `plugins/docs/skills/doc-linker/docs/linking-conventions.md`
- Specs: `docs/specs/SPEC-0029-04.md` through `SPEC-0029-07.md`

---

**Version**: 1.0 (2025-01-15)
