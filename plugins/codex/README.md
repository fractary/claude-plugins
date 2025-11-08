# Fractary Codex Plugin

**Knowledge retrieval and documentation sync** - A memory fabric for AI agents with cache-first retrieval, multi-source support, and MCP integration.

> **Version 3.0** - Major architectural update: Pull-based retrieval with local caching, multi-source support, and MCP protocol integration.

## Overview

The codex plugin provides intelligent knowledge retrieval and documentation synchronization across organization projects. It implements a cache-first retrieval architecture with support for multiple sources (GitHub, external URLs, MCP servers) and fine-grained permission control.

### The Problem

AI agents working across multiple projects need:
- **Fast access** to organizational knowledge (docs, standards, specs)
- **Consistent context** across project boundaries
- **Multi-source integration** (internal docs, external APIs, knowledge bases)
- **Permission control** to protect sensitive documentation
- **Offline access** to frequently used content

Traditional approaches (push-sync, API calls) are slow, expensive, and don't scale.

### The Solution

**Pull-based retrieval with intelligent caching:**

```
Request @codex/project/docs/api.md
         ↓
  Check local cache (< 100ms)
         ↓ (if expired/missing)
  Fetch from source (< 2s)
         ↓
  Cache locally with TTL
         ↓
  Return content
```

**Key Benefits:**
- ⚡ **Fast**: < 100ms cache hits, < 2s cache misses
- 🔒 **Secure**: Frontmatter-based permission control
- 🌐 **Multi-source**: GitHub, HTTP URLs, MCP servers
- 📱 **Dual-mode**: Plugin commands + MCP resources
- 💾 **Offline**: Cached content available without network

---

## Quick Start

### 1. Fetch a Document

```bash
/fractary-codex:fetch @codex/auth-service/docs/oauth.md
```

This will:
- Check local cache first (fast path)
- Fetch from codex repository if needed
- Cache locally with 7-day TTL
- Return the content

### 2. Browse Cached Documents

```bash
/fractary-codex:cache-list
```

Shows all cached documents with freshness status.

### 3. Use MCP Resources (Optional)

