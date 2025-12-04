# Implementation Plan: Codex MCP Server & Sync Unification

**Specification ID**: SPEC-00216
**Issue**: #216 - codex mcp server and sync unification
**Parent Spec**: `specs/SPEC-00033-codex-mcp-server-and-sync-unification.md`
**Addendum**: `specs/SPEC-00033-addendum-architectural-refinements.md`
**Branch**: `feat/216-codex-mcp-server-and-sync-unification`
**Status**: Approved

---

## Overview

Unify v2.0 sync commands with v3.0 MCP-based retrieval architecture by:
1. Adding MCP server that exposes `codex://` resources from local cache
2. Modifying `/fractary-codex:init` to install MCP server reference
3. Updating `--from-codex` sync to write to ephemeral `.fractary/plugins/codex/cache/`
4. Making sync serve as "prefetch" for the MCP server

## Key Architectural Decisions

See `SPEC-00033-addendum-architectural-refinements.md` for full details:

| Decision | Value |
|----------|-------|
| Cache location | `.fractary/plugins/codex/cache/` |
| Reference format | `codex://` only (`@codex/` deprecated) |
| Fetch architecture | Unified layer (lib/ scripts) |
| MCP-to-MCP | Removed (no Context7 handler) |
| TTL format | Seconds (default: 604800 = 7 days) |
| Offline mode | Supported, disabled by default |
| Authentication | Cascade: config → repo plugin → env → git |
| Distribution | Via marketplace plugin install |
| Fractary-docs | Separate spec (SPEC-00217) |

---

## Current State Analysis

**Existing MCP Server** (`plugins/codex/mcp-server/src/index.ts`):
- Basic implementation exists with `codex_fetch` and `codex_cache_status` tools
- Reads from `CODEX_CACHE_PATH`
- Has cache index reading and freshness checking
- Missing: on-demand fetch, current project detection, URI resolution, unified fetch

**Existing Init Command** (`plugins/codex/commands/init.md`):
- Creates `.fractary/plugins/codex/config.json`
- Detects organization from git remote
- Missing: MCP server installation, cache directory creation

**Existing Sync** (`plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`):
- Syncs from codex repo to project
- Currently writes to project root (permanent)
- Missing: cache mode (ephemeral)

---

## Implementation Phases

### Phase 1: Core Infrastructure

#### Task 1.1: Create unified fetch layer
**Directory**: `plugins/codex/lib/`

Create shared scripts used by both sync and MCP server:

```
plugins/codex/lib/
├── fetch-github.sh      # GitHub raw content fetch with auth cascade
├── fetch-http.sh        # HTTP/HTTPS fetch
├── cache-manager.sh     # Read/write cache index, TTL checks
└── resolve-uri.sh       # Parse codex:// URIs, resolve paths
```

**fetch-github.sh**:
- Fetch from GitHub raw content API
- Authentication cascade: config token → `GITHUB_TOKEN` env → git credential
- Handle public fallback if `fallback_to_public: true`
- Output JSON with content and metadata

**cache-manager.sh**:
- `cache-get <uri>` - Check cache, return content if fresh
- `cache-put <uri> <content>` - Write to cache, update index
- `cache-check <uri>` - Return freshness status
- TTL in seconds (default 604800)

#### Task 1.2: Create `scripts/setup-cache-dir.sh`
**File**: `plugins/codex/scripts/setup-cache-dir.sh`

- Create `.fractary/plugins/codex/cache/` directory
- Create `cache/.gitignore` (ignore all except index)
- Add `.fractary/plugins/codex/cache/` to project `.gitignore`
- Create empty `.cache-index.json`

#### Task 1.3: Create `scripts/install-mcp.sh`
**File**: `plugins/codex/scripts/install-mcp.sh`

- Resolve marketplace plugin path: `~/.claude/plugins/marketplaces/fractary/plugins/codex/`
- Verify MCP server dist exists
- Create `.claude/` directory if needed
- Backup existing settings.json
- Add `mcpServers.fractary-codex` configuration via jq
- Set environment variables:
  - `CODEX_CACHE_PATH="./.fractary/plugins/codex/cache"`
  - `CODEX_CONFIG_PATH="./.fractary/plugins/codex/config.json"`

#### Task 1.4: Create `scripts/uninstall-mcp.sh`
**File**: `plugins/codex/scripts/uninstall-mcp.sh`

- Remove `mcpServers.fractary-codex` from settings.json
- Optional: clean up cache directory
- Restore settings.json backup if available

#### Task 1.5: Update init command workflow
**File**: `plugins/codex/commands/init.md`

Add new workflow steps:
- Step 4: Create cache directory (invoke setup-cache-dir.sh)
- Step 5: Install MCP server (invoke install-mcp.sh)
- Step 6: Detect and store project_name in config
- Update completion output to show MCP status and cache location

