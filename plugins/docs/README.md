# Fractary Docs Plugin

Living documentation management with template-based generation, updating, validation, and cross-reference linking.

## Overview

The `fractary-docs` plugin provides comprehensive documentation management for projects with support for multiple document types, automatic front matter generation for codex integration, validation, and cross-reference management.

### Key Features

- **11+ Document Templates**: ADRs, design docs, runbooks, API specs, schemas, test reports, deployments, changelogs, and more
- **Document Updating**: Modify existing docs while preserving structure and formatting
- **Validation**: Markdown linting, front matter validation, required sections checking, link verification
- **Cross-Reference Management**: Auto-generate indexes, update links, visualize relationships
- **Codex Integration**: Automatic front matter for knowledge management
- **Configuration-Driven**: Customize paths, templates, and validation rules
- **Git-Friendly**: Version control integration with atomic commits
- **Template Extensibility**: Support for custom project-specific templates

## Document Types

| Type | Template | Sections | Use Case |
|------|----------|----------|----------|
| **ADR** | adr.md.template | Status, Context, Decision, Consequences | Architecture decisions |
| **Design** | design.md.template | Overview, Architecture, Implementation | System/feature design |
| **Runbook** | runbook.md.template | Purpose, Prerequisites, Steps, Troubleshooting | Operational procedures |
| **API Spec** | api-spec.md.template | Overview, Endpoints, Authentication | API documentation |
| **Schema** | schema.md.template | Overview, Schema Format, Fields, Validation Rules | Data schemas & dictionaries |
| **Test Report** | test-report.md.template | Summary, Test Cases, Results, Coverage | Test execution results |
| **Deployment** | deployment.md.template | Overview, Infrastructure, Steps | Deployment records |
| **Changelog** | changelog.md.template | Version, Changes, Breaking Changes | Version history |
| **Architecture** | architecture.md.template | Overview, Components, Patterns | System architecture |
| **Troubleshooting** | troubleshooting.md.template | Problem, Diagnosis, Solution | Debug guides |
| **Postmortem** | postmortem.md.template | Incident, Timeline, Root Cause, Actions | Incident reviews |

## Quick Start

**New to fractary-docs?** Start with:
1. 📘 [Quick Start Guide](./docs/quick-start.md) - Get up and running in 5 minutes
2. 📂 [Sample Documentation](./samples/) - Real-world examples
3. 🧪 [Integration Testing](./docs/integration-testing.md) - Test the plugin
4. 🔧 [Troubleshooting Guide](./docs/troubleshooting.md) - Common issues and solutions

### 1. Initialize Plugin

```bash
# Initialize with defaults (docs/ directory)
/fractary-docs:init

# Initialize with custom location
/fractary-docs:init --docs-root documentation/

# Initialize globally
/fractary-docs:init --global
```

This creates:
- Configuration file: `.fractary/plugins/docs/config.json`
- Documentation directories: `docs/architecture/`, `docs/operations/`, `docs/api/`, etc.
- Initial index: `docs/INDEX.md`

### 2. Generate Documentation

```bash
# Generate an ADR
/fractary-docs:generate adr "Use PostgreSQL for data storage"

# Generate a design document
/fractary-docs:generate design "User authentication system" --status draft

# Generate a runbook
/fractary-docs:generate runbook "Emergency database failover"

# Generate API documentation
/fractary-docs:generate api-spec "User Service API v2"

# Generate schema documentation
/fractary-docs:generate schema "User API Schema" --version "1.0.0" --schema-format "json-schema"
```

### 3. Update Existing Documentation

```bash
# Update specific section
/fractary-docs:update docs/architecture/adrs/ADR-001.md --section "Status" --content "Accepted"

# Append new section
/fractary-docs:update docs/guides/setup.md --append-section "Troubleshooting" --content "Common issues..."

# Update front matter
/fractary-docs:update docs/api/user-api.md --status approved
```

### 4. Validate Documentation

