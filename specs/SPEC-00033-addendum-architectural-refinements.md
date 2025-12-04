# SPEC-00033 Addendum: Architectural Refinements

**Parent Spec**: SPEC-00033-codex-mcp-server-and-sync-unification.md
**Implementation**: WORK-00216-codex-mcp-server-implementation-plan.md
**Date**: 2025-01-15
**Status**: Approved

This addendum documents architectural refinements to SPEC-00033 based on implementation review.

---

## 1. Cache Location Change

### Original
```
project/
├── codex/                    # Root-level cache directory
│   └── {org}/{project}/...
```

### Refined
```
project/
├── .fractary/
│   └── plugins/
│       └── codex/
│           ├── config.json   # Plugin configuration
│           ├── cache/        # Ephemeral cache (gitignored)
│           │   ├── {org}/{project}/...
│           │   └── .cache-index.json
│           └── state.json    # Plugin state (optional)
```

### Rationale
- Keeps all Fractary plugin data in one `.fractary/` directory
- No need for root-level `/codex/` directory
- Since `@codex/` file references are deprecated (see below), there's no need for a visible directory
- Consistent with other Fractary plugins

### Migration
- Update all path references from `codex/` to `.fractary/plugins/codex/cache/`
- Update gitignore patterns: `.fractary/plugins/codex/cache/`
- Environment variable: `CODEX_CACHE_PATH="./.fractary/plugins/codex/cache"`

---

## 2. Deprecated: @codex/ File References

### Original
The spec supported both reference formats:
- `@codex/project/path` - File-based references (for markdown links)
- `codex://project/path` - MCP URI references

### Refined
**Only `codex://` URI format is supported.**

### Rationale
- `codex://` URIs enable automatic on-demand fetching via MCP
- `@codex/` references required a visible `/codex/` directory
- Single reference format simplifies documentation and tooling
- MCP-first approach is the future direction

### Migration
- Replace all `@codex/` references with `codex://` URIs
- The `validate-refs` command will flag `@codex/` usage

---

## 3. Unified Fetch Layer

### Original
The spec showed duplicated fetch logic:
- Sync commands → handler skills → shell scripts
- MCP server → inline TypeScript fetch functions

### Refined
**Single fetch layer used by both sync and MCP server.**

```
┌─────────────────────────────────────────────────────────────────────┐
│  Sync Commands                    MCP Server                        │
│  /fractary-codex:sync-project     ReadResourceRequest               │
│            │                              │                         │
│            └──────────────┬───────────────┘                         │
│                           ▼                                         │
│               ┌───────────────────────┐                             │
│               │   Unified Fetch Layer │                             │
│               │   (Shell Scripts)     │                             │
│               └───────────────────────┘                             │
│                           │                                         │
│         ┌─────────────────┼─────────────────┐                       │
│         ▼                 ▼                 ▼                       │
│   handler-sync-github  handler-http    (future handlers)            │
│                                                                     │
│                           │                                         │
│                           ▼                                         │
│               ┌───────────────────────┐                             │
│               │   Cache Management    │                             │
│               │   update-cache-index  │                             │
│               └───────────────────────┘                             │
└─────────────────────────────────────────────────────────────────────┘
```

### Implementation
- MCP server invokes fetch scripts via `child_process.exec()`
- Scripts output JSON results
- Same cache index management for both paths

### New Files
```
plugins/codex/lib/
├── fetch-github.sh      # GitHub raw content fetch
├── fetch-http.sh        # HTTP/HTTPS fetch
├── cache-manager.sh     # Cache index operations
└── resolve-uri.sh       # URI parsing and path resolution
```

---

## 4. Removed: MCP-to-MCP Communication

### Original
The spec included `handler-mcp` for fetching from other MCP servers (e.g., Context7).

### Refined
**MCP-to-MCP communication is removed.**

### Rationale
- The codex MCP server is itself an MCP server
- Claude already has direct access to other MCP servers
- No technical benefit to proxy MCP calls through codex
- Simplifies architecture significantly

### Future Direction
A future version may support vector store sources for semantic search, but this is out of scope for the current implementation.

### Removed Components
- `handler-mcp` skill (not created)
- `context7` source type
- MCP server resource types in source registry

---

## 5. Authentication Cascade

### Original
Authentication mechanism was unspecified.

### Refined
**Cascade authentication with sensible defaults.**

```
Authentication Resolution Order:
1. Source-specific token in codex config (for multi-org scenarios)
2. Repo plugin configuration (if available)
3. Environment variable (GITHUB_TOKEN)
4. User's git credential helper / SSH keys
```

### Configuration
```json
{
  "sources": {
    "fractary": {
      "type": "github-org",
      "token_env": "FRACTARY_GITHUB_TOKEN"  // Optional override
    },
    "partner-org": {
      "type": "github-org",
      "token": "${PARTNER_TOKEN}"           // From env var
    }
  },
  "auth": {
    "default": "inherit",                   // Use repo plugin / git config
    "fallback_to_public": true              // Try unauthenticated if auth fails
  }
}
```