#### Task 1.6: Ensure MCP server builds
- Verify `npm run build` works in `mcp-server/`
- Ensure dist/ is included in plugin distribution
- Document Node.js requirements (>=18)

---

### Phase 2: Sync Unification (Cache Mode)

#### Task 2.1: Create cache index management scripts
**File**: `plugins/codex/scripts/update-cache-index.sh`

- Add/update entries in `.cache-index.json`
- Calculate expiration from TTL (seconds)
- Track source, sync metadata, size

**File**: `plugins/codex/scripts/read-cache-index.sh`

- Read and parse cache index
- Check entry freshness (current time vs expires_at)
- Output JSON for skill/MCP consumption

#### Task 2.2: Update sync-from-codex workflow
**File**: `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`

Changes:
- Target path: `.fractary/plugins/codex/cache/{org}/{project}/`
- Remove git commit step for target (files are gitignored)
- Add cache index update step via lib/cache-manager.sh
- Set `CACHE_MODE=true` for handler

#### Task 2.3: Update handler-sync-github
**File**: `plugins/codex/skills/handler-sync-github/workflow/sync-files.md`
**File**: `plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh`

Add CACHE_MODE parameter:
- When true: target = `.fractary/plugins/codex/cache/{org}/{project}/path`
- When true: skip commit creation
- When true: update cache index after sync
- When true: set `synced_via: "sync-project"`
- Use lib/cache-manager.sh for index operations

#### Task 2.4: Update sync-org for cache mode
**File**: `plugins/codex/skills/org-syncer/SKILL.md`

- Apply same cache mode changes for org-wide sync
- Aggregate cache index updates across projects

---

### Phase 3: MCP Server Enhancement

#### Task 3.1: Add current project detection
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `detectCurrentProject()`:
1. Check `CODEX_CURRENT_ORG` + `CODEX_CURRENT_PROJECT` env vars
2. Read from config file: `organization` + `project_name`
3. Parse git remote URL via child_process
4. Fallback to directory names

#### Task 3.2: Implement URI resolution logic
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `resolveUri()`:
- Parse `codex://org/project/path` (GitHub format)
- Parse `codex://identifier/path` (external format)
- Current project → resolve to project root (local files)
- Other projects → resolve to cache directory

#### Task 3.3: Implement on-demand fetch via unified layer
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `readResource()` with cache-miss handling:
- Check cache via lib/cache-manager.sh
- If missing/expired and not offline_mode:
  - Invoke lib/fetch-github.sh or lib/fetch-http.sh
  - Write result via lib/cache-manager.sh
- Return content with metadata

Key: MCP server delegates to lib/ scripts via `child_process.exec()`

#### Task 3.4: Add offline mode support
**File**: `plugins/codex/mcp-server/src/index.ts`

When `config.cache.offline_mode: true`:
- Skip all network fetch attempts
- Return cached content only (ignore expiration)
- Return clear error if not in cache

#### Task 3.5: Update config schema
**File**: `plugins/codex/.claude-plugin/config.schema.json`

Add new fields:
```json
{
  "project_name": "string",
  "cache": {
    "default_ttl": 604800,
    "check_expiration": true,
    "fallback_to_stale": true,
    "offline_mode": false
  },
  "auth": {
    "default": "inherit",
    "fallback_to_public": true
  },
  "sources": {
    "<org>": {
      "type": "github-org",
      "ttl": 604800,
      "token_env": "GITHUB_TOKEN"
    }
  }
}
```

---

### Phase 4: Validation & Documentation

#### Task 4.1: Create reference validation command
**File**: `plugins/codex/commands/validate-refs.md`
**File**: `plugins/codex/scripts/validate-refs.sh`

- Scan markdown files for non-portable references
- Flag `../`, `/`, and deprecated `@codex/` references
- Suggest `codex://` replacements
- Optional `--fix` mode for auto-conversion

#### Task 4.2: Add codex_sync_status tool
**File**: `plugins/codex/mcp-server/src/index.ts`

New MCP tool:
- Check if cache was populated via sync
- Show sync timestamp and file counts
- Show projects in cache
- Show offline mode status

#### Task 4.3: Create validate-setup command
**File**: `plugins/codex/commands/validate-setup.md`
**File**: `plugins/codex/scripts/validate-setup.sh`

Validation checks:
- Config file exists at `.fractary/plugins/codex/config.json`
- Cache directory exists at `.fractary/plugins/codex/cache/`
- MCP server installed in `.claude/settings.json`
- Cache index valid

#### Task 4.4: Update README and documentation
**Files**:
- `plugins/codex/README.md`
- `plugins/codex/docs/MCP-INTEGRATION.md`
- `plugins/codex/QUICK-START.md`