```bash
# Validate all documentation
/fractary-docs:validate

# Validate specific file
/fractary-docs:validate docs/architecture/adrs/ADR-001.md

# Validate and fix issues
/fractary-docs:validate docs/ --fix
```

### 5. Manage Links and Cross-References

```bash
# Create/update documentation index
/fractary-docs:link index

# Check for broken links
/fractary-docs:link check

# Fix broken links automatically
/fractary-docs:link check --fix

# Generate documentation relationship graph
/fractary-docs:link graph
```

## Architecture

The plugin uses a **three-layer architecture** for context efficiency and maintainability:

```
┌─────────────────────────────────────┐
│  Layer 1: docs-manager Agent       │  ← Workflow orchestration
│  (agents/docs-manager.md)          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Layer 2: Documentation Skills      │  ← Focused execution
│  (skills/doc-*)                     │
│  - doc-generator                    │  ← Template-based generation
│  - doc-updater                      │  ← Structure-preserving updates
│  - doc-validator                    │  ← Quality assurance
│  - doc-linker                       │  ← Cross-reference management
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Scripts (Pure Execution)           │  ← NOT in LLM context
│  (skills/*/scripts/)                │
│  - render-template.sh               │
│  - update-section.sh                │
│  - lint-markdown.sh                 │
│  - create-index.sh                  │
└─────────────────────────────────────┘
```

**Benefits**:
- **Context efficiency**: Scripts kept outside LLM context
- **Modular design**: Each skill handles one concern
- **Easy to extend**: Add new templates or validation rules without changing agent
- **Clear separation**: Decision logic vs execution

## Operations

### Generate (doc-generator skill)

Create new documentation from templates with automatic front matter.

**Supported Operations**:
- generate-adr: Architecture Decision Records
- generate-design: System/feature design documents
- generate-runbook: Operational procedures
- generate-api-spec: API documentation
- generate-test-report: Test execution results
- generate-deployment: Deployment records
- generate-changelog: Version changelogs
- generate-architecture: System architecture docs
- generate-troubleshooting: Debug guides
- generate-postmortem: Incident reviews

**Example**:
```bash
/fractary-docs:generate adr "Use PostgreSQL for data storage" --number 001 --status proposed
```

### Update (doc-updater skill)

Modify existing documentation while preserving structure and formatting.

**Supported Operations**:
- update-section: Update specific section by heading
- append-section: Add new section to document
- update-metadata: Modify front matter only
- replace-content: Pattern-based replacement

**Example**:
```bash
/fractary-docs:update docs/architecture/adrs/ADR-001.md --section "Status" --content "Accepted"
```

### Validate (doc-validator skill)

Check documentation quality and compliance with standards.

**Validation Checks**:
- markdown-lint: Markdown syntax and style
- frontmatter: YAML structure and required fields
- structure: Required sections per document type
- links: Internal and external link validity

**Example**:
```bash
/fractary-docs:validate docs/ --markdown-lint --frontmatter --structure
```

### Link (doc-linker skill)

Manage cross-references and documentation relationships.

**Supported Operations**:
- create-index: Generate documentation catalog
- update-references: Update cross-references after file moves
- find-broken-links: Identify dead links
- generate-graph: Visualize documentation relationships

**Example**:
```bash
/fractary-docs:link index --output docs/INDEX.md
```

## Configuration

Configuration is stored in `.fractary/plugins/docs/config.json` (project) or `~/.config/fractary/docs/config.json` (global).

### Example Configuration

```json
{
  "schema_version": "1.0",
  "output_paths": {
    "documentation": "docs",
    "adrs": "docs/architecture/adrs",
    "designs": "docs/architecture/designs",
    "runbooks": "docs/operations/runbooks",
    "api_docs": "docs/api",
    "guides": "docs/guides",
    "testing": "docs/testing",
    "deployments": "docs/deployments"
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
      "design": ["Overview", "Architecture", "Implementation"],
      "runbook": ["Purpose", "Prerequisites", "Steps", "Troubleshooting"]
    }
  },
  "linking": {
    "auto_update_index": true,
    "check_broken_links": true,
    "generate_graph": true
  }
}
```

