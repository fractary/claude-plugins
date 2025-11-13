# ADR Generate Workflow

This workflow implements ADR generation with auto-numbering, template rendering, and validation.

## Overview

The generate operation creates a new Architecture Decision Record (ADR) with:
- Auto-assigned sequential number (or user-specified)
- Slug-based filename
- Codex-compatible frontmatter
- Required section structure
- Self-validation

## Prerequisites

- Schema loaded and configuration resolved
- ADR path exists or can be created
- Title and required content provided

## Implementation Steps

### Step 1: Output Start Message

```
🎯 STARTING: ADR Generation
Title: {title}
Status: {status or 'proposed'}
Auto-number: {yes/no}
───────────────────────────────────────
```

### Step 2: Determine ADR Number

If ADR number not provided, find next sequential number:

```bash
# Get ADR path from config
ADR_PATH=$(echo "$CONFIG" | jq -r '.path')

# Find next number
ADR_NUMBER=$(${SHARED_SCRIPTS}/find-next-number.sh "$ADR_PATH" "ADR-" "%03d")

echo "📊 Assigned ADR number: $ADR_NUMBER"
```

If ADR number provided, validate it doesn't exist:

```bash
# Check if ADR already exists
SLUG=$(${SHARED_SCRIPTS}/slugify.sh "$TITLE" 50)
FILENAME="ADR-${ADR_NUMBER}-${SLUG}.md"
FULL_PATH="${ADR_PATH}/${FILENAME}"

if [[ -f "$FULL_PATH" && "$OVERWRITE" != "true" ]]; then
    echo "❌ Error: ADR-${ADR_NUMBER} already exists at ${FULL_PATH}"
    exit 1
fi
```

### Step 3: Generate Slug

Convert title to URL-friendly slug:

```bash
SLUG=$(${SHARED_SCRIPTS}/slugify.sh "$TITLE" 50)
echo "📝 Generated slug: $SLUG"
```

### Step 4: Construct Filename and Path

```bash
# Construct filename: ADR-NNN-slug.md
FILENAME="ADR-${ADR_NUMBER}-${SLUG}.md"

# Full output path
OUTPUT_FILE="${ADR_PATH}/${FILENAME}"

echo "📄 Output file: $OUTPUT_FILE"
```

### Step 5: Ensure Directory Exists

```bash
mkdir -p "$ADR_PATH"
```

### Step 6: Prepare Template Data

Build template data object with all parameters:

```bash
# Get current date
CURRENT_DATE=$(date +%Y-%m-%d)
CURRENT_TIMESTAMP=$(date -u +%Y-%m-%dT%H:%M:%SZ)

# Extract frontmatter defaults from config
AUTHOR=$(echo "$CONFIG" | jq -r '.frontmatter.default_fields.author // "Claude Code"')
CODEX_SYNC=$(echo "$CONFIG" | jq -r '.frontmatter.codex_sync // true')

# Build template data JSON
TEMPLATE_DATA=$(jq -n \
    --arg number "$ADR_NUMBER" \
    --arg title "$TITLE" \
    --arg status "${STATUS:-proposed}" \
    --arg date "$CURRENT_DATE" \
    --arg author "$AUTHOR" \
    --arg context "$CONTEXT" \
    --arg decision "$DECISION" \
    --argjson consequences "$CONSEQUENCES" \
    --argjson deciders "${DECIDERS:-[]}" \
    --argjson alternatives "${ALTERNATIVES:-[]}" \
    --argjson references "${REFERENCES:-[]}" \
    --argjson tags "${TAGS:-[]}" \
    --arg work_id "${WORK_ID:-}" \
    '{
        number: $number,
        title: $title,
        status: $status,
        date: $date,
        author: $author,
        context: $context,
        decision: $decision,
        consequences: $consequences,
        deciders: $deciders,
        alternatives: $alternatives,
        references: $references,
        tags: $tags,
        work_id: $work_id
    }'
)
```

### Step 7: Prepare Frontmatter

Build YAML frontmatter separately:

```bash
FRONTMATTER=$(jq -n \
    --arg title "ADR-${ADR_NUMBER}: ${TITLE}" \
    --arg type "adr" \
    --arg status "${STATUS:-proposed}" \
    --arg date "$CURRENT_DATE" \
    --arg timestamp "$CURRENT_TIMESTAMP" \
    --arg author "$AUTHOR" \
    --argjson tags "${TAGS:-[]}" \
    --argjson related "${RELATED:-[]}" \
    --arg work_id "${WORK_ID:-}" \
    --argjson codex_sync "$CODEX_SYNC" \
    '{
        title: $title,
        type: $type,
        status: $status,
        date: $date,
        timestamp: $timestamp,
        author: $author,
        tags: $tags,
        related: $related,
        work_id: $work_id,
        codex_sync: $codex_sync,
        generated: true
    } | with_entries(select(.value != "" and .value != null))'
)
```