### Common Case
For single-org usage (90% of cases), no auth configuration needed - inherits from existing git/repo setup.

---

## 6. TTL Configuration

### Original
TTL specified in days: `ttl_days: 7`

### Refined
**TTL in seconds with human-readable defaults.**

```json
{
  "cache": {
    "default_ttl": 604800,     // 7 days in seconds
    "check_expiration": true,
    "fallback_to_stale": true
  },
  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 1209600           // 14 days for stable plugin docs
    },
    "external-api-docs": {
      "type": "http",
      "ttl": 86400             // 1 day for frequently updated docs
    }
  }
}
```

### Common Values
| Duration | Seconds |
|----------|---------|
| 1 hour   | 3600    |
| 1 day    | 86400   |
| 7 days   | 604800  |
| 14 days  | 1209600 |
| 30 days  | 2592000 |

---

## 7. Offline Mode

### New Feature
**Explicit offline mode for network-restricted environments.**

```json
{
  "cache": {
    "offline_mode": false,      // Default: disabled
    "fallback_to_stale": true
  }
}
```

### Behavior When `offline_mode: true`
- Skip all network fetch attempts
- Return cached content only (fresh or stale)
- Return clear error if content not in cache
- No TTL expiration checks (always use cached)

### Use Cases
- Airplane mode development
- CI/CD with pre-populated cache
- Air-gapped environments
- Reducing network latency

---

## 8. MCP Server Distribution

### Original
Assumed MCP server at `plugins/codex/mcp-server/dist/index.js` with unclear distribution.

### Refined
**Distributed via Claude marketplace plugin installation.**

### Installation Path
```
~/.claude/plugins/marketplaces/fractary/plugins/codex/
├── mcp-server/
│   ├── dist/
│   │   └── index.js          # Pre-compiled
│   ├── package.json
│   └── node_modules/         # Dependencies
├── skills/
├── commands/
└── .claude-plugin/
```

### MCP Configuration (in project `.claude/settings.json`)
```json
{
  "mcpServers": {
    "fractary-codex": {
      "command": "node",
      "args": [
        "~/.claude/plugins/marketplaces/fractary/plugins/codex/mcp-server/dist/index.js"
      ],
      "env": {
        "CODEX_CACHE_PATH": "./.fractary/plugins/codex/cache",
        "CODEX_CONFIG_PATH": "./.fractary/plugins/codex/config.json"
      }
    }
  }
}
```

### Build Process
- MCP server TypeScript compiled during plugin build/release
- `dist/` directory included in plugin distribution
- No build step required for users

---

## 9. Fractary-Docs Integration (Separate Spec)

### Original
Phase 6 included fractary-docs plugin modifications.

### Refined
**Moved to separate specification: SPEC-00217.**

### Rationale
- Cross-plugin changes should be separate issues
- Allows independent development and testing
- Clearer scope for each implementation

### SPEC-00217 Scope
- Auto-convert relative paths in syncable docs
- Validate `codex_sync_include: true` docs for portable references
- Integration with codex plugin for URI generation

---

## Summary of Changes

| Area | Original | Refined |
|------|----------|---------|
| Cache path | `codex/` | `.fractary/plugins/codex/cache/` |
| Reference format | `@codex/` + `codex://` | `codex://` only |
| Fetch architecture | Duplicated (sync vs MCP) | Unified fetch layer |
| MCP-to-MCP | Supported (Context7) | Removed |
| Authentication | Unspecified | Cascade with defaults |
| TTL format | Days (`ttl_days: 7`) | Seconds (`ttl: 604800`) |
| Offline mode | Not supported | Optional, disabled by default |
| Distribution | Unclear | Marketplace plugin install |
| Fractary-docs | Phase 6 inline | Separate SPEC-00217 |

---

## Updated File Structure

```
plugins/codex/
├── mcp-server/
│   ├── src/index.ts           # MCP server (delegates to lib/)
│   ├── dist/index.js          # Compiled (distributed)
│   └── package.json
├── lib/                       # NEW: Unified fetch layer
│   ├── fetch-github.sh
│   ├── fetch-http.sh
│   ├── cache-manager.sh
│   └── resolve-uri.sh
├── scripts/
│   ├── install-mcp.sh
│   ├── uninstall-mcp.sh
│   ├── setup-cache-dir.sh
│   ├── update-cache-index.sh
│   ├── read-cache-index.sh
│   ├── validate-refs.sh
│   └── validate-setup.sh
├── skills/
│   ├── handler-sync-github/   # Uses lib/ scripts
│   ├── handler-http/          # Uses lib/ scripts
│   ├── project-syncer/
│   └── org-syncer/
├── commands/
│   ├── init.md
│   ├── validate-refs.md
│   └── validate-setup.md
└── .claude-plugin/
    └── plugin.json
```
