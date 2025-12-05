---
model: claude-haiku-4-5
---

# /fractary-codex:health

Perform comprehensive health checks on the codex knowledge retrieval system and diagnose issues.

## Usage

```bash
# Run all health checks
/fractary-codex:health

# Run specific check category
/fractary-codex:health --check cache
/fractary-codex:health --check config
/fractary-codex:health --check permissions

# Verbose output with details
/fractary-codex:health --verbose

# Fix issues automatically (where possible)
/fractary-codex:health --fix

# Output as JSON
/fractary-codex:health --format json
```

## What It Checks

### Cache Health
- ✓ Cache directory exists and is accessible
- ✓ Cache index file exists and is valid JSON
- ✓ No corrupted cache entries
- ✓ File permissions correct
- ✓ No orphaned files (in cache but not in index)
- ✓ No missing files (in index but not in cache)

### Configuration Health
- ✓ Configuration file exists
- ✓ Configuration is valid JSON
- ✓ Required fields present
- ✓ Source configurations valid
- ✓ Handler references exist
- ✓ TTL values reasonable

### Performance Health
- ✓ Cache hit rate acceptable (> 70%)
- ✓ Average fetch time reasonable (< 3s)
- ✓ No excessive failed fetches (< 5%)
- ✓ Disk I/O performance normal

### Storage Health
- ✓ Sufficient disk space (> 1GB free)
- ✓ Cache size within limits
- ✓ No excessive growth rate
- ✓ Compression working (if enabled)

### System Health
- ✓ Git available and working
- ✓ jq available for JSON processing
- ✓ Network connectivity (for external sources)
- ✓ Permissions for cache operations

## Options

- `--check <category>`: Run specific check (cache|config|performance|storage|system)
- `--verbose`: Show detailed diagnostic information
- `--fix`: Attempt to fix detected issues automatically
- `--format <format>`: Output format (text|json) (default: text)

## Examples

```bash
# Quick health check
/fractary-codex:health

# Diagnose cache issues
/fractary-codex:health --check cache --verbose

# Fix issues automatically
/fractary-codex:health --fix

# Machine-readable output for monitoring
/fractary-codex:health --format json
```

## Sample Output

```
🏥 Codex Health Check
═══════════════════════════════════════════════════════════

CACHE HEALTH                                            ✅ PASS
────────────────────────────────────────────────────────────
✓ Cache directory exists (/project/codex)
✓ Cache index valid (.cache-index.json)
✓ All cached files accessible (156/156)
✓ No orphaned files
✓ No missing files
✓ File permissions correct

CONFIGURATION HEALTH                                    ✅ PASS
────────────────────────────────────────────────────────────
✓ Config file exists (.fractary/plugins/codex/config.json)
✓ Valid JSON format
✓ Required fields present (organization, codex_repo)
✓ All 3 sources configured correctly
✓ TTL values reasonable (7-30 days)

PERFORMANCE HEALTH                                      ⚠️  WARNING
────────────────────────────────────────────────────────────
✓ Cache hit rate good (94.5% > 70%)
✓ Average fetch time acceptable (847ms < 3s)
⚠  14 expired documents (9% of cache)
✓ Failed fetch rate low (0.2% < 5%)

Recommendation: Clear expired documents
  /fractary-codex:cache-clear --expired

STORAGE HEALTH                                          ✅ PASS
────────────────────────────────────────────────────────────
✓ Disk space sufficient (87% free, 450 GB available)
✓ Cache size reasonable (45 MB < 1000 MB limit)
✓ Growth rate normal (~5 MB/week)
! Compression disabled (could save ~30% space)

Recommendation: Enable compression in config
  {"cache": {"compression": true}}

SYSTEM HEALTH                                           ✅ PASS
────────────────────────────────────────────────────────────
✓ Git installed and accessible
✓ jq installed for JSON processing
✓ Network connectivity available
✓ Write permissions on cache directory

═══════════════════════════════════════════════════════

OVERALL STATUS: ✅ Healthy (with recommendations)

Summary:
  Checks passed:  22/24 (92%)
  Warnings:       2
  Errors:         0

Next steps:
  • Clear 14 expired documents
  • Consider enabling compression
  • System is operational and healthy
```

## Automatic Fixes

When using `--fix`, the health check will attempt to automatically repair:

- **Orphaned files**: Remove files in cache not in index
- **Missing index entries**: Rebuild index from cache contents
- **Invalid JSON**: Attempt to repair or rebuild index
- **Incorrect permissions**: Fix file permissions (Unix/Linux only)
- **Expired documents**: Clear expired cache entries
- **Corrupted entries**: Remove and log corrupted entries

## Exit Codes

- `0`: All checks passed
- `1`: Warnings present but system operational
- `2`: Errors detected, manual intervention required
- `3`: Critical failure, system unusable

## Related

- [/fractary-codex:metrics](./metrics.md) - View statistics and metrics
- [/fractary-codex:cache-list](./cache-list.md) - List cached documents
- [Troubleshooting](../docs/MIGRATION-PHASE4.md#troubleshooting) - Troubleshooting guide
