# SPEC-00029-04: Docs Plugin Architecture

**Issue**: #29
**Phase**: 2 (fractary-docs Plugin)
**Dependencies**: SPEC-00029-01, SPEC-00029-02, SPEC-00029-03 (fractary-file)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Create the fractary-docs plugin for managing living documentation across projects. This plugin provides reusable documentation primitives including template-based generation, document updating, validation, and linking. Documentation created by this plugin is stored in the local filesystem, committed to version control, and synced via fractary-codex.

## Key Principles

1. **Documentation is Living**: Docs represent current state, not point-in-time
2. **Local Storage**: All docs stored in `/docs` (default) for git versioning
3. **Codex Integration**: All generated docs include front matter for codex sync
4. **Template-Based**: Consistent structure via reusable templates
5. **Self-Documenting**: Skills document their own work atomically

## Plugin Structure

```
plugins/docs/
├── .claude-plugin/
│   └── plugin.json                  # Dependencies: fractary-file
├── agents/
│   └── docs-manager.md             # Documentation orchestrator
├── commands/
│   ├── init.md                     # /fractary-docs:init
│   ├── generate.md                 # /fractary-docs:generate
│   ├── update.md                   # /fractary-docs:update
│   ├── validate.md                 # /fractary-docs:validate
│   └── link.md                     # /fractary-docs:link
├── skills/
│   ├── doc-generator/              # Template-based generation
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── template-guide.md
│   │   │   └── frontmatter-schema.md
│   │   ├── templates/
│   │   │   ├── adr.md.template
│   │   │   ├── design.md.template
│   │   │   ├── runbook.md.template
│   │   │   ├── test-report.md.template
│   │   │   ├── deployment.md.template
│   │   │   ├── api-spec.md.template
│   │   │   └── changelog.md.template
│   │   ├── scripts/
│   │   │   ├── generate-from-template.sh
│   │   │   ├── add-frontmatter.sh
│   │   │   └── render-template.sh
│   │   └── workflow/
│   │       ├── generate-adr.md
│   │       └── generate-design-doc.md
│   ├── doc-updater/               # Update existing docs (NEW)
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── update-strategies.md
│   │   ├── scripts/
│   │   │   ├── parse-document.sh
│   │   │   ├── update-section.sh
│   │   │   └── preserve-structure.sh
│   │   └── workflow/
│   │       └── update-documentation.md
│   ├── doc-validator/             # Quality checks
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── validation-rules.md
│   │   └── scripts/
│   │       ├── lint-markdown.sh
│   │       ├── check-frontmatter.sh
│   │       ├── validate-structure.sh
│   │       └── check-links.sh
│   └── doc-linker/                # Cross-references
│       ├── SKILL.md
│       ├── docs/
│       │   └── linking-conventions.md
│       └── scripts/
│           ├── create-index.sh
│           ├── update-references.sh
│           └── find-broken-links.sh
├── config/
│   └── config.example.json
└── README.md
```

## Configuration Schema

```json
{
  "schema_version": "1.0",
  "output_paths": {
    "documentation": "/docs",
    "adrs": "/docs/architecture/adrs",
    "designs": "/docs/architecture/designs",
    "runbooks": "/docs/operations/runbooks",
    "api_docs": "/docs/api",
    "guides": "/docs/guides"
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
      "design": ["Overview", "Architecture", "Implementation"]
    }
  },
  "linking": {
    "auto_update_index": true,
    "check_broken_links": true
  }
}
```

## Core Skills

### 1. doc-generator
Generate documentation from templates with dynamic data.

**Operations**:
- generate-adr: Architecture Decision Records
- generate-design: Design documents
- generate-runbook: Operational runbooks
- generate-api-spec: API documentation
- generate-test-report: Test reports
- generate-deployment: Deployment documentation
- generate-changelog: Change logs

**Key Features**:
- Template variable substitution
- Automatic front matter injection
- Validation after generation
- Git commit optional

### 2. doc-updater (NEW)
Update existing documentation while preserving structure.

**Operations**:
- update-section: Update specific section of doc
- append-section: Add new section
- replace-content: Replace matched content
- update-metadata: Update front matter only

**Key Features**:
- Parse markdown structure
- Preserve formatting
- Update table of contents automatically
- Validate after update

### 3. doc-validator
Ensure documentation quality and consistency.

**Checks**:
- Markdown linting
- Front matter validation
- Required sections present
- Link validity
- Spelling/grammar (optional)
- Template compliance

### 4. doc-linker
Manage cross-references and documentation graph.

**Operations**:
- create-index: Generate documentation index
- update-links: Update cross-references
- find-broken-links: Identify dead links
- generate-graph: Visualize doc relationships

