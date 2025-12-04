# MCP Integration Guide

This guide explains how to use the Fractary Codex MCP server with v3.0 architecture including on-demand fetch, offline mode, and multi-source support.

## Table of Contents

1. [Overview](#overview)
2. [Quick Setup](#quick-setup)
3. [Using codex:// Resources](#using-codex-resources)
4. [On-Demand Fetching](#on-demand-fetching)
5. [Offline Mode](#offline-mode)
6. [Configuration](#configuration)
7. [Context7 Integration](#context7-integration)
8. [Troubleshooting](#troubleshooting)

## Overview

The Codex MCP server exposes knowledge documents as MCP resources using the `codex://` URI scheme. Key features:

- **On-demand fetch**: Documents are fetched automatically when accessed
- **Cache-first**: Cached content served instantly (< 100ms)
- **Offline mode**: Work without network using cached content
- **Current project detection**: Relative URIs resolve to current project
- **Multi-source support**: GitHub organizations, HTTP endpoints, local files

### URI Format

```
codex://{org}/{project}/{path}

Examples:
  codex://fractary/auth-service/docs/oauth.md
  codex://fractary/faber-cloud/specs/SPEC-00020.md
  codex://partner-org/shared/standards/api-design.md
```

## Quick Setup

The easiest way to set up the MCP server is via the init command:

```bash
/fractary-codex:init --org fractary --codex codex.fractary.com
```

This will:
1. Create configuration at `.fractary/plugins/codex/config.json`
2. Set up cache directory at `.fractary/plugins/codex/cache/`
3. Install MCP server in `.claude/settings.json`
4. Initialize cache index

### Manual Setup

**1. Build the MCP server:**
```bash
cd plugins/codex/mcp-server
npm install
npm run build
```

**2. Run the install script:**
```bash
./scripts/install-mcp.sh
```

**3. Restart Claude** to load the MCP server.

**4. Verify setup:**
```bash
/fractary-codex:validate-setup
```

## Using codex:// Resources

### In Conversations

Reference documents directly in your conversations:

```
Can you explain the OAuth flow in codex://fractary/auth-service/docs/oauth.md?

Based on codex://fractary/shared/standards/api-design.md, how should I structure this API?

Compare codex://fractary/faber-cloud/specs/SPEC-00020.md with our current implementation.
```

Claude automatically:
1. Checks the local cache
2. Fetches from source if missing/expired
3. Returns the content

### Resource Panel

In Claude Code:
1. Open the resource panel
2. Expand "fractary-codex" server
3. Browse available cached documents
4. Click to view content

### Resource Metadata

Each resource includes:
- **URI**: The codex:// address
- **Source**: Where it came from (fractary, partner-org, etc.)
- **Cached at**: When it was cached
- **Expires at**: When it expires (based on TTL)
- **Fresh**: Whether content is current
- **Size**: Document size

### MCP Tools

The server provides these tools:

**`codex_fetch`**: Fetch a document by URI
```json
{
  "uri": "codex://fractary/auth-service/docs/oauth.md",
  "force_refresh": false
}
```

**`codex_sync_status`**: Check sync and cache status
```json
{
  "check_type": "all"  // or "cache", "config", "mcp"
}
```

## On-Demand Fetching

The MCP server automatically fetches documents when:
1. Document is not in cache
2. Cache entry has expired (TTL exceeded)
3. Force refresh is requested

### Fetch Flow

```
Request codex://org/project/path
         ↓
  Check local cache
         ↓ (if miss or expired)
  Resolve source (GitHub, HTTP)
         ↓
  Fetch with auth cascade
         ↓
  Cache with TTL
         ↓
  Return content
```

### Authentication Cascade

For GitHub sources, authentication tries in order:
1. Source-specific token from config
2. `GITHUB_TOKEN` environment variable
3. Git credential manager
4. Public access (fallback)

Configure in `.fractary/plugins/codex/config.json`:
```json
{
  "auth": {
    "default": "inherit",
    "fallback_to_public": true
  },
  "sources": {
    "partner-org": {
      "type": "github-org",
      "token_env": "PARTNER_TOKEN"
    }
  }
}
```

## Offline Mode

Work without network access using cached content.

### Enable Offline Mode

**Via configuration:**
```json
{
  "cache": {
    "offline_mode": true,
    "fallback_to_stale": true
  }
}
```

**Behavior:**
- All fetch attempts use cache only
- Stale content is returned if `fallback_to_stale: true`
- New documents cannot be fetched until online

### Pre-Cache for Offline

Before going offline, cache frequently used documents:

```bash
/fractary-codex:fetch codex://fractary/shared/standards/coding-guide.md
/fractary-codex:fetch codex://fractary/shared/standards/api-design.md
/fractary-codex:fetch codex://fractary/auth-service/docs/oauth.md
```

### Fallback Behavior

When offline or fetch fails:
- If `fallback_to_stale: true` and cached content exists → returns stale content
- If no cached content → returns error with helpful message

## Configuration

### Configuration File

**Location:** `.fractary/plugins/codex/config.json`

**v3.0 Schema:**
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
      "ttl": 1209600
    },
    "partner-org": {
      "type": "github-org",
      "token_env": "PARTNER_TOKEN"
    },
    "api-docs": {
      "type": "http",
      "base_url": "https://docs.example.com",
      "ttl": 86400
    }
  }
}
```

### Cache Settings

| Setting | Default | Description |
|---------|---------|-------------|
| `default_ttl` | 604800 (7 days) | TTL in seconds for cached documents |
| `check_expiration` | true | Check TTL when reading from cache |
| `fallback_to_stale` | true | Use stale content when fetch fails |
| `offline_mode` | false | Disable network fetches |
| `max_size_mb` | 0 | Maximum cache size (0 = unlimited) |
| `auto_cleanup` | true | Automatically remove expired entries |

### Source Configuration

Sources define where documents can be fetched from:

**GitHub Organization:**
```json
{
  "fractary": {
    "type": "github-org",
    "ttl": 1209600,
    "branch": "main"
  }
}
```

**HTTP Endpoint:**
```json
{
  "api-docs": {
    "type": "http",
    "base_url": "https://docs.example.com",
    "ttl": 86400
  }
}
```

**With Custom Authentication:**
```json
{
  "private-org": {
    "type": "github-org",
    "token_env": "PRIVATE_ORG_TOKEN"
  }
}
```

### MCP Server Registration

The MCP server is registered in `.claude/settings.json`:

```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": [
        "/absolute/path/to/plugins/codex/mcp-server/dist/index.js"
      ],
      "env": {
        "CODEX_CONFIG_PATH": "/absolute/path/to/project/.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

The server reads `CODEX_CONFIG_PATH` to find:
- Cache location (`.fractary/plugins/codex/cache/`)
- Source configuration
- TTL and offline settings

## Context7 Integration

[Context7](https://context7.com) provides access to 33,000+ technical documentation libraries.

### Setup

**Step 1: Get Context7 API key**
1. Sign up at https://context7.com
2. Get your API key
3. Set environment variable:
   ```bash
   export CONTEXT7_API_KEY="your-api-key-here"
   ```

**Step 2: Add Context7 MCP server**

In `.claude/settings.json`:
```json
{
  "mcpServers": {
    "context7": {
      "command": "npx",
      "args": ["-y", "@context7/mcp-server"],
      "env": {
        "CONTEXT7_API_KEY": "${CONTEXT7_API_KEY}"
      }
    },
    "fractary-codex": {
      "command": "node",
      "args": ["..."]
    }
  }
}
```

### Hybrid Usage

Use both Codex (internal docs) and Context7 (external docs):

```
Compare our API design standards from codex://fractary/shared/standards/api-design.md
with React's best practices from Context7.
```

Claude uses:
- Codex for internal organizational knowledge
- Context7 for external technical documentation

## Troubleshooting

### Validate Setup

First, run the setup validator:
```bash
/fractary-codex:validate-setup
```

This checks:
- Configuration file exists and is valid
- Cache directory exists and is writable
- MCP server is registered
- Cache index is valid

### MCP Server Not Appearing

1. **Check Node.js version:** `node --version` (must be >= 18)
2. **Verify build:** `ls plugins/codex/mcp-server/dist/`
3. **Check Claude logs** for MCP errors
4. **Restart Claude** completely

### Documents Not Loading

1. **Check URI format:** Must be `codex://org/project/path`
2. **Verify source exists** in configuration
3. **Test fetch directly:**
   ```bash
   /fractary-codex:fetch codex://org/project/path
   ```
4. **Check cache status:**
   ```bash
   /fractary-codex:cache-list
   ```

### Authentication Errors

1. **Check token environment variable** is set
2. **Verify source config** has correct `token_env`
3. **Test GitHub access:**
   ```bash
   gh api repos/org/repo
   ```
4. **Enable fallback:**
   ```json
   {"auth": {"fallback_to_public": true}}
   ```

### Slow Performance

1. **Check cache hit rate:**
   ```bash
   /fractary-codex:cache-metrics
   ```
2. **Pre-cache frequent docs** before use
3. **Increase TTL** for stable documents
4. **Enable offline mode** when network is slow

### Cache Issues

1. **Check cache health:**
   ```bash
   /fractary-codex:cache-health
   ```
2. **Clear expired entries:**
   ```bash
   /fractary-codex:cache-clear --expired
   ```
3. **Rebuild cache index:**
   ```bash
   /fractary-codex:cache-health --fix
   ```

## Performance Tips

1. **Pre-cache frequently used docs:**
   ```bash
   /fractary-codex:fetch codex://fractary/shared/standards/coding-guide.md
   /fractary-codex:fetch codex://fractary/shared/standards/api-design.md
   ```

2. **Adjust TTL by content stability:**
   - Stable documentation: 2592000 (30 days)
   - Active specs: 604800 (7 days)
   - Frequently updated: 86400 (1 day)

3. **Use offline mode** when network is unreliable

4. **Clear expired entries regularly:**
   ```bash
   /fractary-codex:cache-clear --expired
   ```

5. **Monitor cache metrics:**
   ```bash
   /fractary-codex:cache-metrics
   ```

## Related Documentation

- [README](../README.md) - Plugin overview
- [MIGRATION-v3](./MIGRATION-v3.md) - Migration from v2.0
- [Model Context Protocol](https://modelcontextprotocol.io)
- [Context7 Documentation](https://context7.com/docs)
