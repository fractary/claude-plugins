# Front Matter Schema

This document defines the YAML front matter schema used by fractary-docs for codex integration and metadata tracking.

## Overview

All generated documentation includes YAML front matter at the beginning of the file. This metadata enables:
- **Codex synchronization** for knowledge management
- **Document categorization** and tagging
- **Relationship tracking** between documents
- **Status tracking** through document lifecycle
- **Search and filtering** in documentation indexes

## Schema Structure

```yaml
---
title: "Document Title"
type: adr|design|runbook|api-spec|test-report|deployment|changelog|architecture|troubleshooting|postmortem
status: draft|review|approved|deprecated|proposed|accepted|superseded
date: "2025-01-15"
updated: "2025-01-15"
author: "Claude Code"
tags: [tag1, tag2, tag3]
related: ["/docs/path/to/related-doc.md"]
codex_sync: true
generated: true
---
```

## Field Definitions

### Required Fields

#### title (string)

**Description**: Human-readable title of the document

**Format**: Free-form string, typically sentence case

**Examples**:
- `"ADR-001: Use PostgreSQL for data storage"`
- `"Design: User Authentication System"`
- `"Runbook: Emergency Database Failover"`

**Validation**: Must be non-empty

#### type (string)

**Description**: Document type classifier

**Valid Values**:
- `adr` - Architecture Decision Record
- `design` - System/feature design document
- `runbook` - Operational procedure
- `api-spec` - API documentation
- `test-report` - Test execution results
- `deployment` - Deployment record
- `changelog` - Version changes
- `architecture` - System architecture
- `troubleshooting` - Debug guide
- `postmortem` - Incident review

**Validation**: Must be one of the valid values

#### date (string)

**Description**: Document creation date

**Format**: `YYYY-MM-DD`

**Examples**:
- `"2025-01-15"`
- `"2025-12-31"`

**Validation**: Must be valid ISO 8601 date format

**Auto-Generated**: Yes, set to current date on creation

### Optional But Recommended Fields

#### status (string)

**Description**: Document lifecycle status

**Valid Values by Type**:

**For ADR**:
- `proposed` - Decision proposed, not yet accepted
- `accepted` - Decision accepted and in use
- `deprecated` - Decision outdated but documented
- `superseded` - Replaced by another ADR

**For Design/Runbook/Other**:
- `draft` - Initial draft, work in progress
- `review` - Ready for review
- `approved` - Reviewed and approved
- `deprecated` - No longer current

**Default**: Depends on document type (typically `proposed` for ADR, `draft` for others)

#### updated (string)

**Description**: Last update timestamp

**Format**: `YYYY-MM-DD` or ISO 8601 timestamp

**Examples**:
- `"2025-01-20"`
- `"2025-01-20T14:30:00Z"`

**Auto-Updated**: Yes, should be updated when document is modified

**Default**: Same as `date` on creation

#### author (string)

**Description**: Document author

**Format**: Free-form string

**Examples**:
- `"Claude Code"`
- `"Engineering Team"`
- `"John Doe"`

**Default**: From configuration or `"Claude Code"`

#### tags (array of strings)

**Description**: Categorization tags for search and filtering

**Format**: Array of lowercase strings, typically kebab-case

**Examples**:
```yaml
tags: [database, infrastructure, postgresql]
tags: [authentication, security, oauth]
tags: [api, rest, v2]
```

**Best Practices**:
- Use lowercase
- Be consistent across documents
- Use 2-5 tags per document
- Include technology, domain, and component tags

**Default**: `[]` (empty array)

#### related (array of strings)

**Description**: Paths to related documents

**Format**: Array of relative or absolute paths to other documentation

**Examples**:
```yaml
related:
  - "/docs/architecture/adrs/ADR-001-database-choice.md"
  - "../designs/user-auth.md"
  - "./deployment-2025-01-10.md"
```

**Use Cases**:
- Link ADR to design docs
- Link design to implementation runbooks
- Link postmortem to related incidents
- Link API spec to architecture docs

**Best Practices**:
- Use relative paths when possible
- Verify links exist
- Keep list focused (3-5 most relevant docs)

**Default**: `[]` (empty array)

### Codex Integration Fields

#### codex_sync (boolean)

**Description**: Enable synchronization with codex knowledge base

**Valid Values**: `true`, `false`

**Purpose**:
- When `true`, document is indexed by codex for knowledge management
- Enables AI-assisted document discovery and context
- Supports cross-project knowledge sharing

**Default**: `true` (from configuration)

**Recommendation**: Keep `true` for all important documentation

#### codex_sync_include (array of strings)

**Description**: Glob patterns for additional files to sync with this document

**Format**: Array of glob patterns

**Examples**:
```yaml
codex_sync_include:
  - "docs/**/*.md"
  - "src/auth/**/*.ts"
```

**Use Case**: Include related source code or additional context

**Default**: Not set (sync only this document)

#### codex_sync_exclude (array of strings)

**Description**: Glob patterns for files to exclude from sync

**Format**: Array of glob patterns

**Examples**:
```yaml
codex_sync_exclude:
  - "**/*.backup.*"
  - "**/*.draft.*"
```

**Default**: `[]` (no exclusions)

### System Fields

#### generated (boolean)

**Description**: Indicates document was auto-generated

**Valid Values**: `true`, `false`

**Purpose**: Distinguish generated vs manually created docs

**Default**: `true` for generated documents

**Use**: Can be used to filter or mark generated documentation

## Type-Specific Fields

### ADR-Specific Fields

