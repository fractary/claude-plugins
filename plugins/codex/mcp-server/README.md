# Fractary Codex MCP Server

MCP (Model Context Protocol) server that exposes the Fractary Codex knowledge base as resources using `codex://` URIs.

## Overview

This server integrates with the codex cache (from Phases 1 & 2) and provides:
- **Resource Protocol**: Access cached documents via `codex://project/path` URIs
- **Resource Listing**: Browse all cached documents
- **Cache Status**: Query cache statistics via MCP tools
- **Fresh/Expired Indicators**: Know which content is up-to-date

## Installation

```bash
cd plugins/codex/mcp-server
npm install
npm run build
```

## Configuration

### Claude Code Configuration

Add to `.claude/config.json` or global Claude config:

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

### Environment Variables

- `CODEX_CACHE_PATH`: Path to codex cache directory (default: `./codex`)
- `CODEX_CONFIG_PATH`: Path to codex configuration (default: `./.fractary/plugins/codex/config.json`)

## Usage

### In Claude Code

Once configured, the server automatically starts when Claude Code launches. Cached documents are available as resources.

**List all resources:**
```
Claude can see codex:// resources automatically
```

**Read a resource:**
```
codex://auth-service/docs/oauth.md
```

Resources appear in Claude's resource panel and can be referenced in conversations.

### Available Tools

**codex_cache_status**
Get current cache statistics:
```
Total entries, size, fresh vs expired counts
```

**codex_fetch** (informational only)
Directs users to use `/fractary-codex:fetch` command for actual fetching.

## Resource URI Format

Resources use the `codex://` URI scheme:

```
codex://{project}/{path}

Examples:
  codex://auth-service/docs/oauth.md
  codex://faber-cloud/specs/SPEC-0020.md
  codex://shared/standards/api-design.md
```

URI format matches the cache path structure for perfect alignment.

## Resource Metadata

Each resource includes metadata:
- **source**: Where the document came from (fractary-codex, external-url, etc.)
- **cached_at**: When it was cached
- **expires_at**: When it expires (based on TTL)
- **fresh**: Boolean indicating if content is current
- **size_bytes**: Document size

## Integration with Codex Plugin

The MCP server is **read-only** and serves cached content. To fetch new documents or refresh cache:

1. Use `/fractary-codex:fetch @codex/project/path`
2. Use `/fractary-codex:cache-list` to view cache
3. Use `/fractary-codex:cache-clear` to manage cache

The MCP server automatically reflects cache changes.

## Development

```bash
# Install dependencies
npm install

# Development mode (auto-restart)
npm run dev

# Build
npm run build

# Run built server
npm start
```

## Architecture

```
Claude Desktop/Code
       ↓
MCP Protocol (stdio)
       ↓
Fractary Codex MCP Server (index.ts)
       ↓
Cache Index (.cache-index.json)
       ↓
Cached Documents (codex/{project}/{path})
```

The server is stateless and reads directly from the filesystem cache.

## Limitations

- **Read-only**: Cannot modify cache (use plugin commands)
- **No live fetching**: Serves only cached content
- **No subscriptions**: File watching not implemented (future enhancement)
- **Single workspace**: Configured per workspace

## Future Enhancements (Phase 3+)

- **Resource subscriptions**: Notify on cache updates
- **Context7 integration**: Observe and cache Context7 MCP responses
- **Tool execution**: Actually invoke document-fetcher skill
- **Multi-workspace**: Support multiple project caches
- **Search resources**: Query by content, tags, etc.

## Troubleshooting

**Server not starting:**
- Check Node.js version (>=18.0.0 required)
- Verify paths in MCP configuration
- Check server logs (stderr)

**Resources not appearing:**
- Ensure cache exists (`codex/` directory)
- Ensure cache index exists (`.cache-index.json`)
- Fetch some documents first: `/fractary-codex:fetch @codex/...`

**Permission denied:**
- Verify server has read access to cache directory
- Check file permissions on cache files

## Related Documentation

- [SPEC-0030-04: MCP Integration](../../../docs/specs/SPEC-0030-04-phase3-mcp-integration.md)
- [MCP Protocol Documentation](https://modelcontextprotocol.io)
- [Codex Plugin README](../README.md)

## License

MIT
