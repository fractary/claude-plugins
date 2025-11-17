# MCP Integration Guide

This guide explains how to use the Fractary Codex MCP server and integrate with external MCP servers like Context7.

## Table of Contents

1. [Codex MCP Server Setup](#codex-mcp-server-setup)
2. [Using codex:// Resources](#using-codex-resources)
3. [Context7 Integration](#context7-integration)
4. [Hybrid Caching](#hybrid-caching)
5. [Troubleshooting](#troubleshooting)

## Codex MCP Server Setup

### Prerequisites

- Node.js >= 18.0.0
- Claude Code or Claude Desktop
- Codex plugin installed and configured

### Installation

1. **Build the MCP server:**
   ```bash
   cd plugins/codex/mcp-server
   npm install
   npm run build
   ```

2. **Configure Claude to use the server:**

   **For Claude Code** (`.claude/config.json` in your project):
   ```json
   {
     "mcpServers": {
       "fractary-codex": {
         "command": "node",
         "args": [
           "/absolute/path/to/claude-plugins/plugins/codex/mcp-server/dist/index.js"
         ],
         "env": {
           "CODEX_CACHE_PATH": "${workspaceFolder}/codex",
           "CODEX_CONFIG_PATH": "${workspaceFolder}/.fractary/plugins/codex/config.json"
         }
       }
     }
   }
   ```

   **For Claude Desktop** (global configuration):
   ```json
   {
     "mcpServers": {
       "fractary-codex": {
         "command": "node",
         "args": [
           "/Users/you/projects/claude-plugins/plugins/codex/mcp-server/dist/index.js"
         ],
         "env": {
           "CODEX_CACHE_PATH": "/Users/you/projects/my-project/codex",
           "CODEX_CONFIG_PATH": "/Users/you/projects/my-project/.fractary/plugins/codex/config.json"
         }
       }
     }
   }
   ```

3. **Restart Claude** to load the MCP server.

4. **Verify it's working:**
   - In Claude, you should see "fractary-codex" in the MCP servers list
   - Resources will appear in the resource panel

## Using codex:// Resources

### Resource Format

Resources use the `codex://` URI scheme:

```
codex://{project}/{path}

Examples:
  codex://auth-service/docs/oauth.md
  codex://faber-cloud/specs/SPEC-00020.md
  codex://shared/standards/api-design.md
```

### Browsing Resources

In Claude Code:
1. Open the resource panel
2. Expand "fractary-codex" server
3. Browse available cached documents
4. Click to view content

### Referencing in Conversations

```
Can you explain the OAuth flow described in codex://auth-service/docs/oauth.md?

Based on codex://faber-cloud/specs/SPEC-00020.md, how should I implement...?
```

Claude automatically loads and uses the referenced content.

### Resource Metadata

Each resource includes:
- **Source**: Where it came from (fractary-codex, external-url, etc.)
- **Cached at**: When it was cached
- **Expires at**: When it expires (based on TTL)
- **Fresh**: Whether content is current
- **Size**: Document size in bytes

## Context7 Integration

[Context7](https://context7.com) provides access to 33,000+ technical documentation libraries via MCP.

### Setup (Hybrid Mode)

**Step 1: Get Context7 API key**
1. Sign up at https://context7.com
2. Get your API key
3. Set environment variable:
   ```bash
   export CONTEXT7_API_KEY="your-api-key-here"
   ```

**Step 2: Configure Context7 MCP server**

Add to your MCP configuration:

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

**Step 3: Enable hybrid caching** (optional)

Update your codex configuration (`.fractary/plugins/codex/config.json`):

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
      }
    },
    {
      "name": "context7",
      "type": "external-mcp",
      "handler": "mcp-observer",
      "mcp_config": {
        "server_name": "context7"
      },
      "cache": {
        "enabled": true,
        "ttl_days": 30,
        "auto_cache_responses": true
      }
    }
  ]
}
```

### Using Context7

**Direct usage:**
```
What's the latest API for React hooks in Context7?
```

**With caching:**
When `auto_cache_responses: true`, Context7 responses are automatically cached to your local codex for faster subsequent access.

## Hybrid Caching

Hybrid caching combines external MCP servers (like Context7) with local caching for performance.

### How It Works

```
1. Query Context7 via MCP
   ↓
2. Context7 returns documentation
   ↓
3. MCP Observer detects response
   ↓
4. If auto_cache_responses enabled:
   - Store in local codex cache
   - Index with source="context7"
   - Set TTL (default: 30 days)
   ↓
5. Subsequent requests:
   - Check local cache first
   - Use cached version if fresh
   - Query Context7 if expired
```

### Benefits

- **Performance**: < 100ms for cached responses (vs 1-3s for Context7 queries)
- **Offline access**: Cached content available without internet
- **Cost savings**: Fewer API calls to Context7
- **Consistency**: Same content across team members

### Configuration

```json
{
  "cache": {
    "enabled": true,
    "ttl_days": 30,
    "auto_cache_responses": true
  }
}
```

**Options:**
- `enabled`: Turn caching on/off
- `ttl_days`: How long to keep cached responses (default: 30)
- `auto_cache_responses`: Automatically cache (default: true)

## Troubleshooting

### MCP Server Not Appearing

1. Check Node.js version: `node --version` (must be >= 18)
2. Verify MCP server built: `ls plugins/codex/mcp-server/dist/`
3. Check Claude logs for errors
4. Restart Claude completely

### No Resources Showing

1. Ensure cache exists:
   ```bash
   ls -la codex/.cache-index.json
   ```

2. Fetch some documents first:
   ```
   /fractary-codex:fetch @codex/project/docs/file.md
   ```

3. Refresh resource list in Claude

### codex:// URIs Not Working

1. Verify URI format: `codex://project/path` (no `@`)
2. Check if document is cached:
   ```
   /fractary-codex:cache-list
   ```

3. Fetch document if missing:
   ```
   /fractary-codex:fetch @codex/project/path
   ```

### Context7 Integration Issues

1. Verify API key: `echo $CONTEXT7_API_KEY`
2. Check Context7 server in MCP servers list
3. Test Context7 directly (without caching)
4. Check codex configuration for `mcp_config`

### Permission Errors

1. Check file permissions on cache directory
2. Verify paths in MCP configuration are absolute
3. Ensure cache directory is writable

## Performance Tips

1. **Pre-cache frequently used docs:**
   ```
   /fractary-codex:fetch @codex/common/docs/api.md
   /fractary-codex:fetch @codex/shared/standards/style-guide.md
   ```

2. **Adjust TTL for different sources:**
   - Stable docs: 60+ days
   - Frequently updated: 7 days
   - Ephemeral: 1 day

3. **Clear expired entries regularly:**
   ```
   /fractary-codex:cache-clear --expired
   ```

4. **Monitor cache size:**
   ```
   /fractary-codex:cache-list
   ```

## Examples

### Example 1: Reference Project Documentation

```
I'm working on the auth service. Show me the OAuth implementation guide.

Claude loads: codex://auth-service/docs/oauth.md
```

### Example 2: Multi-Source Query

```
Compare our internal API design standards with React's best practices from Context7.

Claude uses:
  - codex://shared/standards/api-design.md (internal)
  - Context7 React documentation (external, cached)
```

### Example 3: Specification Review

```
Review the FABER architecture spec and suggest improvements.

Claude loads: codex://faber-cloud/specs/SPEC-00020.md
```

## Next Steps

- [Phase 4: Migration Guide](./MIGRATION-PHASE4.md)
- [Codex Plugin README](../README.md)
- [MCP Server README](../mcp-server/README.md)

## Related Links

- [Model Context Protocol](https://modelcontextprotocol.io)
- [Context7 Documentation](https://context7.com/docs)
- [Claude Code MCP Guide](https://docs.claude.com/claude-code/mcp)
