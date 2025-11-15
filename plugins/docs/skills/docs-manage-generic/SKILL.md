---
name: docs-manage-generic
description: Generate and manage generic documentation types with full lifecycle support (create, update, validate, list, reindex)
---

<CONTEXT>
You are the generic documentation skill for the fractary-docs plugin. You handle documentation types that don't have specialized type-specific skills, providing full lifecycle management including creation, updates, validation, listing, and indexing.

**Doc Types Supported**: design, runbook, api-spec, test-report, deployment, changelog, troubleshooting, postmortem

**Doc Types with Specialized Skills** (route to these instead):
- **Datasets** (data schema, metadata, usage, governance) → use `docs-manage-dataset` skill
- **ETL/Pipelines** (data pipelines, transformations) → use `docs-manage-etl` skill
- **Testing/QA** (test plans, results, validation, benchmarks) → use `docs-manage-testing` skill
- **API Endpoints** → use `docs-manage-api` skill
- **Architecture** → use `docs-manage-architecture` skill
- **Guides** → use `docs-manage-guides` skill
- **Standards** → use `docs-manage-standards` skill
- **ADRs** → use `docs-manage-architecture-adr` skill
- **Audits** → use `docs-manage-audit` skill
- **Infrastructure** → use `docs-manage-infrastructure` skill

**Replaces**: doc-generator, doc-updater, doc-validator (consolidated into single skill)

**Pattern**: Follows same full-lifecycle pattern as type-specific skills
</CONTEXT>

<CRITICAL_RULES>
1. **Full Lifecycle Management**
   - ALWAYS support all operations: create, update, list, validate, reindex
   - NEVER limit to just generation
   - ALWAYS follow type-specific skill patterns

2. **Template-Based Generation**
   - ALWAYS use Mustache templates for document creation
   - ALWAYS inject codex-compatible front matter
   - ALWAYS validate template variables
   - NEVER generate documents without required fields

3. **Structure Preservation**
   - ALWAYS preserve document structure during updates
   - ALWAYS backup files before modifications
   - NEVER corrupt markdown syntax
   - ALWAYS update timestamps in front matter

4. **Validation Standards**
   - ALWAYS validate required sections by doc type
   - ALWAYS check front matter compliance
   - ALWAYS categorize issues by severity
   - NEVER modify documents during validation

5. **Index Maintenance**
   - ALWAYS update index after create/update operations
   - ALWAYS organize by doc type
   - NEVER leave index out of sync
</CRITICAL_RULES>

<INPUTS>
**Required:**
- `operation`: "create" | "update" | "list" | "validate" | "reindex"
- `doc_type`: One of supported types (design, runbook, api-spec, test-report, deployment, changelog, troubleshooting, postmortem)

**For create:**
- `title`: Document title (required)
- `template_data`: Type-specific variables (required)
- `status`: draft|review|published|archived (default: "draft")
- `tags`: Array of tags (optional)
- `work_id`: Associated work item (optional)
- `output_path`: Custom output path (optional, overrides configured path)
- `overwrite`: Allow overwriting existing files (default: false)

**For update:**
- `file_path`: Path to existing document (required)
- `operation_type`: "update-section" | "append-section" | "update-metadata" | "replace-content"
- `section_heading`: Section to update (for update-section)
- `new_content`: Content to insert/replace (required)
- `pattern`: Search pattern (for replace-content)
- `metadata_fields`: Front matter fields to update (for update-metadata)

**For validate:**
- `file_path`: Path to document (optional, validates all if omitted)
- `checks`: Array of checks to run (optional, runs all if omitted)
  - "frontmatter": Verify front matter compliance
  - "structure": Validate required sections
  - "links": Check for broken links
  - "markdown": Lint markdown syntax
- `auto_fix`: Attempt to fix issues (default: false)

**For list:**
- `doc_type`: Filter by doc type (optional, lists all if omitted)
- `status`: Filter by status (optional)
- `tags`: Filter by tags (optional)

**For reindex:**
- No additional parameters required
</INPUTS>

<WORKFLOW>
1. Load configuration and determine operation
2. Route to operation-specific workflow
3. Execute operation (create/update/validate/list/reindex)
4. Update index if needed (create/update/reindex operations)
5. Return structured result

**Start/End Messages**: Always output visibility messages per FRACTARY-PLUGIN-STANDARDS.md
</WORKFLOW>

<OPERATIONS>

## CREATE Operation

Creates new documentation from templates.

**Process:**
1. Validate inputs (doc_type, title, template_data)
2. Load template (custom → project → built-in)
3. Render template with Mustache
4. Inject codex-compatible front matter
5. Write file to configured output path
6. Validate generated document
7. Update index
8. Return file path and validation status

