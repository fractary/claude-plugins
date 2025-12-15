---
spec_id: SPEC-00218-codex-cli-integration-plan
work_id: 360
issue_url: https://github.com/fractary/claude-plugins/issues/360
title: Fractary Codex CLI Integration Plan
type: feature
status: draft
created: 2025-12-14
author: Claude
validated: false
source: conversation
refined: 2025-12-14
---

# Feature Specification: Fractary Codex CLI Integration Plan

**Type**: Feature
**Status**: Draft
**Created**: 2025-12-14

## Summary

This specification outlines the integration plan for migrating the `fractary-codex` Claude Code plugin from its current bash-script-based implementation to using the `@fractary/cli` (v0.3.2) and `@fractary/codex` SDK (v0.1.3). The migration will reduce custom code by ~70%, improve reliability through TypeScript type safety, and ensure consistency with the broader Fractary tooling ecosystem.

## Background

### Current State

The codex plugin (v3.0.1) currently implements:
- Document fetching with cache-first strategy
- Cache management (list, clear, stats, health)
- Project/org sync (bidirectional)
- MCP server integration
- Permission-based access control
- Multi-source support (GitHub, HTTP)

**Implementation**: Custom bash scripts (~2000+ lines) in `plugins/codex/skills/*/scripts/*.sh`

### Target State

Migrate to `@fractary/cli` which provides:
- `CodexClient` for fetching with cache management
- `CacheManager` for cache operations
- `SyncManager` for project/org synchronization
- `StorageManager` with multi-provider support
- `PermissionManager` for access control
- `TypeRegistry` for custom document types
- Built-in configuration validation and migration tools

## Functional Requirements

- **FR1**: All existing plugin commands must continue to work with same interface
- **FR2**: Plugin must delegate core operations to `fractary codex <command>` CLI
- **FR3**: Configuration must migrate from JSON to YAML format (`.fractary/codex.yaml`)
- **FR4**: Cache behavior must remain functionally equivalent (< 100ms hit, < 2s miss)
- **FR5**: MCP server integration must be preserved or upgraded to SDK version
- **FR6**: Backward compatibility period must support both JSON and YAML configs
- **FR7**: Migration tooling must convert existing configs automatically

## Non-Functional Requirements

- **NFR1**: Code reduction of at least 60% in custom bash scripts (maintainability)
- **NFR2**: No performance regression in cache operations (performance)
- **NFR3**: TypeScript type safety for all SDK operations (reliability)
- **NFR4**: Comprehensive error messages from SDK (usability)
- **NFR5**: Unit test coverage via Jest from SDK (testability)

## Technical Design

### Architecture Changes

```
Before (Current):
┌─────────────────────────────────────────────────┐
│  Plugin Commands                                │
│  (/fractary-codex:fetch, etc.)                  │
├─────────────────────────────────────────────────┤
│  codex-manager Agent                            │
│  (Delegates to skills)                          │
├─────────────────────────────────────────────────┤
│  Skills (document-fetcher, cache-*, etc.)       │
│  (Read workflow files, execute bash scripts)    │
├─────────────────────────────────────────────────┤
│  Bash Scripts (~20+ scripts, ~2000 lines)       │
│  (git sparse checkout, jq parsing, etc.)        │
└─────────────────────────────────────────────────┘

After (Target):
┌─────────────────────────────────────────────────┐
│  Plugin Commands                                │
│  (/fractary-codex:fetch, etc.)                  │
├─────────────────────────────────────────────────┤
│  codex-manager Agent                            │
│  (Simplified delegation)                        │
├─────────────────────────────────────────────────┤
│  cli-helper Skill (NEW)                         │
│  (Wrapper for CLI invocation)                   │
├─────────────────────────────────────────────────┤
│  @fractary/cli (TypeScript)                     │
│  └─ @fractary/codex SDK                         │
│     ├─ CodexClient                              │
│     ├─ CacheManager                             │
│     ├─ SyncManager                              │
│     └─ StorageManager                           │
└─────────────────────────────────────────────────┘
```

### Command Mapping

| Plugin Command | CLI Command | Notes |
|----------------|-------------|-------|
| `/fractary-codex:fetch` | `fractary codex fetch <uri>` | Direct replacement |
| `/fractary-codex:cache-list` | `fractary codex cache list` | Direct replacement |
| `/fractary-codex:cache-clear` | `fractary codex cache clear` | Direct replacement |
| `/fractary-codex:metrics` | `fractary codex cache stats` | Direct replacement |
| `/fractary-codex:health` | `fractary codex health` | Direct replacement |
| `/fractary-codex:init` | `fractary codex init` | Different config format |
| `/fractary-codex:sync-project` | `fractary codex sync project` | Direct replacement |
| `/fractary-codex:sync-org` | `fractary codex sync org` | Direct replacement |
| `/fractary-codex:migrate` | `fractary codex migrate` | Built-in migration |
| `/fractary-codex:validate-setup` | `fractary codex health` | Covered by health |
| `/fractary-codex:validate-refs` | `fractary codex check` | Reference validation |