After configuring the MCP server (see [MCP Integration](#mcp-integration)):

```
codex://auth-service/docs/oauth.md
```

Access cached documents via `codex://` URIs in Claude Desktop or Claude Code.

---

## Architecture

### Three-Phase Implementation

The codex plugin implements a progressive architecture across three phases:

#### Phase 1: Local Cache & Reference System ✅
- **@codex/** reference syntax for universal document addressing
- **Cache-first retrieval** with TTL-based freshness (< 100ms cache hit)
- **GitHub sparse checkout** for efficient remote fetching (< 2s)
- **Atomic cache operations** with index-based metadata

#### Phase 2: Multi-Source Support & Permissions ✅
- **Source routing** to multiple backends (GitHub, HTTP, S3, local)
- **Handler abstraction** for pluggable source adapters
- **Frontmatter permissions** with whitelist/blacklist patterns
- **External URL fetching** with safety checks and retries

#### Phase 3: MCP Integration ✅
- **MCP server** exposing cache as resources (codex:// URIs)
- **Resource protocol** for Claude Desktop/Code integration
- **Dual-mode access** (plugin commands + MCP resources)
- **Context7 integration** (documented, hybrid caching)

#### Phase 4: Migration & Optimization ✅
- **Migration tooling** from v2.0 (push-sync) to v3.0 (pull-retrieval)
- **Deprecation warnings** on legacy commands with 6-9 month timeline
- **Metrics & monitoring** (cache hit rate, performance tracking)
- **Health checks** (diagnostics, auto-repair, system validation)
- **Performance optimizations** (10-50ms cache hits, improved indexing)

### Architecture Diagram

```
┌─────────────────────────────────────────────────┐
│         Fractary Codex Architecture              │
├─────────────────────────────────────────────────┤
│                                                  │
│  Access Layer (Dual-Mode)                       │
│  ├─ Plugin Commands  (/fractary-codex:fetch)    │
│  └─ MCP Resources    (codex://{project}/{path}) │
│                                                  │
│  Routing Layer                                  │
│  ├─ Reference Parser  (@codex/ → components)    │
│  └─ Source Router     (determine handler)       │
│                                                  │
│  Source Handlers                                │
│  ├─ GitHub Handler    (sparse checkout)         │
│  ├─ HTTP Handler      (external URLs)           │
│  └─ MCP Handler       (future: Context7)        │
│                                                  │
│  Permission Layer                               │
│  └─ Frontmatter-based access control            │
│                                                  │
│  Cache Layer (< 100ms)                          │
│  ├─ Local filesystem  (codex/{project}/{path})  │
│  ├─ Cache index       (.cache-index.json)       │
│  └─ TTL management    (default: 7 days)         │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## Features

### 📚 Knowledge Retrieval

**@codex/ Reference Syntax:**
```
@codex/{project}/{path}

Examples:
  @codex/auth-service/docs/oauth.md
  @codex/faber-cloud/specs/SPEC-0020.md
  @codex/shared/standards/api-design.md
```

Perfect path alignment: `@codex/project/path` → `codex/project/path`

**Cache-First Strategy:**
1. Check local cache (< 100ms if fresh)
2. Validate TTL (default: 7 days)
3. Fetch from source if expired/missing (< 2s)
4. Store in cache with metadata
5. Return content

**Performance:**
- Cache hit: < 100ms ✅
- Cache miss: < 2s (GitHub sparse checkout) ✅
- Permission check: < 50ms ✅

### 🌐 Multi-Source Support

**Supported Sources:**
- **GitHub** (codex repositories): Sparse checkout, branch selection
- **HTTP/HTTPS** (external docs): Safety checks, retries, metadata extraction
- **MCP Servers** (future): Context7, custom MCP providers
- **S3/R2** (future): Cloud storage backends
- **Local** (future): Filesystem sources

**Source Configuration:**
```json
{
  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "handler_config": {
        "org": "fractary",
        "repo": "codex.fractary.com",
        "branch": "main"
      },
      "cache": {"ttl_days": 7},
      "permissions": {"enabled": true}
    },
    {
      "name": "external-docs",
      "type": "external-url",
      "handler": "http",
      "url_pattern": "https://docs.example.com/**",
      "cache": {"ttl_days": 30}
    }
  ]
}
```

### 🔒 Permission Control

**Frontmatter-Based Permissions:**

Documents can declare access control in YAML frontmatter:

```yaml
---
codex_sync_include:
  - auth-service        # Exact project match
  - *-service           # Wildcard suffix
  - shared/team-*       # Directory pattern
  - "*"                 # Public (all projects)
codex_sync_exclude:
  - temp-*              # Exclusion (takes precedence)
  - project-sensitive
---

# Document content...
```

**Permission Rules:**
1. Check exclude list (deny if matched)
2. Check include list (allow if matched)
3. If include = `["*"]` → public access
4. Default: deny if not in include list

**Pattern Matching:**
- `*` - Wildcard matching
- `prefix-*` - Prefix matching
- `*-suffix` - Suffix matching
- Exclusions take precedence over inclusions

### 🎯 MCP Integration

**Resource Protocol:**

Expose cached documents as MCP resources using `codex://` URIs:

```
codex://{project}/{path}

Examples:
  codex://auth-service/docs/oauth.md
  codex://shared/standards/api-guide.md
```

**Usage in Claude:**
```
Can you explain the OAuth flow in codex://auth-service/docs/oauth.md?

Based on codex://shared/standards/api-guide.md, how should I...?
```

**MCP Server Features:**
- Resource listing (browse all cached documents)
- Resource reading (fetch content by URI)
- Cache status tool (view statistics)
- Automatic freshness indicators

See [MCP Integration Guide](./docs/MCP-INTEGRATION.md) for setup.

### 💾 Intelligent Caching

**Cache Structure:**
```
codex/                          # Ephemeral cache (gitignored)
├── .cache-index.json          # Metadata index
├── auth-service/
│   └── docs/
│       └── oauth.md           # Cached document
└── shared/
    └── standards/
        └── api-design.md
```

**Cache Index:**
```json
{
  "version": "1.0",
  "entries": [{
    "reference": "@codex/auth-service/docs/oauth.md",
    "path": "auth-service/docs/oauth.md",
    "source": "fractary-codex",
    "cached_at": "2025-01-15T10:00:00Z",
    "expires_at": "2025-01-22T10:00:00Z",
    "ttl_days": 7,
    "size_bytes": 12543,
    "hash": "abc123...",
    "last_accessed": "2025-01-15T10:00:00Z"
  }],
  "stats": {
    "total_entries": 42,
    "total_size_bytes": 3200000,
    "last_cleanup": "2025-01-15T09:00:00Z"
  }
}
```

**Cache Management:**
- Automatic TTL expiration
- Manual refresh via `--force-refresh`
- Selective clearing (expired, by project, by pattern)
- Size monitoring and cleanup

---

## Commands

### `/fractary-codex:fetch`

Fetch a document from codex by reference.

**Usage:**
```bash
/fractary-codex:fetch @codex/project/path

# Force refresh (bypass cache)
/fractary-codex:fetch @codex/project/path --force-refresh

# Custom TTL (override default)
/fractary-codex:fetch @codex/project/path --ttl 14
```

**Examples:**
```bash
# Fetch OAuth documentation
/fractary-codex:fetch @codex/auth-service/docs/oauth.md

# Fetch specification with longer TTL
/fractary-codex:fetch @codex/faber-cloud/specs/SPEC-0020.md --ttl 30

# Force fresh fetch from source
/fractary-codex:fetch @codex/shared/standards/api.md --force-refresh
```

**Output:**
```
✅ Document retrieved: @codex/auth-service/docs/oauth.md
Source: fractary-codex (cached)
Size: 12.3 KB
Expires: 2025-01-22T10:00:00Z
Fetch time: 156ms

[Document content displayed]
```

### `/fractary-codex:cache-list`

List cached documents with freshness status.

**Usage:**
```bash
/fractary-codex:cache-list                    # All entries
/fractary-codex:cache-list --fresh            # Only fresh
/fractary-codex:cache-list --expired          # Only expired
/fractary-codex:cache-list --project auth-service
/fractary-codex:cache-list --sort size        # Sort by size
```

**Output:**
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
  Size: 12.3 KB | Expires: 2025-01-22 (6 days)

✓ @codex/faber-cloud/specs/SPEC-0020.md
  Size: 45.2 KB | Expires: 2025-01-21 (5 days)

EXPIRED ENTRIES (4):
⚠ @codex/old-service/README.md
  Size: 5.1 KB | Expired: 2025-01-10 (5 days ago)
```

### `/fractary-codex:cache-clear`

Clear cache entries by filter.

**Usage:**
```bash
/fractary-codex:cache-clear --expired         # Clear expired (safe)
/fractary-codex:cache-clear --project auth-service
/fractary-codex:cache-clear --pattern "**/*.md"
/fractary-codex:cache-clear --all             # Clear everything (requires confirmation)
/fractary-codex:cache-clear --dry-run         # Preview first
```

**Safety Features:**
- `--all` requires confirmation
- `--dry-run` previews before deletion
- Atomic index updates
- Only affects cache (source documents unchanged)

### `/fractary-codex:migrate`

Migrate configuration from v2.0 (push-based sync) to v3.0 (pull-based retrieval).

**Usage:**
```bash
/fractary-codex:migrate                   # Interactive migration
/fractary-codex:migrate --dry-run         # Preview changes
/fractary-codex:migrate --yes             # Auto-confirm
/fractary-codex:migrate --force           # Re-migrate if already v3.0
```

**What it does:**
- Detects v2.0 configuration
- Converts to v3.0 format with `sources` array
- Creates backup of old configuration
- Validates new configuration
- Provides rollback instructions

**See:** [MIGRATION-PHASE4.md](docs/MIGRATION-PHASE4.md) for complete migration guide

### `/fractary-codex:metrics`

Display cache statistics, performance metrics, and health information.

**Usage:**
```bash
/fractary-codex:metrics                     # Show all metrics
/fractary-codex:metrics --category cache    # Cache stats only
/fractary-codex:metrics --format json       # Machine-readable output
/fractary-codex:metrics --history           # Include trends (7 days)
```

**Metrics shown:**
- **Cache**: Total docs, size, fresh/expired ratio
- **Performance**: Hit rate, avg times, failed fetches
- **Sources**: Documents per source, size breakdown
- **Storage**: Disk usage, compression savings

**Example output:**
```
📊 Codex Knowledge Retrieval Metrics
═══════════════════════════════════════

CACHE STATISTICS
────────────────────────────────────────
Total Documents:        156 files
Cache Size:             45.2 MB
Fresh Documents:        142 (91%)
Cache Hit Rate:         94.5%
Avg Cache Hit Time:     12 ms
```

### `/fractary-codex:health`

Perform comprehensive health checks and diagnose issues.

**Usage:**
```bash
/fractary-codex:health                    # Run all checks
/fractary-codex:health --check cache      # Specific category
/fractary-codex:health --fix              # Auto-repair issues
/fractary-codex:health --verbose          # Detailed diagnostics
```

**Health checks:**
- **Cache**: Index validity, file accessibility, orphaned files
- **Configuration**: Valid JSON, required fields, source configs
- **Performance**: Hit rate, fetch times, failure rate
- **Storage**: Disk space, cache size, growth rate
- **System**: Git, jq, network, permissions

**Example output:**
```
🏥 Codex Health Check
═══════════════════════════════════════

CACHE HEALTH                     ✅ PASS
✓ Cache directory exists
✓ Cache index valid
✓ All cached files accessible

OVERALL STATUS: ✅ Healthy
Checks passed: 22/24 (92%)
```

---

## Configuration

### Configuration File

**Location:** `.fractary/plugins/codex/config.json`

**Schema:**
```json
{
  "version": "1.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",

  "cache": {
    "ttl_days": 7,
    "max_size_mb": 500,
    "auto_cleanup": true,
    "cleanup_interval_days": 7
  },

  "sources": [
    {
      "name": "fractary-codex",
      "type": "codex",
      "handler": "github",
      "handler_config": {
        "org": "fractary",
        "repo": "codex.fractary.com",
        "branch": "main",
        "base_path": "projects"
      },
      "cache": {
        "ttl_days": 7
      },
      "permissions": {
        "enabled": true,
        "default": "check_frontmatter"
      }
    }
  ]
}
```

### Configuration Options

**Cache Settings:**
- `ttl_days`: Default TTL for cached documents (default: 7)
- `max_size_mb`: Maximum cache size (0 = unlimited)
- `auto_cleanup`: Automatically remove expired entries
- `cleanup_interval_days`: How often to run cleanup (default: 7)

**Source Settings:**
- `name`: Unique identifier for the source
- `type`: Source type (`codex`, `external-url`, `s3`, `local`)
- `handler`: Handler to use (`github`, `http`, `s3`, `local`)
- `handler_config`: Handler-specific configuration
- `cache`: Source-specific cache settings
- `permissions`: Permission configuration

**Permission Settings:**
- `enabled`: Enable frontmatter permission checking
- `default`: Default action when no frontmatter (`allow`, `deny`, `check_frontmatter`)

---

## MCP Integration

The codex plugin includes an MCP server that exposes cached documents as resources.

### Setup

**1. Build the MCP server:**
```bash
cd plugins/codex/mcp-server
npm install
npm run build
```

**2. Configure Claude:**

Add to `.claude/config.json` (Claude Code) or global config (Claude Desktop):

```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": [
        "/absolute/path/to/plugins/codex/mcp-server/dist/index.js"
      ],
      "env": {
        "CODEX_CACHE_PATH": "${workspaceFolder}/codex",
        "CODEX_CONFIG_PATH": "${workspaceFolder}/.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

**3. Restart Claude**

Resources will appear in the resource panel as `codex://` URIs.

### Usage

**In conversations:**
```
Explain the OAuth implementation in codex://auth-service/docs/oauth.md

Compare codex://shared/standards/api-design.md with React best practices
```

**Resource panel:**
- Browse cached documents
- Click to view content
- See metadata (source, cached_at, expires_at, fresh status)

**MCP tools:**
- `codex_cache_status`: View cache statistics
- `codex_fetch`: Get information about fetching (redirects to plugin command)

See [MCP Integration Guide](./docs/MCP-INTEGRATION.md) for detailed setup and troubleshooting.

---

## Legacy: Push-Based Sync & Migration

> **⚠️ Deprecation Notice:** The push-based sync system (v2.0, SPEC-0012) is being phased out in favor of pull-based retrieval (v3.0, SPEC-0030). Both systems are currently supported during the transition period (6-9 months).

### Deprecation Timeline

The migration from v2.0 to v3.0 follows a **4-stage rollout over 6-12 months**:

| Stage | Timeline | Status | Description |
|-------|----------|--------|-------------|
| **Stage 1** | Months 0-3 | **Current** | Both systems work, retrieval opt-in |
| **Stage 2** | Months 3-6 | Planned | Push works, pull deprecated, retrieval recommended |
| **Stage 3** | Months 6-9 | Planned | Sync commands show warnings, retrieval is standard |
| **Stage 4** | Months 9-12 | Planned | Sync commands removed, retrieval only |

### Migration Path

**Automated migration:**
```bash
/fractary-codex:migrate              # Convert v2.0 config to v3.0
/fractary-codex:migrate --dry-run    # Preview changes first
```

**What changes:**
- **Old (v2.0)**: Bidirectional sync with `sync_patterns`
  - Project → Codex: Aggregate project docs into codex
  - Codex → Projects: Distribute shared docs to projects
- **New (v3.0)**: Pull-based retrieval with `sources` array
  - On-demand fetching from any source
  - Cache-first with TTL management

**See:** [MIGRATION-PHASE4.md](docs/MIGRATION-PHASE4.md) for complete migration guide

### Legacy Commands

⚠️ **These commands are deprecated and will be removed in Stage 4 (Month 9-12)**

- `/fractary-codex:sync-project [project] [--to-codex|--from-codex|--bidirectional]` - Sync single project
- `/fractary-codex:sync-org [--to-codex|--from-codex|--bidirectional]` - Sync entire organization

**Migration examples:**
```bash
# Old (v2.0): Sync from codex
/fractary-codex:sync-project my-project --from-codex

# New (v3.0): Fetch on-demand
/fractary-codex:fetch @codex/my-project/docs/architecture.md
/fractary-codex:cache-prefetch    # Or prefetch multiple docs

# Old (v2.0): Sync to codex
/fractary-codex:sync-project my-project --to-codex

# New (v3.0): Publishing workflows separate from retrieval
# Continue using git push or CI/CD to publish to codex repository
```

### Why Migrate?

**Performance improvements:**
- **10-50x faster** cache hits (< 50ms vs 1-3s)
- **No manual sync** required - fetch on-demand
- **Multi-source support** (not just codex repository)
- **Offline-first** with local cache
- **MCP integration** for Claude Desktop/Code

**Architectural benefits:**
- No single-repository bottleneck
- Document-level permission control
- Flexible source configuration
- Simpler mental model (pull vs bidirectional sync)

For new implementations, use the pull-based retrieval system which is faster, more scalable, and supports multi-source integration.

---

## Use Cases

### 1. Fast Document Access

**Scenario:** Frequently reference the same docs across conversations.

**Solution:**
```bash
# First access: fetch and cache
/fractary-codex:fetch @codex/shared/standards/api-design.md

# Subsequent access: < 100ms from cache
codex://shared/standards/api-design.md
```

### 2. Multi-Source Knowledge

**Scenario:** Combine internal docs with external references.

**Configuration:**
```json
{
  "sources": [
    {"name": "internal-codex", "handler": "github"},
    {"name": "aws-docs", "handler": "http", "url_pattern": "https://docs.aws.amazon.com/**"},
    {"name": "react-docs", "handler": "http", "url_pattern": "https://react.dev/**"}
  ]
}
```

### 3. Permission-Controlled Docs

**Scenario:** Some docs are team-specific, others are public.

**Document frontmatter:**
```yaml
---
codex_sync_include:
  - auth-team-*     # Only auth team projects
  - platform-core
codex_sync_exclude:
  - temp-*
---
```

### 4. Offline Development

**Scenario:** Work without internet access.

**Setup:**
```bash
# Pre-cache frequently used docs
/fractary-codex:fetch @codex/shared/standards/coding-guide.md
/fractary-codex:fetch @codex/shared/standards/api-design.md
/fractary-codex:fetch @codex/auth-service/docs/oauth.md

# Use offline (from cache)
codex://shared/standards/coding-guide.md
```

### 5. Context7 Integration

**Scenario:** Access 33,000+ external documentation libraries.

**Setup:** See [MCP Integration Guide](./docs/MCP-INTEGRATION.md#context7-integration)

Hybrid caching automatically caches Context7 responses locally for fast subsequent access.

---

## Best Practices

### 1. Pre-Cache Frequently Used Docs

```bash
/fractary-codex:fetch @codex/shared/standards/api-design.md
/fractary-codex:fetch @codex/shared/templates/service-template.md
```

### 2. Adjust TTL Based on Content Stability

```json
{
  "sources": [{
    "name": "stable-docs",
    "cache": {"ttl_days": 60}  // Rarely updated
  }, {
    "name": "active-specs",
    "cache": {"ttl_days": 3}   // Frequently updated
  }]
}
```

### 3. Use Permissions for Sensitive Docs

```yaml
---
codex_sync_include:
  - platform-core
  - security-team-*
codex_sync_exclude:
  - temp-*
  - external-contractors-*
---
```

### 4. Monitor Cache Size

```bash
/fractary-codex:cache-list
/fractary-codex:cache-clear --expired  # Regular cleanup
```

### 5. Use MCP for Interactive Work

Configure MCP server for seamless integration in Claude Desktop/Code conversations.

---

## Troubleshooting

### Cache Not Working

**Symptom:** Every fetch is slow.

**Check:**
```bash
ls -la codex/.cache-index.json
/fractary-codex:cache-list
```

**Fix:** Ensure cache directory exists and is writable.

### Permission Denied

**Symptom:** "Access denied" errors.

**Check:** Document frontmatter permissions:
```yaml
---
codex_sync_include: ["your-project"]
---
```

**Fix:** Update frontmatter or disable permissions:
```json
{"permissions": {"enabled": false}}
```

### MCP Resources Not Appearing

**Symptom:** No resources in Claude panel.

**Check:**
1. MCP server built: `ls plugins/codex/mcp-server/dist/`
2. Configuration correct in `.claude/config.json`
3. Cache has documents: `/fractary-codex:cache-list`

**Fix:** Restart Claude, fetch some documents first.

### Slow Fetches

**Symptom:** Fetches take > 5 seconds.

**Possible Causes:**
- Large documents
- Slow network
- GitHub rate limiting

**Solutions:**
- Check document size
- Pre-cache during good network
- Increase timeout in configuration

---

## Development

### Directory Structure

```
plugins/codex/
├── .claude-plugin/
│   ├── plugin.json              # Plugin metadata (v3.0.0)
│   └── config.schema.json       # Configuration schema
├── agents/
│   └── codex-manager.md         # Main orchestration agent
├── commands/
│   ├── fetch.md                 # Fetch command
│   ├── cache-list.md            # Cache list command
│   ├── cache-clear.md           # Cache clear command
│   ├── init.md                  # Init command (legacy)
│   ├── sync-project.md          # Project sync (legacy)
│   └── sync-org.md              # Org sync (legacy)
├── skills/
│   ├── document-fetcher/        # Core retrieval skill (Phase 1)
│   │   ├── scripts/
│   │   │   ├── resolve-reference.sh
│   │   │   ├── cache-lookup.sh
│   │   │   ├── cache-store.sh
│   │   │   ├── github-fetch.sh
│   │   │   ├── check-permissions.sh    # Phase 2
│   │   │   ├── parse-frontmatter.sh    # Phase 2
│   │   │   └── route-source.sh         # Phase 2
│   │   └── workflow/
│   │       └── fetch-with-permissions.md
│   ├── cache-list/              # Cache listing skill
│   ├── cache-clear/             # Cache clearing skill
│   ├── handler-http/            # HTTP handler (Phase 2)
│   └── [legacy sync skills...]
├── mcp-server/                  # MCP server (Phase 3)
│   ├── src/
│   │   └── index.ts
│   ├── package.json
│   ├── tsconfig.json
│   └── README.md
├── config/
│   ├── codex.example.json       # Example configuration
│   └── codex.project.example.json
├── docs/
│   └── MCP-INTEGRATION.md       # MCP setup guide
└── examples/
    ├── mcp-config.json          # MCP configuration
    └── mcp-with-context7.json   # With Context7
```

### Standards Compliance

Follows [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md):
- 3-layer architecture (command → agent → skill → script)
- Handler pattern for source abstraction
- XML markup in agents and skills
- Deterministic operations in bash scripts
- Comprehensive error handling and documentation

---

## Version History

### v3.0.0 (Current) - Knowledge Retrieval Architecture

**Phase 1: Local Cache & Reference System**
- @codex/ reference syntax
- Cache-first retrieval (< 100ms)
- GitHub sparse checkout
- TTL-based freshness
- Cache management commands

**Phase 2: Multi-Source Support & Permissions**
- Multi-source configuration
- Handler abstraction (GitHub, HTTP)
- Frontmatter-based permissions
- Source routing
- External URL fetching

**Phase 3: MCP Integration**
- TypeScript MCP server
- codex:// resource protocol
- Dual-mode access
- Context7 integration (documented)
- Claude Desktop/Code support

**Phase 4: Migration & Optimization**
- Migration tooling (/fractary-codex:migrate)
- Deprecation warnings on legacy commands
- Metrics & monitoring (/fractary-codex:metrics)
- Health checks (/fractary-codex:health)
- Performance optimizations (10-50ms cache hits)
- 4-stage deprecation timeline (6-12 months)

### v2.0.0 - Push-Based Sync (Legacy)

- Organization-agnostic implementation
- 3-layer architecture with handler pattern
- Parallel organization sync
- Safety features (deletion thresholds)

### v1.0.x (Deprecated)

- OmniDAS-specific implementation
- GitHub Actions workflows

---

## Dependencies

### Required

- **Node.js >= 18.0.0** (for MCP server)
- **jq** (JSON processing)
- **bash** (scripts)

### Optional

- **yq** (YAML parsing, falls back to basic parsing)
- **python3** (frontmatter parsing, has fallback)

### Plugin Dependencies

- **fractary-repo** (optional, for legacy sync operations)

---

## Support

- **Documentation**:
  - [MCP Integration Guide](./docs/MCP-INTEGRATION.md)
  - [Specifications](../../docs/specs/) (SPEC-0030-01 through SPEC-0030-04)
- **Examples**: See `examples/` directory
- **Issues**: Repository issue tracker
- **Standards**: [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)

---

**Memory fabric for AI agents** - Fast, intelligent knowledge retrieval with the codex plugin.
