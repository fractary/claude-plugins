---
spec_id: WORK-00356-implement-faber-cli-work-commands
issue_number: 356
issue_url: https://github.com/fractary/claude-plugins/issues/356
title: Implement Faber CLI Work Commands
type: feature
status: draft
created: 2025-12-12
author: Claude (with human direction)
validated: false
related_specs:
  - SPEC-00015-faber-orchestrator
  - SPEC-00023-fractary-core-sdk
  - SPEC-00024-fractary-faber-sdk
  - SPEC-00025-fractary-codex-sdk
changelog:
  - date: 2025-12-12
    round: 1
    changes:
      - "Added CLI version requirement (@fractary/cli >= 1.0.0)"
      - "Clarified configuration path: migrate to .fractary/faber/config.json"
      - "Confirmed migration strategy: all-at-once (no feature flags)"
      - "Added init command delegation to CLI"
      - "Added missing skills: issue-classifier, issue-assigner"
      - "Added prerequisite: CLI completeness verification required"
      - "Added CLI command mapping for init"
---

# Feature Specification: Implement Faber CLI Work Commands

**Issue**: [#356](https://github.com/fractary/claude-plugins/issues/356)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-12

## Summary

Refactor the `fractary-work` Claude Code plugin to use the Fractary CLI (`@fractary/cli`) as its backend, replacing the current shell script-based implementation with lightweight wrappers that delegate to the CLI's work module. This aligns with the broader architectural shift described in SPEC-00015 where deterministic code (the CLI/SDK) handles core logic while plugins become thin orchestration layers.

The Fractary CLI exposes work operations directly via `fractary work <command>` (shortcut) or `fractary faber work <command>`, providing full functionality for issue management, comments, labels, milestones, and state transitions.

## Background

### Current Architecture (Plugin-based)

```
Command (e.g., /fractary-work:issue-create)
    ↓
Agent (work-manager)
    ↓
Skill (issue-creator)
    ↓
Shell Scripts (github/create-issue.sh, jira/create-issue.sh)
    ↓
Platform API (gh cli, curl to Jira, etc.)
```

### Target Architecture (CLI-based)

```
Command (e.g., /fractary-work:issue-create)
    ↓
Agent (work-manager) - lightweight router
    ↓
Skill (issue-creator) - thin wrapper
    ↓
Fractary CLI (fractary work issue create)
    ↓
@fractary/faber SDK (WorkManager)
    ↓
@fractary/core SDK (WorkProvider adapters)
    ↓
Platform API (GitHub/Jira/Linear)
```

### Benefits of Migration

1. **Single source of truth** - Business logic lives in SDK, not duplicated in scripts
2. **Type safety** - TypeScript SDK provides compile-time guarantees
3. **Platform abstraction** - Add new platforms (Linear, Asana) without plugin changes
4. **Consistent error handling** - SDK provides structured errors
5. **Reduced maintenance** - Fix bugs in one place (SDK), not per-platform scripts
6. **Testability** - SDK has unit/integration tests; shell scripts are harder to test

## User Stories

### US1: Plugin User Experience Unchanged
**As a** Claude Code user
**I want** the work plugin commands to work exactly as before
**So that** I don't need to learn new syntax or change my workflows

**Acceptance Criteria**:
- [ ] All existing commands maintain same syntax
- [ ] Output format remains consistent
- [ ] Error messages are similar or improved
- [ ] No new dependencies required in project

### US2: CLI Available for Direct Use
**As a** developer
**I want** to use the Fractary CLI directly for work operations
**So that** I can script automations outside Claude Code

**Acceptance Criteria**:
- [ ] `fractary work issue list` works from terminal
- [ ] `fractary work issue create` works from terminal
- [ ] JSON output mode for scripting (`--json`)
- [ ] Same configuration as plugin uses

### US3: Seamless Plugin-to-CLI Handoff
**As a** plugin maintainer
**I want** skills to delegate to CLI with minimal code
**So that** the plugin stays maintainable

**Acceptance Criteria**:
- [ ] Skills invoke CLI via single subprocess call
- [ ] CLI output parsed into plugin response format
- [ ] Errors propagated correctly
- [ ] No shell script maintenance required

## Functional Requirements

- **FR1**: All work plugin commands must delegate to `fractary work` CLI commands
- **FR2**: CLI must support all current work operations (issue CRUD, comments, labels, milestones, state)
- **FR3**: CLI must read configuration from `.fractary/faber/config.json` (with `[work]` section)
- **FR4**: CLI must support `--json` output mode for programmatic consumption
- **FR5**: Plugin skills must parse CLI JSON output into standard plugin response format
- **FR6**: Error codes from CLI must map to plugin error handling patterns
- **FR7**: CLI must be invokable without requiring interactive auth during skill execution

## Non-Functional Requirements

- **NFR1**: CLI invocation overhead must be < 100ms (excluding network latency) (Performance)
- **NFR2**: Plugin response time must not regress > 10% from current implementation (Performance)
- **NFR3**: CLI must be installable via npm globally or as project dependency (Usability)
- **NFR4**: Configuration must remain backward-compatible with existing plugin configs (Compatibility)
- **NFR5**: Secrets must continue to use environment variables, never stored in files (Security)

## Technical Design

### Architecture Changes

The work plugin transforms from a "full-stack" implementation to a "thin wrapper" pattern:

**Before**: Plugin contains all business logic in shell scripts
**After**: Plugin delegates to CLI which uses SDK

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Plugin                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Command   │→ │    Agent    │→ │    Skill    │         │
│  │  (router)   │  │  (router)   │  │  (wrapper)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                           │                  │
└───────────────────────────────────────────│──────────────────┘
                                            ▼
┌─────────────────────────────────────────────────────────────┐
│                     Fractary CLI                             │
│  fractary work <operation> [args] --json                     │
│                         │                                    │
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              @fractary/faber SDK                     │   │
│  │  import { getWorkManager } from '@fractary/cli';     │   │
│  │  const work = await getWorkManager();                │   │
│  │  const issue = await work.createIssue({...});        │   │
│  └─────────────────────────────────────────────────────┘   │
│                         │                                    │
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              @fractary/core SDK                      │   │
│  │  WorkProvider interface + platform adapters          │   │
│  │  (GitHubWorkProvider, JiraWorkProvider, etc.)        │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### CLI Command Mapping

| Plugin Command | CLI Command | Notes |
|----------------|-------------|-------|
| `/fractary-work:issue-create` | `fractary work issue create` | |
| `/fractary-work:issue-fetch` | `fractary work issue get` | |
| `/fractary-work:issue-update` | `fractary work issue update` | |
| `/fractary-work:issue-assign` | `fractary work issue assign` | |
| `/fractary-work:issue-search` | `fractary work issue list` | With filters |
| `/fractary-work:comment-create` | `fractary work comment add` | |
| `/fractary-work:comment-list` | `fractary work comment list` | |
| `/fractary-work:label-add` | `fractary work label add` | |
| `/fractary-work:label-remove` | `fractary work label remove` | |
| `/fractary-work:state-update` | `fractary work state set` | close/reopen |
| `/fractary-work:milestone-list` | `fractary work milestone list` | |
| `/fractary-work:init` | `fractary work init` | Delegates to CLI |
| `/fractary-work:issue-classify` | `fractary work issue classify` | Work type inference |

### Skill Wrapper Pattern

Each skill becomes a thin wrapper that:
1. Receives operation request from agent
2. Maps parameters to CLI arguments
3. Invokes CLI with `--json` flag
4. Parses JSON response
5. Maps to plugin response format

```bash
# Example: issue-creator skill invoking CLI
fractary work issue create \
  --title "Add CSV export" \
  --body "Implement CSV export feature" \
  --labels "type: feature,priority: high" \
  --json

# CLI returns:
{
  "success": true,
  "data": {
    "number": 357,
    "url": "https://github.com/org/repo/issues/357",
    "title": "Add CSV export"
  }
}
```

### Configuration

The CLI reads configuration from multiple sources (in priority order):
1. Command-line arguments
2. Environment variables
3. Project config: `.fractary/faber/config.json`
4. User config: `~/.config/fractary/config.json`

**Configuration Migration** (Decision: Migrate to unified path):
- **Current**: `.fractary/plugins/work/config.json`
- **Target**: `.fractary/faber/config.json` with `[work]` section
- **Migration**: `/fractary-work:init` will create config at new location
- **Backward Compatibility**: CLI checks old path if new path not found (transition period only)

### Error Handling

CLI error responses follow standard format:
```json
{
  "success": false,
  "error": {
    "code": "ISSUE_NOT_FOUND",
    "message": "Issue #999 does not exist",
    "details": { "issue_number": 999 }
  }
}
```

Skills map CLI errors to plugin error responses:
```json
{
  "status": "failure",
  "message": "Issue #999 not found",
  "errors": ["Issue #999 does not exist"],
  "error_analysis": "The specified issue number does not correspond to an existing issue",
  "suggested_fixes": ["Verify issue number", "Create the issue first"]
}
```

## Implementation Plan

### Phase 0: Prerequisites (BLOCKING)
**Status**: ⬜ Not Started

**Objective**: Verify CLI work module exists and is complete before proceeding

**Tasks**:
- [ ] Confirm `@fractary/cli >= 1.0.0` includes work module
- [ ] Verify all required CLI commands exist (see CLI Command Mapping table)
- [ ] Document any missing features - these MUST be implemented in CLI first
- [ ] If gaps found: create issues in `fractary/cli` repo and wait for completion

**Blocking**: This phase MUST complete before Phase 1 begins. Missing CLI commands would block the entire migration.

**Estimated Scope**: Small (verification only, but may discover blocking issues)

### Phase 1: CLI Work Module Verification
**Status**: ⬜ Not Started

**Objective**: Thoroughly test CLI work module functionality

**Tasks**:
- [ ] Test `fractary work issue create` with all parameter combinations
- [ ] Test `fractary work issue get` with various issue IDs
- [ ] Test `fractary work issue list` with filters
- [ ] Test `fractary work comment add/list`
- [ ] Test `fractary work label add/remove`
- [ ] Test `fractary work state set` (close/reopen)
- [ ] Test `fractary work init` creates correct config
- [ ] Verify JSON output mode for all commands
- [ ] Test error responses for invalid inputs

**Estimated Scope**: Small (testing only)

### Phase 2: Skill Wrapper Implementation
**Status**: ⬜ Not Started

**Objective**: Convert ALL skills from shell scripts to CLI invocations (all-at-once migration)

**Migration Strategy**: All-at-once (no feature flags). All skills converted in single PR.

**Tasks**:
- [ ] Create helper function for CLI invocation with JSON parsing
- [ ] Convert `issue-creator` skill to use CLI
- [ ] Convert `issue-fetcher` skill to use CLI
- [ ] Convert `issue-updater` skill to use CLI
- [ ] Convert `issue-classifier` skill to use CLI
- [ ] Convert `issue-assigner` skill to use CLI
- [ ] Convert `comment-creator` skill to use CLI
- [ ] Convert `comment-lister` skill to use CLI
- [ ] Convert `label-manager` skill to use CLI
- [ ] Convert `state-manager` skill to use CLI
- [ ] Convert `milestone-manager` skill to use CLI
- [ ] Convert `issue-searcher` skill to use CLI
- [ ] Update `init` command to delegate to `fractary work init`

**Estimated Scope**: Medium (12 skills + init command)

### Phase 3: Handler Deprecation
**Status**: ⬜ Not Started

**Objective**: Remove platform-specific handlers (CLI handles platform abstraction)

**Tasks**:
- [ ] Mark `handler-work-tracker-github` as deprecated
- [ ] Mark `handler-work-tracker-jira` as deprecated
- [ ] Mark `handler-work-tracker-linear` as deprecated
- [ ] Update skill routing to bypass handlers
- [ ] Remove handler invocation logic from skills

**Estimated Scope**: Small (deprecation, not deletion yet)

### Phase 4: Testing & Validation
**Status**: ⬜ Not Started

**Objective**: Ensure all commands work correctly with new backend

**Tasks**:
- [ ] Test each plugin command end-to-end
- [ ] Verify error handling for common failure cases
- [ ] Validate response format compatibility
- [ ] Performance testing (response time comparison)
- [ ] Test with GitHub, Jira, and Linear configurations

**Estimated Scope**: Medium

### Phase 5: Documentation & Cleanup
**Status**: ⬜ Not Started

**Objective**: Update documentation and remove deprecated code

**Tasks**:
- [ ] Update plugin README with CLI dependency note
- [ ] Document CLI installation requirement
- [ ] Update CLAUDE.md with new architecture
- [ ] Remove deprecated shell scripts (after validation period)
- [ ] Archive handler skills (after validation period)

**Estimated Scope**: Small

## Files to Create/Modify

### New Files
- `plugins/work/skills/cli-helper/SKILL.md`: Shared CLI invocation helper
- `plugins/work/skills/cli-helper/scripts/invoke-cli.sh`: CLI wrapper script

### Modified Files
- `plugins/work/skills/issue-creator/SKILL.md`: Update to use CLI
- `plugins/work/skills/issue-fetcher/SKILL.md`: Update to use CLI
- `plugins/work/skills/issue-updater/SKILL.md`: Update to use CLI
- `plugins/work/skills/issue-classifier/SKILL.md`: Update to use CLI
- `plugins/work/skills/issue-assigner/SKILL.md`: Update to use CLI
- `plugins/work/skills/comment-creator/SKILL.md`: Update to use CLI
- `plugins/work/skills/comment-lister/SKILL.md`: Update to use CLI
- `plugins/work/skills/label-manager/SKILL.md`: Update to use CLI
- `plugins/work/skills/state-manager/SKILL.md`: Update to use CLI
- `plugins/work/skills/milestone-manager/SKILL.md`: Update to use CLI
- `plugins/work/skills/issue-searcher/SKILL.md`: Update to use CLI
- `plugins/work/commands/init.md`: Delegate to `fractary work init`
- `plugins/work/agents/work-manager.md`: Simplify routing (handlers removed)
- `plugins/work/README.md`: Add CLI dependency documentation

### Deprecated Files (to archive later)
- `plugins/work/skills/handler-work-tracker-github/`
- `plugins/work/skills/handler-work-tracker-jira/`
- `plugins/work/skills/handler-work-tracker-linear/`

## Testing Strategy

### Unit Tests
- CLI wrapper script returns correct exit codes
- JSON parsing handles all response formats
- Parameter mapping covers all argument types

### Integration Tests
- Each plugin command produces expected CLI invocation
- CLI responses map correctly to plugin responses
- Error scenarios handled gracefully

### E2E Tests
- Create issue via plugin, verify on GitHub
- Fetch issue, modify, update via plugin
- Full workflow: create → comment → label → close

### Performance Tests
- Measure baseline with current shell script implementation
- Measure with CLI implementation
- Ensure < 10% regression threshold met

## Dependencies

- `@fractary/cli >= 1.0.0` - Must be installed globally or in project (REQUIRED)
- `@fractary/faber` - SDK providing WorkManager (bundled with CLI)
- `@fractary/core` - SDK providing WorkProvider adapters (bundled with CLI)
- Node.js 18+ - Required for CLI
- npm/pnpm - For CLI installation

**Version Requirement**: Plugin skills will check for CLI availability and verify version >= 1.0.0 before proceeding.

## Risks and Mitigations

- **Risk**: CLI not installed when plugin invoked
  - **Likelihood**: Medium
  - **Impact**: High (commands fail)
  - **Mitigation**: Check CLI availability at skill start, provide helpful error message with installation instructions

- **Risk**: CLI output format changes break parsing
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Pin CLI version, use semantic versioning, add output schema validation

- **Risk**: Performance regression from subprocess overhead
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Benchmark early, optimize if needed (consider keeping CLI process warm)

- **Risk**: Configuration format incompatibility
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: CLI reads both plugin-style and native config paths

## Documentation Updates

- `plugins/work/README.md`: Add prerequisites section for CLI
- `CLAUDE.md`: Update architecture diagram showing CLI integration
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Add CLI integration pattern

## Rollout Plan

1. **Alpha**: Implement Phase 1-2, test internally
2. **Beta**: Enable for select users, gather feedback
3. **GA**: Remove feature flag, deprecate shell scripts
4. **Cleanup**: Archive deprecated handlers after 30-day validation

## Success Metrics

- **Command success rate**: > 99% (same as current)
- **Response time P95**: < 2s (not regressed > 10%)
- **Lines of code reduced**: > 50% in skill implementations
- **Platform addition effort**: < 1 day (vs. weeks currently)

## Implementation Notes

### CLI Invocation Pattern

```bash
# Skills should use this pattern:
result=$(fractary work issue create \
  --title "$title" \
  --body "$body" \
  --labels "$labels" \
  --json 2>&1)

exit_code=$?

if [ $exit_code -ne 0 ]; then
  # CLI error - extract message
  error_msg=$(echo "$result" | jq -r '.error.message // "Unknown error"')
  echo "Error: $error_msg"
  exit 1
fi

# Parse success response
issue_number=$(echo "$result" | jq -r '.data.number')
issue_url=$(echo "$result" | jq -r '.data.url')
```

### Environment Variables

The CLI respects existing plugin environment variables:
- `GITHUB_TOKEN` - GitHub API authentication
- `JIRA_API_TOKEN` - Jira Cloud authentication
- `LINEAR_API_KEY` - Linear authentication

### Backward Compatibility

The plugin continues to work with existing project configurations. The only new requirement is the Fractary CLI being installed. Users without CLI get a helpful error:

```
Error: Fractary CLI not found

The work plugin requires the Fractary CLI to be installed.

Installation:
  npm install -g @fractary/cli

Or add to your project:
  npm install @fractary/cli
```
