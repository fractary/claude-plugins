---
name: fractary-docs:validate
description: Validate documentation quality and compliance
---

# Validate Documentation

Validate documentation quality, check for required sections, lint markdown, verify links, and ensure front matter compliance.

<CONTEXT>
You are the validate command for the fractary-docs plugin. Your role is to parse arguments and immediately invoke the docs-manager agent to validate documentation using the doc-validator skill.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking agent
2. NEVER validate directly - always delegate to docs-manager agent
3. ALWAYS report all issues found, not just first error
4. ALWAYS invoke agent with structured parameters
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/fractary-docs:validate [file_or_directory] [options]
```

**Positional Arguments**:
- `file_or_directory`: File or directory to validate (default: docs/)

**Validation Check Flags** (specify which checks to run, default: all):
- `--markdown-lint`: Check markdown syntax and style
- `--frontmatter`: Validate front matter structure and fields
- `--structure`: Check required sections per doc type
- `--links`: Verify internal and external links
- `--all`: Run all validation checks (default)

**Optional Arguments**:
- `--doc-type <type>`: Expected document type (for structure validation)
- `--strict`: Treat warnings as errors
- `--fix`: Auto-fix issues where possible
- `--report <path>`: Save validation report to file
- `--exclude <pattern>`: Exclude files matching pattern
- `--verbose`: Show detailed validation output

Examples:
```bash
# Validate all documentation (default)
/fractary-docs:validate

# Validate specific file
/fractary-docs:validate docs/architecture/adrs/ADR-001.md

# Validate specific directory
/fractary-docs:validate docs/architecture/

# Validate with specific checks only
/fractary-docs:validate docs/ --markdown-lint --frontmatter

# Validate and fix issues
/fractary-docs:validate docs/api/ --fix

# Strict validation (warnings become errors)
/fractary-docs:validate docs/architecture/adrs/ --strict

# Validate with type specification
/fractary-docs:validate docs/architecture/adrs/ADR-001.md --doc-type adr

# Validate and save report
/fractary-docs:validate docs/ --report validation-report.txt

# Validate excluding patterns
/fractary-docs:validate docs/ --exclude "*.backup.*,*.draft.*"

# Verbose validation
/fractary-docs:validate docs/guides/ --verbose

# Check links only
/fractary-docs:validate docs/ --links

# Check structure only
/fractary-docs:validate docs/architecture/designs/ --structure
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `target`: File or directory to validate (default: "docs/")
- `checks`: Array of checks to run (default: ["all"])
- `doc_type`: Expected document type (optional)
- `strict`: Boolean (default: false)
- `fix`: Boolean (default: false)
- `report_path`: Path to save report (optional)
- `exclude`: Array of exclude patterns (optional)
- `verbose`: Boolean (default: false)

Validation:
- Verify target exists (file or directory)
- If doc_type specified, verify it's a valid type
- If report_path specified, verify directory exists and is writable
- Parse exclude patterns into array

## Step 2: Determine Validation Scope

If target is a file:
- Validate single file
- Detect doc type from front matter or --doc-type

If target is a directory:
- Scan for all .md files
- Apply exclude patterns
- Group by doc type based on front matter

## Step 3: Determine Checks to Run

Map flags to checks:
- `--markdown-lint` → markdown linting check
- `--frontmatter` → front matter validation
- `--structure` → required sections check
- `--links` → link validity check
- `--all` or no flags → all checks

## Step 4: Load Configuration

Load validation rules from configuration:
- required_sections per doc type
- status_values per doc type
- lint_on_generate setting
- check_links_on_generate setting

Use defaults if configuration not found.

## Step 5: Prepare Validation Parameters

Build parameters for validation:

**For single file**:
```json
{
  "operation": "validate-single",
  "file_path": "{file_path}",
  "doc_type": "{doc_type or auto-detect}",
  "checks": ["markdown-lint", "frontmatter", "structure", "links"],
  "strict": false,
  "fix": false,
  "validation_rules": {
    "required_sections": ["Status", "Context", "Decision"],
    "lint_config": {...},
    "check_external_links": false
  }
}
```

