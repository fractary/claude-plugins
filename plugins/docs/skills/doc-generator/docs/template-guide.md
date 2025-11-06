# Template Guide

This guide explains how to create and use documentation templates in the fractary-docs plugin.

## Template System Overview

Templates use **Mustache-style** syntax for variable substitution, conditionals, and loops. Templates are rendered using the `render-template.sh` script which processes template syntax and produces final markdown.

## Template Syntax

### 1. Simple Variables

Use `{{variable_name}}` for simple variable substitution:

```markdown
# {{title}}

**Author**: {{author}}
**Date**: {{date}}
```

With data:
```json
{
  "title": "My Document",
  "author": "Claude Code",
  "date": "2025-01-15"
}
```

Renders as:
```markdown
# My Document

**Author**: Claude Code
**Date**: 2025-01-15
```

### 2. Nested Objects

Use dot notation for nested object properties:

```markdown
**Region**: {{config.region}}
**Bucket**: {{config.bucket_name}}
```

With data:
```json
{
  "config": {
    "region": "us-east-1",
    "bucket_name": "my-bucket"
  }
}
```

### 3. Conditionals - Positive

Use `{{#condition}}...{{/condition}}` to show content only if condition is truthy:

```markdown
{{#has_errors}}
## Errors

There were errors during execution.
{{/has_errors}}
```

Content appears only if `has_errors` is true, non-empty, or non-empty array.

### 4. Conditionals - Negative

Use `{{^condition}}...{{/condition}}` to show content only if condition is falsy:

```markdown
{{^errors}}
✅ No errors found!
{{/errors}}
```

Content appears only if `errors` is false, empty, null, or empty array.

### 5. Loops - Arrays

Use `{{#array}}...{{/array}}` to iterate over arrays:

```markdown
## Requirements

{{#requirements}}
- {{.}}
{{/requirements}}
```

With data:
```json
{
  "requirements": ["Fast", "Secure", "Scalable"]
}
```

Renders as:
```markdown
## Requirements

- Fast
- Secure
- Scalable
```

### 6. Loops - Array of Objects

Access object properties within loops:

```markdown
{{#components}}
### {{name}}

{{description}}

**Tech**: {{technology}}

{{/components}}
```

With data:
```json
{
  "components": [
    {
      "name": "API Server",
      "description": "Handles HTTP requests",
      "technology": "Node.js"
    },
    {
      "name": "Database",
      "description": "Stores data",
      "technology": "PostgreSQL"
    }
  ]
}
```

### 7. Current Item in Loop

Use `{{.}}` to reference the current item in simple arrays:

```markdown
{{#tags}}
- Tag: {{.}}
{{/tags}}
```

### 8. Empty Array Handling

Combine positive and negative conditionals for empty arrays:

```markdown
{{#features}}
- {{.}}
{{/features}}
{{^features}}
(No features yet)
{{/features}}
```

If `features` is empty, shows "(No features yet)". Otherwise, shows the list.

## Template Variables

### Standard Variables

All templates automatically receive these variables:

- `date`: Current date (YYYY-MM-DD)
- `timestamp`: ISO 8601 timestamp
- `author`: From config or "Claude Code"
- `generated`: Always true
- `year`: Current year
- `month`: Current month name
- `day`: Current day

### Document-Type-Specific Variables

