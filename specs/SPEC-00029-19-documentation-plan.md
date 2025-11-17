# SPEC-00029-19: Documentation Plan

**Issue**: #29
**Phase**: 6 (Migration & Documentation)
**Dependencies**: All previous specs (0029-01 through 0029-18)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Comprehensive documentation plan for all four new plugins (fractary-file, fractary-docs, fractary-spec, fractary-logs) including user guides, API documentation, examples, tutorials, and troubleshooting resources.

## Documentation Structure

### Repository Documentation (docs/)

**Human Reference - NOT deployed with plugins**:

```
docs/
├── standards/
│   ├── documentation-standards.md (updated)
│   ├── file-plugin-architecture.md
│   ├── spec-lifecycle-model.md
│   └── log-retention-strategy.md
├── guides/
│   ├── fractary-file-guide.md
│   ├── fractary-docs-guide.md
│   ├── fractary-spec-guide.md
│   ├── fractary-logs-guide.md
│   ├── migrating-to-new-plugins.md
│   └── troubleshooting.md
└── specs/
    └── SPEC-00029-*.md (these specs)
```

### Plugin Documentation (Deployed)

**Deployed with each plugin**:

```
plugins/file/
├── README.md (overview, quick start)
└── skills/*/docs/ (skill-specific guides)

plugins/docs/
├── README.md (overview, quick start)
└── skills/*/docs/ (template guides, validation rules)

plugins/spec/
├── README.md (overview, quick start)
└── skills/*/docs/ (spec formats, archive process)

plugins/logs/
├── README.md (overview, quick start)
└── skills/*/docs/ (session capture, search syntax)
```

## Documentation Content

### 1. fractary-file Plugin

**README.md**:
```markdown
# Fractary File Plugin

Multi-provider cloud storage for the Fractary ecosystem.

## Quick Start

```bash
# Initialize with local storage (default)
/fractary-file:init

# Or configure cloud provider
/fractary-file:init --handler s3
```

## Supported Providers

- **Local** (default): Local filesystem storage
- **R2**: Cloudflare R2
- **S3**: AWS S3
- **GCS**: Google Cloud Storage
- **Google Drive**: Google Drive

## Operations

- `upload`: Upload file to storage
- `download`: Download file from storage
- `delete`: Delete file from storage
- `list`: List files in storage
- `get-url`: Generate accessible URL
- `read`: Read file content without downloading

## Configuration

See `/fractary-file:init` for interactive setup.

Example `.fractary/plugins/file/config.json`:
[config example]

## Documentation

- Handler setup guides: `skills/handler-storage-*/docs/`
- Operations reference: `skills/file-manager/docs/operations.md`
```

**Handler-Specific Docs**:

- `skills/handler-storage-local/docs/local-storage-guide.md`
- `skills/handler-storage-r2/docs/r2-setup-guide.md`
- `skills/handler-storage-s3/docs/s3-setup-guide.md`
- `skills/handler-storage-gcs/docs/gcs-setup-guide.md`
- `skills/handler-storage-gdrive/docs/gdrive-setup-guide.md`

Each includes:
- Authentication setup
- Configuration options
- Permissions required
- Troubleshooting

### 2. fractary-docs Plugin

**README.md**:
```markdown
# Fractary Docs Plugin

Living documentation management for consistent, version-controlled project documentation.

## Quick Start

```bash
# Initialize
/fractary-docs:init

# Generate documentation
/fractary-docs:generate adr "Use PostgreSQL for data store"

# Update existing doc
/fractary-docs:update "/docs/architecture/database.md" --section "Performance" --content "..."

# Validate documentation
/fractary-docs:validate
```

## Features

- **10+ Templates**: ADRs, design docs, runbooks, API specs, test reports
- **Document Updates**: Modify existing docs while preserving structure
- **Validation**: Ensure docs meet quality standards
- **Linking**: Cross-reference and index documentation
- **Codex Integration**: Automatic front matter for codex sync

## Templates

[List of templates with descriptions]

## Commands

[Command reference]

## Documentation

- Template guide: `skills/doc-generator/docs/template-guide.md`
- Front matter schema: `skills/doc-generator/docs/frontmatter-schema.md`
- Validation rules: `skills/doc-validator/docs/validation-rules.md`
- Linking conventions: `skills/doc-linker/docs/linking-conventions.md`
```

### 3. fractary-spec Plugin

**README.md**:
```markdown
# Fractary Spec Plugin

Ephemeral specification lifecycle management tied to work items.

## Quick Start

```bash
# Initialize
/fractary-spec:init

# Generate spec from issue
/fractary-spec:generate 123

# Validate implementation
/fractary-spec:validate 123

# Archive when complete
/fractary-spec:archive 123

# Read archived spec
/fractary-spec:read 123
```

## Key Concepts

- **Issue-Centric**: Specs tied to issue numbers
- **Ephemeral**: Temporary, archived when work completes
- **Lifecycle-Based**: Archive on issue close, not time
- **Multi-Spec**: One issue can have multiple specs (phases)
- **Dual Storage**: Local while active, cloud when archived

## Why Archive?

Old specs confuse Claude. Archiving keeps local context clean while preserving history in searchable cloud storage.

## Commands

[Command reference]

## Documentation

- Spec format guide: `skills/spec-generator/docs/spec-format-guide.md`
- Validation checklist: `skills/spec-validator/docs/validation-checklist.md`
- Archive process: `skills/spec-archiver/docs/archive-process.md`
```

### 4. fractary-logs Plugin

**README.md**:
```markdown
# Fractary Logs Plugin

Operational log management with hybrid retention and intelligent archival.

## Quick Start

```bash
# Initialize
/fractary-logs:init