### Configuration Migration

**Old Format** (`.fractary/plugins/codex/config.json`):
```json
{
  "version": "3.0",
  "organization": "fractary",
  "codex_repo": "codex.fractary.com",
  "cache": {
    "default_ttl": 604800,
    "check_expiration": true
  },
  "sources": {
    "fractary": {
      "type": "github-org",
      "ttl": 604800
    }
  }
}
```

**New Format** (`.fractary/codex.yaml`):
```yaml
version: "3.0"
organization: fractary
storage:
  providers:
    github:
      owner: fractary
      repo: codex.fractary.com
      branch: main
cache:
  default_ttl: 604800
  check_expiration: true
sync:
  environments:
    dev: develop
    test: test
    staging: staging
    prod: main
```

### CLI Helper Skill Design

**Architecture Decision**: The cli-helper skill is a **shared utility skill** that other skills delegate to. This provides clean separation and avoids duplicating CLI invocation logic across multiple skills.

**Location**: `plugins/codex/skills/cli-helper/`

**Structure**:
```
skills/cli-helper/
├── SKILL.md
├── workflow/
│   └── invoke-cli.md
└── scripts/
    ├── invoke-cli.sh      # Main wrapper script
    ├── validate-cli.sh    # Check CLI installation
    └── parse-output.sh    # Parse JSON output
```

**Delegation Pattern**: Other skills (document-fetcher, cache-*, etc.) delegate to cli-helper rather than calling CLI directly:
```
document-fetcher skill
    └── delegates to cli-helper skill
        └── invokes: fractary codex fetch <uri>
```

**Script**: `invoke-cli.sh`
```bash
#!/bin/bash
# Wrapper for fractary CLI codex commands
# Supports global install or npx fallback

set -e

command="$1"
shift
args="$@"

# Check for CLI availability (global first, then npx fallback)
if command -v fractary &> /dev/null; then
    FRACTARY_CMD="fractary"
elif command -v npx &> /dev/null; then
    # npx fallback - will download if not cached
    FRACTARY_CMD="npx @fractary/cli"
    echo '{"info":"Using npx fallback - consider installing globally: npm install -g @fractary/cli"}' >&2
else
    echo '{"status":"failure","message":"@fractary/cli not installed and npx not available","suggested_fixes":["Run: npm install -g @fractary/cli","Or ensure npx is available"]}' >&2
    exit 1
fi

# Execute command with JSON output
$FRACTARY_CMD codex "$command" $args --json 2>&1

exit $?
```

## Implementation Plan

### Phase 1: Foundation (Week 1-2)

**Objective**: Add CLI dependency and create wrapper infrastructure

**Tasks**:
- [ ] Add `@fractary/cli` as npm dependency for plugin
- [ ] Create `cli-helper` skill with wrapper scripts
- [ ] Add CLI installation validation
- [ ] Create JSON output parsing utilities
- [ ] Test basic CLI invocation from skill
- [ ] Document wrapper skill usage

**Estimated Scope**: Small - ~500 lines new code, infrastructure only

### Phase 2: Core Operations Migration (Week 3-4)

**Objective**: Replace bash-based skills with CLI delegation

**Tasks**:
- [ ] Migrate `document-fetcher` skill to use CLI
- [ ] Migrate `cache-list` skill to use CLI
- [ ] Migrate `cache-clear` skill to use CLI
- [ ] Migrate `cache-metrics` skill to use CLI
- [ ] Migrate `cache-health` skill to use CLI
- [ ] Update skill workflow files
- [ ] Comprehensive testing of all operations
- [ ] Performance benchmarking

**Estimated Scope**: Medium - Replace ~1500 lines bash with ~200 lines wrapper

### Phase 3: Sync Operations Migration (Week 5)

**Objective**: Migrate sync operations to CLI

**Tasks**:
- [ ] Migrate `project-syncer` skill to CLI
- [ ] Migrate `org-syncer` skill to CLI
- [ ] Update environment handling
- [ ] Test bidirectional sync
- [ ] Test dry-run mode
- [ ] Verify commit creation

**Estimated Scope**: Medium - Replace ~500 lines bash with CLI delegation

### Phase 4: Configuration Migration (Week 6)

**Objective**: Support YAML config and provide migration tooling

**Tasks**:
- [ ] Create config detection logic (JSON vs YAML)
- [ ] Update init command for YAML format
- [ ] Add deprecation warnings for JSON config
- [ ] Create user-facing migration guide
- [ ] Test migration paths
- [ ] Document configuration changes

