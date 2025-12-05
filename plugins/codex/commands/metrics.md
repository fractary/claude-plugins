---
model: claude-haiku-4-5
---

# /fractary-codex:metrics

Display cache statistics, performance metrics, and health information for the codex knowledge retrieval system.

## Usage

```bash
# Show all metrics
/fractary-codex:metrics

# Show specific category
/fractary-codex:metrics --category cache
/fractary-codex:metrics --category performance
/fractary-codex:metrics --category sources

# Output as JSON
/fractary-codex:metrics --format json

# Include historical data (last 7 days)
/fractary-codex:metrics --history
```

## What It Shows

### Cache Statistics
- Total cached documents
- Total cache size (MB)
- Fresh vs expired documents
- Last cleanup time
- Cache directory location

### Performance Metrics
- Cache hit rate (%)
- Average cache hit time (ms)
- Average fetch time (ms)
- Total fetches (lifetime)
- Failed fetches count

### Source Breakdown
- Documents per source
- Size per source
- Freshness by source
- TTL settings by source

### Storage Usage
- Disk space used
- Compression savings (if enabled)
- Largest documents
- Growth rate

## Options

- `--category <name>`: Show specific category (cache|performance|sources|storage)
- `--format <format>`: Output format (text|json) (default: text)
- `--history`: Include historical trends (last 7 days)
- `--reset`: Reset performance counters (requires confirmation)

## Examples

```bash
# Quick overview
/fractary-codex:metrics

# Performance analysis
/fractary-codex:metrics --category performance --history

# Machine-readable output
/fractary-codex:metrics --format json

# Storage analysis
/fractary-codex:metrics --category storage
```

## Sample Output

```
📊 Codex Knowledge Retrieval Metrics
═══════════════════════════════════════════════════════════

CACHE STATISTICS
────────────────────────────────────────────────────────────
Total Documents:        156 files
Cache Size:             45.2 MB
Fresh Documents:        142 (91%)
Expired Documents:      14 (9%)
Last Cleanup:           2 hours ago
Cache Path:             /project/codex

PERFORMANCE METRICS
────────────────────────────────────────────────────────────
Cache Hit Rate:         94.5%
Avg Cache Hit Time:     12 ms
Avg Fetch Time:         847 ms
Total Fetches:          1,247
Failed Fetches:         3 (0.2%)

SOURCE BREAKDOWN
────────────────────────────────────────────────────────────
fractary-codex:         120 docs (38.4 MB, TTL: 7 days)
external-docs:          28 docs (5.1 MB, TTL: 30 days)
context7:               8 docs (1.7 MB, TTL: 30 days)

STORAGE USAGE
────────────────────────────────────────────────────────────
Disk Space Used:        45.2 MB
Compression:            Disabled
Largest Document:       architecture.md (2.4 MB)
Growth Rate:            ~5 MB/week

HEALTH STATUS: ✅ Healthy
────────────────────────────────────────────────────────────
✓ Cache accessible
✓ Index valid
✓ No corrupted entries
✓ Disk space available (87% free)

Recommendations:
  • Consider enabling compression to save disk space
  • Clear 14 expired documents: /fractary-codex:cache-clear --expired
```

## Related

- [/fractary-codex:health](./health.md) - Detailed health checks
- [/fractary-codex:cache-list](./cache-list.md) - List cached documents
- [README](../README.md) - Full documentation
