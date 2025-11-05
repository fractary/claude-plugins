# Workflow: Generate Architecture Decision Record (ADR)

This workflow guides the generation of an Architecture Decision Record using the ADR template.

## Overview

ADRs document significant architectural decisions including context, the decision itself, consequences, and alternatives considered.

## Required Parameters

- `number`: ADR number (string, e.g., "001", "042")
- `title`: Decision title (string)
- `status`: proposed|accepted|deprecated|superseded
- `context`: Context and problem statement
- `decision`: The decision made
- `consequences`: Object with positive[] and negative[] arrays

## Optional Parameters

- `deciders`: Who made the decision (default: "Team")
- `tags`: Array of tags
- `alternatives`: Array of alternative objects
- `references`: Array of reference objects

## Steps

### 1. Gather Decision Information

Collect the following information:
- What problem are we solving?
- What decision have we made?
- What are the positive consequences?
- What are the negative consequences?
- What alternatives did we consider and why did we reject them?

### 2. Determine ADR Number

Auto-increment from existing ADRs:
```bash
# Find highest ADR number
HIGHEST=$(ls docs/architecture/adrs/ADR-*.md 2>/dev/null | sed 's/.*ADR-\([0-9]*\).*/\1/' | sort -n | tail -1)
NEXT_NUM=$(printf "%03d" $((10#$HIGHEST + 1)))
```

### 3. Prepare Template Data

Build template data JSON:
```json
{
  "number": "001",
  "title": "Use PostgreSQL for data storage",
  "status": "proposed",
  "date": "2025-01-15",
  "author": "Claude Code",
  "deciders": "Engineering Team",
  "tags": ["database", "infrastructure"],
  "context": "We need a reliable database with ACID guarantees...",
  "decision": "We will use PostgreSQL 15 as our primary data store...",
  "consequences": {
    "positive": [
      "Strong ACID compliance ensures data integrity",
      "Rich query capabilities with SQL",
      "Mature ecosystem and tooling"
    ],
    "negative": [
      "Additional operational overhead",
      "Learning curve for team members unfamiliar with SQL"
    ]
  },
  "alternatives": [
    {
      "name": "MongoDB",
      "description": "Document database with flexible schema",
      "pros": ["Flexible schema", "Easy to get started"],
      "cons": ["Weaker consistency guarantees", "Less mature for complex queries"],
      "rejection_reason": "Our use case requires strong consistency and complex joins"
    }
  ],
  "references": [
    {
      "title": "PostgreSQL Documentation",
      "url": "https://www.postgresql.org/docs/"
    }
  ]
}
```

### 4. Prepare Front Matter

Build front matter JSON:
```json
{
  "title": "ADR-001: Use PostgreSQL for data storage",
  "type": "adr",
  "status": "proposed",
  "date": "2025-01-15",
  "author": "Claude Code",
  "tags": ["database", "infrastructure"],
  "related": [],
  "codex_sync": true,
  "generated": true
}
```

### 5. Generate Output Path

Calculate output path:
```bash
SLUG=$(echo "$TITLE" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
OUTPUT_PATH="docs/architecture/adrs/ADR-${NUMBER}-${SLUG}.md"
```

Example: `docs/architecture/adrs/ADR-001-use-postgresql-for-data-storage.md`

### 6. Invoke Generation Script

Call generate-from-template.sh:
```bash
./skills/doc-generator/scripts/generate-from-template.sh \
  --template skills/doc-generator/templates/adr.md.template \
  --data "$TEMPLATE_DATA_JSON" \
  --frontmatter "$FRONTMATTER_JSON" \
  --output "$OUTPUT_PATH" \
  --validate
```

### 7. Validate Result

Check generation result:
```json
{
  "success": true,
  "output": "docs/architecture/adrs/ADR-001-use-postgresql-for-data-storage.md",
  "validation": "passed",
  "sections": ["Context", "Decision", "Consequences", "Alternatives Considered"]
}
```

### 8. Return Structured Result

Return result to agent:
```json
{
  "success": true,
  "operation": "generate-adr",
  "file_path": "docs/architecture/adrs/ADR-001-use-postgresql-for-data-storage.md",
  "size_bytes": 2048,
  "sections": ["Context", "Decision", "Consequences", "Alternatives Considered"],
  "validation": "passed",
  "frontmatter": {
    "title": "ADR-001: Use PostgreSQL for data storage",
    "type": "adr",
    "status": "proposed",
    "codex_sync": true
  }
}
```

## Example Usage

From docs-manager agent:
```json
{
  "operation": "generate",
  "doc_type": "adr",
  "parameters": {
    "title": "Use PostgreSQL for data storage",
    "number": "001",
    "status": "proposed",
    "context": "We need a reliable database...",
    "decision": "We will use PostgreSQL 15...",
    "consequences": {
      "positive": ["Strong ACID compliance", "Rich query capabilities"],
      "negative": ["Additional operational overhead"]
    }
  },
  "options": {
    "validate_after": true
  }
}
```

## Error Handling

Common errors and solutions:

**File Already Exists**:
- Error: "File already exists: docs/architecture/adrs/ADR-001-*.md"
- Solution: Use `overwrite_existing: true` or choose different number

**Missing Required Field**:
- Error: "Missing required template variable: context"
- Solution: Ensure all required fields are provided in template_data

**Validation Failed**:
- Warning: "Missing required section: Consequences"
- Solution: Check template rendering, ensure section is generated

## Best Practices

1. **Incremental Numbers**: Always use next available number
2. **Clear Titles**: Use descriptive titles (not "Database Decision")
3. **Complete Context**: Explain the problem thoroughly
4. **List Alternatives**: Document why alternatives were rejected
5. **Update Status**: Change from "proposed" to "accepted" after approval
6. **Link Related ADRs**: Use front matter "related" field
7. **Tag Appropriately**: Use consistent tags across ADRs