**Estimated Scope**: Small - ~300 lines new code

### Phase 5: Agent Simplification (Week 7)

**Objective**: Simplify codex-manager agent

**Tasks**:
- [ ] Remove direct bash operations from agent
- [ ] Update delegation logic to use cli-helper
- [ ] Simplify error handling (SDK provides better errors)
- [ ] Remove redundant validation
- [ ] Update agent documentation
- [ ] Test all operations end-to-end

**Estimated Scope**: Small - Net reduction of ~500 lines

### Phase 6: MCP Migration to SDK (Week 8)

**Objective**: Migrate to SDK MCP server (Option B - confirmed decision)

**Decision**: Use SDK MCP server for long-term consistency with the Fractary ecosystem. The existing TypeScript MCP server will be replaced.

**Tasks**:
- [ ] Remove existing MCP server (`plugins/codex/mcp-server/`)
- [ ] Configure SDK MCP server via `fractary codex init --mcp`
- [ ] Update `.claude/settings.json` MCP registration
- [ ] Test resource listing and reading
- [ ] Verify cache integration (SDK MCP reads from SDK cache)
- [ ] Update MCP documentation
- [ ] Test Claude Desktop/Code integration
- [ ] Document migration for users with existing MCP setup

**Estimated Scope**: Medium - Remove ~500 lines MCP server, configure SDK alternative

### Phase 7: Cleanup and Release (Week 9)

**Objective**: Remove legacy code and release v4.0

**Tasks**:
- [ ] Remove deprecated bash scripts
- [ ] Remove legacy skills (keep wrappers only)
- [ ] Update all documentation
- [ ] Create migration guide for users
- [ ] Update changelog
- [ ] Release v4.0

**Estimated Scope**: Small - Mostly deletions and documentation

## Files to Create/Modify

### New Files
- `plugins/codex/skills/cli-helper/SKILL.md`: CLI wrapper skill definition
- `plugins/codex/skills/cli-helper/scripts/invoke-cli.sh`: Main wrapper script
- `plugins/codex/skills/cli-helper/scripts/validate-cli.sh`: CLI validation
- `plugins/codex/skills/cli-helper/scripts/parse-output.sh`: Output parsing
- `plugins/codex/skills/cli-helper/workflow/invoke-cli.md`: Workflow instructions
- `plugins/codex/docs/MIGRATION-v4.md`: Migration guide for users

### Modified Files
- `plugins/codex/.claude-plugin/plugin.json`: Add CLI dependency info
- `plugins/codex/agents/codex-manager.md`: Simplify delegation logic
- `plugins/codex/skills/document-fetcher/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/cache-list/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/cache-clear/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/cache-metrics/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/cache-health/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/project-syncer/SKILL.md`: Use CLI delegation
- `plugins/codex/skills/org-syncer/SKILL.md`: Use CLI delegation
- `plugins/codex/README.md`: Update with v4.0 changes
- `plugins/codex/QUICK-START.md`: Update setup instructions

### Files to Remove (Phase 7)
- `plugins/codex/skills/document-fetcher/scripts/*.sh`: 12 bash scripts
- `plugins/codex/skills/cache-list/scripts/*.sh`: Cache listing scripts
- `plugins/codex/skills/cache-clear/scripts/*.sh`: Cache clearing scripts
- `plugins/codex/skills/cache-metrics/scripts/*.sh`: Metrics scripts
- `plugins/codex/skills/cache-health/scripts/*.sh`: Health check scripts
- `plugins/codex/skills/handler-sync-github/scripts/*.sh`: Sync scripts
- `plugins/codex/skills/handler-http/`: **Entire skill removed** - CLI's HttpStorage provider replaces it
- `plugins/codex/skills/repo-discoverer/scripts/*.sh`: Discovery scripts
- `plugins/codex/mcp-server/`: **Entire directory removed** - SDK MCP server replaces it

## Testing Strategy

### Unit Tests
- CLI wrapper script execution
- JSON output parsing
- Error handling and fallbacks
- Configuration detection logic

### Integration Tests
- Full fetch cycle via CLI
- Cache operations (list, clear, stats)
- Health check reporting
- Sync operations (project, org)

### E2E Tests
- Complete FABER workflow with codex
- MCP resource access
- User migration path

### Performance Tests
- Cache hit latency (target: < 100ms)
- Cache miss latency (target: < 2s)
- Sync operation timing
- CLI startup overhead measurement

## Dependencies

- `@fractary/cli` v0.3.2 or higher
- `@fractary/codex` v0.1.3 or higher (transitive via CLI)
- Node.js >= 18.0.0 (required by CLI)
- `jq` for JSON parsing in wrapper scripts (existing dependency)

## Risks and Mitigations

- **Risk**: CLI not installed in user environment
  - **Likelihood**: Medium
  - **Impact**: High - Operations will fail
  - **Mitigation**: Add installation check with clear error message and instructions; provide npm install command in error output

