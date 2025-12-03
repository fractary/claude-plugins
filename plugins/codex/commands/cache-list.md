---
name: cache-list
description: List documents in the codex cache with freshness status
model: claude-haiku-4-5
usage: /fractary-codex:cache-list [--expired] [--fresh] [--project <name>]
examples:
  - /fractary-codex:cache-list
  - /fractary-codex:cache-list --expired
  - /fractary-codex:cache-list --project auth-service
---

# List Codex Cache

List all documents currently cached in the local codex cache with freshness status and metadata.

## Usage

```
/fractary-codex:cache-list [OPTIONS]
```

## Options

- `--expired`: Show only expired cache entries
- `--fresh`: Show only fresh (valid) cache entries
- `--project <name>`: Filter by project name
- `--sort <field>`: Sort by field (size, cached_at, expires_at)

## Examples

**List all cached documents:**
```bash
/fractary-codex:cache-list
```

**Show only expired entries:**
```bash
/fractary-codex:cache-list --expired
```

**Filter by project:**
```bash
/fractary-codex:cache-list --project auth-service
```

**Sort by size:**
```bash
/fractary-codex:cache-list --sort size
```

## Output Format

```
📦 CODEX CACHE STATUS
───────────────────────────────────────
Total entries: 42
Total size: 3.2 MB
Fresh: 38 | Expired: 4
Last cleanup: 2025-01-15T10:00:00Z
───────────────────────────────────────

FRESH ENTRIES (38):
✓ @codex/auth-service/docs/oauth.md
  Size: 12.3 KB | Expires: 2025-01-22T10:00:00Z (6 days)

✓ @codex/faber-cloud/specs/SPEC-00020.md
  Size: 45.2 KB | Expires: 2025-01-21T14:30:00Z (5 days)

✓ @codex/shared/standards/api-design.md
  Size: 8.7 KB | Expires: 2025-01-28T09:15:00Z (12 days)

EXPIRED ENTRIES (4):
⚠ @codex/old-service/README.md
  Size: 5.1 KB | Expired: 2025-01-10T08:00:00Z (5 days ago)

⚠ @codex/deprecated/guide.md
  Size: 3.2 KB | Expired: 2025-01-08T12:00:00Z (7 days ago)

───────────────────────────────────────
Use /fractary-codex:cache-clear to remove entries
Use /fractary-codex:fetch --force-refresh to refresh
```

## Understanding Status Indicators

- **✓ Fresh**: Cache entry is valid and within TTL
- **⚠ Expired**: Cache entry has exceeded TTL (will be refreshed on next fetch)
- **Size**: Uncompressed document size
- **Expires/Expired**: TTL status with relative time

## Cache Location

Cache is stored in: `codex/` (ephemeral, gitignored, regeneratable)

## Related Commands

- `/fractary-codex:fetch` - Fetch documents (populates cache)
- `/fractary-codex:cache-clear` - Clear cache entries
- `/fractary-codex:init` - Configure codex plugin

---

USE AGENT: @agent-fractary-codex:codex-manager
Operation: cache-list
Parameters: {
  filter: {
    expired: <from-flag>,
    fresh: <from-flag>,
    project: <from-flag>
  },
  sort: <from-flag>
}
