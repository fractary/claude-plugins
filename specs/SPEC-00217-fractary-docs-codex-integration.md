# Fractary-Docs Codex Integration

**Specification ID**: SPEC-00217
**Status**: Draft
**Created**: 2025-01-15
**Related Specs**: SPEC-00033 (Codex MCP Server), SPEC-00216 (Implementation Plan)

---

## Overview

This specification defines how the fractary-docs plugin should integrate with the codex plugin to ensure portable document references in syncable documentation.

## Problem Statement

Documents marked for sync (via `codex_sync_include: true` frontmatter) will be copied to other projects. Any relative or non-portable references in these docs will break when synced:

```markdown
---
codex_sync_include: true
---

# Integration Guide

<!-- These break when synced to other projects -->
See [Schema Docs](../schema/overview.md)
See [API Reference](/docs/api/endpoints.md)

<!-- These work everywhere -->
See [Schema Docs](codex://corthosai/etl.corthion.ai/docs/schema/overview.md)
See [API Reference](codex://corthosai/etl.corthion.ai/docs/api/endpoints.md)
```

## Solution

### 1. Writing Phase Enforcement

When the doc-writer skill creates or updates a document with `codex_sync_include: true`:

1. **Detect non-portable references** during write
2. **Auto-convert** relative/absolute paths to `codex://` format
3. **Log conversions** to user for visibility

#### Implementation

**File**: `plugins/docs/skills/doc-writer/workflow/write-doc.md`

Add reference conversion step:

```markdown
## Step: Convert References for Syncable Docs

If the document has `codex_sync_include: true` in frontmatter:

1. Scan for markdown links: `[text](path)`
2. For each link that is NOT:
   - A `codex://` URI
   - An external URL (http://, https://)
   - An anchor link (#section)
   - A same-folder relative (./file.md)
3. Convert to `codex://` format:
   - Read org/project from `.fractary/plugins/codex/config.json`
   - Resolve relative path to absolute path within project
   - Format as: `codex://{org}/{project}/{resolved-path}`
4. Log conversions for user visibility
```

### 2. Validation Phase Enforcement

The doc-validator skill should check syncable docs for non-portable references:

**File**: `plugins/docs/skills/doc-validator/workflow/validate.md`

```markdown
## Step: Validate Syncable Doc References

For each document with `codex_sync_include: true`:

1. Extract all markdown links
2. Flag any link that:
   - Uses relative parent paths (../)
   - Uses absolute paths (/)
   - Uses deprecated @codex/ format
   - Is not a codex:// URI, external URL, or anchor
3. Generate suggested fix using current org/project
4. If --fix flag: apply conversions automatically
5. Report results with line numbers
```

### 3. Enhanced Validation Command

**Command**: `/fractary-docs:validate`

Add syncable doc reference checking:

```
$ /fractary-docs:validate

Validating documentation...

Syncable docs with non-portable references:

docs/guides/integration.md (codex_sync_include: true)
  Line 15: [Schema Docs](../schema/overview.md)
           Fix: codex://corthosai/etl.corthion.ai/docs/schema/overview.md
  Line 23: [API Endpoints](/docs/api/endpoints.md)
           Fix: codex://corthosai/etl.corthion.ai/docs/api/endpoints.md

Found 2 non-portable references in 1 syncable doc.
Run with --fix to automatically convert.
```

### 4. Auto-Fix Option

```
$ /fractary-docs:validate --fix

Converting non-portable references in syncable docs...

docs/guides/integration.md: 2 references converted

All syncable docs now use portable codex:// references.
```

---

## Implementation Tasks

### Task 1: Add org/project detection
**File**: `plugins/docs/lib/codex-integration.sh`

Read from `.fractary/plugins/codex/config.json`:
- Extract `organization` and `project_name`
- Fall back to git remote parsing if not found
- Used for generating correct `codex://` URIs

### Task 2: Update doc-writer skill
**File**: `plugins/docs/skills/doc-writer/workflow/write-doc.md`

- Add syncable doc detection
- Add reference scanning
- Add auto-conversion logic
- Add user notification

### Task 3: Update doc-validator skill
**File**: `plugins/docs/skills/doc-validator/workflow/validate.md`

- Add syncable doc reference check
- Generate fix suggestions with line numbers
- Report summary of issues

### Task 4: Implement --fix option
**File**: `plugins/docs/scripts/fix-refs.sh`

- Parse markdown links in syncable docs
- Convert non-portable references to `codex://` format
- Preserve link text and formatting
- Write updated content back to file

### Task 5: Create integration tests
- Test reference conversion during write
- Test validation detection
- Test --fix auto-conversion
- Test cross-org reference handling

---

## Reference Conversion Rules

| Original Reference | Converted Reference |
|-------------------|---------------------|
| `../schema/overview.md` | `codex://{org}/{project}/docs/schema/overview.md` |
| `/docs/api/endpoints.md` | `codex://{org}/{project}/docs/api/endpoints.md` |
| `@codex/project/path.md` | `codex://{org}/project/path.md` |

### Exceptions (No Conversion)

| Reference Type | Example | Reason |
|---------------|---------|--------|
| Same folder | `./sibling.md` | Always resolves correctly |
| Anchor | `#section` | Internal navigation |
| External URL | `https://...` | Not affected by sync |
| Already portable | `codex://...` | Already correct |

---

## Configuration

The docs plugin reads codex configuration from:

```json
// .fractary/plugins/codex/config.json
{
  "organization": "corthosai",
  "project_name": "etl.corthion.ai"
}
```

If not found, falls back to git remote parsing.

---

## Dependencies

- **Requires**: fractary-codex plugin configured with `organization` and `project_name`
- **Optional**: Works without codex plugin (validation warns but doesn't convert)

---

## Testing Scenarios

| Scenario | Expected Result |
|----------|-----------------|
| Write syncable doc with relative ref | Auto-converted to `codex://` |
| Write non-syncable doc with relative ref | Left unchanged |
| Validate syncable doc with `../file.md` | Warning with fix suggestion |
| Validate with --fix | Refs converted, file updated |
| Cross-org reference in syncable | Already portable |
| Anchor links in syncable | Ignored |
| External URLs in syncable | Ignored |
