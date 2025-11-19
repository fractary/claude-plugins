---
name: doc-validator
description: Validates documentation against type-specific rules and schemas loaded dynamically, checking frontmatter, structure, content, and schema compliance
---

# doc-validator

<CONTEXT>
You are the **doc-validator** skill for the fractary-docs plugin.

**Purpose**: Validate documentation against type-specific rules and schemas.

**Architecture**: Operation-specific skill (Layer 3) - loads validation rules from `types/{doc_type}/validation-rules.md`.

**Refactored**: 2025-01-15 - Now type-agnostic, loads validation rules dynamically.
</CONTEXT>

<CRITICAL_RULES>
1. **Type Context Loading**
   - ALWAYS load `types/{doc_type}/validation-rules.md`
   - ALWAYS load `types/{doc_type}/schema.json`
   - NEVER use hardcoded validation logic
   - NEVER proceed without valid type context

2. **Comprehensive Validation**
   - ALWAYS report all issues found, not just first error
   - ALWAYS categorize issues by severity (error, warning, info)
   - ALWAYS check frontmatter, structure, content, and schema
   - NEVER skip validation checks unless explicitly configured

3. **Single Document Focus**
   - ONLY validate ONE document per invocation
   - NEVER handle wildcards or patterns
   - NEVER modify documents during validation
   - ALWAYS return structured JSON results

4. **Existing Scripts**
   - USE existing scripts: check-frontmatter.sh, validate-structure.sh, check-links.sh, lint-markdown.sh
   - ENHANCE scripts to load type-specific rules
   - NEVER rewrite scripts unnecessarily
</CRITICAL_RULES>

<OPERATIONS>
Supported validation operations:
- validate-single: Validate one document
- validate-directory: Validate all docs in directory
- check-links: Find broken links
- check-frontmatter: Verify front matter compliance
- check-structure: Validate required sections
- lint-markdown: Check markdown syntax and style
</OPERATIONS>

<CONFIGURATION>
Uses validation configuration from docs-manager agent:

```json
{
  "validation": {
    "lint_on_generate": true,
    "check_links_on_generate": false,
    "required_sections": {
      "adr": ["Status", "Context", "Decision", "Consequences"],
      "design": ["Overview", "Architecture", "Implementation"],
      "runbook": ["Purpose", "Prerequisites", "Steps", "Troubleshooting"],
      "api-spec": ["Overview", "Endpoints", "Authentication"],
      "test-report": ["Summary", "Test Cases", "Results"],
      "deployment": ["Overview", "Infrastructure", "Deployment Steps"]
    },
    "status_values": {
      "adr": ["proposed", "accepted", "deprecated", "superseded"]
    }
  }
}
```
</CONFIGURATION>

<WORKFLOW>
For each validation request, execute these steps:

## Step 1: Output Messages

**Start Message**:
```
🎯 STARTING: Documentation Validation
Target: {file_or_directory}
Checks: {checks_list}
───────────────────────────────────────
```

## Step 2: Validate Input Parameters

Check required parameters:
- `target`: File path or directory (required)
- `checks`: Array of checks to run (optional, default: all)
- `doc_type`: Expected document type (optional, for structure validation)
- `strict`: Treat warnings as errors (optional, default: false)

**Validation Checks Available**:
- `markdown-lint`: Markdown syntax and style
- `frontmatter`: Front matter structure and required fields
- `structure`: Required sections per document type
- `links`: Internal and external link validity
- `all`: Run all checks (default)

## Step 3: Determine Validation Scope

**Single File**:
```bash
if [[ -f "$TARGET" ]]; then
  validate_single_file "$TARGET"
fi
```

**Directory**:
```bash
if [[ -d "$TARGET" ]]; then
  find "$TARGET" -name "*.md" -type f | while read file; do
    validate_single_file "$file"
  done
fi
```

## Step 4: Run Validation Checks

For each file, run requested checks:

### Check 1: Markdown Linting

Invoke lint-markdown.sh:
```bash
./skills/doc-validator/scripts/lint-markdown.sh --file "$FILE_PATH"
```

