# Update Index Workflow

This workflow regenerates the README.md index for all architecture documents.

## Purpose

The index provides a centralized catalog of all architecture documents with:
- Document titles and descriptions
- Status information
- Quick navigation links
- Document metadata

## When to Run

- After creating a new document (automatic if auto_update_index enabled)
- After updating document metadata
- After deleting documents
- Manually when index becomes out of sync

## Steps

### 1. Load Configuration

```bash
# Get architecture directory path
DOC_PATH=$(get_config_value "doc_types.architecture.path" "$PROJECT_CONFIG")
DOC_PATH="${DOC_PATH:-docs/architecture}"
```

### 2. Invoke Shared Index Updater

```bash
# Use shared index-updater library
source "$SKILL_ROOT/../_shared/lib/index-updater.sh"

# Update index with architecture-specific settings
update_index "$DOC_PATH" "architecture" "" "Architecture Documentation"
```

### 3. Verify Index Created

```bash
INDEX_FILE="$DOC_PATH/README.md"

if [[ ! -f "$INDEX_FILE" ]]; then
    echo "ERROR: Failed to create index: $INDEX_FILE" >&2
    exit 1
fi

echo "Index updated: $INDEX_FILE"
```

## Implementation Details

The shared `index-updater.sh` library handles:
- Scanning directory for all .md files (except README.md)
- Extracting frontmatter metadata (title, status, date, description)
- Sorting documents by date or title
- Generating markdown list with links
- Atomic write to README.md (safe for concurrent access)
- Timestamp in footer

## Index Structure

```markdown
# Architecture Documentation

## Overview
This directory contains N architecture document(s).

## Documents
- [**Document Title**](./filename.md) - Description *(Status: draft)*
- [**Another Document**](./other.md) - Description *(Status: approved)*

## Contributing
Guidelines for adding architecture documentation...

---
*This index is automatically generated. Do not edit manually.*
*Last updated: 2025-11-13 13:00:00 UTC*
```

## Success Criteria

- ✅ README.md exists in architecture directory
- ✅ All documents listed with correct titles
- ✅ Links are valid
- ✅ Status information included
- ✅ Timestamp updated

## Error Handling

- Directory doesn't exist → Create it first
- No documents found → Generate empty index with instructions
- Permission denied → Return error with path
- Concurrent updates → Atomic write handles this

## Notes

- Index updates are fast (<1 second for 100+ documents)
- Safe to run repeatedly (idempotent)
- Doesn't modify existing documents
- Manual edits to README.md will be overwritten