## Template System

### Template Format

Templates use Mustache-style syntax:

```markdown
---
title: {{title}}
type: adr
status: {{status}}
date: {{date}}
author: {{author}}
codex_sync: true
---

# ADR-{{number}}: {{title}}

## Status

{{status}}

## Context

{{context}}

## Decision

{{decision}}

## Consequences

### Positive
{{#positive_consequences}}
- {{.}}
{{/positive_consequences}}

### Negative
{{#negative_consequences}}
- {{.}}
{{/negative_consequences}}

## Alternatives Considered

{{#alternatives}}
### {{name}}
{{description}}

**Rejected because**: {{rejection_reason}}
{{/alternatives}}
```

### Standard Templates

1. **ADR (Architecture Decision Record)**
   - Sections: Status, Context, Decision, Consequences, Alternatives
   - Use case: Document technical decisions
   - Output: `/docs/architecture/adrs/ADR-NNN-title.md`

2. **Design Document**
   - Sections: Overview, Requirements, Architecture, Implementation, Testing
   - Use case: System/feature design
   - Output: `/docs/architecture/designs/design-feature-name.md`

3. **Runbook**
   - Sections: Purpose, Prerequisites, Steps, Troubleshooting, Rollback
   - Use case: Operational procedures
   - Output: `/docs/operations/runbooks/runbook-process-name.md`

4. **API Specification**
   - Sections: Endpoints, Authentication, Request/Response, Examples, Errors
   - Use case: API documentation
   - Output: `/docs/api/api-service-name.md`

5. **Test Report**
   - Sections: Summary, Test Cases, Results, Coverage, Issues
   - Use case: Test execution results
   - Output: `/docs/testing/test-report-YYYY-MM-DD.md`

6. **Deployment Documentation**
   - Sections: Overview, Infrastructure, Configuration, Deployment Steps, Verification
   - Use case: Record deployments
   - Output: `/docs/deployments/deployment-YYYY-MM-DD.md`

## Front Matter Schema (Codex Integration)

All generated documents include:

```yaml
---
title: "Document Title"
type: adr|design|runbook|api|test-report|deployment
author: "Claude Code"
created: "2025-01-15"
updated: "2025-01-15"
status: draft|review|approved|deprecated
tags: [infrastructure, security, api]
related: ["/docs/other-doc.md"]
codex_sync: true
codex_sync_include: ["docs/**"]
codex_sync_exclude: []
---
```

## Agent Specification

**agents/docs-manager.md**:

```markdown
<CONTEXT>
You are the docs-manager agent for the fractary-docs plugin. You orchestrate documentation operations including generation, updating, validation, and linking across all project documentation.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS store documentation in configured paths (default: /docs)
2. ALWAYS include codex-compatible front matter
3. NEVER overwrite existing docs without explicit confirmation
4. ALWAYS validate documentation after generation/update
5. ALWAYS commit documentation changes to version control
</CRITICAL_RULES>

<WORKFLOW>
1. Receive documentation request (generate, update, validate, link)
2. Load configuration for output paths
3. Invoke appropriate skill (doc-generator, doc-updater, doc-validator, doc-linker)
4. Validate result
5. Optionally commit to git
6. Return confirmation with file path
</WORKFLOW>

<SKILLS>
- doc-generator: Create new documentation from templates
- doc-updater: Modify existing documentation
- doc-validator: Check documentation quality
- doc-linker: Manage cross-references
</SKILLS>

<OUTPUTS>
Return structured results:
{
  "success": true,
  "operation": "generate-adr",
  "file_path": "/docs/architecture/adrs/ADR-001-api-choice.md",
  "validation": "passed",
  "committed": true
}
</OUTPUTS>
```

## Integration Points

- **fractary-file**: Not used initially (docs stay local in git)
- **fractary-codex**: Syncs docs via front matter
- **faber**: Uses doc-generator for workflow documentation
- **faber-cloud**: Uses doc-generator for infrastructure docs
- **fractary-spec**: Specs are separate, not docs

## Testing Strategy

- Template rendering with various data
- Front matter generation and validation
- Document updating preserves structure
- Link checking and index generation
- Integration with version control

## Success Criteria

- [ ] Plugin structure created
- [ ] docs-manager agent implemented
- [ ] 7+ templates available
- [ ] All 4 skills functional
- [ ] Configuration system working
- [ ] Front matter schema defined
- [ ] Documentation complete

## Timeline

**Estimated**: 1.5 weeks for architecture and core skills

## Next Steps

- **SPEC-00029-05**: Detailed template system and doc-generator
- **SPEC-00029-06**: doc-updater skill implementation
- **SPEC-00029-07**: Validation and linking skills