- **Risk**: Breaking changes in CLI interface
  - **Likelihood**: Low
  - **Impact**: Medium - May break plugin operations
  - **Mitigation**: Pin CLI version in dependencies; test against new versions before updating

- **Risk**: Performance regression from CLI overhead
  - **Likelihood**: Low
  - **Impact**: Medium - Slower operations
  - **Mitigation**: Benchmark before/after; CLI is compiled TypeScript, likely faster than bash

- **Risk**: Config migration issues for existing users
  - **Likelihood**: Medium
  - **Impact**: Medium - User confusion
  - **Mitigation**: Comprehensive migration tool; backward compatibility period; clear documentation

- **Risk**: MCP integration complexity
  - **Likelihood**: Medium
  - **Impact**: Low - Can keep existing server during transition
  - **Mitigation**: Phased approach; keep existing MCP server until SDK approach proven

## Documentation Updates

- `plugins/codex/README.md`: Complete rewrite for v4.0 architecture
- `plugins/codex/QUICK-START.md`: Update installation to include CLI
- `plugins/codex/docs/MIGRATION-v4.md`: New file for migration guide
- `plugins/codex/docs/MCP-INTEGRATION.md`: Update for SDK approach
- `CLAUDE.md`: Update codex plugin references

## Rollout Plan

1. **Alpha** (Week 9): Internal testing with Fractary team
2. **Beta** (Week 10): Release as v4.0-beta, gather feedback
3. **GA** (Week 11): Full release as v4.0
4. **Deprecation** (Week 12-24): JSON config deprecated, YAML required

## Success Metrics

- **Code Reduction**: At least 60% reduction in custom bash code
- **Test Coverage**: SDK provides comprehensive test coverage
- **Performance**: No regression in cache hit/miss latency
- **User Migration**: 90% of users migrated within 3 months
- **Error Quality**: Measurable improvement in error message clarity

## Implementation Notes

### Key Technical Decisions

1. **CLI vs Direct SDK Import**: Using CLI (not importing SDK directly) because:
   - CLI handles configuration loading
   - CLI provides consistent interface across all tools
   - CLI is the officially supported interface
   - Avoids Node.js runtime dependency in plugin context

2. **JSON Output Mode**: All CLI commands support `--json` flag for programmatic output parsing

3. **Backward Compatibility**: Support both JSON and YAML configs during transition period

4. **MCP Strategy**: Recommend Option B (SDK MCP server) for long-term consistency, but allow Option A (existing server) as interim solution

### CLI Command Reference

```bash
# Fetch
fractary codex fetch <uri> [--bypass-cache] [--ttl <seconds>] [--json]

# Cache operations
fractary codex cache list [--json]
fractary codex cache clear [--all|--expired|--pattern <glob>] [--json]
fractary codex cache stats [--json]

# Health
fractary codex health [--json]

# Init
fractary codex init [--org <slug>] [--mcp] [--force]

# Sync
fractary codex sync project [name] [--env <env>] [--dry-run] [--direction <dir>] [--json]
fractary codex sync org [--env <env>] [--dry-run] [--exclude <pattern>] [--json]

# Migration
fractary codex migrate [--dry-run]

# Validation
fractary codex check [--fix]
```

### Resolved Decisions

| Decision | Resolution | Rationale |
|----------|------------|-----------|
| **Architecture Pattern** | Shared cli-helper skill | Clean separation, avoids duplicating CLI invocation logic |
| **HTTP Handler** | Remove entirely | CLI's HttpStorage provider fully replaces it |
| **MCP Server Strategy** | Option B: SDK MCP server | Long-term consistency with Fractary ecosystem |
| **CLI Installation** | Global + npx fallback | Maximum flexibility for different environments |

### Remaining Open Questions

1. **Node.js Requirement**: Is Node.js 18+ available in all target environments? (Required by CLI)
2. **CI/CD Integration**: How to handle CLI in automated workflows? (npx fallback may help)

---

## Changelog

### 2025-12-14 - Refinement Round 1
**Questions Addressed**:
1. Architecture: Confirmed shared cli-helper skill pattern (delegation)
2. HTTP Handler: Confirmed removal (CLI HttpStorage replaces)
3. MCP Strategy: Confirmed Option B (SDK MCP server)
4. CLI Installation: Added npx fallback support

**Changes Applied**:
- Added delegation pattern documentation to cli-helper skill design
- Updated invoke-cli.sh to support npx fallback
- Updated Phase 6 with confirmed MCP migration plan
- Added handler-http and mcp-server to Files to Remove list
- Added Resolved Decisions table
- Linked spec to issue #360

---

*This specification was generated from conversation context about integrating the @fractary/cli with the codex plugin.*
