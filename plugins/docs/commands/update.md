---
name: fractary-docs:update
description: Update existing documentation while preserving structure
---

# Update Documentation

Update existing documentation while preserving structure, formatting, and non-targeted content.

<CONTEXT>
You are the update command for the fractary-docs plugin. Your role is to parse arguments and immediately invoke the docs-manager agent to update existing documentation using the doc-updater skill.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking agent
2. NEVER update documentation directly - always delegate to docs-manager agent
3. ALWAYS preserve document structure and formatting
4. ALWAYS invoke agent with structured parameters
5. NEVER update without validating file exists first
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/fractary-docs:update <file_path> [operation] [options]
```

**Positional Arguments**:
- `file_path`: Path to documentation file to update (required)

**Operation Flags** (choose one, required):
- `--section <heading>`: Update specific section by heading
- `--append-section <heading>`: Add new section to document
- `--metadata <field>`: Update front matter field only
- `--replace <pattern>`: Pattern-based content replacement
- `--status <status>`: Shortcut to update status field

**Content Argument** (required for most operations):
- `--content <text>`: New content (use quotes for multi-word)
- `--content-file <path>`: Read content from file

**Optional Arguments**:
- `--after <heading>`: Place new section after this heading (for append-section)
- `--validate`: Validate after update (default: true)
- `--commit`: Create git commit after update
- `--backup`: Create backup before updating (default: true)

Examples:
```bash
# Update specific section
/fractary-docs:update docs/architecture/adrs/ADR-001.md --section "Status" --content "Accepted"

# Update section with multi-line content
/fractary-docs:update docs/api/user-api.md --section "Authentication" --content "Uses OAuth 2.0 with JWT tokens.

Token lifetime: 1 hour
Refresh token lifetime: 30 days"

# Update section from file
/fractary-docs:update docs/guides/setup.md --section "Prerequisites" --content-file requirements.txt

# Append new section
/fractary-docs:update docs/architecture/designs/auth.md --append-section "Performance Considerations" --content "Expected to handle 1000 req/s" --after "Implementation"

# Update front matter status (shortcut)
/fractary-docs:update docs/architecture/adrs/ADR-002.md --status approved

# Update front matter field
/fractary-docs:update docs/runbooks/deployment.md --metadata "updated" --content "2025-01-15"

# Replace content pattern
/fractary-docs:update docs/api/v1-api.md --replace "version: 1.0" --content "version: 1.1"

# Update with commit
/fractary-docs:update docs/guides/quickstart.md --section "Installation" --content "Updated steps..." --commit

# Update without validation
/fractary-docs:update docs/changelog.md --append-section "Version 2.1.0" --content "Bug fixes and improvements" --no-validate

# Update without backup
/fractary-docs:update docs/temp.md --section "Notes" --content "New notes" --no-backup
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `file_path`: Path to document (required)
- `operation`: One of: update-section, append-section, update-metadata, replace-content (determined from flags)
- `section_heading`: Section to update (for section operations)
- `content`: New content (required for most operations)
- `content_file`: Path to file with content (alternative to --content)
- `after_heading`: Reference heading for placement (for append-section)
- `validate`: Boolean (default: true)
- `commit`: Boolean (default: false)
- `backup`: Boolean (default: true)

Validation:
- Verify exactly one operation flag is specified
- Verify `file_path` is provided
- Verify `content` or `content_file` is provided (except for --status shortcut)
- If `--content-file`, verify file exists and is readable
- If `--after`, verify `--append-section` is also specified

## Step 2: Determine Operation Type

Map flags to operation:
- `--section` → update-section
- `--append-section` → append-section
- `--metadata` or `--status` → update-metadata
- `--replace` → replace-content

For `--status` shortcut:
- Operation: update-metadata
- Field: "status"
- Content: provided status value

## Step 3: Verify File Exists

Check if target file exists:
- If not found: Error with file path
- If found: Proceed

Check if file is in documentation directory:
- If outside docs root: Warn user, ask for confirmation

## Step 4: Load Content

If `--content-file` specified:
- Read content from file
- Handle file read errors gracefully