**Templates Supported:**
- `design.md.template` - System/feature design documents
- `runbook.md.template` - Operational procedures
- `api-spec.md.template` - API documentation
- `test-report.md.template` - Test execution results
- `deployment.md.template` - Deployment records
- `changelog.md.template` - Version change logs
- `troubleshooting.md.template` - Debug guides
- `postmortem.md.template` - Incident reviews

**Front Matter Injection:**
```yaml
---
title: "{title}"
type: "{doc_type}"
status: "{status}"
created: "{timestamp}"
updated: "{timestamp}"
author: "{author}"
tags: [{tags}]
work_id: "{work_id}"
generated: true
codex_sync: true
---
```

## UPDATE Operation

Updates existing documentation while preserving structure.

**Operation Types:**

### update-section
Updates specific section by heading match.
- Find section by heading
- Replace section content
- Preserve structure

### append-section
Adds new section to document.
- Find insertion point
- Add new section
- Maintain hierarchy

### update-metadata
Modifies front matter fields only.
- Parse front matter
- Update specified fields
- Update "updated" timestamp

### replace-content
Pattern-based content replacement.
- Search for pattern
- Replace matches
- Preserve formatting

**Process:**
1. Validate file exists
2. Create backup
3. Parse document structure
4. Apply update operation
5. Validate updated document
6. Update "updated" timestamp
7. Return diff and validation status

## LIST Operation

Lists documentation with optional filtering.

**Process:**
1. Load documentation index
2. Apply filters (doc_type, status, tags)
3. Sort by creation date (newest first)
4. Return structured list with metadata

**Output Format:**
```json
{
  "documents": [
    {
      "title": "Document title",
      "type": "design",
      "status": "published",
      "file_path": "docs/architecture/designs/auth-system.md",
      "created": "2025-01-15T10:30:00Z",
      "updated": "2025-01-20T14:45:00Z",
      "tags": ["auth", "security"],
      "work_id": "123"
    }
  ],
  "total_count": 42,
  "filtered_count": 5
}
```

## VALIDATE Operation

Validates documentation quality and compliance.

**Validation Checks:**

### frontmatter
- Required fields present (title, type, status, created)
- Valid status values
- Valid date formats
- Codex sync enabled

### structure
- Required sections present (type-specific)
- Proper heading hierarchy
- No missing sections

### links
- Internal links resolve
- External links accessible (HTTP 200)
- Anchor links exist

### markdown
- Valid markdown syntax
- Code blocks properly closed
- Lists properly formatted
- Tables valid

**Severity Levels:**
- **error**: Must be fixed (missing required section, invalid syntax)
- **warning**: Should be fixed (broken link, inconsistent formatting)
- **info**: Consider fixing (style suggestions, best practices)

**Output Format:**
```json
{
  "valid": false,
  "file_path": "docs/architecture/designs/auth-system.md",
  "checks_run": ["frontmatter", "structure", "links", "markdown"],
  "issues": [
    {
      "severity": "error",
      "check": "structure",
      "message": "Missing required section: Implementation",
      "line": null
    },
    {
      "severity": "warning",
      "check": "links",
      "message": "Broken link: ../api/auth.md",
      "line": 42
    }
  ],
  "issues_by_severity": {
    "error": 1,
    "warning": 1,
    "info": 0
  }
}
```

## REINDEX Operation

Rebuilds documentation index.

**Process:**
1. Scan configured documentation directories
2. Parse front matter from all documents
3. Build hierarchical index by type
4. Write index to docs/README.md
5. Return count of indexed documents

**Index Structure:**
```markdown
# Documentation Index

## Design Documents
- [Authentication System](architecture/designs/auth-system.md) - Published
- [Data Pipeline](architecture/designs/data-pipeline.md) - Draft

## Runbooks
- [Database Failover](operations/runbooks/db-failover.md) - Published
- [Deploy to Production](operations/runbooks/deploy-prod.md) - Published

...
```

</OPERATIONS>

<CONFIGURATION>
Configuration loaded from `.fractary/plugins/docs/config.json`:

```json
{
  "doc_types": {
    "designs": {
      "path": "docs/architecture/designs",
      "template": "design.md.template",
      "required_sections": ["Overview", "Architecture", "Implementation", "Testing"]
    },
    "runbooks": {
      "path": "docs/operations/runbooks",
      "template": "runbook.md.template",
      "required_sections": ["Purpose", "Prerequisites", "Steps", "Troubleshooting", "Rollback"]
    },
    "api_specs": {
      "path": "docs/api",
      "template": "api-spec.md.template",
      "required_sections": ["Overview", "Endpoints", "Authentication", "Examples"]
    },
    "test_reports": {
      "path": "docs/testing",
      "template": "test-report.md.template",
      "required_sections": ["Summary", "Test Cases", "Results", "Coverage"]
    },
    "deployments": {
      "path": "docs/deployments",
      "template": "deployment.md.template",
      "required_sections": ["Overview", "Infrastructure", "Deployment Steps", "Rollback"]
    },
    "changelogs": {
      "path": "docs/changelogs",
      "template": "changelog.md.template",
      "required_sections": ["Version", "Date", "Changes"]
    },
    "troubleshooting": {
      "path": "docs/troubleshooting",
      "template": "troubleshooting.md.template",
      "required_sections": ["Problem", "Symptoms", "Diagnosis", "Solution"]
    },
    "postmortems": {
      "path": "docs/postmortems",
      "template": "postmortem.md.template",
      "required_sections": ["Summary", "Timeline", "Root Cause", "Impact", "Action Items"]
    }
  },
  "templates": {
    "custom_template_dir": null,
    "use_project_templates": true
  },
  "validation": {
    "validate_after_create": true,
    "validate_after_update": true,
    "create_backup_before_update": true,
    "check_links_on_validate": false,
    "auto_fix": false
  },
  "index": {
    "path": "docs/README.md",
    "auto_update": true,
    "organize_by": "type"
  }
}
```

**Template Location Priority**:
1. Custom template directory (if configured): `{custom_template_dir}/{doc_type}.md.template`
2. Project templates: `.templates/docs/{doc_type}.md.template`
3. Built-in templates: `skills/docs-manage-generic/templates/{doc_type}.md.template`

</CONFIGURATION>

<DOCUMENTATION>
After successful operations, document the work performed:

**For create:**
```
✅ COMPLETED: Generic Documentation Management
Operation: create
Doc Type: {doc_type}
Title: {title}
File: {file_path}
Size: {size_bytes} bytes
Validation: {passed|failed}
───────────────────────────────────────
Next: Edit content, validate, or update index
```

**For update:**
```
✅ COMPLETED: Generic Documentation Management
Operation: update
Doc Type: {doc_type}
File: {file_path}
Update Type: {operation_type}
Backup: {backup_path}
Validation: {passed|failed}
───────────────────────────────────────
Next: Review changes, validate, or commit
```

**For validate:**
```
✅ COMPLETED: Generic Documentation Management
Operation: validate
Files Validated: {count}
Issues Found: {error_count} errors, {warning_count} warnings
───────────────────────────────────────
{if issues}
Issues by file:
- {file_path}: {error_count} errors, {warning_count} warnings
{endif}
Next: Fix issues or mark as reviewed
```

**For list:**
```
✅ COMPLETED: Generic Documentation Management
Operation: list
Total Documents: {total_count}
Filtered: {filtered_count}
───────────────────────────────────────
Documents listed by type and status
Next: Create new, update existing, or validate
```

**For reindex:**
```
✅ COMPLETED: Generic Documentation Management
Operation: reindex
Documents Indexed: {count}
Index File: docs/README.md
───────────────────────────────────────
Next: Review index or validate documentation
```
</DOCUMENTATION>

<ERROR_HANDLING>

**Missing required parameters:**
```
❌ Error: Missing required parameter: {parameter}
Operation: {operation}
Required: {list of required parameters}
```

**Invalid doc type:**
```
❌ Error: Unsupported doc type: {doc_type}
Supported: design, runbook, api-spec, test-report, deployment, changelog, troubleshooting, postmortem
```

**File not found:**
```
❌ Error: Document not found: {file_path}
Use list operation to see available documents
```

**Template not found:**
```
❌ Error: Template not found: {template_name}
Searched:
  1. Custom: {custom_path}
  2. Project: {project_path}
  3. Built-in: {builtin_path}
```

**Validation failed:**
```
❌ Error: Validation failed after {operation}
Issues: {error_count} errors, {warning_count} warnings
File: {file_path}
Fix issues or use --no-validate to skip
```

**Overwrite protection:**
```
❌ Error: File already exists: {file_path}
Use --overwrite flag to replace existing file
```

</ERROR_HANDLING>

<OUTPUTS>
All operations return structured JSON:

```json
{
  "success": true|false,
  "operation": "create|update|list|validate|reindex",
  "doc_type": "design|runbook|...",
  "result": {
    // Operation-specific results
  },
  "message": "Human-readable summary",
  "next_steps": ["Suggested actions"]
}
```
</OUTPUTS>
