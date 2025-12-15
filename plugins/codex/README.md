# Fractary Codex Plugin

**Knowledge retrieval and documentation sync** - A memory fabric for AI agents with cache-first retrieval, multi-source support, and MCP integration.

> **Version 4.1** - SDK-based MCP server: Migrated from custom TypeScript MCP server to SDK-provided MCP server for better maintainability and ecosystem integration.

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
Request codex://org/project/docs/api.md
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

### 1. Initialize the Plugin

```bash
/fractary-codex:init --org fractary --codex codex.fractary.com
```

This sets up:
- Configuration at `.fractary/codex.yaml` (YAML format, v4.0)
- Cache directory at `.fractary/plugins/codex/cache/`
- SDK MCP server in `.claude/settings.json`

### 2. Fetch a Document

```bash
/fractary-codex:fetch codex://fractary/auth-service/docs/oauth.md
```

This will:
- Check local cache first (fast path)
- Fetch from GitHub if needed (on-demand)
- Cache locally with 7-day TTL
- Return the content

### 3. Browse Cached Documents

```bash
/fractary-codex:cache-list
```

Shows all cached documents with freshness status.

### 4. Use MCP Resources

After initialization, MCP resources are available:

```
codex://fractary/auth-service/docs/oauth.md
```

Access cached documents via `codex://` URIs directly in conversations.

### 5. Validate Setup

```bash
/fractary-codex:validate-setup
```

Checks configuration, cache, and MCP server status.

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
│  ├─ Cache index       (index.json)             │
│  └─ TTL management    (default: 7 days)         │
│                                                  │
└─────────────────────────────────────────────────┘
```

---

## Features

### 📚 Knowledge Retrieval

**codex:// URI Syntax:**
```
codex://{org}/{project}/{path}

Examples:
  codex://fractary/auth-service/docs/oauth.md
  codex://fractary/faber-cloud/specs/SPEC-00020.md
  codex://partner-org/shared/standards/api-design.md
```

Path alignment: `codex://org/project/path` → `.fractary/plugins/codex/cache/org/project/path`

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
  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 604800,
      "branch": "main"
    },
    "partner-org": {
      "type": "github-org",
      "token_env": "PARTNER_TOKEN"
    },
    "api-docs": {
      "type": "http",
      "base_url": "https://docs.example.com",
      "ttl": 2592000
    }
  }
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
.fractary/plugins/codex/
├── config.json                 # Plugin configuration
└── cache/                      # Ephemeral cache (gitignored)
    ├── index.json             # Cache metadata index
    └── fractary/              # Organization
        ├── auth-service/
        │   └── docs/
        │       └── oauth.md   # Cached document
        └── shared/
            └── standards/
                └── api-design.md
