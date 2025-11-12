# Validation Rules

This document defines the validation rules used by the fractary-docs doc-validator skill.

## Overview

The doc-validator skill performs 4 types of validation checks:

1. **Markdown Linting** - Syntax and style checks
2. **Front Matter Validation** - YAML metadata compliance
3. **Structure Validation** - Required sections per document type
4. **Link Checking** - Broken link detection

Each check returns issues with severity levels: **error**, **warning**, or **info**.

## Severity Levels

### Error
- **Impact**: Document is incomplete or non-compliant
- **Action**: Must be fixed before document is considered valid
- **Examples**:
  - Missing required front matter fields
  - Missing required sections
  - Broken internal links
  - Invalid document type

### Warning
- **Impact**: Document is valid but may have quality issues
- **Action**: Should be fixed to improve quality
- **Examples**:
  - Missing recommended fields
  - Invalid status values
  - Potentially broken external links
  - Missing recommended sections

### Info
- **Impact**: Suggestions for improvement
- **Action**: Optional fixes for better documentation
- **Examples**:
  - Missing optional fields
  - Code blocks without language tags
  - Deeply nested sections
  - Missing optional but helpful sections

## Validation Checks

### 1. Markdown Linting

**Script**: `lint-markdown.sh`

**Purpose**: Check markdown syntax and style

**Checks**:

| Check | Severity | Description |
|-------|----------|-------------|
| Line length | info | Lines exceeding 120 characters |
| Trailing whitespace | info | Lines with trailing spaces |
| Hard tabs | info | Using tabs instead of spaces |
| Code block language | info | Code blocks missing language identifier |
| markdownlint rules | varies | All markdownlint rules if CLI available |

**markdownlint Integration**:

If `markdownlint` CLI is installed, uses full rule set:
- MD### rules (e.g., MD001: Heading levels should increment)
- Configurable via `.markdownlint.json` in project root
- Falls back to basic checks if not available

**Example Issues**:
```json
{
  "line": 42,
  "rule": "MD022",
  "severity": "warning",
  "message": "Headings should be surrounded by blank lines"
}
```

### 2. Front Matter Validation

**Script**: `check-frontmatter.sh`

**Purpose**: Validate YAML front matter structure and required fields

**Required Fields**:

| Field | Type | Format | Description |
|-------|------|--------|-------------|
| title | string | Free-form | Document title |
| type | string | Enum | Document type (see valid types below) |
| date | string | YYYY-MM-DD | Creation date |

**Valid Document Types**:
- `adr` - Architecture Decision Record
- `design` - System/feature design
- `runbook` - Operational procedure
- `api-spec` - API documentation
- `schema` - Data schema / Data dictionary
- `test-report` - Test execution results
- `deployment` - Deployment record
- `changelog` - Version changes
- `architecture` - System architecture
- `troubleshooting` - Debug guide
- `postmortem` - Incident review

**Recommended Fields** (warnings in strict mode):

| Field | Type | Description |
|-------|------|-------------|
| status | string | Document lifecycle status |
| author | string | Document author |
| tags | array | Categorization tags |
| updated | string | Last update date |

**Status Values by Type**:

**For ADR**:
- `proposed` - Decision proposed
- `accepted` - Decision accepted
- `deprecated` - Decision outdated
- `superseded` - Replaced by another

**For Other Types**:
- `draft` - Initial draft
- `review` - Ready for review
- `approved` - Reviewed and approved
- `deprecated` - No longer current

**Type-Specific Fields**:

**ADR**:
- `number` (recommended) - ADR number

**API Spec**:
- `version` (recommended) - API version
- `base_url` (recommended) - API base URL

**Test Report**:
- `environment` (recommended) - Test environment

**Deployment**:
- `version` (recommended) - Version deployed
- `environment` (recommended) - Deployment target

**Example Issues**:
```json
{
  "severity": "error",
  "field": "type",
  "message": "Missing required field: type"
}
```

**Strict Mode**:

Use `--strict` flag to enable warnings for missing recommended fields:
```bash
./check-frontmatter.sh --file doc.md --strict
```

### 3. Structure Validation

**Script**: `validate-structure.sh`

**Purpose**: Check document has required sections based on type

**Required Sections by Type**:

#### ADR
| Section | Severity | Description |
|---------|----------|-------------|
| Status | error | Current status |
| Context | error | Problem context |
| Decision | error | The decision made |
| Consequences | error | Positive/negative outcomes |
| Alternatives | info | Options considered |

#### Design
| Section | Severity | Description |
|---------|----------|-------------|
| Overview | error | High-level summary |
| Architecture | error | System design |
| Requirements | info | Functional/non-functional requirements |
| Implementation | info | Implementation details |

#### Runbook
| Section | Severity | Description |
|---------|----------|-------------|
| Purpose | error | What this runbook does |
| Steps | error | Execution steps |
| Prerequisites | info | Required setup |
| Troubleshooting | info | Common issues |
| Rollback | warning | How to undo |

#### API Spec
| Section | Severity | Description |
|---------|----------|-------------|
| Overview | error | API description |
| Authentication | error | Auth mechanism |
| Endpoints | error | API endpoints |
| Models | info | Data models |
| Errors | info | Error responses |