### Step 8: Render Template

Use Claude's capabilities to render the template with provided data.

**Template Location Priority**:
1. Project templates: `.templates/docs/adr.md.template`
2. Global templates: `~/.config/fractary/docs/templates/adr.md.template`
3. Built-in template: `${PLUGIN_ROOT}/skills/doc-manage-adr/templates/default.md.template`

**Template Variables Available**:
- `{{number}}` - ADR number (formatted: 005)
- `{{title}}` - ADR title
- `{{status}}` - Current status
- `{{date}}` - Creation date
- `{{author}}` - Author name
- `{{context}}` - Context and problem statement
- `{{decision}}` - The decision made
- `{{consequences.positive}}` - Array of positive consequences
- `{{consequences.negative}}` - Array of negative consequences
- `{{#deciders}}` - Loop over deciders
- `{{#alternatives}}` - Loop over alternatives (name, description, rejection_reason)
- `{{#references}}` - Loop over references (title, url)
- `{{#superseded_by}}` - Supersession info (if applicable)
- `{{#deprecated_reason}}` - Deprecation reason (if applicable)

**Rendering**:

Generate the ADR content by rendering the template with the template data. The template uses Mustache-style syntax:
- Simple variables: `{{variable}}`
- Conditionals: `{{#condition}}...{{/condition}}`
- Negation: `{{^condition}}...{{/condition}}`
- Loops: `{{#array}}{{.}}{{/array}}`

The rendered content should follow the template structure in `templates/default.md.template`.

### Step 9: Add Frontmatter

Prepend YAML frontmatter to the rendered content:

```markdown
---
title: "ADR-005: Use PostgreSQL for Primary Datastore"
type: adr
status: proposed
date: "2025-01-15"
timestamp: "2025-01-15T12:00:00Z"
author: Claude Code
tags: [database, postgresql]
related: []
codex_sync: true
generated: true
---

# Use PostgreSQL for Primary Datastore

## Status

proposed

...
```

### Step 10: Write to File

Write the complete ADR (frontmatter + content) to the output file:

```bash
# Write to file atomically (write to temp, then move)
TEMP_FILE="${OUTPUT_FILE}.tmp"
echo "$COMPLETE_CONTENT" > "$TEMP_FILE"
mv "$TEMP_FILE" "$OUTPUT_FILE"

echo "✅ ADR written to: $OUTPUT_FILE"
```

### Step 11: Validate Generated ADR

Validate the generated ADR against schema rules:

**Validation Checks**:
1. **Frontmatter**: Valid YAML, all required fields present
2. **Required Sections**: Status, Context, Decision, Consequences present
3. **Section Length**: Context ≥ 50 chars, Decision ≥ 50 chars, Consequences ≥ 30 chars
4. **Consequences Structure**: Both Positive and Negative subsections exist and have content
5. **Status Value**: In allowed values (proposed, accepted, deprecated, superseded)
6. **Filename Match**: Filename matches pattern ADR-NNN-slug.md

**Validation Result**:
```json
{
  "status": "passed" | "warnings" | "errors",
  "issues": [
    {
      "severity": "error|warning|info",
      "rule": "rule_name",
      "message": "Issue description",
      "section": "Section name or null"
    }
  ]
}
```

If validation has errors, report them but still return success (file was created).

### Step 12: Calculate File Metrics

```bash
# Get file size
FILE_SIZE=$(wc -c < "$OUTPUT_FILE")

# Extract sections (all ## headings)
SECTIONS=$(grep '^## ' "$OUTPUT_FILE" | sed 's/^## //' | jq -R . | jq -s .)
```

### Step 13: Build Result Object

