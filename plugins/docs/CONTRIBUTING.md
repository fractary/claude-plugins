# Contributing to fractary-docs Plugin

Thank you for your interest in contributing to the fractary-docs plugin! This guide will help you understand the architecture and how to make changes effectively.

## Table of Contents

- [Architecture Overview](#architecture-overview)
- [Adding a New Document Type](#adding-a-new-document-type)
- [Modifying Operation Skills](#modifying-operation-skills)
- [Enhancing Coordination](#enhancing-coordination)
- [Testing Your Changes](#testing-your-changes)
- [Submitting Changes](#submitting-changes)
- [Code Standards](#code-standards)

## Architecture Overview

The fractary-docs plugin uses a **3-layer architecture** with **data-driven type context**:

```
Layer 1: Commands (/docs:write, /docs:validate, etc.)
   ↓
Layer 2: Coordination (docs-manager, docs-director)
   ↓
Layer 3: Operations (doc-writer, doc-validator, doc-classifier, doc-lister)
   ↓
Type Context (5 files per type in types/{doc_type}/)
```

### Key Principles

1. **Separation of Data and Logic**
   - Type-specific behavior = data files in `types/{doc_type}/`
   - Universal operations = skills in `skills/doc-*/`

2. **Single Responsibility**
   - Each skill does ONE thing well
   - No type-specific logic in skills

3. **Data-Driven**
   - Skills load type context at runtime
   - Adding new types requires NO skill changes

## Adding a New Document Type

This is the most common contribution! Follow these steps:

### 1. Create Type Directory

```bash
mkdir -p plugins/docs/types/{your-type}
```

### 2. Create 5 Required Files

#### a. `schema.json` (JSON Schema Draft 7)

Defines the frontmatter structure and validation:

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "title": "Your Type Documentation Schema",
  "description": "Schema for {your-type} documentation frontmatter",
  "properties": {
    "fractary_doc_type": {
      "const": "your-type",
      "description": "Document type identifier"
    },
    "title": {
      "type": "string",
      "description": "Document title"
    },
    "status": {
      "enum": ["draft", "published", "deprecated"],
      "description": "Document status"
    },
    "version": {
      "type": "string",
      "pattern": "^\\d+\\.\\d+\\.\\d+$",
      "description": "Semantic version"
    },
    "date": {
      "type": "string",
      "format": "date",
      "description": "Creation date"
    },
    // Add your type-specific fields here
    "custom_field": {
      "type": "string",
      "description": "Example custom field"
    }
  },
  "required": [
    "fractary_doc_type",
    "title",
    "status",
    "version",
    "date"
  ],
  "additionalProperties": false
}
```

**Tips**:
- Use JSON Schema Draft 7 syntax
- Mark `fractary_doc_type` with `"const": "your-type"`
- Include clear descriptions for all fields
- Use `pattern` for format validation (e.g., semver, URLs)
- Mark truly required fields in `required` array

#### b. `template.md` (Mustache Template)

Document template with variable substitution:

```markdown
---
title: "{{title}}"
fractary_doc_type: your-type
status: {{status}}
version: {{version}}
date: {{date}}
custom_field: {{custom_field}}
---

# {{title}}

## Overview

{{overview}}

## Details

{{details}}

## Related

{{related}}
```

**Tips**:
- Use `{{variable}}` for simple substitution
- Frontmatter should match schema.json fields
- Include all required sections from standards.md
- Use markdown formatting (headings, lists, code blocks)
- Keep template clean and well-structured

#### c. `standards.md` (Writing Guidelines)

Document the writing standards and best practices:

```markdown
# {Your Type} Documentation Standards

## Purpose

{Explain what this document type is for}

## Required Sections

All {your-type} documents MUST include:

1. **Overview** - High-level summary (2-3 sentences)
2. **Details** - In-depth explanation
3. **Related** - Links to related documentation

## Optional Sections

- Examples (highly recommended)
- References
- Notes

## Naming Conventions

- File names: `{your-type}-{slug}.md` (e.g., `changelog-v1.0.0.md`)
- Titles: Use sentence case
- Headings: Use ## for main sections, ### for subsections

## Content Guidelines

- **Clarity**: Write for your target audience (developers, users, etc.)
- **Completeness**: Include all required sections
- **Consistency**: Follow template structure
- **Links**: Use relative paths for internal links

## Examples

See `examples/{your-type}/` for complete examples.
```

**Tips**:
- Be specific about requirements vs recommendations
- Include naming conventions for files and content
- Provide examples when helpful
- Explain the purpose and audience

#### d. `validation-rules.md` (Quality Checks)

Define type-specific validation rules:

```markdown
# {Your Type} Validation Rules

## Frontmatter Validation

✅ **MUST have** valid frontmatter with all required fields
✅ **MUST have** `fractary_doc_type: your-type`
✅ **MUST have** valid semver in `version` field
✅ **MUST have** valid ISO date in `date` field

## Structure Validation

✅ **MUST have** Overview section
✅ **MUST have** Details section
✅ **MUST have** Related section
⚠️  **SHOULD have** Examples section

## Content Validation

✅ **Overview MUST be** 2-3 sentences (not paragraphs)
✅ **Links MUST be** valid (no broken references)
✅ **Code blocks MUST have** language specified

## Custom Validation

✅ **Custom field MUST** meet pattern: [a-z0-9-]+
✅ **Related section MUST** contain at least one link

## Error Messages

When validation fails, provide:
- Clear description of the issue
- Location (section/line)
- How to fix it
```

**Tips**:
- Use ✅ for MUST, ⚠️ for SHOULD, ℹ️ for MAY
- Be specific about what's being validated
- Provide clear error messages
- Explain how to fix common issues

#### e. `index-config.json` (Index Organization)

Configure how documents are organized in indices:

```json
{
  "index_file": "docs/{your-type}/README.md",
  "organization": "hierarchical",
  "group_by": ["status", "version"],
  "sort_by": "date",
  "sort_order": "desc",
  "entry_template": "- [**{{title}}**]({{relative_path}}) - v{{version}} ({{status}})",
  "section_template": "## {{group_name}}"
}
```

**Configuration options**:

- **organization**: `"flat"` (simple list) or `"hierarchical"` (grouped)
- **group_by**: Array of fields for grouping (hierarchical only)
  - Examples: `["status"]`, `["service", "version"]`, `["audience", "topic"]`
- **sort_by**: Field to sort by (`"title"`, `"date"`, `"version"`, etc.)
- **sort_order**: `"asc"` (ascending) or `"desc"` (descending)
- **entry_template**: Mustache template for each document entry
  - Available variables: All frontmatter fields + `{{relative_path}}`, `{{filename}}`, `{{description_short}}`
- **section_template**: Mustache template for section headers (hierarchical only)
  - Available variables: `{{group_name}}`

**Examples**:

Flat list (sorted by date, newest first):
```json
{
  "organization": "flat",
  "sort_by": "date",
  "sort_order": "desc",
  "entry_template": "- [{{title}}]({{relative_path}}) - {{date}}"
}
```

Hierarchical (grouped by service, then version):
```json
{
  "organization": "hierarchical",
  "group_by": ["service", "version"],
  "sort_by": "endpoint",
  "entry_template": "- [**{{method}} {{endpoint}}**]({{relative_path}}) - {{title}}",
  "section_template": "### {{group_name}}"
}
```

### 3. Test Your Type

```bash
# Create a test document
/docs:write your-type

# Validate it
/docs:validate docs/{your-type}/*.md

# Check the generated index
cat docs/{your-type}/README.md
```

### 4. Add Examples (Optional but Recommended)

Create `examples/{your-type}/` with sample documents:

```bash
mkdir -p plugins/docs/examples/{your-type}
# Add 2-3 example documents
```

### 5. Submit Your Changes

See [Submitting Changes](#submitting-changes) below.

## Modifying Operation Skills

Operation skills handle universal operations (write, validate, classify, list). Modify these when:
- Adding new operation capabilities
- Fixing bugs in core operations
- Improving error handling

### Operation Skills

1. **doc-writer** (`skills/doc-writer/`)
   - Handles CREATE and UPDATE operations
   - Loads type context, renders template, writes file

2. **doc-validator** (`skills/doc-validator/`)
   - Validates frontmatter (JSON Schema)
   - Validates structure (required sections)
   - Validates content (custom rules)

3. **doc-classifier** (`skills/doc-classifier/`)
   - Auto-detects document type from path or content
   - Path-based: `docs/{doc_type}/` pattern
   - Content-based: `fractary_doc_type` frontmatter field

4. **doc-lister** (`skills/doc-lister/`)
   - Lists and filters documentation
   - Supports table, JSON, and markdown output
   - Filters by type, status, etc.

### Guidelines for Skill Changes

1. **Maintain Type-Agnostic Design**
   - NO hardcoded type logic in skills
   - ALWAYS load type context from `types/{doc_type}/`

2. **Follow SKILL.md Structure**
   ```markdown
   <CONTEXT>Who you are, what you do</CONTEXT>
   <CRITICAL_RULES>Must-never-violate rules</CRITICAL_RULES>
   <INPUTS>What you receive</INPUTS>
   <WORKFLOW>Steps to execute</WORKFLOW>
   <COMPLETION_CRITERIA>How to know you're done</COMPLETION_CRITERIA>
   <OUTPUTS>What you return</OUTPUTS>
   <ERROR_HANDLING>How to handle errors</ERROR_HANDLING>
   ```

3. **Output Start/End Messages**
   ```markdown
   🎯 STARTING: [Skill Name]
   [Key parameters]
   ───────────────────────────────────────

   [... execution ...]

   ✅ COMPLETED: [Skill Name]
   [Key results]
   ───────────────────────────────────────
   Next: [What to do next]
   ```

4. **Test Against All Types**
   - Run tests with api, adr, dataset, etc.
   - Ensure no regressions

## Enhancing Coordination

Coordination skills orchestrate workflows:

1. **docs-manager-skill** (`skills/docs-manager-skill/`)
   - Single-document workflows
   - write → validate → index pipeline

2. **docs-director-skill** (`skills/docs-director-skill/`)
   - Multi-document workflows
   - Parallel execution with file locking
   - Audit and batch operations

### When to Modify Coordination

- Adding new multi-step workflows
- Improving parallel execution
- Enhancing error recovery

### Guidelines

1. **Keep Coordination Separate from Operations**
   - Coordination = decision-making and orchestration
   - Operations = actual work (delegated to operation skills)

2. **Use File Locking for Concurrency**
   ```bash
   flock -x -w 30 "$file_path.lock" \
       coordinate-write.sh "$file_path" "$doc_type"
   ```

3. **Aggregate Results**
   - Collect results from parallel operations
   - Report summary to user

## Testing Your Changes

### Unit Testing

Test individual skills:

```bash
# Test doc-classifier
bash plugins/docs/skills/doc-classifier/scripts/classify-by-path.sh \
    "docs/api/user-login/README.md"

# Test doc-writer (requires type context)
# Create test type first, then test
```

### Integration Testing

Test full workflows:

```bash
# Test write → validate → index pipeline
/docs:write api
# Verify: document created, validated, index updated

# Test batch operations
/docs:write api docs/api/**/README.md --batch
```

### Type Coverage

Test with multiple document types:

```bash
for type in api adr dataset etl testing; do
    echo "Testing type: $type"
    /docs:write $type
    /docs:validate --doc-type $type
done
```

### Regression Testing

Ensure v1.x functionality preserved:

```bash
# Compare outputs
diff <(old-version output) <(new-version output)
```

## Submitting Changes

### 1. Create Feature Branch

```bash
git checkout -b feature/your-feature-name
```

### 2. Make Changes

Follow the guidelines above for your change type.

### 3. Test Thoroughly

Run all relevant tests (see [Testing](#testing-your-changes)).

### 4. Update Documentation

- Update README.md if user-facing changes
- Update CHANGELOG.md with your changes
- Add/update examples if applicable

### 5. Commit with Conventional Commits

```bash
git commit -m "feat(docs): add changelog document type

- Create types/changelog/ with 5 context files
- Add schema for version and release_date fields
- Configure flat index sorted by version (desc)
- Add examples/changelog/ with sample documents"
```

Format: `<type>(<scope>): <subject>`

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `refactor`: Code refactor
- `test`: Adding tests
- `chore`: Maintenance

### 6. Create Pull Request

Title: Clear, descriptive summary
Description:
- What changed and why
- Testing performed
- Breaking changes (if any)
- Related issues

## Code Standards

### Shell Scripts

- Use `set -euo pipefail` at start
- Quote all variables: `"$var"`
- Use `local` for function variables
- Add clear comments
- Include usage documentation in header

```bash
#!/usr/bin/env bash
# Script Name - Brief description
# Usage: script.sh <arg1> <arg2>

set -euo pipefail

main() {
    local arg1="$1"
    local arg2="$2"

    # Clear, commented logic
}

main "$@"
```

### Markdown (SKILL.md, *.md)

- Use UPPERCASE XML tags in SKILL.md
- Keep line length ≤ 120 characters
- Use fenced code blocks with language
- Include examples where helpful

### JSON

- Use 2-space indentation
- Include `$schema` in schema.json files
- Validate with `jq .` before committing

```bash
cat types/your-type/schema.json | jq .
```

### Type Context Files

- **schema.json**: Valid JSON Schema Draft 7
- **template.md**: Valid markdown with `{{variables}}`
- **standards.md**: Clear, specific guidelines
- **validation-rules.md**: Actionable rules with ✅/⚠️/ℹ️
- **index-config.json**: Valid configuration

## Getting Help

- **Questions**: Open a discussion in GitHub
- **Bugs**: Open an issue with reproduction steps
- **Ideas**: Open an issue with "enhancement" label
- **Docs**: Read `README.md` and `docs/specs/SPEC-docs-plugin-refactor.md`

## License

By contributing, you agree that your contributions will be licensed under the same license as the project.

---

Thank you for contributing to fractary-docs! 🎉
