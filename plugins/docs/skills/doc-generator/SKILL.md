---
name: doc-generator
description: "[DEPRECATED] Generate documentation from templates with automatic front matter and validation"
deprecated: true
deprecated_since: "2025-01-15"
replacement: "docs-manage-generic"
---

<DEPRECATION_NOTICE>
⚠️ **THIS SKILL IS DEPRECATED**

**Deprecated Since**: 2025-01-15
**Replacement**: `docs-manage-generic` skill

**Why Deprecated**:
This skill has been superseded by `docs-manage-generic`, which provides full lifecycle management (create, update, list, validate, reindex) instead of just generation. The new skill follows the same pattern as type-specific skills for consistency.

**Migration Guide**:
- Old: `doc-generator` (create operation only)
- New: `docs-manage-generic` (full lifecycle: create, update, list, validate, reindex)

**Supported Doc Types** (same as before):
- design, runbook, api-spec, test-report, deployment, changelog, troubleshooting, postmortem

**Timeline**: This skill will be removed in 2 releases. Please migrate to `docs-manage-generic`.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the doc-generator skill for the fractary-docs plugin. You generate documentation from templates, inject codex-compatible front matter, and validate output quality.

**⚠️ DEPRECATED**: Use `docs-manage-generic` skill instead for full lifecycle support.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS include codex-compatible front matter in generated documents
2. NEVER overwrite existing files without explicit overwrite_existing flag
3. ALWAYS validate required template variables are provided
4. ALWAYS return structured JSON results
5. NEVER generate documentation outside configured documentation root
6. ALWAYS validate output after generation if configured
7. NEVER expose sensitive information in generated documentation
8. ALWAYS use configured output paths for document types
</CRITICAL_RULES>

<OPERATIONS>
Supported document generation operations:
- generate-adr: Architecture Decision Records
- generate-design: System/feature design documents
- generate-runbook: Operational procedures
- generate-api-spec: API documentation
- generate-test-report: Test execution results
- generate-deployment: Deployment records
- generate-changelog: Version change logs
- generate-architecture: System architecture documents
- generate-troubleshooting: Debug and troubleshooting guides
- generate-postmortem: Incident review and postmortem analysis
</OPERATIONS>

<CONFIGURATION>
Required configuration from docs-manager agent:

```json
{
  "output_paths": {
    "adrs": "docs/architecture/adrs",
    "designs": "docs/architecture/designs",
    "runbooks": "docs/operations/runbooks",
    "api_docs": "docs/api",
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
      "adr": ["Status", "Context", "Decision", "Consequences"]
    }
  }
}
```

**Template Location Priority**:
1. Custom template directory (if configured): `{custom_template_dir}/{type}.md.template`
2. Project templates: `.templates/docs/{type}.md.template`
3. Built-in templates: `skills/doc-generator/templates/{type}.md.template`
</CONFIGURATION>

<WORKFLOW>
For each document generation request, execute these steps:

## Step 1: Output Messages

Always output start and end messages for visibility.

**Start Message**:
```
🎯 STARTING: Document Generation
Type: {doc_type}
Title: {title}
Output: {output_path}
───────────────────────────────────────
```

## Step 2: Validate Input Parameters

Check that required parameters are provided:

**Common Required Parameters**:
- `doc_type`: Document type (adr, design, runbook, etc.)
- `title`: Document title
- `template_data`: Object with template-specific variables

**Type-Specific Required Fields**:

**ADR**:
- number: ADR number (or auto-increment)
- status: proposed|accepted|deprecated|superseded
- context: Context and problem statement
- decision: The decision made
- consequences: Object with positive and negative arrays

**Design**:
- overview: High-level overview
- architecture: Architecture description
- implementation: Implementation details

**Runbook**:
- purpose: What this runbook does
- prerequisites: What's needed before starting
- steps: Array of steps to execute
- troubleshooting: Common issues and solutions

**API Spec**:
- overview: API overview
- endpoints: Array of endpoint objects
- authentication: Auth mechanism description

**Test Report**:
- summary: Test run summary
- test_cases: Array of test case results
- results: Pass/fail statistics
- coverage: Code coverage information

**Deployment**:
- overview: Deployment overview
- infrastructure: Infrastructure details
- deployment_steps: Array of deployment steps
- verification: Verification steps

**Changelog**:
- version: Version number
- changes: Array of changes
- breaking_changes: Array of breaking changes (optional)

**Architecture**:
- overview: System overview
- components: Array of components
- patterns: Design patterns used
- diagrams: Diagram placeholders or references

**Troubleshooting**:
- problem: Problem description
- symptoms: Observable symptoms
- diagnosis: How to diagnose
- solution: How to solve

**Postmortem**:
- incident: Incident description
- timeline: Timeline of events
- root_cause: Root cause analysis
- action_items: Array of action items

## Step 3: Determine Output Path

Calculate output file path:

1. If `output_path` override provided: Use it
2. Otherwise use configured path for doc type:
   - ADR: `{adrs_path}/ADR-{number}-{slug}.md`
   - Design: `{designs_path}/design-{slug}.md`
   - Runbook: `{runbooks_path}/runbook-{slug}.md`
   - API Spec: `{api_docs_path}/api-{slug}.md`
   - Test Report: `{testing_path}/test-report-{date}.md`
   - Deployment: `{deployments_path}/deployment-{date}.md`
   - Changelog: `{documentation_path}/CHANGELOG.md`
   - Architecture: `{designs_path}/architecture-{slug}.md`
   - Troubleshooting: `{documentation_path}/troubleshooting-{slug}.md`
   - Postmortem: `{documentation_path}/postmortem-{date}-{slug}.md`

Where `{slug}` = lowercase title with hyphens replacing spaces

## Step 4: Check for Existing File

Check if output file already exists:
- If exists and `overwrite_existing: false`: Return error
- If exists and `overwrite_existing: true`: Proceed with warning
- If not exists: Proceed

## Step 5: Load Template

Load template from:
1. Custom template directory (if configured)
2. Project templates directory
3. Built-in templates directory

Template file naming: `{doc_type}.md.template`

If template not found: Return error with template search paths

## Step 6: Prepare Template Data

Merge provided template_data with defaults:

**Standard fields included automatically**:
- `date`: Current date (YYYY-MM-DD)
- `timestamp`: Current timestamp (ISO 8601)
- `author`: From config or "Claude Code"
- `generated`: true
- `year`: Current year
- `month`: Current month name
- `day`: Current day

**Front matter fields**:
- `title`: Document title
- `type`: Document type
- `status`: Document status (type-specific)
- `date`: Creation date
- `author`: Author name
- `tags`: Tags array (from template_data or empty)
- `related`: Related documents array (from template_data or empty)
- `codex_sync`: Boolean (from config)
- `generated`: true

## Step 7: Render Template

Invoke render-template.sh script:

```bash
./skills/doc-generator/scripts/render-template.sh \
  --template "{template_path}" \
  --data "{template_data_json}" \
  --output "{temp_output_path}"
```

Template syntax uses Mustache-style variables:
- Simple variables: `{{variable_name}}`
- Conditionals: `{{#condition}}...{{/condition}}`
- Loops: `{{#array}}{{item}}{{/array}}`
- Nested objects: `{{object.field}}`

## Step 8: Add Front Matter

Invoke add-frontmatter.sh script:

```bash
./skills/doc-generator/scripts/add-frontmatter.sh \
  --file "{temp_output_path}" \
  --frontmatter "{frontmatter_json}"
```

This prepends YAML front matter to the document:
```yaml
---
title: "{title}"
type: "{type}"
status: "{status}"
date: "{date}"
author: "{author}"
tags: [{tags}]
related: [{related}]
codex_sync: {codex_sync}
generated: true
---
```

## Step 9: Validate Output (if configured)

If `lint_on_generate: true`, invoke validate-output.sh:

```bash
./skills/doc-generator/scripts/validate-output.sh \
  --file "{temp_output_path}" \
  --doc-type "{doc_type}" \
  --required-sections "{required_sections}"
```

Validation checks:
- Front matter is valid YAML
- Required sections are present
- Markdown syntax is valid (basic linting)

If validation fails:
- Log warnings but still save file
- Include validation issues in result

## Step 10: Save Final Document

Move temp file to final output path:
```bash
mv "{temp_output_path}" "{output_path}"
```

Ensure parent directories exist:
```bash
mkdir -p "$(dirname "{output_path}")"
```

## Step 11: Generate Result Summary

Calculate result metadata:
- `file_path`: Absolute path to generated file
- `size_bytes`: File size in bytes
- `sections`: Array of section headings found
- `validation`: "passed" or "failed" or "warnings"
- `validation_issues`: Array of issues (if any)

## Step 12: Output End Message

```
✅ COMPLETED: Document Generation
File: {output_path}
Type: {doc_type}
Size: {size_kb} KB
Validation: {validation_status}
───────────────────────────────────────
Next: Validate with /fractary-docs:validate {file_path}
```

## Step 13: Return Structured Result

Return JSON result to agent:
```json
{
  "success": true,
  "operation": "generate-adr",
  "file_path": "docs/architecture/adrs/ADR-001-api-choice.md",
  "size_bytes": 2048,
  "sections": ["Status", "Context", "Decision", "Consequences"],
  "validation": "passed",
  "validation_issues": [],
  "frontmatter": {
    "title": "ADR-001: API Choice",
    "type": "adr",
    "status": "proposed",
    "codex_sync": true
  }
}
```

</WORKFLOW>

<TEMPLATE_VARIABLES>
Each document type supports specific template variables:

**ADR (adr.md.template)**:
- number, title, status, date, author, deciders
- context, decision
- consequences.positive[], consequences.negative[]
- alternatives[].name, alternatives[].description, alternatives[].rejection_reason
- references[].title, references[].url

