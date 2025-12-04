# Implementation Plan: Codex MCP Server & Sync Unification

**Specification ID**: SPEC-00216
**Issue**: #216 - codex mcp server and sync unification
**Parent Spec**: `specs/SPEC-00033-codex-mcp-server-and-sync-unification.md`
**Branch**: `feat/216-codex-mcp-server-and-sync-unification`
**Status**: Approved

---

## Overview

Unify v2.0 sync commands with v3.0 MCP-based retrieval architecture by:
1. Adding MCP server that exposes `codex://` resources from local cache
2. Modifying `/fractary-codex:init` to install MCP server reference
3. Updating `--from-codex` sync to write to ephemeral `codex/` cache
4. Making sync serve as "prefetch" for the MCP server

## Current State Analysis

**Existing MCP Server** (`plugins/codex/mcp-server/src/index.ts`):
- Basic implementation exists with `codex_fetch` and `codex_cache_status` tools
- Reads from `CODEX_CACHE_PATH` (default: `./codex`)
- Has cache index reading and freshness checking
- Missing: on-demand fetch, current project detection, URI resolution

**Existing Init Command** (`plugins/codex/commands/init.md`):
- Creates `.fractary/plugins/codex/config.json`
- Detects organization from git remote
- Missing: MCP server installation, cache directory creation

**Existing Sync** (`plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`):
- Syncs from codex repo to project
- Currently writes to project root (permanent)
- Missing: cache mode (ephemeral to `codex/`)

---

## Implementation Phases

### Phase 1: MCP Installation Infrastructure

#### Task 1.1: Create `scripts/install-mcp.sh`
**File**: `plugins/codex/scripts/install-mcp.sh`

- Find plugin path (env var, global, npm)
- Verify MCP server dist exists
- Create `.claude/` directory if needed
- Backup existing settings.json
- Add `mcpServers.fractary-codex` configuration via jq
- Set environment variables: `CODEX_ROOT`, `CODEX_CONFIG_PATH`

#### Task 1.2: Create `scripts/uninstall-mcp.sh`
**File**: `plugins/codex/scripts/uninstall-mcp.sh`

- Remove `mcpServers.fractary-codex` from settings.json
- Optional: clean up `codex/` directory
- Restore backup if available

#### Task 1.3: Create `scripts/setup-cache-dir.sh`
**File**: `plugins/codex/scripts/setup-cache-dir.sh`

- Create `codex/` directory
- Create `codex/.gitignore` (ignore all except index)
- Add `codex/` to project root `.gitignore`
- Create empty `.cache-index.json`

#### Task 1.4: Update init command workflow
**File**: `plugins/codex/commands/init.md`

Add new workflow steps:
- Step 4: Create cache directory (invoke setup-cache-dir.sh)
- Step 5: Install MCP server (invoke install-mcp.sh)
- Update completion output to show MCP status

#### Task 1.5: Ensure MCP server builds
- Verify `npm run build` works in `mcp-server/`
- Add build to plugin installation process
- Document Node.js requirements

---

### Phase 2: Sync Unification (Cache Mode)

#### Task 2.1: Create cache index management scripts
**File**: `plugins/codex/scripts/update-cache-index.sh`

- Add/update entries in `.cache-index.json`
- Calculate TTL and expiration
- Track source and sync metadata

**File**: `plugins/codex/scripts/read-cache-index.sh`

- Read and parse cache index
- Check entry freshness
- Output JSON for skill consumption

#### Task 2.2: Update sync-from-codex workflow
**File**: `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md`

Changes:
- Target path: `codex/{project}/` instead of project root
- Remove git commit step for target (files are gitignored)
- Add cache index update step
- Set `CACHE_MODE=true` for handler

#### Task 2.3: Update handler-sync-github
**File**: `plugins/codex/skills/handler-sync-github/workflow/sync-files.md`
**File**: `plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh`

Add CACHE_MODE parameter:
- When true: target = `codex/{project}/path`
- When true: skip commit creation
- When true: update cache index after sync
- When true: set synced_via = "sync-project"

#### Task 2.4: Update sync-org for cache mode
**File**: `plugins/codex/skills/org-syncer/SKILL.md`

- Apply same cache mode changes for org-wide sync
- Aggregate cache index updates across projects

---

### Phase 3: Universal Reference Resolution

#### Task 3.1: Add current project detection to MCP server
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `detectCurrentProject()`:
1. Check `CODEX_CURRENT_ORG` + `CODEX_CURRENT_PROJECT` env vars
2. Read from config file: `organization` + `project_name`
3. Parse git remote URL
4. Fallback to directory names