# Capture session
/fractary-logs:capture 123

# Archive logs
/fractary-logs:archive 123

# Search logs
/fractary-logs:search "OAuth error"

# Read archived logs
/fractary-logs:read 123
```

## Features

- **Session Capture**: Record Claude conversations
- **Hybrid Retention**: Local (30 days) + Cloud (forever)
- **Lifecycle Archival**: Archive when work completes
- **Search**: Query across local and cloud logs
- **Analysis**: Extract patterns, errors, insights

## Log Types

- Session logs (conversations)
- Build logs
- Deployment logs
- Debug logs

## Commands

[Command reference]

## Documentation

- Session logging: `skills/log-capturer/docs/session-logging-guide.md`
- Archive process: `skills/log-archiver/docs/archive-process.md`
- Search syntax: `skills/log-searcher/docs/search-syntax.md`
- Analysis types: `skills/log-analyzer/docs/analysis-types.md`
```

## User Guides (docs/guides/)

### Guide: Fractary File Plugin

**docs/guides/fractary-file-guide.md**:

- Overview and philosophy
- Installation and initialization
- Configuring each handler
- Operations with examples
- Integration with other plugins
- Troubleshooting common issues
- Advanced topics (custom endpoints, IAM roles)

### Guide: Fractary Docs Plugin

**docs/guides/fractary-docs-guide.md**:

- Documentation philosophy
- Template system
- Generating documentation
- Updating existing docs
- Validation and quality checks
- Linking and cross-references
- Codex integration
- Custom templates

### Guide: Fractary Spec Plugin

**docs/guides/fractary-spec-guide.md**:

- Why specs are ephemeral
- Generating from issues
- Multi-phase specifications
- Validation workflow
- Archive lifecycle
- Reading archived specs
- Integration with FABER

### Guide: Fractary Logs Plugin

**docs/guides/fractary-logs-guide.md**:

- Operational logging philosophy
- Session capture
- Log types and organization
- Hybrid retention strategy
- Archive workflow
- Searching logs
- Analysis and insights
- Integration with FABER

### Guide: Migration

**docs/guides/migrating-to-new-plugins.md**:

- For plugin developers
- For end users
- Migration tools
- Backward compatibility
- Rollback procedures

### Guide: Troubleshooting

**docs/guides/troubleshooting.md**:

Common issues and solutions for all four plugins:
- Connection errors
- Authentication problems
- Archive failures
- Search not finding results
- Performance issues

## Examples and Tutorials

### Example: Complete FABER Workflow

**docs/examples/faber-workflow-with-new-plugins.md**:

Step-by-step example showing:
1. Initialize plugins
2. Run FABER workflow
3. Spec generation
4. Session capture
5. Log management
6. Archive on completion
7. Reading archived content

### Example: Multi-Phase Spec

**docs/examples/multi-phase-specification.md**:

How to handle large issues with multiple specs.

### Example: Log Analysis

**docs/examples/log-analysis-patterns.md**:

Finding patterns and insights in historical logs.

### Tutorial: Setting Up Cloud Storage

**docs/tutorials/setup-cloud-storage.md**:

Step-by-step for each provider:
- R2 setup
- S3 setup
- GCS setup
- Google Drive setup

## API Documentation

For each plugin, document agent invocation patterns:

**docs/api/fractary-file-api.md**
**docs/api/fractary-docs-api.md**
**docs/api/fractary-spec-api.md**
**docs/api/fractary-logs-api.md**

Each includes:
- Agent invocation syntax
- Request/response schemas
- Error codes
- Examples

## Video/Visual Content

Consider creating:
- Architecture diagrams
- Workflow diagrams
- Screen recordings of key workflows
- Visual guide to configuration

## Documentation Deliverables

### Phase 1: Core Documentation (Week 1)
- [ ] README.md for all 4 plugins
- [ ] Skill-specific docs (in skills/*/docs/)
- [ ] Configuration examples
- [ ] Command reference

### Phase 2: User Guides (Week 2)
- [ ] Complete user guide for each plugin
- [ ] Migration guide
- [ ] Troubleshooting guide
- [ ] Quick start guide

### Phase 3: Examples & Tutorials (Week 2)
- [ ] FABER workflow example
- [ ] Multi-phase spec example
- [ ] Log analysis example
- [ ] Cloud storage setup tutorials

### Phase 4: Advanced Documentation (Week 3)
- [ ] API documentation
- [ ] Architecture diagrams
- [ ] Standards documents
- [ ] Best practices

## Documentation Standards

All documentation should:
- Use clear, concise language
- Include code examples
- Show expected output
- Explain "why" not just "how"
- Include troubleshooting sections
- Link to related docs
- Keep up-to-date with implementation

## Success Criteria

- [ ] All plugins have comprehensive README
- [ ] All skills have documentation
- [ ] Complete user guides for all 4 plugins
- [ ] Migration guides written
- [ ] Troubleshooting guide complete
- [ ] Examples and tutorials created
- [ ] API documentation available
- [ ] Standards documents updated

## Timeline

**Estimated**: 2 weeks

- Week 1: Core plugin docs, skill docs, configuration
- Week 2: User guides, examples, tutorials, troubleshooting

## Maintenance

Documentation should be updated:
- With each new feature
- When APIs change
- When user feedback reveals gaps
- Quarterly review for accuracy

---

**END OF SPEC-00029 SERIES**

This completes all 19 specifications for implementing fractary-file, fractary-docs, fractary-spec, and fractary-logs plugins as defined in issue #29.