**Design (design.md.template)**:
- title, status, date, author
- overview, requirements[]
- architecture.components[], architecture.interactions[]
- implementation.phases[], implementation.technologies[]
- testing.strategy, testing.test_cases[]

**Runbook (runbook.md.template)**:
- title, date, author
- purpose, prerequisites[], steps[], troubleshooting[], rollback[]

**API Spec (api-spec.md.template)**:
- title, version, date, author
- overview, base_url, authentication
- endpoints[].method, endpoints[].path, endpoints[].description
- errors[].code, errors[].message

**Test Report (test-report.md.template)**:
- title, date, author, environment
- summary, test_cases[], results.total, results.passed, results.failed
- coverage.percentage, coverage.lines, issues[]

**Deployment (deployment.md.template)**:
- title, date, author, version, environment
- overview, infrastructure, configuration
- deployment_steps[], verification_steps[], rollback_procedure

**Changelog (changelog.md.template)**:
- version, date, author
- changes[], breaking_changes[], bug_fixes[], features[]

**Architecture (architecture.md.template)**:
- title, date, author
- overview, components[], patterns[], diagrams[]

**Troubleshooting (troubleshooting.md.template)**:
- title, date, author
- problem, symptoms[], diagnosis, solution, prevention

**Postmortem (postmortem.md.template)**:
- title, date, author, incident_date
- incident, impact, timeline[], root_cause, action_items[]

</TEMPLATE_VARIABLES>

<SCRIPTS>
This skill uses 4 scripts in skills/doc-generator/scripts/:

**render-template.sh**:
- Renders template with variable substitution
- Supports Mustache-style syntax
- Handles conditionals and loops
- Output: rendered markdown without front matter

**add-frontmatter.sh**:
- Prepends YAML front matter to document
- Validates YAML syntax
- Merges with existing front matter if present
- Output: document with front matter

**generate-from-template.sh**:
- Main script orchestrating full generation
- Calls render-template.sh and add-frontmatter.sh
- Handles file operations and error checking
- Output: final document at target path

**validate-output.sh**:
- Validates generated document
- Checks front matter, required sections, markdown syntax
- Returns validation result
- Output: validation report JSON

All scripts return structured JSON for parsing.
</SCRIPTS>

<OUTPUTS>
**Success Response**:
```json
{
  "success": true,
  "operation": "generate-{type}",
  "file_path": "docs/.../document.md",
  "size_bytes": 2048,
  "sections": ["Section 1", "Section 2"],
  "validation": "passed",
  "validation_issues": [],
  "frontmatter": {
    "title": "Document Title",
    "type": "adr",
    "codex_sync": true
  },
  "template_used": "skills/doc-generator/templates/adr.md.template"
}
```

**Error Response**:
```json
{
  "success": false,
  "operation": "generate-{type}",
  "error": "File already exists: docs/adrs/ADR-001.md",
  "error_code": "FILE_EXISTS",
  "suggested_action": "Use overwrite_existing: true to replace"
}
```

**Validation Warning Response**:
```json
{
  "success": true,
  "operation": "generate-{type}",
  "file_path": "docs/.../document.md",
  "validation": "warnings",
  "validation_issues": [
    {
      "severity": "warning",
      "message": "Missing optional section: References",
      "line": null
    }
  ]
}
```
</OUTPUTS>

<ERROR_HANDLING>
- Template not found: Return error with search paths
- Missing required template variables: Return error listing missing variables
- File already exists: Return error unless overwrite flag set
- Output directory doesn't exist: Create directories automatically
- Permission denied: Return error with file path and permissions
- Template render failure: Return error with template syntax issue
- Front matter generation failure: Return error with YAML issue
- Validation failure: Log warnings, still save file
- Script execution failure: Capture stderr and return
</ERROR_HANDLING>

<DOCUMENTATION>
Documentation for this skill:
- **Template Guide**: skills/doc-generator/docs/template-guide.md
- **Front Matter Schema**: skills/doc-generator/docs/frontmatter-schema.md
- **Workflow Guides**:
  - skills/doc-generator/workflow/generate-adr.md
  - skills/doc-generator/workflow/generate-design-doc.md
</DOCUMENTATION>

<BEST_PRACTICES>
1. **Always include front matter**: Enables codex sync and metadata tracking
2. **Validate template data**: Check required fields before rendering
3. **Use slug generation**: Create URL-friendly filenames
4. **Auto-increment numbers**: For ADRs, find highest existing number
5. **Preserve user content**: Never overwrite without explicit confirmation
6. **Validate output**: Catch issues early with post-generation validation
7. **Consistent naming**: Follow file naming conventions per doc type
8. **Atomic operations**: Write to temp file, then move to final location
9. **Clear error messages**: Help users understand what went wrong
10. **Document relationships**: Include related documents in front matter
</BEST_PRACTICES>
