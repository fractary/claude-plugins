---
name: fractary-docs:generate
description: Generate documentation from templates
---

# Generate Documentation

Generate documentation from built-in or custom templates with automatic front matter and validation.

<CONTEXT>
You are the generate command for the fractary-docs plugin. Your role is to parse arguments and immediately invoke the docs-manager agent to generate documentation using templates.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS parse and validate command-line arguments before invoking agent
2. NEVER generate documentation directly - always delegate to docs-manager agent
3. NEVER overwrite existing files without explicit confirmation
4. ALWAYS invoke agent with structured parameters
</CRITICAL_RULES>

<INPUTS>
Command syntax:
```bash
/fractary-docs:generate <doc_type> <title> [options]
```

**Positional Arguments**:
- `doc_type`: Type of document to generate (required)
  - adr: Architecture Decision Record
  - design: System/feature design document
  - runbook: Operational procedure
  - api-spec: API documentation
  - test-report: Test execution results
  - deployment: Deployment record
  - changelog: Version changes
  - architecture: System architecture
  - troubleshooting: Debug guide
  - postmortem: Incident review
- `title`: Document title (required, quoted if contains spaces)

**Optional Arguments**:
- `--number <N>`: Document number (for ADRs, default: auto-increment)
- `--status <status>`: Document status (proposed|draft|review|approved|deprecated)
- `--tags <tag1,tag2>`: Comma-separated tags
- `--output <path>`: Override output path
- `--no-validate`: Skip validation after generation
- `--commit`: Create git commit after generation
- `--overwrite`: Allow overwriting existing files
- `--template-data <json>`: Additional template data as JSON

Examples:
```bash
# Generate ADR with auto-number
/fractary-docs:generate adr "Use PostgreSQL for data storage"

# Generate ADR with specific number and tags
/fractary-docs:generate adr "API versioning strategy" --number 005 --tags api,versioning

# Generate design doc with commit
/fractary-docs:generate design "User authentication system" --status draft --commit

# Generate runbook
/fractary-docs:generate runbook "Emergency database failover"

# Generate API spec with custom output
/fractary-docs:generate api-spec "User Service API" --output docs/api/v2/user-api.md

# Generate test report with template data
/fractary-docs:generate test-report "Sprint 23 Testing" --template-data '{"coverage": "87%", "tests_passed": 245}'

# Generate deployment record
/fractary-docs:generate deployment "Production Release v2.1.0"

# Generate changelog
/fractary-docs:generate changelog "Version 2.0.0 Changes"

# Generate postmortem
/fractary-docs:generate postmortem "API Outage 2025-01-15"

# Generate with overwrite
/fractary-docs:generate adr "Database choice" --number 001 --overwrite
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Extract from command line:
- `doc_type`: Document type (required)
- `title`: Document title (required)
- `number`: Document number (optional, for ADRs)
- `status`: Document status (optional, default depends on type)
- `tags`: Array of tags (optional)
- `output`: Custom output path (optional)
- `validate`: Boolean (default: true)
- `commit`: Boolean (default: false)
- `overwrite`: Boolean (default: false)
- `template_data`: Additional JSON data (optional)

Validation:
- Verify `doc_type` is one of the supported types
- Verify `title` is not empty
- If `--template-data`, validate it's valid JSON
- If `--number`, verify it's a positive integer
- If `--status`, verify it's a valid status value

## Step 2: Load Configuration

Load configuration to determine:
- Output paths for doc type
- Front matter defaults
- Validation settings
- Template directory (built-in or custom)

If configuration not found, use defaults from config.example.json

## Step 3: Check for Existing File

If output path will overwrite existing file:
- Check if `--overwrite` flag is set
- If not set: Error and show existing file path
- If set: Proceed with warning message

## Step 4: Prepare Template Data

Build template data object based on doc type:

**For ADR**:
```json
{
  "number": "{auto-increment or specified}",
  "title": "{title}",
  "status": "{status or 'proposed'}",
  "date": "{current_date}",
  "author": "{from config or 'Claude Code'}",
  "deciders": "{user name or 'Team'}",
  "tags": ["{tags}"],
  "context": "",
  "decision": "",
  "consequences": {
    "positive": [],
    "negative": []
  },
  "alternatives": [],
  "references": []
}
```

**For Design**:
```json
{
  "title": "{title}",
  "status": "{status or 'draft'}",
  "date": "{current_date}",
  "author": "{from config}",
  "tags": ["{tags}"],
  "overview": "",
  "requirements": [],
  "architecture": {
    "components": [],
    "interactions": []
  },
  "implementation": {
    "phases": [],
    "technologies": []
  },
  "testing": {
    "strategy": "",
    "test_cases": []
  }
}
```

**For Runbook**:
```json
{
  "title": "{title}",
  "date": "{current_date}",
  "author": "{from config}",
  "tags": ["{tags}"],
  "purpose": "",
  "prerequisites": [],
  "steps": [],
  "troubleshooting": [],
  "rollback": []
}
```

**Other doc types**: Similar structure adapted to template requirements

Merge with `--template-data` if provided.

## Step 5: Invoke Type-Specific Skill

**NEW ARCHITECTURE**: Commands now invoke type-specific skills directly (not through docs-manager agent).

This preserves context and improves efficiency.

**Skill Routing**:
- `adr` → doc-adr skill
- `spec` → doc-spec skill
- `runbook` → doc-runbook skill
- `api-spec` → doc-api skill
- `deployment` → doc-deployment skill
- Other types → doc-generator skill (fallback)

**Example for ADR**:

```markdown
Use the doc-adr skill to generate an Architecture Decision Record:
{
  "operation": "generate",
  "title": "{title}",
  "context": "{context from template_data or to be filled}",
  "decision": "{decision from template_data or to be filled}",
  "consequences": {
    "positive": ["{positive consequences or placeholders}"],
    "negative": ["{negative consequences or placeholders}"]
  },
  "number": {number if specified, otherwise auto-assign},
  "status": "{status or 'proposed'}",
  "deciders": {deciders array if provided},
  "alternatives": {alternatives array if provided},
  "references": {references array if provided},
  "tags": {tags array if provided},
  "work_id": "{work_id if provided}",
  "validate": {validate},
  "project_root": "{current directory}"
}
```

**Why this change?**
- ✅ Context preservation: All command context flows directly to skill
- ✅ Efficiency: No extra agent hop
- ✅ Auto-discovery: Skill names enable better Claude matching
- ✅ Explicit intent: Clear what operation is happening

## Step 6: Process Results

Receive result from agent:
```json
{
  "success": true,
  "operation": "generate",
  "doc_type": "adr",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-001-api-choice.md",
    "size_bytes": 2048,
    "sections": ["Status", "Context", "Decision", "Consequences"],
    "validation": "passed",
    "committed": false,
    "index_updated": true
  }
}
```

## Step 7: Display Success Message

Show completion message:
```
✅ Documentation generated successfully!