Document:
- New unified workflow
- Reference guidelines (`codex://` only)
- Cache location change
- Offline mode usage

#### Task 4.5: Create migration guide
**File**: `plugins/codex/docs/MIGRATION-v3.md`

- Breaking changes: cache location, `@codex/` deprecation
- Step-by-step migration
- Configuration updates

---

### Phase 5: Handler Updates

#### Task 5.1: Refactor handler-sync-github to use lib/
**File**: `plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh`

- Move fetch logic to lib/fetch-github.sh
- Use lib/cache-manager.sh for cache operations
- Keep sync-specific orchestration in handler

#### Task 5.2: Update handler-http to use lib/
**File**: `plugins/codex/skills/handler-http/SKILL.md`

- Use lib/fetch-http.sh for HTTP operations
- Integrate with cache-manager.sh
- Support TTL per domain configuration

---

### Phase 6: Fractary-Docs Integration (Separate)

**See**: SPEC-00217-fractary-docs-codex-integration.md

This phase is moved to a separate specification and issue.

---

### Phase 7: Wildcard & Sync Enhancements (Future)

#### Task 7.1: Implement wildcard MCP requests
- Detect `*`, `**`, `*.md` patterns in URIs
- Pattern matching in cache
- GitHub API file listing for discovery

#### Task 7.2: Bulk fetch for wildcards
- Parallel fetching with concurrency limit
- Progress reporting
- Partial failure handling

---

## Recommended Implementation Order

### Milestone 1: Core Infrastructure (Priority: High)
1. Task 1.1: Create unified fetch layer (lib/)
2. Task 1.2: setup-cache-dir.sh
3. Task 1.3: install-mcp.sh
4. Task 1.4: uninstall-mcp.sh
5. Task 1.5: Update init command
6. Task 1.6: Ensure MCP builds

### Milestone 2: Sync Unification (Priority: High)
7. Task 2.1: Cache index scripts
8. Task 2.2: Update sync-from-codex workflow
9. Task 2.3: Update handler-sync-github
10. Task 2.4: Update sync-org

### Milestone 3: MCP Server Enhancement (Priority: High)
11. Task 3.1: Current project detection
12. Task 3.2: URI resolution logic
13. Task 3.3: On-demand fetch via unified layer
14. Task 3.4: Offline mode support
15. Task 3.5: Update config schema

### Milestone 4: Validation & Docs (Priority: Medium)
16. Task 4.1: validate-refs command
17. Task 4.2: codex_sync_status tool
18. Task 4.3: validate-setup command
19. Task 4.4: Update documentation
20. Task 4.5: Migration guide

### Milestone 5: Handler Refactoring (Priority: Medium)
21. Task 5.1: Refactor handler-sync-github
22. Task 5.2: Update handler-http

---

## Files Summary

### New Files
```
plugins/codex/lib/
├── fetch-github.sh
├── fetch-http.sh
├── cache-manager.sh
└── resolve-uri.sh

plugins/codex/scripts/
├── install-mcp.sh
├── uninstall-mcp.sh
├── setup-cache-dir.sh
├── update-cache-index.sh
├── read-cache-index.sh
├── validate-refs.sh
└── validate-setup.sh

plugins/codex/commands/
├── validate-refs.md
└── validate-setup.md

plugins/codex/docs/
└── MIGRATION-v3.md
```

### Modified Files
```
plugins/codex/mcp-server/src/index.ts
plugins/codex/commands/init.md
plugins/codex/skills/project-syncer/workflow/sync-from-codex.md
plugins/codex/skills/handler-sync-github/workflow/sync-files.md
plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh
plugins/codex/skills/org-syncer/SKILL.md
plugins/codex/skills/handler-http/SKILL.md
plugins/codex/.claude-plugin/config.schema.json
plugins/codex/README.md
plugins/codex/docs/MCP-INTEGRATION.md
plugins/codex/QUICK-START.md
```

### Removed (Not Created)
```
plugins/codex/skills/handler-mcp/  # MCP-to-MCP removed
```

---

## Risk Assessment

### Low Risk
- Script creation (lib/, scripts/)
- Documentation updates
- New validation commands

### Medium Risk
- Sync workflow changes (cache path change)
- Cache index schema changes
- MCP server enhancements

### Higher Risk
- Breaking change: cache location `.fractary/plugins/codex/cache/`
  - Clean break, no backward compatibility
- On-demand fetch network dependencies
  - Mitigation: offline_mode, fallback_to_stale

---

## Testing Strategy

1. **Unit tests**: Shell scripts with test cases
2. **Integration tests**: Init → Sync → MCP access flow
3. **Manual testing**: Cross-project references, cache behavior, offline mode
4. **Validation commands**: Built-in setup verification