### Configuration Options

**output_paths**: Customize where different document types are stored

**templates**: Use built-in templates or specify custom template directory

**frontmatter**: Control front matter generation and codex sync

**validation**: Configure validation rules per document type

**linking**: Enable auto-index updates and broken link checking

## Hooks

Hooks allow projects to extend fractary-docs with custom logic while using the standard plugin. Hooks are shell scripts that execute at specific points in documentation workflows.

### Hook Types

```json
{
  "hooks": {
    "pre_generate": "./scripts/pre-generate.sh",
    "post_generate": "./scripts/post-generate.sh",
    "pre_validate": "./scripts/validate-custom.sh",
    "post_validate": null,
    "pre_update": null,
    "post_update": "./scripts/update-index.sh"
  },
  "validation": {
    "custom_rules_script": "./scripts/validate-custom.sh",
    "project_standards_doc": "./docs/DOCUMENTATION-STANDARDS.md"
  }
}
```

### When Hooks Execute

- **pre_generate**: Before generating a new document
- **post_generate**: After successfully generating a document
- **pre_validate**: Before running validation checks (for custom validation rules)
- **post_validate**: After validation completes
- **pre_update**: Before updating an existing document
- **post_update**: After successfully updating a document

### Hook Script Interface

Hooks receive context via environment variables:

```bash
#!/usr/bin/env bash
# Example post_generate hook

# Available variables:
# - DOC_TYPE: Type of document (adr, design, runbook, etc.)
# - FILE_PATH: Path to the document
# - OPERATION: Operation being performed (generate, update, validate)

# Example: Auto-generate table of contents
if [[ "$DOC_TYPE" == "design" ]]; then
  markdown-toc -i "$FILE_PATH"
fi
```

### Common Hook Use Cases

**1. Auto-generate TOC** (post_generate):
```bash
#!/usr/bin/env bash
# scripts/post-generate.sh
markdown-toc -i "$FILE_PATH"
```

**2. Custom validation** (pre_validate):
```bash
#!/usr/bin/env bash
# scripts/validate-custom.sh

# Validate API specs have language examples
if [[ "$DOC_TYPE" == "api-spec" ]]; then
  for lang in python typescript go; do
    if ! grep -q "\`\`\`$lang" "$FILE_PATH"; then
      echo "ERROR: API spec missing $lang example"
      exit 1
    fi
  done
fi
```

**3. Update documentation index** (post_update):
```bash
#!/usr/bin/env bash
# scripts/update-index.sh
/fractary-docs:link index
```

**4. Notify team** (post_generate):
```bash
#!/usr/bin/env bash
# scripts/notify-team.sh
if [[ "$DOC_TYPE" == "adr" ]]; then
  curl -X POST "$SLACK_WEBHOOK" \
    -d "{\"text\": \"New ADR created: $FILE_PATH\"}"
fi
```

### Project-Specific Standards

The `project_standards_doc` configuration points to a markdown file documenting project-specific documentation requirements:

```markdown
# Documentation Standards

## API Documentation
All API specs must include code examples in:
- Python
- TypeScript
- Go

## Naming Conventions
- Features: `feature-name-YYYYMMDD.md`
- ADRs: `ADR-NNN-short-title.md`

## Custom Requirements
- Security-related docs must be reviewed by security team
- API changes require migration guide section
```

This document is referenced during validation and audit workflows.

### Schema Documentation Customization

Schema documentation supports extensive customization via project-specific standards and validation scripts. See the complete reference implementation in `examples/schema-standards/`.

**Example: Custom Schema Validation**

Create a custom validation script to enforce project-specific requirements:

```bash
# .fractary/plugins/docs/scripts/validate-schema-docs.sh
#!/usr/bin/env bash

# Check naming conventions
# Check field documentation completeness
# Validate semantic versioning
# Verify code generation sections
# Check PII security annotations

# Return structured JSON with errors/warnings
```

**Example: Schema-Specific Hooks**

```bash
# .fractary/plugins/docs/hooks/post-generate.sh
#!/usr/bin/env bash

if [[ "$DOC_TYPE" == "schema" ]]; then
  # Auto-generate code from schema
  case "$SCHEMA_FORMAT" in
    json-schema)
      npx quicktype "$FILE_PATH" -o "src/types/$(basename "$FILE_PATH" .md).ts"
      ;;
    openapi)
      openapi-generator generate -i "$FILE_PATH" -g typescript-axios -o ./generated/api
      ;;
  esac

  # Update schema registry
  echo "Updating schema index..."
fi
```

**Example Configuration**:

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

**Complete Example**: See `examples/schema-standards/` for:
- Project-specific schema standards document
- Custom validation script with 10+ checks
- Pre-validate and post-generate hooks
- Example configuration
- Setup instructions and best practices

## Front Matter Schema

All generated documents include codex-compatible front matter:

```yaml
---
title: "ADR-001: Use PostgreSQL for data storage"
type: adr
status: proposed
date: 2025-01-15
author: Claude Code
tags: [database, infrastructure]
related: ["/docs/architecture/designs/database-schema.md"]
codex_sync: true
generated: true
---
```

**Standard Fields**:
- `title`: Document title
- `type`: Document type (adr, design, runbook, etc.)
- `status`: Document status (proposed, draft, review, approved, deprecated)
- `date`: Creation date
- `updated`: Last update date (auto-maintained)
- `author`: Author name
- `tags`: Array of tags for categorization
- `related`: Array of related document paths
- `codex_sync`: Enable/disable codex synchronization
- `generated`: Indicates auto-generated document

## Agent Invocation

Use declarative invocation to interact with the docs-manager agent:

```
Use the @agent-fractary-docs:docs-manager agent to generate ADR:
{
  "operation": "generate",
  "doc_type": "adr",
  "parameters": {
    "title": "Use PostgreSQL for data storage",
    "number": "001",
    "status": "proposed",
    "context": "We need a reliable database with ACID guarantees...",
    "decision": "We will use PostgreSQL 15 as our primary data store...",
    "consequences": {
      "positive": ["Strong ACID compliance", "Rich query capabilities"],
      "negative": ["Additional operational overhead"]
    }
  },
  "options": {
    "validate_after": true,
    "commit_after": false
  }
}
```

## Integration

### With fractary-codex

All generated documents include front matter with `codex_sync: true`, enabling automatic synchronization with the codex knowledge base.

### With FABER Workflows

FABER workflows can use doc-generator to create workflow documentation:
- Specifications (Architect phase)
- Test reports (Evaluate phase)
- Deployment records (Release phase)

### With fractary-repo

Documentation changes can be automatically committed to version control using the `--commit` flag or via fractary-repo agent.

## Commands

- `/fractary-docs:init` - Initialize plugin configuration
- `/fractary-docs:generate` - Generate documentation from templates
- `/fractary-docs:update` - Update existing documentation
- `/fractary-docs:validate` - Validate documentation quality
- `/fractary-docs:link` - Manage cross-references and indexes

See individual command files in `commands/` for detailed usage.

## Best Practices

1. **Always include front matter**: Enables codex sync and metadata tracking
2. **Use semantic doc types**: Choose appropriate template for content
3. **Validate before commit**: Catch errors early with `--validate`
4. **Update index regularly**: Keep documentation discoverable
5. **Follow naming conventions**: Use consistent file naming (ADR-NNN-title.md)
6. **Link related docs**: Use front matter "related" field
7. **Update timestamps**: Keep "updated" field current when modifying
8. **Use status fields**: Track document lifecycle (draft → review → approved)
9. **Store in git**: All documentation should be version controlled
10. **Keep docs current**: Update documentation when implementation changes