#### Task 3.2: Update config schema
**File**: `plugins/codex/.claude-plugin/config.schema.json`

Add new fields:
- `project_name`: Current project name
- `cache.default_ttl_days`: Default cache TTL
- `cache.check_expiration`: Enable/disable expiration checks
- `cache.fallback_to_stale`: Use stale content on fetch failure

#### Task 3.3: Implement URI resolution logic
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `resolveUri()`:
- Parse `codex://org/project/path` (GitHub format)
- Parse `codex://identifier/path` (external format)
- Current project → resolve to project root
- Other projects → resolve to cache directory

#### Task 3.4: Update init to store project_name
**File**: `plugins/codex/commands/init.md`

- Detect project name from git remote or directory
- Store in config.json
- Pass to MCP server via env vars

#### Task 3.5: Create reference validation command
**File**: `plugins/codex/commands/validate-refs.md`
**File**: `plugins/codex/scripts/validate-refs.sh`

- Scan markdown files for non-portable references
- Flag `../` and `/` paths in syncable docs
- Suggest `codex://` replacements
- Optional `--fix` mode for auto-conversion

---

### Phase 4: On-Demand Fetch & Multi-Source

#### Task 4.1: Implement on-demand fetch in MCP server
**File**: `plugins/codex/mcp-server/src/index.ts`

Implement `readResource()` with cache-miss handling:
- Check if file exists in cache
- Check if entry is expired
- If missing/expired: fetch and cache automatically
- Update cache index with fetch metadata

Implement `fetchAndCache()`:
- Determine handler from source type
- Invoke appropriate fetch mechanism
- Write to cache directory
- Update cache index

#### Task 4.2: Implement GitHub fetch
**File**: `plugins/codex/mcp-server/src/index.ts`

- Fetch from GitHub raw content API
- Handle authentication for private repos
- Error handling with helpful messages

#### Task 4.3: Implement source registry
**File**: `plugins/codex/mcp-server/src/index.ts`

- Load `sources` from cache index
- `getHandler()` for source type lookup
- Infer handler from identifier pattern as fallback

#### Task 4.4: Update cache index schema
**File**: `plugins/codex/scripts/update-cache-index.sh`

Add source registry:
```json
{
  "sources": {
    "corthosai": { "type": "github-org", "handler": "..." },
    "context7": { "type": "mcp", "handler": "..." }
  },
  "current_project": { "org": "...", "project": "..." },
  "entries": [...]
}
```

#### Task 4.5: Add on-demand fetch configuration
**File**: `plugins/codex/.claude-plugin/config.schema.json`

Add `on_demand_fetch` section:
- `enabled`: Toggle feature
- `timeout_ms`: Fetch timeout
- `retry_count`: Number of retries
- `fallback_to_stale`: Use stale on failure
- `allowed_orgs`: Whitelist
- `blocked_domains`: Blacklist

#### Task 4.6: Create handler-mcp skill
**File**: `plugins/codex/skills/handler-mcp/SKILL.md`
**File**: `plugins/codex/skills/handler-mcp/scripts/fetch-mcp.sh`

- Fetch resources from MCP servers (Context7)
- Cache responses with source-specific TTL
- Handle MCP protocol communication

#### Task 4.7: Update handler-http skill
**File**: `plugins/codex/skills/handler-http/SKILL.md`

- Enhance for on-demand fetch use case
- Add TTL configuration per domain
- Add URL-to-path mapping

---

### Phase 5: Integration & Documentation

#### Task 5.1: Add codex_sync_status tool
**File**: `plugins/codex/mcp-server/src/index.ts`

New MCP tool:
- Check if cache was populated via sync
- Show sync timestamp and file counts
- Show projects in cache

#### Task 5.2: Create validate-setup command
**File**: `plugins/codex/commands/validate-setup.md`
**File**: `plugins/codex/scripts/validate-setup.sh`

Validation checks:
- Config file exists
- Cache directory exists
- MCP server installed in settings.json
- Cache index valid

#### Task 5.3: Update README and documentation
**Files**:
- `plugins/codex/README.md`
- `plugins/codex/docs/MCP-INTEGRATION.md`
- `plugins/codex/QUICK-START.md`

Document:
- New unified workflow
- Reference guidelines (when to use `codex://`)
- Multi-source configuration

#### Task 5.4: Create migration guide
**File**: `plugins/codex/docs/MIGRATION-v3.md`

- Breaking changes documentation
- Step-by-step migration