Each document type has its own required and optional variables. See [Template Reference](#template-reference) below.

## Front Matter

All generated documents include YAML front matter:

```yaml
---
title: "Document Title"
type: adr|design|runbook|api-spec|test-report|deployment|changelog|architecture|troubleshooting|postmortem
status: draft|review|approved|deprecated|proposed|accepted|superseded
date: "2025-01-15"
updated: "2025-01-15"
author: "Claude Code"
tags: [tag1, tag2]
related: ["/docs/other-doc.md"]
codex_sync: true
generated: true
---
```

Front matter is automatically added by `add-frontmatter.sh` script.

## Template Reference

### ADR Template (adr.md.template)

**Required**:
- `number`: ADR number (string)
- `title`: Decision title
- `status`: proposed|accepted|deprecated|superseded
- `date`: Date
- `context`: Problem context
- `decision`: The decision made
- `consequences`: Object with `positive[]` and `negative[]`

**Optional**:
- `deciders`: Who decided
- `tags`: Array of tags
- `alternatives[]`: Array with `name`, `description`, `pros[]`, `cons[]`, `rejection_reason`
- `references[]`: Array with `title`, `url`

### Design Template (design.md.template)

**Required**:
- `title`: Design title
- `overview`: High-level overview
- `status`: draft|review|approved

**Optional**:
- `requirements[]`: Array of requirements
- `architecture.components[]`: Components with `name`, `description`, `responsibilities[]`, `interfaces[]`
- `architecture.interactions[]`: Interactions with `from`, `to`, `description`
- `implementation.phases[]`: Phases with `number`, `name`, `description`, `tasks[]`, `duration`
- `implementation.technologies[]`: Technologies with `name`, `description`
- `testing.strategy`: Testing approach
- `testing.test_cases[]`: Test cases with `name`, `description`, `steps[]`, `expected_result`
- `security`: Security considerations
- `performance`: Performance considerations
- `deployment`: Deployment strategy

### Runbook Template (runbook.md.template)

**Required**:
- `title`: Runbook title
- `purpose`: What this runbook does
- `steps[]`: Array with `number`, `name`, `description`, `commands[]`, `expected_output`, `validation[]`

**Optional**:
- `prerequisites[]`: What's needed before starting
- `troubleshooting[]`: Common issues with `problem`, `symptoms[]`, `diagnosis`, `solution`, `commands[]`
- `rollback`: Rollback info with `rollback_steps[]`
- `verification[]`: Verification steps
- `notes`: Additional notes

### API Spec Template (api-spec.md.template)

**Required**:
- `title`: API title
- `version`: API version
- `base_url`: Base URL
- `overview`: API overview

**Optional**:
- `authentication`: Auth with `method`, `description`, `example`
- `endpoints[]`: Endpoints with `method`, `path`, `description`, `request`, `response`
- `models[]`: Data models with `name`, `description`, `schema`, `fields[]`
- `errors[]`: Error codes with `code`, `message`, `description`
- `rate_limiting`: Rate limiting policy
- `pagination`: Pagination mechanism

### Test Report Template (test-report.md.template)

**Required**:
- `title`: Report title
- `date`: Test date
- `environment`: Test environment
- `summary`: Test summary
- `results`: Object with `total`, `passed`, `failed`, `skipped`, `duration`, `pass_rate`

**Optional**:
- `test_cases[]`: Test cases with `name`, `status`, `duration`, `description`
- `coverage`: Coverage with `percentage`, `by_module[]`
- `issues[]`: Issues with `title`, `severity`, `component`, `description`
- `performance.metrics[]`: Performance metrics
- `environment_details`: Environment details

### Deployment Template (deployment.md.template)

**Required**:
- `title`: Deployment title
- `version`: Version deployed
- `environment`: Target environment
- `overview`: Deployment overview

**Optional**:
- `infrastructure[]`: Infrastructure with `name`, `description`, `configuration[]`
- `configuration_changes[]`: Changes with `key`, `old_value`, `new_value`
- `deployment_steps[]`: Steps with `number`, `name`, `description`, `commands[]`, `duration`
- `verification_steps[]`: Verification with `name`, `description`, `commands[]`, `expected`
- `rollback`: Rollback with `description`, `steps[]`, `commands[]`, `estimate`
- `migrations[]`: Database migrations
- `monitoring`: Monitoring checklist

## Creating Custom Templates

### 1. Create Template File

Create `.md.template` file in custom template directory:

```bash
mkdir -p .templates/docs
vim .templates/docs/my-custom-doc.md.template
```

### 2. Define Template Content

Use Mustache syntax:

```markdown
# {{title}}

**Type**: {{type}}
**Date**: {{date}}

## Overview

{{overview}}

## Custom Section

{{#custom_items}}
- **{{name}}**: {{value}}
{{/custom_items}}

{{^custom_items}}
(No custom items)
{{/custom_items}}
```

### 3. Update Configuration

Point to custom template directory in config:

```json
{
  "templates": {
    "custom_template_dir": ".templates/docs",
    "use_project_templates": true
  }
}
```

### 4. Use Custom Template

Generate using custom template:

```bash
/fractary-docs:generate my-custom-doc "My Document" --template-data '{"overview": "...", "custom_items": [...]}'
```

## Best Practices

1. **Use Fallback Content**: Always provide fallback for optional sections using `{{^condition}}`
2. **Validate Data**: Ensure all required variables are provided before rendering
3. **Consistent Naming**: Use snake_case for variable names
4. **Document Variables**: List all variables in template comments
5. **Test Thoroughly**: Test with various data combinations
6. **Keep Simple**: Avoid deeply nested conditionals
7. **Use Arrays**: Prefer arrays for repeated content
8. **Provide Examples**: Include example data in template comments
9. **Handle Empty State**: Show helpful messages when arrays are empty
10. **Follow Conventions**: Match existing template structure and style

## Troubleshooting

### Variable Not Rendering

**Problem**: `{{myvar}}` appears literally in output

**Solution**: Check JSON path is correct, ensure variable exists in data

### Loop Not Working

**Problem**: Loop content doesn't repeat

**Solution**: Verify array is not empty, check array variable name matches template

### Conditional Always Shows/Hides

**Problem**: Content shows when it shouldn't or vice versa

**Solution**: Check if using `#` (positive) vs `^` (negative) correctly

### Nested Object Not Found

**Problem**: `{{object.field}}` renders as empty

**Solution**: Verify object structure in JSON, check dot notation path

## Examples

See `workflow/` directory for complete examples:
- `generate-adr.md` - ADR generation workflow
- `generate-design-doc.md` - Design document workflow

## Reference

- Mustache documentation: https://mustache.github.io/
- Template files: `skills/doc-generator/templates/`
- Rendering script: `skills/doc-generator/scripts/render-template.sh`
