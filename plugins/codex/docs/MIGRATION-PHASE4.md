# Migration Guide: SPEC-00012 to SPEC-00030 (Phase 4)

This guide helps you migrate from the **push-based sync system** (SPEC-00012, Codex v2.0) to the **pull-based knowledge retrieval system** (SPEC-00030, Codex v3.0).

## Table of Contents

1. [Overview](#overview)
2. [Why Migrate?](#why-migrate)
3. [Migration Timeline](#migration-timeline)
4. [Prerequisites](#prerequisites)
5. [Step-by-Step Migration](#step-by-step-migration)
6. [Configuration Conversion](#configuration-conversion)
7. [Command Mapping](#command-mapping)
8. [Rollback Procedures](#rollback-procedures)
9. [FAQ](#faq)
10. [Troubleshooting](#troubleshooting)

## Overview

### What's Changing?

**Old System (v2.0 - Push-based Sync)**:
- Documents were **pushed** to codex repository
- Bidirectional sync (`sync-project`, `sync-org`)
- Centralized storage in codex repository
- Manual sync operations required

**New System (v3.0 - Pull-based Retrieval)**:
- Documents are **pulled** on-demand from sources
- Local cache with TTL-based freshness
- Multi-source support (GitHub, HTTP, S3, MCP)
- Automatic cache management

### Migration Stages

The migration follows a **4-stage rollout over 6-12 months**:

| Stage | Timeline | Status | Description |
|-------|----------|--------|-------------|
| **Stage 1** | Months 0-3 | Current | Publish-only, opt-in retrieval |
| **Stage 2** | Months 3-6 | Planned | Retrieval adoption, disable pull-sync |
| **Stage 3** | Months 6-9 | Planned | Full migration, rename commands |
| **Stage 4** | Months 9-12 | Planned | Deprecation complete |

## Why Migrate?

### Benefits of Pull-based Retrieval

1. **Performance**: 10-50ms cache hits (vs 1-3s sync operations)
2. **Flexibility**: Support multiple documentation sources simultaneously
3. **Scalability**: No single-repository bottleneck
4. **Simplicity**: No manual sync required
5. **Offline-first**: Works with local cache when offline

### Comparison

| Feature | v2.0 (Push) | v3.0 (Pull) |
|---------|-------------|-------------|
| **Access Speed** | 1-3s | 10-50ms (cached) |
| **Sources** | 1 (codex repo) | Unlimited |
| **Manual Sync** | Required | Optional |
| **Offline Access** | Limited | Full (cached) |
| **Permission Control** | Repo-level | Document-level |
| **MCP Support** | No | Yes |

## Migration Timeline

### Stage 1: Publish-only, Opt-in Retrieval (Months 0-3)

**Status**: Current

**What happens**:
- Old push-based sync still works
- New retrieval system available for testing
- Codex repository remains source of truth

**Actions required**:
- ✅ None (backwards compatible)
- ⚠️ Start testing retrieval commands

**Commands available**:
- Legacy: `/fractary-codex:sync-project`, `/fractary-codex:sync-org` (still work)
- New: `/fractary-codex:fetch`, `/fractary-codex:cache-list` (opt-in)

### Stage 2: Retrieval Adoption, Disable Pull-sync (Months 3-6)

**Status**: Planned

**What happens**:
- Push operations to codex still work
- Pull operations from codex (bidirectional sync) deprecated
- Retrieval becomes recommended approach

**Actions required**:
- ⚠️ Migrate configurations (run `/fractary-codex:migrate`)
- ⚠️ Test retrieval workflows
- ⚠️ Update team documentation

**Commands available**:
- Deprecated: `/fractary-codex:sync-org` (pull direction)
- Working: `/fractary-codex:sync-project` (push only)
- Recommended: `/fractary-codex:fetch`, `/fractary-codex:cache-prefetch`

### Stage 3: Full Migration, Rename Commands (Months 6-9)

**Status**: Planned

**What happens**:
- All sync commands show deprecation warnings
- Retrieval is the standard approach
- Codex repository becomes one of many sources

**Actions required**:
- ✅ Complete configuration migration
- ✅ Switch to retrieval commands
- ✅ Update CI/CD pipelines

**Commands available**:
- Deprecated (with warnings): All `/fractary-codex:sync-*` commands
- Standard: All `/fractary-codex:fetch` and `/fractary-codex:cache-*` commands

### Stage 4: Deprecation Complete (Months 9-12)

**Status**: Planned

**What happens**:
- Sync commands removed entirely
- Retrieval is the only approach
- Old configurations no longer supported

**Actions required**:
- ✅ All teams migrated
- ✅ Old configs removed

## Prerequisites

Before migrating, ensure you have:

1. **Codex v3.0+** installed:
   ```bash
   grep '"version"' plugins/codex/.claude-plugin/plugin.json
   # Should show: "version": "3.0.0" or higher
   ```

2. **Git repository** with existing codex sync configuration

3. **Backup** of current configuration:
   ```bash
   cp .fractary/plugins/codex/config.json .fractary/plugins/codex/config.json.backup
   ```

4. **Access** to all documentation sources (GitHub tokens, etc.)

## Step-by-Step Migration

### Option 1: Automated Migration (Recommended)

Use the migration script to automatically convert your configuration:

```bash
# Run migration script
/fractary-codex:migrate

# Or with preview (dry-run):
/fractary-codex:migrate --dry-run
```

The script will:
1. Detect your current SPEC-00012 configuration
2. Convert to SPEC-00030 format
3. Preserve all settings
4. Create backup of old config
5. Test new configuration

### Option 2: Manual Migration

If you prefer manual migration or have custom configuration:

#### Step 1: Update Configuration Format

**Old format** (`.fractary/plugins/codex/config.json`):
```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": {
    "include": ["*.md", "*.json"],
    "exclude": ["temp/**"]
  }
}
```

**New format** (same file):
```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "permissions": {
        "enabled": true
      },
      "cache": {
        "ttl_days": 7
      }
    }
  ]
}
```

#### Step 2: Add Frontmatter Permissions (Optional)

If you had project-specific sync patterns, convert to frontmatter:

**Old approach** (config-based):
```json
{
  "sync_patterns": {
    "include": ["auth-service/**"]
  }
}
```

**New approach** (frontmatter in docs):
```markdown
---
codex_sync_include:
  - auth-service
  - payment-service
---

# Your document content
```

#### Step 3: Test Retrieval

Verify retrieval works with your configuration:

```bash
# Fetch a document
/fractary-codex:fetch @codex/your-project/docs/test.md

# Check cache
/fractary-codex:cache-list

# Verify content
cat codex/your-project/docs/test.md
```

#### Step 4: Update Workflows

Replace sync commands with retrieval commands:

**Old workflow**:
```bash
# Pull latest from codex
/fractary-codex:sync-project my-project --from-codex

# Make changes...

# Push back to codex
/fractary-codex:sync-project my-project --to-codex
```

**New workflow**:
```bash
# Fetch on-demand
/fractary-codex:fetch @codex/my-project/docs/architecture.md

# Changes are fetched automatically when needed
# No manual sync required!
```

#### Step 5: Enable MCP (Optional)

For Claude Desktop/Code integration:

```bash
# Build MCP server
cd plugins/codex/mcp-server
npm install
npm run build

# Configure Claude (see MCP-INTEGRATION.md)
# Restart Claude
```

## Configuration Conversion

### Full Configuration Example

**Before (v2.0)**:
```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sync_patterns": {
    "include": ["*.md", "*.json", "docs/**"],
    "exclude": ["temp/**", "*.draft.md"]
  },
  "auto_sync": false,
  "batch_size": 10
}
```

**After (v3.0)**:
```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "permissions": {
        "enabled": true,
        "default_policy": "allow"
      },
      "cache": {
        "enabled": true,
        "ttl_days": 7,
        "max_size_mb": 1000,
        "compression": true
      }
    }
  ],
  "performance": {
    "parallel_fetches": 10,
    "cache_strategy": "memory+disk",
    "compression_level": 6
  }
}
```

### Pattern Migration

| Old Pattern | New Approach |
|-------------|--------------|
| `sync_patterns.include` | Frontmatter `codex_sync_include` |
| `sync_patterns.exclude` | Frontmatter `codex_sync_exclude` |
| `auto_sync: true` | Not needed (retrieval is on-demand) |
| `batch_size` | `performance.parallel_fetches` |

## Command Mapping

### Deprecated Commands → New Commands

| Old Command (v2.0) | New Command (v3.0) | Notes |
|--------------------|-------------------|-------|
| `/fractary-codex:sync-project --from-codex` | `/fractary-codex:fetch @codex/{project}/**` | Fetch specific docs |
| `/fractary-codex:sync-project --to-codex` | _Not needed_ | Publish to codex repo directly |
| `/fractary-codex:sync-org` | `/fractary-codex:cache-prefetch` | Pre-fetch multiple projects |
| `/fractary-codex:sync-status` | `/fractary-codex:metrics` | View cache statistics |
| _N/A_ | `/fractary-codex:cache-list` | List cached documents |
| _N/A_ | `/fractary-codex:cache-clear` | Clear expired cache |
| _N/A_ | `/fractary-codex:health` | Check system health |

### Command Examples

**Fetching documents**:
```bash
# Old (v2.0)
/fractary-codex:sync-project auth-service --from-codex

# New (v3.0)
/fractary-codex:fetch @codex/auth-service/docs/oauth.md
/fractary-codex:fetch @codex/auth-service/docs/**  # wildcard support
```

**Cache management**:
```bash
# Old (v2.0)
# No equivalent - manual cleanup

# New (v3.0)
/fractary-codex:cache-list                    # View cache
/fractary-codex:cache-list --expired          # Show expired only
/fractary-codex:cache-clear --expired         # Clean expired
/fractary-codex:metrics                       # View statistics
```

**Pre-fetching**:
```bash
# Old (v2.0)
/fractary-codex:sync-org fractary --from-codex

# New (v3.0)
/fractary-codex:cache-prefetch                # Scan project for @codex/ refs
/fractary-codex:cache-prefetch --all-sources  # Prefetch from all sources
```

## Rollback Procedures

If you encounter issues, you can rollback to v2.0:

### Quick Rollback

```bash
# 1. Restore old configuration
cp .fractary/plugins/codex/config.json.backup .fractary/plugins/codex/config.json

# 2. Clear new cache
rm -rf codex/.cache-index.json

# 3. Use old sync commands
/fractary-codex:sync-project your-project --from-codex
```

### Full Rollback

If you need to completely revert:

```bash
# 1. Checkout v2.0 plugin
cd plugins/codex
git checkout v2.0.0

# 2. Restore configuration
cp .fractary/plugins/codex/config.json.backup .fractary/plugins/codex/config.json

# 3. Remove v3.0 cache
rm -rf codex/

# 4. Restart Claude Code
```

## FAQ

### Q: Do I need to migrate immediately?

**A**: No. During Stage 1 (months 0-3), both systems work. You can migrate at your own pace.

### Q: Will my existing sync still work?

**A**: Yes, until Stage 4 (months 9-12). You have 6-9 months to migrate.

### Q: Can I use both systems during migration?

**A**: Yes! You can use sync commands for publishing and retrieval commands for fetching.

### Q: What happens to my codex repository?

**A**: It remains a valid documentation source. In v3.0, it's one of potentially many sources.

### Q: Do I lose any functionality?

**A**: No. v3.0 is a superset of v2.0 features with better performance.

### Q: How do I publish documents in v3.0?

**A**: Publishing workflows are separate from retrieval. Continue using your current publish process (git push, CI/CD, etc.)

### Q: Can I have multiple documentation sources?

**A**: Yes! That's one of the main benefits. Configure multiple sources in `config.json`.

### Q: What about offline access?

**A**: Better than v2.0! Local cache provides full offline access to previously fetched docs.

### Q: How do I know if cache is stale?

**A**: Use `/fractary-codex:cache-list` to see cache age and freshness. Expired docs are automatically refetched.

### Q: Can I customize TTL per source?

**A**: Yes. Configure `cache.ttl_days` in each source configuration.

## Troubleshooting

### Issue: Migration script fails

**Symptoms**: `/fractary-codex:migrate` shows errors

**Solutions**:
1. Check you have valid v2.0 configuration:
   ```bash
   cat .fractary/plugins/codex/config.json
   ```

2. Verify file permissions:
   ```bash
   ls -la .fractary/plugins/codex/
   ```

3. Run with debug logging:
   ```bash
   /fractary-codex:migrate --debug
   ```

### Issue: Fetch fails after migration

**Symptoms**: `/fractary-codex:fetch` returns errors

**Solutions**:
1. Verify source configuration:
   ```bash
   cat .fractary/plugins/codex/config.json
   ```

2. Check permissions on document:
   ```bash
   /fractary-codex:fetch @codex/project/path --verbose
   ```

3. Test with simple reference:
   ```bash
   /fractary-codex:fetch @codex/README.md
   ```

### Issue: Cache not updating

**Symptoms**: Old content returned

**Solutions**:
1. Check cache freshness:
   ```bash
   /fractary-codex:cache-list --expired
   ```

2. Force refetch:
   ```bash
   /fractary-codex:cache-clear --path project/path
   /fractary-codex:fetch @codex/project/path
   ```

3. Verify TTL settings in config

### Issue: Performance slower than expected

**Symptoms**: Cache hits slower than 50ms

**Solutions**:
1. Enable compression:
   ```json
   {"cache": {"compression": true}}
   ```

2. Increase parallel fetches:
   ```json
   {"performance": {"parallel_fetches": 20}}
   ```

3. Check cache size:
   ```bash
   /fractary-codex:metrics
   ```

### Issue: MCP resources not appearing

**Symptoms**: `codex://` URIs don't work

**Solutions**:
1. Verify MCP server built:
   ```bash
   ls plugins/codex/mcp-server/dist/
   ```

2. Check Claude configuration:
   ```bash
   cat .claude/config.json
   ```

3. Restart Claude completely

4. Check cache exists:
   ```bash
   ls -la codex/.cache-index.json
   ```

## Next Steps

After successful migration:

1. **Update Documentation**: Update your team's docs to use new commands
2. **CI/CD Integration**: Update automated workflows
3. **Enable MCP**: Set up MCP server for Claude Desktop/Code
4. **Explore Multi-Source**: Add additional documentation sources
5. **Monitor Performance**: Use `/fractary-codex:metrics` to track usage

## Related Documentation

- [README.md](../README.md) - Full v3.0 documentation
- [MCP-INTEGRATION.md](./MCP-INTEGRATION.md) - MCP server setup
- [SPEC-00030](./specs/SPEC-00030-01-overview.md) - Technical specification

## Support

If you encounter issues during migration:

1. Check this troubleshooting guide
2. Review [GitHub Issues](https://github.com/fractary/claude-plugins/issues)
3. Consult the team in #codex-support

---

**Migration Status**: Stage 1 (Months 0-3) - Both systems fully supported
**Last Updated**: 2025-01-07