#### Schema
| Section | Severity | Description |
|---------|----------|-------------|
| Overview | error | Schema purpose and scope |
| Schema Format | error | Format specification (JSON Schema, OpenAPI, etc.) |
| Fields | error | Field definitions with types and constraints |
| Examples | error | Usage examples |
| Validation Rules | error | Data validation requirements |
| Entities | info | Entity/model definitions |
| Relationships | info | Entity relationships |
| Constraints | info | Schema-level constraints |
| Versioning | info | Schema versioning strategy |

**Schema-Specific Validation**:
- **Format consistency**: All schema definitions use declared format consistently
- **Field completeness**: Each field has type, description, and constraints documented
- **Example validity**: Examples conform to schema rules
- **Reference integrity**: All entity references point to documented entities

**Project-Specific Extensions**:
Projects can extend schema validation via `custom_rules_script`:
- Validate naming conventions (e.g., snake_case, camelCase)
- Enforce required field annotations
- Check schema format-specific rules (JSON Schema draft compliance, OpenAPI spec version)
- Verify code generation compatibility
- Validate business rule documentation

#### Test Report
| Section | Severity | Description |
|---------|----------|-------------|
| Summary | error | Test overview |
| Results | error | Test results |
| Test Cases | info | Individual tests |
| Coverage | info | Code coverage |
| Issues | warning | Problems found |

#### Deployment
| Section | Severity | Description |
|---------|----------|-------------|
| Overview | error | Deployment summary |
| Deployment Steps | error | How to deploy |
| Infrastructure | info | Infrastructure setup |
| Configuration | info | Config changes |
| Verification | warning | How to verify |
| Rollback | warning | How to rollback |

#### Changelog
- Flexible structure
- Should have version sections (e.g., `## [1.0.0]`)
- Warning if no version headings found

#### Architecture
| Section | Severity | Description |
|---------|----------|-------------|
| Overview | error | System overview |
| Components | error | System components |
| Data Flow | info | How data moves |
| Technology Stack | info | Technologies used |
| Deployment | info | Deployment architecture |

#### Troubleshooting
| Section | Severity | Description |
|---------|----------|-------------|
| Problem | error | Problem description |
| Diagnosis | error | How to diagnose |
| Solution | error | How to fix |
| Prevention | info | How to prevent |

#### Postmortem
| Section | Severity | Description |
|---------|----------|-------------|
| Incident Summary | error | What happened |
| Timeline | error | Event timeline |
| Root Cause | error | Why it happened |
| Action Items | error | What to do |
| Impact | info | Impact analysis |
| Lessons Learned | info | What we learned |

**Additional Structural Checks**:

| Check | Severity | Description |
|-------|----------|-------------|
| Empty document | error | No sections found |
| Too short | warning | Less than 100 bytes |
| Deeply nested | info | Sections nested >4 levels |
| Code blocks | info | Missing language identifiers |

**Example Issues**:
```json
{
  "severity": "error",
  "section": "Context",
  "message": "Missing required section: Context"
}
```

### 4. Link Checking

**Script**: `check-links.sh`

**Purpose**: Find broken internal and external links

**Link Types Checked**:

1. **Inline links**: `[text](url)`
2. **Reference links**: `[text][ref]` with `[ref]: url`
3. **Internal links**: Relative paths to local files
4. **External links**: HTTP/HTTPS URLs (optional)

**Internal Link Checks**:
- Resolves relative paths from document directory
- Checks file existence
- Handles anchors (`#section`)
- Reports broken links as errors

**External Link Checks**:
- Disabled by default (use `--check-external`)
- Uses HTTP HEAD request via curl
- Configurable timeout (default: 5 seconds)
- Reports failures as warnings (not errors)

**Ignored Links**:
- Links in code blocks
- `mailto:` links
- Anchor-only links (`#section`)

**Example Usage**:
```bash
# Check internal links only (default)
./check-links.sh --file doc.md

# Check both internal and external links
./check-links.sh --file doc.md --check-external

# Custom timeout for external checks
./check-links.sh --file doc.md --check-external --timeout 10
```

**Example Issues**:
```json
{
  "severity": "error",
  "line": 42,
  "link": "../missing.md",
  "message": "Broken internal link: file not found"
}
```

## Validation Modes

### Single Document Validation

Validate one document with all checks:
```bash
/fractary-docs:validate path/to/doc.md
```

**Performs**:
1. Markdown linting
2. Front matter validation (auto-detects type)
3. Structure validation (based on type)
4. Internal link checking

### Directory Validation

Validate all documents in directory:
```bash
/fractary-docs:validate path/to/docs/
```

**Performs**:
- Recursively finds all `.md` files
- Validates each document
- Aggregates results
- Reports summary statistics

### Strict Mode

Enable additional warnings:
```bash
/fractary-docs:validate doc.md --strict
```

**Adds warnings for**:
- Missing recommended front matter fields
- Missing optional but helpful sections
- More detailed structural checks

### External Link Checking