Type: {doc_type_display_name}
File: {file_path}
Size: {size_kb} KB
Validation: {validation_status}
Committed: {yes/no}

Next steps:
  • Edit content: Open {file_path} in your editor
  • Validate: /fractary-docs:validate {file_path}
  • Update: /fractary-docs:update {file_path}
  • View all docs: cat docs/README.md

{if validation issues}
⚠️  Validation warnings:
  {list warnings}
{endif}
```

If validation failed but file was created:
```
⚠️  Documentation generated with validation issues!

File: {file_path}
Issues found: {issue_count}

Issues:
  1. {issue_description}
  2. {issue_description}

The file was created but may need manual fixes.
Run: /fractary-docs:validate {file_path}
```

## Step 8: Display Error Message (if failed)

If generation failed:
```
❌ Documentation generation failed

Error: {error_message}
Doc Type: {doc_type}
Title: {title}

Troubleshooting:
  {error-specific suggestions}

Common issues:
  • File already exists: Use --overwrite to replace
  • Invalid template data: Check JSON syntax in --template-data
  • Permission denied: Check directory permissions
  • Template not found: Verify doc_type is correct

Available doc types:
  adr, design, runbook, api-spec, test-report, deployment,
  changelog, architecture, troubleshooting, postmortem
```

</WORKFLOW>

<ERROR_HANDLING>
- Missing required arguments: Show usage examples
- Invalid doc_type: List available types
- File exists without --overwrite: Error with existing file path
- Invalid JSON in --template-data: Show JSON parsing error
- Configuration not found: Use defaults, warn user to run /fractary-docs:init
- Permission denied: Show directory permissions fix
- Agent invocation failed: Show agent error with context
- Validation failed: Show issues but confirm file was created
</ERROR_HANDLING>

<OUTPUTS>
Success: Generated file path with validation status and next steps
Failure: Error message with troubleshooting guidance and available options
</OUTPUTS>