```bash
RESULT=$(jq -n \
    --arg file_path "$OUTPUT_FILE" \
    --arg adr_number "$ADR_NUMBER" \
    --arg title "$TITLE" \
    --arg status "${STATUS:-proposed}" \
    --arg size_bytes "$FILE_SIZE" \
    --argjson sections "$SECTIONS" \
    --argjson frontmatter "$FRONTMATTER" \
    --argjson validation "$VALIDATION_RESULT" \
    --arg timestamp "$CURRENT_TIMESTAMP" \
    '{
        success: true,
        operation: "generate",
        doc_type: "adr",
        result: {
            file_path: $file_path,
            adr_number: ($adr_number | tonumber),
            title: $title,
            status: $status,
            size_bytes: ($size_bytes | tonumber),
            sections: $sections,
            frontmatter: $frontmatter,
            validation: $validation
        },
        timestamp: $timestamp
    }'
)
```

### Step 14: Output Completion Message

```
✅ COMPLETED: ADR Generation
File: {output_file}
Number: ADR-{adr_number}
Title: {title}
Status: {status}
Size: {size_kb} KB
Validation: {validation_status}
───────────────────────────────────────
Next: Review ADR and update status to "accepted" when approved
      Command: /fractary-docs:update {output_file} --status accepted
```

If validation has warnings or errors, also display:

```
⚠️  Validation Issues:
  - [warning] Context section is short (45 chars). Minimum recommended: 50 chars.
  - [info] No alternatives section found. Consider documenting alternatives.
```

### Step 15: Return Result

Return the result JSON to the caller:

```json
{
  "success": true,
  "operation": "generate",
  "doc_type": "adr",
  "result": {
    "file_path": "docs/architecture/adrs/ADR-005-use-postgresql.md",
    "adr_number": 5,
    "title": "Use PostgreSQL for Primary Datastore",
    "status": "proposed",
    "size_bytes": 2048,
    "sections": ["Status", "Context", "Decision", "Consequences"],
    "frontmatter": {...},
    "validation": {
      "status": "passed",
      "issues": []
    }
  },
  "timestamp": "2025-01-15T12:00:00Z"
}
```

## Error Handling

### ADR Number Already Exists

```json
{
  "success": false,
  "operation": "generate",
  "doc_type": "adr",
  "error": "ADR-005 already exists. Use overwrite option to replace.",
  "error_code": "ADR_EXISTS",
  "details": {
    "existing_file": "docs/architecture/adrs/ADR-005-existing-title.md",
    "requested_number": 5
  }
}
```

### Missing Required Parameters

```json
{
  "success": false,
  "operation": "generate",
  "doc_type": "adr",
  "error": "Missing required parameters: context, decision, consequences",
  "error_code": "MISSING_PARAMS",
  "details": {
    "missing": ["context", "decision", "consequences"]
  }
}
```

### Invalid Consequences Format

```json
{
  "success": false,
  "operation": "generate",
  "doc_type": "adr",
  "error": "Consequences must include both 'positive' and 'negative' arrays",
  "error_code": "INVALID_CONSEQUENCES"
}
```

### Directory Creation Failed

```json
{
  "success": false,
  "operation": "generate",
  "doc_type": "adr",
  "error": "Failed to create ADR directory: Permission denied",
  "error_code": "PERMISSION_DENIED",
  "details": {
    "directory": "docs/architecture/adrs"
  }
}
```

## Success Criteria

ADR generation succeeds when:
- ✅ ADR number assigned (auto or specified)
- ✅ Slug generated from title
- ✅ Filename constructed: ADR-NNN-slug.md
- ✅ Template rendered with all data
- ✅ Frontmatter added with required fields
- ✅ File written to correct location
- ✅ File is valid markdown
- ✅ All required sections present
- ✅ Validation completed (warnings allowed)
- ✅ Result returned with file path and metadata

## Template Example

Given input:
```json
{
  "title": "Use PostgreSQL for Primary Datastore",
  "context": "We need a reliable database with ACID guarantees...",
  "decision": "We will use PostgreSQL 15...",
  "consequences": {
    "positive": ["ACID compliance", "Rich queries"],
    "negative": ["Operational overhead", "Scaling limits"]
  }
}
```

Generates:
```markdown
---
title: "ADR-005: Use PostgreSQL for Primary Datastore"
type: adr
status: proposed
date: "2025-01-15"
...
---

# Use PostgreSQL for Primary Datastore

## Status

proposed

## Context

We need a reliable database with ACID guarantees...

## Decision

We will use PostgreSQL 15...

## Consequences

### Positive

- ACID compliance
- Rich queries

### Negative

- Operational overhead
- Scaling limits
```

## Notes

- ADRs are immutable after acceptance, so content must be thorough
- Auto-numbering prevents gaps and ensures sequential history
- Validation ensures consistency across all ADRs
- Template system allows project-specific customization