Check external links (slower):
```bash
/fractary-docs:validate doc.md --check-external
```

**Note**: External checks can be slow and may have false positives due to rate limiting, timeouts, or firewalls.

## Configuration

Validation behavior is configured in `config/config.json`:

```json
{
  "validation": {
    "enabled": true,
    "strict_mode": false,
    "check_external_links": false,
    "external_link_timeout": 5,
    "ignore_patterns": [
      "**/*.draft.md",
      "**/*.backup.*"
    ],
    "required_frontmatter_fields": ["title", "type", "date"],
    "markdownlint_config": ".markdownlint.json"
  }
}
```

### Configuration Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| enabled | boolean | true | Enable validation |
| strict_mode | boolean | false | Warn on missing recommended fields |
| check_external_links | boolean | false | Check external URLs |
| external_link_timeout | number | 5 | Timeout for external checks (seconds) |
| ignore_patterns | array | [] | Glob patterns to skip |
| required_frontmatter_fields | array | [...] | Required front matter fields |
| markdownlint_config | string | null | Path to markdownlint config |

## Exit Codes

Validation scripts use standard exit codes:

- **0**: Success, validation completed
- **1**: Error, validation failed or file not found

**Note**: Exit code 0 doesn't mean no issues found. Check JSON output for issue counts.

## Response Format

All validation scripts return structured JSON:

```json
{
  "success": true,
  "file": "/path/to/doc.md",
  "check": "frontmatter",
  "total_issues": 2,
  "errors": 1,
  "warnings": 1,
  "info": 0,
  "issues": [
    {
      "severity": "error",
      "field": "type",
      "message": "Missing required field: type"
    },
    {
      "severity": "warning",
      "field": "status",
      "message": "Missing recommended field: status"
    }
  ]
}
```

## Best Practices

### 1. Validate Before Commit
Always validate documents before committing:
```bash
/fractary-docs:validate docs/ && git commit -m "Update docs"
```

### 2. Use Strict Mode in CI
Enable strict mode in CI pipelines for higher quality:
```bash
/fractary-docs:validate docs/ --strict
```

### 3. Fix Errors First
Address errors before warnings:
1. Fix all errors (missing required fields/sections)
2. Fix warnings (quality improvements)
3. Address info items (optional enhancements)

### 4. Check Links Regularly
Run link checking periodically (not on every commit):
```bash
# Weekly link check
/fractary-docs:validate docs/ --check-external
```

### 5. Ignore Draft Documents
Use ignore patterns for work-in-progress:
```json
{
  "ignore_patterns": ["**/*.draft.md", "**/WIP-*.md"]
}
```

### 6. Use markdownlint
Install markdownlint for comprehensive syntax checking:
```bash
npm install -g markdownlint-cli
```

### 7. Configure markdownlint
Create `.markdownlint.json` to customize rules:
```json
{
  "MD013": false,
  "MD033": {"allowed_elements": ["details", "summary"]}
}
```

## Common Validation Issues

### Issue: "Missing required field: type"
**Cause**: Front matter missing `type` field

**Fix**:
```yaml
---
title: "My Document"
type: design
date: "2025-01-15"
---
```

### Issue: "Invalid document type"
**Cause**: Type field has invalid value

**Fix**: Use one of: adr, design, runbook, api-spec, test-report, deployment, changelog, architecture, troubleshooting, postmortem

### Issue: "Missing required section: Context"
**Cause**: ADR missing Context section

**Fix**: Add required section:
```markdown
## Context

[Describe the problem context...]
```

### Issue: "Broken internal link: file not found"
**Cause**: Link points to non-existent file

**Fix**:
- Verify file path is correct
- Use relative paths from document directory
- Check file actually exists: `ls path/to/file.md`

### Issue: "Undefined reference link: [ref]"
**Cause**: Reference-style link used but not defined

**Fix**: Add reference definition:
```markdown
[ref]: https://example.com
```

## Troubleshooting

### Validation Hangs on External Links
**Problem**: `--check-external` takes too long

**Solution**: Increase timeout or disable external checking:
```bash
/fractary-docs:validate doc.md --timeout 30
# or
/fractary-docs:validate doc.md  # skip external
```

### markdownlint Not Found
**Problem**: Linting falls back to basic checks

**Solution**: Install markdownlint:
```bash
npm install -g markdownlint-cli
```

### False Positive on External Link
**Problem**: Valid URL reported as broken

**Causes**:
- Rate limiting by server
- Firewall blocking requests
- Temporary server issue

**Solution**: Verify manually or skip external checks

### Section Not Found But Exists
**Problem**: Structure validator reports missing section that exists

**Cause**: Case-sensitive heading match (fixed in v1.0, but verify)

**Solution**: Check heading spelling and capitalization match exactly

## Reference

- **Validation Scripts**: `skills/doc-validator/scripts/`
- **Front Matter Schema**: `skills/doc-generator/docs/frontmatter-schema.md`
- **Template Guide**: `skills/doc-generator/docs/template-guide.md`
- **markdownlint Rules**: https://github.com/DavidAnson/markdownlint/blob/main/doc/Rules.md