```

**Cache Index:**
```json
{
  "version": "3.0",
  "entries": [{
    "uri": "codex://fractary/auth-service/docs/oauth.md",
    "path": "fractary/auth-service/docs/oauth.md",
    "source": "fractary",
    "cached_at": "2025-01-15T10:00:00Z",
    "expires_at": "2025-01-22T10:00:00Z",
    "ttl": 604800,
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

Fetch a document from codex by URI.

**Usage:**
```bash
/fractary-codex:fetch codex://org/project/path

# Force refresh (bypass cache)
/fractary-codex:fetch codex://org/project/path --force-refresh

# Custom TTL in seconds (override default)
/fractary-codex:fetch codex://org/project/path --ttl 1209600
```

**Examples:**
```bash
# Fetch OAuth documentation
/fractary-codex:fetch codex://fractary/auth-service/docs/oauth.md

# Fetch specification with longer TTL (14 days)
/fractary-codex:fetch codex://fractary/faber-cloud/specs/SPEC-00020.md --ttl 1209600

# Force fresh fetch from source
/fractary-codex:fetch codex://fractary/shared/standards/api.md --force-refresh
```

**Output:**
```
✅ Document retrieved: codex://fractary/auth-service/docs/oauth.md
Source: fractary (cached)
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
✓ codex://fractary/auth-service/docs/oauth.md
  Size: 12.3 KB | Expires: 2025-01-22 (6 days)

✓ codex://fractary/faber-cloud/specs/SPEC-00020.md
  Size: 45.2 KB | Expires: 2025-01-21 (5 days)

EXPIRED ENTRIES (4):
⚠ codex://fractary/old-service/README.md
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

### `/fractary-codex:validate-setup`

Validate plugin setup and configuration status.

**Usage:**
```bash
/fractary-codex:validate-setup              # Basic validation
/fractary-codex:validate-setup --verbose    # Include warnings
```

**Checks:**
- Configuration file exists and is valid JSON
- Required fields present (organization, codex_repo)
- Cache directory exists and is writable
- MCP server installed in `.claude/settings.json`
- Cache index exists and is valid

### `/fractary-codex:validate-refs`

Validate codex references in markdown files.

**Usage:**
```bash
/fractary-codex:validate-refs                    # Scan current directory
/fractary-codex:validate-refs --path docs/       # Scan specific directory
/fractary-codex:validate-refs --fix              # Auto-convert @codex/ to codex://
```

**Checks:**
- Deprecated `@codex/` references (should be `codex://`)
- Relative path references (`../`)
- Absolute path references (`/`)

**Fix Mode:**
Converts deprecated `@codex/project/path` references to `codex://org/project/path` format.

---

## Configuration

### Configuration File

**Location:** `.fractary/plugins/codex/config.json`

**Schema (v3.0):**
```json
{
  "version": "3.0",
  "organization": "fractary",
  "project_name": "my-project",
  "codex_repo": "codex.fractary.com",

  "cache": {
    "default_ttl": 604800,
    "check_expiration": true,
    "fallback_to_stale": true,
    "offline_mode": false,
    "max_size_mb": 0,
    "auto_cleanup": true,
    "cleanup_interval_days": 7
  },

  "auth": {
    "default": "inherit",
    "fallback_to_public": true
  },

  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 604800,
      "branch": "main"
    },
    "partner-org": {
      "type": "github-org",
      "token_env": "PARTNER_TOKEN"
    }
  }
}
```

### Configuration Options

**Cache Settings:**
- `default_ttl`: TTL in seconds for cached documents (default: 604800 = 7 days)
- `check_expiration`: Check TTL when reading from cache (default: true)
- `fallback_to_stale`: Use stale content when fetch fails (default: true)
- `offline_mode`: Disable network fetches (default: false)
- `max_size_mb`: Maximum cache size in MB (0 = unlimited)
- `auto_cleanup`: Automatically remove expired entries (default: true)
- `cleanup_interval_days`: How often to run cleanup (default: 7)

**Auth Settings:**
- `default`: Auth method: `inherit` (git/repo), `env` (env vars), `config` (tokens)
- `fallback_to_public`: Try unauthenticated access if auth fails (default: true)

**Source Settings (per org key):**
- `type`: Source type (`github-org`, `http`, `s3`, `local`)
- `ttl`: TTL override in seconds for this source
- `branch`: Default branch for GitHub sources (default: main)
- `token_env`: Environment variable name for auth token
- `base_url`: Base URL for HTTP sources

---

## MCP Integration

The codex plugin uses the SDK-provided MCP server from `@fractary/codex` to expose cached documents as resources with on-demand fetching.

### Setup

**Automatic (Recommended):**
```bash
/fractary-codex:init --org fractary --codex codex.fractary.com
```

This automatically:
1. Creates YAML configuration at `.fractary/codex.yaml`
2. Sets up cache directory
3. Registers SDK MCP server in `.claude/settings.json`
4. Detects and migrates legacy custom MCP server (if present)

**Manual:**
```bash
# Install the SDK MCP server
./scripts/install-mcp.sh

# This configures:
# - npx @fractary/codex mcp --config .fractary/codex.yaml
# OR
# - fractary codex mcp --config .fractary/codex.yaml (if global CLI installed)
```

**Verify:**
```bash
/fractary-codex:validate-setup
```

Resources will appear in the resource panel as `codex://` URIs.

### Usage

**In conversations:**
```
Explain the OAuth implementation in codex://fractary/auth-service/docs/oauth.md

Compare codex://fractary/shared/standards/api-design.md with React best practices
```

**Resource panel:**
- Browse cached documents
- Click to view content
- See metadata (source, cached_at, expires_at, fresh status)

**MCP tools:**
- `codex_fetch`: Fetch document by URI with on-demand fetching
- `codex_sync_status`: Check cache, config, and MCP status

See [MCP Integration Guide](./docs/MCP-INTEGRATION.md) for detailed setup and troubleshooting.

---

## Documentation Sync (Environment-Aware)

The codex plugin provides **environment-aware documentation synchronization** for keeping project documentation in sync with the central codex repository.

### Sync Commands (Primary Interface)

These commands are the **primary interface** for documentation synchronization:

- `/fractary-codex:sync-project` - Sync single project with codex
- `/fractary-codex:sync-org` - Sync entire organization with codex

### Environment Support

Sync commands now support environment-aware targeting:

| Environment | Default Branch | Use Case |
|-------------|----------------|----------|
| `dev` | test | Development work |
| `test` | test | QA/testing, FABER evaluate phase |
| `staging` | main | Pre-production |
| `prod` | main | Production, FABER release phase |

**Auto-detection:**
- Feature branches (`feat/*`, `fix/*`, etc.) → `test` environment
- Main/master branch → `prod` environment (with confirmation)

### Usage Examples

```bash
# Auto-detect environment from current branch
/fractary-codex:sync-project
# On feat/123-feature → syncs to test (no prompt)
# On main → syncs to prod (prompts for confirmation)

# Explicit environment (skips confirmation)
/fractary-codex:sync-project --env test
/fractary-codex:sync-project --env prod

# Direction-specific sync
/fractary-codex:sync-project --to-codex --env prod
/fractary-codex:sync-project --from-codex --env test

# Dry-run preview
/fractary-codex:sync-project --dry-run

# Org-wide sync (defaults to test for safety)
/fractary-codex:sync-org --env test
/fractary-codex:sync-org --env prod  # Requires confirmation
```

### FABER Workflow Integration

Environment-aware sync integrates with the FABER workflow:

- **Evaluate Phase**: Sync to `test` environment for review
- **Release Phase**: Sync to `prod` environment for production

```bash
# During FABER evaluate (on feature branch)
/fractary-codex:sync-project  # Auto-detects test

# During FABER release (explicit prod)
/fractary-codex:sync-project --env prod
```

### Fetch vs Sync

**Important distinction:**

| Command | Purpose | Environment |
|---------|---------|-------------|
| `/fractary-codex:fetch` | Read-only knowledge retrieval | Always production |
| `/fractary-codex:sync-project` | Bidirectional documentation sync | Configurable |

- **fetch** = For AI agents accessing stable, production-grade documentation
- **sync** = For developers keeping documentation in sync across environments

---

## Use Cases

### 1. Fast Document Access

**Scenario:** Frequently reference the same docs across conversations.

**Solution:**
```bash
# First access: fetch and cache
/fractary-codex:fetch codex://fractary/shared/standards/api-design.md

# Subsequent access: < 100ms from cache
codex://fractary/shared/standards/api-design.md
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
/fractary-codex:fetch codex://fractary/shared/standards/coding-guide.md
/fractary-codex:fetch codex://fractary/shared/standards/api-design.md
/fractary-codex:fetch codex://fractary/auth-service/docs/oauth.md

# Enable offline mode in config
# "cache": { "offline_mode": true, "fallback_to_stale": true }

# Use offline (from cache)
codex://fractary/shared/standards/coding-guide.md
```

### 5. Context7 Integration

**Scenario:** Access 33,000+ external documentation libraries.

**Setup:** See [MCP Integration Guide](./docs/MCP-INTEGRATION.md#context7-integration)

Hybrid caching automatically caches Context7 responses locally for fast subsequent access.

---

## Best Practices

### 1. Pre-Cache Frequently Used Docs

```bash
/fractary-codex:fetch codex://fractary/shared/standards/api-design.md
/fractary-codex:fetch codex://fractary/shared/templates/service-template.md
```

### 2. Adjust TTL Based on Content Stability

```json
{
  "sources": {
    "stable-docs": {
      "type": "github-org",
      "ttl": 5184000
    },
    "active-specs": {
      "type": "github-org",
      "ttl": 259200
    }
  }
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
/fractary-codex:validate-setup
/fractary-codex:cache-list
ls -la .fractary/plugins/codex/cache/index.json
```

**Fix:** Run `/fractary-codex:init` to set up the cache directory.

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
```bash
/fractary-codex:validate-setup
ls plugins/codex/mcp-server/dist/
```

**Fix:**
1. Run `/fractary-codex:init` to configure MCP
2. Restart Claude
3. Fetch some documents: `/fractary-codex:fetch codex://org/project/file.md`

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
│   ├── cli-helper/              # CLI delegation (Phase 4)
│   └── [other skills...]
├── config/
│   └── codex.example.yaml       # Example YAML configuration (v4.0)
├── docs/
│   ├── CLI-INTEGRATION-SUMMARY.md  # CLI integration details
│   ├── MIGRATION-GUIDE-v4.md       # v3→v4 migration guide
│   └── MCP-INTEGRATION.md          # MCP setup guide
└── examples/
    └── mcp-config.json          # SDK MCP server configuration
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

### v4.1.0 (Current) - SDK-Based MCP Server

**Phase 6: MCP Migration**
- Migrated from custom TypeScript MCP server to SDK-provided MCP server
- Automatic detection and migration of legacy MCP configurations
- Global CLI detection with npx fallback
- ~200+ files removed (custom server + node_modules)
- ~50MB disk space saved
- Maintenance burden eliminated (SDK handles updates)
- Full feature parity maintained

### v4.0.0 - CLI Integration

**Phase 4: Configuration Migration**
- YAML configuration format (`.fractary/codex.yaml`)
- JSON→YAML migration tooling
- Version detection and automatic migration
- CLI delegation via @fractary/cli

**Phase 5: Agent Simplification**
- Simplified codex-manager agent
- CLI-first operations
- Better error propagation

### v3.0.0 - Knowledge Retrieval Architecture

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

**Phase 3: MCP Integration** (Custom Server - Deprecated in v4.1)
- Custom TypeScript MCP server
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

- **@fractary/codex SDK** (for MCP server, installed automatically via npx)
- **@fractary/cli** (optional - global install for faster operations, falls back to npx)
- **jq** (JSON processing)
- **yq** (YAML processing, for v4.0 config migration)
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
  - [Migration Guide v3.0](./docs/MIGRATION-v3.md)
  - [Specifications](../../docs/specs/) (SPEC-00033)
- **Examples**: See `examples/` directory
- **Issues**: Repository issue tracker
- **Standards**: [Fractary Plugin Standards](../../docs/standards/FRACTARY-PLUGIN-STANDARDS.md)

---

**Memory fabric for AI agents** - Fast, intelligent knowledge retrieval with the codex plugin.
