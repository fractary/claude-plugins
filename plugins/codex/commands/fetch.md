---
name: fetch
description: Fetch a document from codex knowledge base by reference
model: claude-haiku-4-5
usage: /fractary-codex:fetch <reference> [--force-refresh] [--ttl <days>]
examples:
  - /fractary-codex:fetch @codex/auth-service/docs/oauth.md
  - /fractary-codex:fetch @codex/faber-cloud/specs/SPEC-00020.md --force-refresh
  - /fractary-codex:fetch @codex/shared/standards/api-design.md --ttl 14
---

# Fetch Document from Codex

Fetch a document from the codex knowledge base using `@codex/` reference syntax.

## Usage

```
/fractary-codex:fetch <reference> [OPTIONS]
```

## Arguments

**Required:**
- `<reference>`: Document reference in format `@codex/{project}/{path}`
  - Example: `@codex/auth-service/docs/oauth.md`
  - Example: `@codex/faber-cloud/specs/SPEC-00020.md`

**Optional:**
- `--force-refresh`: Bypass cache and fetch fresh from source
- `--ttl <days>`: Override default TTL for this document (default: 7 days)

## Examples

**Fetch document (cache-first):**
```bash
/fractary-codex:fetch @codex/auth-service/docs/oauth.md
```

**Force fresh fetch:**
```bash
/fractary-codex:fetch @codex/auth-service/docs/oauth.md --force-refresh
```

**Fetch with custom TTL:**
```bash
/fractary-codex:fetch @codex/shared/standards/api-design.md --ttl 14
```

## How It Works

1. **Cache Check**: First checks local cache (`codex/` directory)
2. **TTL Validation**: Verifies cached content is still fresh
3. **Source Fetch**: If cache miss or expired, fetches from codex repository (production branch)
4. **Cache Update**: Stores fetched content in local cache
5. **Content Return**: Returns document content with metadata

## Environment Behavior

**Important**: The fetch command always retrieves documents from the **production** branch of the codex repository. This is by design:

- **fetch** = Read-only retrieval for knowledge access (always production)
- **sync-project** = Bidirectional sync for documentation updates (environment-aware)

This separation ensures:
- AI agents always have access to stable, production-grade documentation
- Work-in-progress documentation stays in test environment until promoted
- No risk of fetching unstable test content during normal operations

**To sync with a specific environment**, use:
```bash
/fractary-codex:sync-project --env test   # Sync with test environment
/fractary-codex:sync-project --env prod   # Sync with production environment
```

## Output

**Success:**
```
✅ Document retrieved: @codex/auth-service/docs/oauth.md
Source: fractary-codex (cached)
Size: 12.3 KB
Expires: 2025-01-22T10:00:00Z

[Document content displayed]
```

**Error:**
```
❌ Document not found: @codex/auth-service/docs/invalid.md
Repository: fractary/codex.fractary.com

Suggestions:
- Verify project name is correct
- Check that document exists in codex repository
- Ensure you have access to the repository
```

## Performance

- **Cache hit**: < 100ms (fast path)
- **Cache miss**: < 2s (includes remote fetch)
- **Optimal for**: Frequently accessed documents

## Related Commands

- `/fractary-codex:cache-list` - View cached documents
- `/fractary-codex:cache-clear` - Clear cache entries
- `/fractary-codex:init` - Configure codex plugin

---

USE AGENT: @agent-fractary-codex:codex-manager
Operation: fetch
Parameters: {
  reference: <from-arg>,
  force_refresh: <from-flag>,
  ttl_override: <from-flag>
}