**For directory**:
```json
{
  "operation": "validate-directory",
  "directory": "{directory_path}",
  "checks": ["markdown-lint", "frontmatter", "structure", "links"],
  "strict": false,
  "fix": false,
  "exclude_patterns": ["*.backup.*", "*.draft.*"],
  "recursive": true,
  "validation_rules": {...}
}
```

## Step 6: Route to Appropriate Skill

**NEW ARCHITECTURE**: Route to type-specific skills when available, fallback to docs-manage-generic.

### For Single File Validation

Determine doc type from file path or front matter, then route accordingly:

**For API documentation** (`docs/api/`):
```
Skill(skill="docs-manage-api")

Use the docs-manage-api skill to validate API endpoint documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For ADR documentation** (`docs/architecture/adrs/`):
```
Skill(skill="docs-manage-architecture-adr")

Use the docs-manage-architecture-adr skill to validate ADR:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For architecture documentation** (`docs/architecture/`):
```
Skill(skill="docs-manage-architecture")

Use the docs-manage-architecture skill to validate architecture documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For guide documentation** (`docs/guides/`):
```
Skill(skill="docs-manage-guides")

Use the docs-manage-guides skill to validate guide documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For dataset documentation** (`docs/datasets/`):
```
Skill(skill="docs-manage-dataset")

Use the docs-manage-dataset skill to validate dataset documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For ETL/pipeline documentation** (`docs/etl/` or `docs/pipelines/`):
```
Skill(skill="docs-manage-etl")

Use the docs-manage-etl skill to validate ETL/pipeline documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For testing/QA documentation** (`docs/testing/`, `docs/tests/`, or `docs/qa/`):
```
Skill(skill="docs-manage-testing")

Use the docs-manage-testing skill to validate testing/QA documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For standards documentation** (`docs/standards/`):
```
Skill(skill="docs-manage-standards")

Use the docs-manage-standards skill to validate standards documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For audit documentation** (`docs/audits/`):
```
Skill(skill="docs-manage-audit")

Use the docs-manage-audit skill to validate audit documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For infrastructure documentation** (`docs/infrastructure/`):
```
Skill(skill="docs-manage-infrastructure")

Use the docs-manage-infrastructure skill to validate infrastructure documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}"
}
```

**For generic documentation** (design, runbook, etc.):
```
Skill(skill="docs-manage-generic")

Use the docs-manage-generic skill to validate documentation:
{
  "operation": "validate",
  "file_path": "{file_path}",
  "doc_type": "{doc_type}",
  "checks": ["frontmatter", "structure", "markdown", "links"],
  "strict": "{strict}",
  "fix": "{fix}",
  "verbose": "{verbose}",
  "report_path": "{report_path or null}"
}
```

### For Directory Validation

When validating a directory:
1. Scan for all .md files
2. Group files by doc type (based on path or front matter)
3. Route each group to appropriate skill
4. Aggregate results from all skills

**Why this routing?**
- ✅ Direct skill invocation (no agent hop) for efficiency
- ✅ Type-specific validation rules when available
- ✅ Fallback to generic for simple template-based docs
- ✅ Consistent with create/update operations

## Step 7: Process Results

Receive result from agent:
```json
{
  "success": true,
  "operation": "validate",
  "result": {
    "files_checked": 15,
    "files_passed": 12,
    "files_failed": 3,
    "total_issues": 8,
    "issues_by_severity": {
      "error": 2,
      "warning": 4,
      "info": 2
    },
    "issues": [
      {
        "file": "docs/architecture/adrs/ADR-001.md",
        "severity": "error",
        "check": "structure",
        "message": "Missing required section: Consequences",
        "line": null
      },
      {
        "file": "docs/api/user-api.md",
        "severity": "warning",
        "check": "markdown-lint",
        "message": "MD013: Line length should not exceed 80 characters",
        "line": 42
      }
    ],
    "fixed_issues": 2,
    "report_path": "validation-report.txt"
  }
}
```

## Step 8: Display Validation Summary

Show summary:
```
📋 Documentation Validation Report
───────────────────────────────────────────

