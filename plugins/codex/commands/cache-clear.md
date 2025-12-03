---
name: cache-clear
description: Clear codex cache entries (all, expired, or by pattern)
model: claude-haiku-4-5
usage: /fractary-codex:cache-clear [--all] [--expired] [--project <name>] [--pattern <glob>]
examples:
  - /fractary-codex:cache-clear --expired
  - /fractary-codex:cache-clear --project auth-service
  - /fractary-codex:cache-clear --pattern "**/*.md"
  - /fractary-codex:cache-clear --all
---

# Clear Codex Cache

Remove entries from the codex cache. Cache is ephemeral and regeneratable - clearing does not affect source documents.

## Usage

```
/fractary-codex:cache-clear [OPTIONS]
```

## Options

**At least one option is required:**

- `--all`: Clear entire cache (requires confirmation)
- `--expired`: Clear only expired cache entries
- `--project <name>`: Clear all entries for a specific project
- `--pattern <glob>`: Clear entries matching glob pattern
- `--dry-run`: Show what would be deleted without actually deleting

## Examples

**Clear expired entries (safe, no confirmation needed):**
```bash
/fractary-codex:cache-clear --expired
```

**Clear specific project:**
```bash
/fractary-codex:cache-clear --project auth-service
```

**Clear by pattern:**
```bash
/fractary-codex:cache-clear --pattern "@codex/*/README.md"
```

**Clear entire cache (requires confirmation):**
```bash
/fractary-codex:cache-clear --all
```

**Preview what would be deleted:**
```bash
/fractary-codex:cache-clear --expired --dry-run
```

## Output Format

**Dry-run:**
```
🔍 DRY-RUN: Cache Clear Preview
───────────────────────────────────────
Would delete 4 entries:

⚠ @codex/old-service/README.md (5.1 KB)
  Reason: Expired 5 days ago

⚠ @codex/deprecated/guide.md (3.2 KB)
  Reason: Expired 7 days ago

Total to delete: 8.3 KB
───────────────────────────────────────
Run without --dry-run to execute
```

**Actual deletion:**
```
🗑️  CACHE CLEAR COMPLETED
───────────────────────────────────────
Deleted 4 entries (8.3 KB):

✓ @codex/old-service/README.md
✓ @codex/deprecated/guide.md
✓ @codex/temp-service/notes.md
✓ @codex/archived/spec.md

Cache stats updated:
- Total entries: 38 (was 42)
- Total size: 3.1 MB (was 3.2 MB)
───────────────────────────────────────
Cache index updated: codex/.cache-index.json
```

## Safety Features

1. **Confirmation Required**: Clearing entire cache (`--all`) requires user confirmation
2. **Dry-run Mode**: Preview deletions before executing
3. **Atomic Updates**: Cache index is updated atomically
4. **No Source Impact**: Only affects local cache, source documents unchanged

## When to Clear Cache

**Clear expired entries regularly:**
```bash
/fractary-codex:cache-clear --expired
```

**Clear when switching contexts:**
```bash
/fractary-codex:cache-clear --project old-project
```

**Clear after major codex updates:**
```bash
/fractary-codex:cache-clear --all
```

## Cache Regeneration

All cleared entries will be automatically re-fetched when accessed:
- Next `/fractary-codex:fetch` will retrieve from source
- Cache will be repopulated with fresh content
- TTL will be reset to configured default

## Related Commands

- `/fractary-codex:fetch` - Fetch documents (populates cache)
- `/fractary-codex:cache-list` - View cache status
- `/fractary-codex:init` - Configure codex plugin

---

USE AGENT: @agent-fractary-codex:codex-manager
Operation: cache-clear
Parameters: {
  scope: <all|expired|project|pattern>,
  filter: {
    project: <from-flag>,
    pattern: <from-flag>
  },
  dry_run: <from-flag>
}