If `--content` specified:
- Use content directly
- Preserve newlines and formatting

## Step 5: Create Backup (if enabled)

If `--backup` is true (default):
- Create backup: `{file_path}.backup-{timestamp}`
- Inform user of backup location

## Step 6: Prepare Update Parameters

Build parameters based on operation:

**For update-section**:
```json
{
  "operation": "update-section",
  "file_path": "{file_path}",
  "section_heading": "{section_heading}",
  "new_content": "{content}",
  "preserve_formatting": true
}
```

**For append-section**:
```json
{
  "operation": "append-section",
  "file_path": "{file_path}",
  "section_heading": "{new_section_heading}",
  "content": "{content}",
  "after_heading": "{after_heading or null}",
  "heading_level": 2
}
```

**For update-metadata**:
```json
{
  "operation": "update-metadata",
  "file_path": "{file_path}",
  "field": "{field_name}",
  "value": "{content}",
  "auto_update_timestamp": true
}
```

**For replace-content**:
```json
{
  "operation": "replace-content",
  "file_path": "{file_path}",
  "pattern": "{pattern}",
  "replacement": "{content}",
  "regex": false
}
```

## Step 7: Invoke docs-manager Agent

Use the @agent-fractary-docs:docs-manager agent to update documentation:
```json
{
  "operation": "update",
  "parameters": {
    ... operation-specific parameters ...
  },
  "options": {
    "validate_after": "{validate}",
    "commit_after": "{commit}",
    "backup_created": "{backup_path or null}"
  }
}
```

## Step 8: Process Results

Receive result from agent:
```json
{
  "success": true,
  "operation": "update",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-001.md",
    "operation_type": "update-section",
    "section_updated": "Status",
    "lines_changed": 3,
    "validation": "passed",
    "backup_path": "docs/architecture/adrs/ADR-001.md.backup-20250115120000",
    "committed": false
  }
}
```

## Step 9: Display Success Message

Show completion message:
```
✅ Documentation updated successfully!

File: {file_path}
Operation: {operation_display}
Section: {section_heading if applicable}
Lines Changed: {lines_changed}
Validation: {validation_status}
Backup: {backup_path}
Committed: {yes/no}

Next steps:
  • View changes: git diff {file_path}
  • Validate: /fractary-docs:validate {file_path}
  • Restore backup: cp {backup_path} {file_path}
  • Commit: git add {file_path} && git commit -m "Update {doc_name}"

{if validation issues}
⚠️  Validation warnings:
  {list warnings}
{endif}
```

If validation failed:
```
⚠️  Documentation updated but validation failed!

File: {file_path}
Issues found: {issue_count}

Issues:
  1. {issue_description}
  2. {issue_description}

The file was updated but may have issues. You can:
  • Restore backup: cp {backup_path} {file_path}
  • Fix manually: Edit {file_path}
  • Validate: /fractary-docs:validate {file_path}
```

## Step 10: Display Error Message (if failed)

If update failed:
```
❌ Documentation update failed

Error: {error_message}
File: {file_path}
Operation: {operation}

Troubleshooting:
  {error-specific suggestions}

Common issues:
  • Section not found: Check section heading (case-sensitive)
  • File not found: Verify file path is correct
  • Permission denied: Check file permissions
  • Invalid metadata field: Check front matter structure
  • Pattern not found: Verify pattern exists in document

{if backup exists}
Backup available: {backup_path}
Restore: cp {backup_path} {file_path}
{endif}
```

</WORKFLOW>

<ERROR_HANDLING>
- Missing required arguments: Show usage examples
- File not found: Error with file path and suggestion to check path
- Section not found: Error with available sections in document
- Invalid metadata field: Error with valid front matter fields
- Pattern not found for replace: Error with no changes made
- Permission denied: Show file permissions fix
- Agent invocation failed: Show agent error with context
- Validation failed: Show issues but confirm update was made
- Content file not found: Error with file path
- Empty content: Error, require non-empty content
</ERROR_HANDLING>

<OUTPUTS>
Success: Updated file path with validation status, changes made, and next steps
Failure: Error message with troubleshooting guidance and backup restoration instructions
</OUTPUTS>