---

### Phase 6: Fractary-Docs Integration (Future)

#### Task 6.1: Update doc-writer skill
- Detect `codex_sync_include: true` frontmatter
- Auto-convert relative paths to `codex://` during write
- Log conversions to user

#### Task 6.2: Update doc-validator skill
- Check syncable docs for non-portable references
- Generate fix suggestions
- Implement `--fix` option

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

#### Task 7.3: Sync cache behavior options
- `--respect-cache` flag
- `--force` flag
- Default behavior configuration

---

## Recommended Implementation Order

### Milestone 1: Core Infrastructure (Priority: High)
1. Task 1.3: setup-cache-dir.sh
2. Task 1.1: install-mcp.sh
3. Task 1.2: uninstall-mcp.sh
4. Task 1.4: Update init command
5. Task 1.5: Ensure MCP builds

### Milestone 2: Sync Unification (Priority: High)
6. Task 2.1: Cache index scripts
7. Task 2.2: Update sync-from-codex workflow
8. Task 2.3: Update handler-sync-github
9. Task 2.4: Update sync-org

### Milestone 3: URI Resolution (Priority: High)
10. Task 3.1: Current project detection
11. Task 3.2: Update config schema
12. Task 3.3: URI resolution logic
13. Task 3.4: Update init for project_name

### Milestone 4: On-Demand Fetch (Priority: Medium)
14. Task 4.1: On-demand fetch in MCP
15. Task 4.2: GitHub fetch implementation
16. Task 4.3: Source registry
17. Task 4.4: Cache index schema update
18. Task 4.5: On-demand fetch config

### Milestone 5: Validation & Docs (Priority: Medium)
19. Task 3.5: validate-refs command
20. Task 5.1: codex_sync_status tool
21. Task 5.2: validate-setup command
22. Task 5.3: Update documentation
23. Task 5.4: Migration guide

### Milestone 6: Multi-Source (Priority: Low)
24. Task 4.6: handler-mcp skill
25. Task 4.7: Update handler-http

### Milestone 7: Fractary-Docs & Wildcards (Priority: Future)
26. Phase 6 tasks
27. Phase 7 tasks

---

## Files to Create/Modify Summary

### New Files
- `plugins/codex/scripts/install-mcp.sh`
- `plugins/codex/scripts/uninstall-mcp.sh`
- `plugins/codex/scripts/setup-cache-dir.sh`
- `plugins/codex/scripts/update-cache-index.sh`
- `plugins/codex/scripts/read-cache-index.sh`
- `plugins/codex/scripts/validate-refs.sh`
- `plugins/codex/scripts/validate-setup.sh`
- `plugins/codex/commands/validate-refs.md`
- `plugins/codex/commands/validate-setup.md`
- `plugins/codex/docs/MIGRATION-v3.md`
- `plugins/codex/skills/handler-mcp/SKILL.md` (future)
- `plugins/codex/skills/handler-mcp/scripts/fetch-mcp.sh` (future)

### Modify Files
- `plugins/codex/mcp-server/src/index.ts` (major enhancements)
- `plugins/codex/commands/init.md` (add MCP installation steps)
- `plugins/codex/skills/project-syncer/workflow/sync-from-codex.md` (cache mode)
- `plugins/codex/skills/handler-sync-github/workflow/sync-files.md` (cache mode)
- `plugins/codex/skills/handler-sync-github/scripts/sync-docs.sh` (cache mode)
- `plugins/codex/skills/org-syncer/SKILL.md` (cache mode)
- `plugins/codex/.claude-plugin/config.schema.json` (new fields)
- `plugins/codex/README.md` (documentation)
- `plugins/codex/docs/MCP-INTEGRATION.md` (documentation)
- `plugins/codex/QUICK-START.md` (documentation)

---

## Risk Assessment

### Low Risk
- Script creation (install-mcp, setup-cache-dir, etc.)
- Documentation updates
- New validation commands

### Medium Risk
- Sync workflow changes
- Cache index schema changes
- MCP server enhancements

### Higher Risk
- Breaking change: `--from-codex` behavior change (ephemeral cache instead of project root)
  - Note: No backward compatibility mode - clean break
- On-demand fetch network dependencies
  - Mitigation: Fallback to stale content, configurable timeouts

---

## Testing Strategy

1. **Unit tests**: Shell scripts with test cases
2. **Integration tests**: Init → Sync → MCP access flow
3. **Manual testing**: Cross-project references, cache behavior
4. **Validation commands**: Built-in setup verification