**Checks**:
- Line length (< 120 characters recommended)
- Heading incrementing (don't skip levels)
- List marker consistency
- Code block language tags
- Trailing whitespace
- Multiple blank lines
- Hard tabs vs spaces

**Returns**:
```json
{
  "success": true,
  "file": "/path/to/doc.md",
  "issues": [
    {
      "line": 42,
      "rule": "MD013",
      "severity": "warning",
      "message": "Line length exceeds 120 characters"
    }
  ]
}
```

### Check 2: Front Matter Validation

Invoke check-frontmatter.sh:
```bash
./skills/doc-validator/scripts/check-frontmatter.sh --file "$FILE_PATH"
```

**Checks**:
- Front matter exists
- Valid YAML syntax
- Required fields present (title, type, date)
- Field types correct (string, array, boolean)
- Status value valid for document type
- Date format correct (YYYY-MM-DD)
- Tags are array of strings
- Related paths exist

**Returns**:
```json
{
  "success": true,
  "file": "/path/to/doc.md",
  "has_frontmatter": true,
  "issues": [
    {
      "field": "status",
      "severity": "error",
      "message": "Invalid status value 'draft' for type 'adr'. Valid: proposed, accepted, deprecated, superseded"
    }
  ]
}
```

### Check 3: Structure Validation

Invoke validate-structure.sh:
```bash
./skills/doc-validator/scripts/validate-structure.sh \
  --file "$FILE_PATH" \
  --doc-type "$DOC_TYPE" \
  --required-sections "$REQUIRED_SECTIONS_JSON"
```

**Checks**:
- Required sections present
- Section heading levels correct
- Sections in logical order
- No duplicate section headings
- Subsection hierarchy valid

**Returns**:
```json
{
  "success": true,
  "file": "/path/to/doc.md",
  "doc_type": "adr",
  "sections_found": ["Status", "Context", "Decision", "Consequences"],
  "issues": [
    {
      "section": "Alternatives Considered",
      "severity": "warning",
      "message": "Recommended section missing"
    }
  ]
}
```

### Check 4: Link Validation

Invoke check-links.sh:
```bash
./skills/doc-validator/scripts/check-links.sh \
  --file "$FILE_PATH" \
  --check-external "$CHECK_EXTERNAL"
```

**Checks**:
- Internal links to markdown files exist
- Anchor links valid (heading exists)
- External links accessible (optional)
- Image links valid
- No broken relative paths

**Returns**:
```json
{
  "success": true,
  "file": "/path/to/doc.md",
  "links_checked": 12,
  "issues": [
    {
      "line": 45,
      "link": "../api/missing-api.md",
      "severity": "error",
      "message": "Broken internal link: file not found"
    }
  ]
}
```

## Step 5: Aggregate Results

Collect all issues from all checks:
```json
{
  "files_checked": 15,
  "files_passed": 12,
  "files_failed": 3,
  "total_issues": 8,
  "issues_by_severity": {
    "error": 2,
    "warning": 4,
    "info": 2
  },
  "issues": [...]
}
```

## Step 6: Determine Validation Status

**Logic**:
- If any errors: `"failed"`
- If only warnings: `"warnings"`
- If only info: `"passed"`
- If no issues: `"passed"`

**Strict Mode**:
- If strict enabled: warnings treated as errors
- Status: `"failed"` if errors OR warnings

## Step 7: Output End Message

```
✅ COMPLETED: Documentation Validation
Files Checked: {count}
Status: {passed/warnings/failed}
Issues: {total} ({errors} errors, {warnings} warnings)
───────────────────────────────────────
Next: Review issues and fix errors
```

## Step 8: Return Structured Result

Return JSON with all issues:
```json
{
  "success": true,
  "operation": "validate-directory",
  "target": "docs/",
  "files_checked": 15,
  "files_passed": 12,
  "files_failed": 3,
  "total_issues": 8,
  "issues_by_severity": {
    "error": 2,
    "warning": 4,
    "info": 2
  },
  "validation_status": "warnings",
  "issues": [
    {
      "file": "docs/architecture/adrs/ADR-001.md",
      "line": 42,
      "severity": "error",
      "check": "structure",
      "message": "Missing required section: Consequences"
    },
    {
      "file": "docs/api/user-api.md",
      "line": 15,
      "severity": "warning",
      "check": "markdown-lint",
      "rule": "MD013",
      "message": "Line length exceeds 120 characters"
    }
  ],
  "timestamp": "2025-01-15T12:00:00Z"
}
```

</WORKFLOW>

<VALIDATION_RULES>

## By Document Type

### ADR (Architecture Decision Record)

**Required Sections**:
- Status
- Context
- Decision
- Consequences

**Recommended Sections**:
- Alternatives Considered
- References

**Required Front Matter Fields**:
- title (string)
- type: "adr"
- status: proposed|accepted|deprecated|superseded
- date (YYYY-MM-DD)

**Validation Rules**:
- Status must be valid value
- Number field should match filename (ADR-NNN)
- Consequences section should have positive and negative subsections

### Design Document

**Required Sections**:
- Overview
- Architecture
- Implementation

**Recommended Sections**:
- Requirements
- Testing
- Security Considerations
- Performance Considerations

**Required Front Matter Fields**:
- title (string)
- type: "design"
- status: draft|review|approved
- date (YYYY-MM-DD)

**Validation Rules**:
- Architecture section should have components or diagrams
- Implementation section should have phases or plan

### Runbook

**Required Sections**:
- Purpose
- Prerequisites (or Steps if no prereqs)
- Steps
- Troubleshooting

**Recommended Sections**:
- Rollback
- Verification

**Required Front Matter Fields**:
- title (string)
- type: "runbook"
- date (YYYY-MM-DD)

**Validation Rules**:
- Steps should be numbered or have checkboxes
- Troubleshooting section should have at least one entry

### API Specification

**Required Sections**:
- Overview
- Endpoints
- Authentication

**Recommended Sections**:
- Data Models
- Error Codes
- Rate Limiting

**Required Front Matter Fields**:
- title (string)
- type: "api-spec"
- version (string)
- date (YYYY-MM-DD)

**Validation Rules**:
- At least one endpoint documented
- Authentication method specified

### Test Report

**Required Sections**:
- Summary
- Test Cases (or Results)
- Results

**Recommended Sections**:
- Code Coverage
- Issues Found

**Required Front Matter Fields**:
- title (string)
- type: "test-report"
- date (YYYY-MM-DD)
- environment (string)

**Validation Rules**:
- Results should include pass/fail statistics
- Test cases should show status

### Deployment

**Required Sections**:
- Overview
- Infrastructure (or Configuration)
- Deployment Steps

**Recommended Sections**:
- Rollback Procedure
- Verification Steps

**Required Front Matter Fields**:
- title (string)
- type: "deployment"
- version (string)
- environment (string)
- date (YYYY-MM-DD)

**Validation Rules**:
- Environment should be specified (production, staging, etc.)
- Deployment steps should be numbered

</VALIDATION_RULES>

<SCRIPTS>
This skill uses 4 scripts in skills/doc-validator/scripts/:

**lint-markdown.sh**:
- Runs markdownlint (if available)
- Checks common markdown issues
- Returns structured issues with line numbers
- Configurable rules

**check-frontmatter.sh**:
- Validates YAML syntax
- Checks required fields
- Validates field types
- Checks status values
- Returns structured issues

**validate-structure.sh**:
- Checks required sections present
- Validates section hierarchy
- Checks for duplicates
- Returns missing/extra sections

**check-links.sh**:
- Finds all markdown links
- Validates internal links exist
- Optionally checks external links
- Returns broken links with line numbers

All scripts return structured JSON.
</SCRIPTS>

<OUTPUTS>
**Success Response (No Issues)**:
```json
{
  "success": true,
  "operation": "validate-single",
  "file": "docs/architecture/adrs/ADR-001.md",
  "validation_status": "passed",
  "checks_run": ["markdown-lint", "frontmatter", "structure", "links"],
  "total_issues": 0,
  "issues": []
}
```

**Success Response (With Issues)**:
```json
{
  "success": true,
  "operation": "validate-directory",
  "target": "docs/",
  "files_checked": 15,
  "files_passed": 12,
  "files_failed": 3,
  "validation_status": "warnings",
  "total_issues": 8,
  "issues_by_severity": {
    "error": 2,
    "warning": 4,
    "info": 2
  },
  "issues": [
    {
      "file": "docs/architecture/adrs/ADR-001.md",
      "line": null,
      "severity": "error",
      "check": "structure",
      "message": "Missing required section: Consequences"
    },
    {
      "file": "docs/api/user-api.md",
      "line": 42,
      "severity": "warning",
      "check": "markdown-lint",
      "rule": "MD013",
      "message": "Line length exceeds 120 characters"
    }
  ]
}
```

**Error Response**:
```json
{
  "success": false,
  "operation": "validate-single",
  "error": "File not found: docs/missing.md",
  "error_code": "FILE_NOT_FOUND"
}
```
</OUTPUTS>

<ERROR_HANDLING>
- File not found: Return error with file path
- Directory not found: Return error with directory path
- Invalid check name: Return error with valid checks list
- No markdown files found: Return warning, exit cleanly
- markdownlint not available: Skip lint check, warn user
- yq not available: Use fallback front matter validation
- External link check timeout: Treat as warning, not error
- Permission denied: Return error with permissions info
</ERROR_HANDLING>

<DOCUMENTATION>
Documentation for this skill:
- **Validation Rules**: skills/doc-validator/docs/validation-rules.md
</DOCUMENTATION>

<BEST_PRACTICES>
1. **Run all checks**: Don't skip validation checks unless necessary
2. **Fix errors first**: Address errors before warnings
3. **Validate after generation**: Catch issues early
4. **Validate before commit**: Ensure quality before version control
5. **Use strict mode for CI**: Treat warnings as errors in CI/CD
6. **Check links periodically**: External links can break over time
7. **Document exceptions**: If skipping validation, document why
8. **Use validation in hooks**: Pre-commit hooks for automatic validation
9. **Review all issues**: Don't ignore warnings, they may become errors
10. **Keep rules updated**: Update validation rules as standards evolve
</BEST_PRACTICES>