Target: {target}
Files Checked: {files_checked}

Results:
  ✓ Passed: {files_passed}
  ✗ Failed: {files_failed}

Issues Found: {total_issues}
  • Errors: {error_count}
  • Warnings: {warning_count}
  • Info: {info_count}

{if fix enabled and fixes made}
Fixed: {fixed_issues} issues automatically
{endif}

───────────────────────────────────────────
```

## Step 9: Display Detailed Issues

Show each issue:
```
Issues:

[ERROR] docs/architecture/adrs/ADR-001.md
  Structure validation failed
  → Missing required section: Consequences
  Fix: Add ## Consequences section

[WARNING] docs/api/user-api.md:42
  Markdown lint (MD013)
  → Line length should not exceed 80 characters
  Fix: Break line into multiple lines

[WARNING] docs/guides/setup.md:15
  Broken link
  → Link target not found: ../api/legacy-api.md
  Fix: Update link or create missing file

[INFO] docs/runbooks/deploy.md
  Front matter suggestion
  → Consider adding 'tags' field for better organization
```

## Step 10: Display Validation Passed Message

If all checks passed:
```
✅ All documentation passed validation!

Files Checked: {files_checked}
Checks Run: {checks_list}
Target: {target}

Your documentation is:
  ✓ Syntactically correct
  ✓ Well-structured
  ✓ Links are valid
  ✓ Front matter is compliant

Great job maintaining quality documentation! 🎉
```

## Step 11: Display Error Summary (if failed)

If validation failed and strict mode:
```
❌ Documentation validation failed!

Files Failed: {files_failed}/{files_checked}
Total Issues: {total_issues} ({error_count} errors, {warning_count} warnings)

{if not strict}
Note: Run with --strict to treat warnings as errors
{endif}

{if fix available}
Auto-fix: Run with --fix to automatically fix {fixable_count} issues
{endif}

Next steps:
  • Review issues above
  • Fix manually or use --fix flag
  • Validate again: /fractary-docs:validate {target}
  {if report_path}
  • Full report: cat {report_path}
  {endif}

Common fixes:
  • Missing sections: Add required sections from template
  • Broken links: Update paths or create missing files
  • Lint issues: Run markdownlint --fix
  • Front matter: Add required fields (title, type, date)
```

## Step 12: Save Report (if requested)

If `--report` specified, save detailed report:
```
Documentation Validation Report
Generated: {timestamp}
Target: {target}
Checks: {checks_list}

Summary:
  Files Checked: {files_checked}
  Files Passed: {files_passed}
  Files Failed: {files_failed}
  Total Issues: {total_issues}

Issues by Severity:
  Errors: {error_count}
  Warnings: {warning_count}
  Info: {info_count}

Detailed Issues:

{for each issue}
[{severity}] {file}{if line}:{line}{endif}
  Check: {check_name}
  Message: {message}
  {if fix_suggestion}
  Suggested Fix: {fix_suggestion}
  {endif}

{end for}

{if fixes_applied}
Auto-Fixed Issues: {fixed_count}
{list fixed issues}
{endif}

End of Report
```

Inform user:
```
📄 Validation report saved: {report_path}
```

</WORKFLOW>

<ERROR_HANDLING>
- Target not found: Error with file/directory path
- Permission denied reading files: Show permissions fix
- Invalid doc_type specified: List valid types
- Report path not writable: Error with directory permissions
- Configuration not found: Use defaults, warn user
- Agent invocation failed: Show agent error with context
- No markdown files found in directory: Warn user, exit cleanly
- Exclude pattern invalid: Error with pattern syntax
</ERROR_HANDLING>

<OUTPUTS>
Success (all passed): Summary with files checked and validation passed message
Partial success: Summary with issues listed by severity, suggested fixes
Failure: Error message with troubleshooting guidance
Report file: Detailed validation report if --report specified
</OUTPUTS>