## File Naming Conventions

- **ADRs**: `ADR-NNN-short-title.md` (e.g., `ADR-001-api-choice.md`)
- **Design Docs**: `design-feature-name.md` (e.g., `design-user-auth.md`)
- **Runbooks**: `runbook-process-name.md` (e.g., `runbook-deployment.md`)
- **API Specs**: `api-service-name.md` (e.g., `api-user-service.md`)
- **Test Reports**: `test-report-YYYY-MM-DD.md`
- **Deployments**: `deployment-YYYY-MM-DD.md`
- **Changelogs**: `CHANGELOG.md` (standard)
- **Postmortems**: `postmortem-YYYY-MM-DD-incident.md`

## Troubleshooting

### Configuration not found

Run `/fractary-docs:init` to create default configuration.

### Validation failing

Check specific validation errors and use `--fix` to auto-fix simple issues:
```bash
/fractary-docs:validate docs/ --fix
```

### Broken links

Find and fix broken links:
```bash
/fractary-docs:link check --fix
```

### Permission denied

Ensure documentation directories are writable:
```bash
chmod -R u+w docs/
```

### Template not found

Verify doc_type is correct and templates exist in `skills/doc-generator/templates/` or your custom template directory.

## Examples

The `samples/` directory contains a complete documentation set demonstrating all plugin features:

### Sample Documentation Set

```
samples/
├── adrs/
│   └── ADR-001-postgresql.md          # Architecture decision record
├── designs/
│   └── database-architecture.md        # System design document
└── runbooks/
    ├── database-failover.md            # Emergency procedures
    └── database-maintenance.md         # Regular maintenance
```

**Features demonstrated**:
- ✅ Proper front matter with all required fields
- ✅ Document relationships using `related[]` arrays
- ✅ Complete sections per document type
- ✅ Valid markdown and internal links
- ✅ Tags for categorization
- ✅ Real-world content and structure

### Try the Samples

```bash
# Validate samples
/fractary-docs:validate samples/

# Generate index
/fractary-docs:create-index samples/ --output samples/INDEX.md

# Check links
/fractary-docs:link-check samples/

# Generate relationship graph
/fractary-docs:generate-graph samples/ --output samples/GRAPH.md
```

### Example Workflows

See the [Integration Testing Guide](./docs/integration-testing.md) for complete workflows including:
- Creating documentation sets (ADR → Design → Runbook)
- Updating existing documents
- Validation and link checking
- Index and graph generation
- Error handling and recovery

## Documentation

- **[Quick Start Guide](./docs/quick-start.md)** - Get started in 5 minutes
- **[Integration Testing](./docs/integration-testing.md)** - Complete test suite and workflows
- **[Troubleshooting Guide](./docs/troubleshooting.md)** - Common issues and solutions
- **[Template Guide](./skills/doc-generator/docs/template-guide.md)** - Template reference
- **[Validation Rules](./skills/doc-validator/docs/validation-rules.md)** - Validation details
- **[Linking Conventions](./skills/doc-linker/docs/linking-conventions.md)** - Best practices for linking
- **[Front Matter Schema](./skills/doc-generator/docs/frontmatter-schema.md)** - Metadata reference

## Contributing

To add a new document template:

1. Create template file in `skills/doc-generator/templates/{type}.md.template`
2. Use Mustache-style syntax for variables: `{{variable_name}}`
3. Include front matter template with required fields
4. Define required sections in configuration
5. Add validation rules for the new doc type
6. Document the template in `skills/doc-generator/docs/template-guide.md`

## License

Part of the Fractary Claude Code Plugins repository.

## Version

1.0.0 - Initial release

---

For more information, see:
- Plugin configuration: `config/config.example.json`
- Agent specification: `agents/docs-manager.md`
- Skill documentation: `skills/*/docs/`
- Command reference: `commands/*.md`
