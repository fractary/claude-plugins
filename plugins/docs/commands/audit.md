# /docs:audit

Audit documentation across the project - identify issues, gaps, and quality problems.

## Usage

```bash
/docs:audit [directory] [--doc-type <type>]
```

## Arguments

- `[directory]` - Directory to audit (default: docs/)
- `--doc-type <type>` - Filter audit to specific doc type

## Examples

```bash
# Audit all documentation
/docs:audit

# Audit specific directory
/docs:audit docs/api

# Audit only API documentation
/docs:audit --doc-type api

# Audit datasets
/docs:audit docs/datasets --doc-type dataset
```

## What This Does

1. **Scan Documentation**
   - Find all markdown files
   - Classify by doc_type
   - Extract metadata from frontmatter

2. **Analyze Current State**
   - Count documents by type and status
   - Identify missing indices
   - Find validation issues
   - Check for missing fractary_doc_type fields

3. **Generate Report**
   ```
   ═══════════════════════════════════════
   DOCUMENTATION AUDIT REPORT
   ═══════════════════════════════════════

   Summary:
     Total Documents: 156
     Document Types: 8
     Missing Indices: 2
     Validation Issues: 5

   By Type:
     api             45 documents
     adr             32 documents
     guide           28 documents
     dataset         18 documents
     ...

   Issues Found:
     ⚠️  docs/api/deprecated/: Missing index
     ❌ docs/dataset/metrics.md: Missing fractary_doc_type
   ```

4. **Return Actionable Results**
   - Summary with counts
   - Breakdown by type and status
   - List of issues to fix
   - Suggested next steps

## Output

### Summary
- Total document count
- Document types found
- Missing indices count
- Validation issues count

### By Type
- Document count per type
- Status distribution

### By Status
- draft, published, deprecated counts

### Issues
- Missing indices
- Missing fractary_doc_type fields
- Validation errors
- Structural problems

## Related Commands

- `/docs:write` - Create or update documentation
- `/docs:validate` - Validate specific documents
- `/docs:list` - List documentation files

---

Use the @agent-fractary-docs:docs-manager agent to handle this audit request.