```yaml
number: "001"           # ADR number (string for leading zeros)
deciders: "Team Name"   # Who made the decision
```

### API Spec-Specific Fields

```yaml
version: "2.0"          # API version
base_url: "https://api.example.com/v2"  # API base URL
```

### Test Report-Specific Fields

```yaml
environment: "staging"  # Test environment
build: "v2.1.0-rc1"    # Build version tested
```

### Deployment-Specific Fields

```yaml
version: "2.1.0"        # Version deployed
environment: "production"  # Deployment target
```

## Validation Rules

### Required Field Validation

The doc-validator skill checks:
1. All required fields are present
2. Fields are not null or empty
3. Type field matches valid values
4. Date fields use correct format

### Optional Field Validation

Warnings for:
1. Missing recommended fields (author, tags, status)
2. Empty arrays when content expected
3. Invalid date formats in optional fields
4. Broken links in related[] array

## Examples

### Complete ADR Front Matter

```yaml
---
title: "ADR-001: Use PostgreSQL for data storage"
type: adr
status: accepted
number: "001"
date: "2025-01-10"
updated: "2025-01-15"
author: "Engineering Team"
deciders: "Tech Lead, Principal Engineer"
tags: [database, infrastructure, postgresql, storage]
related:
  - "/docs/architecture/designs/database-schema.md"
  - "/docs/operations/runbooks/postgres-maintenance.md"
codex_sync: true
generated: true
---
```

### Complete Design Document Front Matter

```yaml
---
title: "Design: User Authentication System"
type: design
status: approved
date: "2025-01-12"
updated: "2025-01-18"
author: "Claude Code"
tags: [authentication, security, backend, oauth, jwt]
related:
  - "/docs/architecture/adrs/ADR-003-jwt-tokens.md"
  - "/docs/api/auth-api-spec.md"
codex_sync: true
codex_sync_include:
  - "src/auth/**/*.ts"
generated: true
---
```

### Complete Runbook Front Matter

```yaml
---
title: "Runbook: Emergency Database Failover"
type: runbook
status: approved
date: "2025-01-15"
updated: "2025-01-15"
author: "Operations Team"
tags: [database, operations, failover, emergency, postgresql]
related:
  - "/docs/architecture/designs/database-architecture.md"
  - "/docs/operations/runbooks/database-backup.md"
codex_sync: true
generated: true
---
```

## Best Practices

### Title Guidelines

1. **Be Descriptive**: Title should clearly indicate content
2. **Include Numbers**: For ADRs, include number in title
3. **Use Prefixes**: Consider prefixing with document type (optional)
4. **Avoid Abbreviations**: Use full words when possible

### Status Workflow

**ADR Lifecycle**:
```
proposed → accepted → [deprecated/superseded]
```

**Design/Runbook Lifecycle**:
```
draft → review → approved → [deprecated]
```

### Tagging Strategy

1. **Technology Tags**: `postgresql`, `kubernetes`, `nodejs`
2. **Domain Tags**: `authentication`, `storage`, `api`
3. **Component Tags**: `backend`, `frontend`, `infrastructure`
4. **Process Tags**: `security`, `performance`, `testing`

### Relationship Linking

1. **Link Up**: Link to higher-level architecture docs
2. **Link Down**: Link to implementation details
3. **Link Across**: Link to related but parallel docs
4. **Keep Current**: Update related[] when docs move or are renamed

## Codex Integration

### How Codex Uses Front Matter

1. **Indexing**: `title`, `type`, `tags` used for search indexing
2. **Relationships**: `related[]` builds document graph
3. **Filtering**: `status`, `type`, `date` enable filtering
4. **Context**: `codex_sync_include` pulls additional context
5. **Versioning**: `date`, `updated` track document evolution

### Optimizing for Codex

1. **Rich Tags**: Use 3-5 specific tags per document
2. **Link Generously**: Connect related documents explicitly
3. **Update Dates**: Keep `updated` field current
4. **Include Context**: Use `codex_sync_include` for related code
5. **Use Status**: Track document lifecycle properly

## Migration

### Adding Front Matter to Existing Docs

Use `doc-updater` skill to add front matter:

```bash
/fractary-docs:update existing-doc.md --metadata title --content "My Document"
/fractary-docs:update existing-doc.md --metadata type --content "design"
/fractary-docs:update existing-doc.md --metadata date --content "2025-01-15"
```

Or use `add-frontmatter.sh` script directly:

```bash
./skills/doc-generator/scripts/add-frontmatter.sh \
  --file existing-doc.md \
  --frontmatter '{"title": "My Document", "type": "design", "date": "2025-01-15"}'
```

## Validation

### Validation Tools

1. **doc-validator skill**: `/fractary-docs:validate docs/`
2. **validate-output.sh script**: Direct validation
3. **yq**: Manual YAML validation

### Common Validation Errors

**Missing Title**:
```
Error: Missing required field: title
Fix: Add title field to front matter
```

**Invalid Type**:
```
Error: Invalid document type: 'docs'
Fix: Use one of: adr, design, runbook, api-spec, test-report, deployment, changelog, architecture, troubleshooting, postmortem
```

**Invalid Date Format**:
```
Warning: Date format should be YYYY-MM-DD
Fix: Change "01/15/2025" to "2025-01-15"
```

## Reference

- YAML Specification: https://yaml.org/spec/
- Codex Integration: See fractary-codex plugin documentation
- Validation Script: `skills/doc-generator/scripts/validate-output.sh`
- Add Front Matter Script: `skills/doc-generator/scripts/add-frontmatter.sh`
