---
spec_id: WORK-00359-integrate-spec-plugin-cli
issue_number: 359
issue_url: https://github.com/fractary/claude-plugins/issues/359
title: Integrate Spec Plugin with FABER CLI Spec Commands
type: feature
status: draft
created: 2025-12-13
author: Claude (with human direction)
validated: false
related_specs:
  - WORK-00356-implement-faber-cli-work-commands
  - SPEC-00021-spec-sdk
  - SPEC-00015-faber-orchestrator
changelog:
  - date: 2025-12-13
    round: 1
    changes:
      - "Initial spec creation based on issue #359"
      - "Mapped CLI spec commands to plugin skills"
      - "Identified 8 CLI commands available"
      - "Defined integration pattern following work plugin migration"
  - date: 2025-12-13
    round: 2
    changes:
      - "Refined: Hard-fail when CLI unavailable (no fallback)"
      - "Refined: Use temp file for context passing to CLI"
      - "Refined: Remove spec-archiver, spec-linker, spec-initializer (unused)"
      - "Refined: Reuse work plugin cli-helper pattern"
---

# Feature Specification: Integrate Spec Plugin with FABER CLI Spec Commands

**Issue**: [#359](https://github.com/fractary/claude-plugins/issues/359)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-13

## Summary

Refactor the `fractary-spec` Claude Code plugin to use the Fractary CLI (`@fractary/cli`) as its backend, replacing the current direct implementation with lightweight wrappers that delegate to the CLI's spec module. This follows the same pattern established in the work plugin CLI migration (#356).

The Fractary CLI exposes spec operations directly via `fractary spec <command>` (shortcut) or `fractary faber spec <command>`, providing functionality for specification creation, validation, updates, and refinement.

## Background

### Current Architecture (Plugin-based)

```
Command (e.g., /fractary-spec:create)
    ↓
Agent (spec-manager)
    ↓
Skill (spec-generator, spec-validator, etc.)
    ↓
Direct Implementation (markdown generation, file I/O, GitHub API)
```

### Target Architecture (CLI-based)

```
Command (e.g., /fractary-spec:create)
    ↓
Agent (spec-manager) - lightweight router
    ↓
Skill (spec-generator) - thin wrapper
    ↓
Fractary CLI (fractary spec create)
    ↓
@fractary/faber SDK (SpecManager)
    ↓
Local filesystem + GitHub API (via SDK)
```

### Benefits of Migration

1. **Single source of truth** - Business logic lives in SDK, not duplicated in plugins
2. **Type safety** - TypeScript SDK provides compile-time guarantees
3. **Consistent error handling** - SDK provides structured errors
4. **Reduced maintenance** - Fix bugs in one place (SDK), not across plugins
5. **Testability** - SDK has unit/integration tests; plugin skills are harder to test
6. **CLI/Plugin parity** - Same functionality available via terminal and Claude Code

## User Stories

### US1: Plugin User Experience Unchanged
**As a** Claude Code user
**I want** the spec plugin commands to work exactly as before
**So that** I don't need to learn new syntax or change my workflows

**Acceptance Criteria**:
- [ ] All existing commands maintain same syntax
- [ ] Output format remains consistent
- [ ] Error messages are similar or improved
- [ ] No new dependencies required in project

### US2: CLI Available for Direct Use
**As a** developer
**I want** to use the Fractary CLI directly for spec operations
**So that** I can script automations outside Claude Code

**Acceptance Criteria**:
- [ ] `fractary spec list` works from terminal
- [ ] `fractary spec create` works from terminal
- [ ] JSON output mode for scripting (`--json`)
- [ ] Same configuration as plugin uses

### US3: Seamless Plugin-to-CLI Handoff
**As a** plugin maintainer
**I want** skills to delegate to CLI with minimal code
**So that** the plugin stays maintainable

**Acceptance Criteria**:
- [ ] Skills invoke CLI via subprocess call
- [ ] CLI output parsed into plugin response format
- [ ] Errors propagated correctly
- [ ] Context-dependent operations handled appropriately

## Functional Requirements

- **FR1**: Core spec operations must delegate to `fractary spec` CLI commands
- **FR2**: CLI must support all current spec operations (create, get, update, validate, refine)
- **FR3**: Plugin skills must parse CLI JSON output into standard plugin response format
- **FR4**: Error codes from CLI must map to plugin error handling patterns
- **FR5**: CLI must be invokable without requiring interactive auth during skill execution
- **FR6**: Skills requiring Claude Code context (refinement questions) must handle CLI limitations appropriately

## Non-Functional Requirements

- **NFR1**: CLI invocation overhead must be < 100ms (excluding network latency) (Performance)
- **NFR2**: Plugin response time must not regress > 10% from current implementation (Performance)
- **NFR3**: CLI must be installable via npm globally or as project dependency (Usability)
- **NFR4**: Configuration must remain backward-compatible with existing plugin configs (Compatibility)

## Technical Design

### Architecture Changes

The spec plugin transforms from a "full-implementation" to a "thin wrapper + context handler" pattern:

**Before**: Plugin contains all business logic directly
**After**: Plugin delegates core operations to CLI, handles context-dependent features

```
┌─────────────────────────────────────────────────────────────┐
│                    Claude Code Plugin                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐         │
│  │   Command   │→ │    Agent    │→ │    Skill    │         │
│  │  (router)   │  │  (router)   │  │  (wrapper)  │         │
│  └─────────────┘  └─────────────┘  └─────────────┘         │
│                                           │                  │
│                               ┌───────────┴───────────┐     │
│                               │                       │     │
│                               ▼                       ▼     │
│                        CLI Operation          Context-Aware │
│                                               Operations    │
└───────────────────────────────│──────────────────────│──────┘
                                ▼                      │
┌─────────────────────────────────────────────────────────────┐
│                     Fractary CLI                             │
│  fractary spec <operation> [args] --json                     │
│                         │                                    │
│                         ▼                                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │              @fractary/faber SDK                     │   │
│  │  import { getSpecManager } from '@fractary/cli';     │   │
│  │  const spec = await getSpecManager();                │   │
│  │  const result = await spec.create({...});            │   │
│  └─────────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────────┘
```

### CLI Command Mapping

| Plugin Skill | CLI Command | Status | Notes |
|--------------|-------------|--------|-------|
| spec-generator | `fractary spec create` | ✅ Available | Core generation |
| spec-validator | `fractary spec validate` | ✅ Available | Validation checks |
| spec-updater | `fractary spec update` | ✅ Available | Update spec content |
| spec-refiner | `fractary spec refine` | ✅ Available | Generate questions |
| (fetch) | `fractary spec get` | ✅ Available | Read spec by ID |
| (list) | `fractary spec list` | ✅ Available | List all specs |
| (delete) | `fractary spec delete` | ✅ Available | Remove spec |
| (templates) | `fractary spec templates` | ✅ Available | List templates |
| ~~spec-archiver~~ | N/A | ❌ Removed | Delete skill (unused) |
| ~~spec-linker~~ | N/A | ❌ Removed | Delete skill (unused) |
| ~~spec-initializer~~ | N/A | ❌ Removed | Delete skill (unused) |

### Skill-Specific Integration Notes

#### spec-generator

**Current**: Full markdown generation, template selection, GitHub integration
**Target**: Delegate core generation to CLI, plugin handles context extraction

**CLI Command**:
```bash
fractary spec create "Title" \
  --template feature \
  --work-id 123 \
  --json
```

**Integration Approach**:
1. Plugin extracts context from conversation (Claude Code-specific)
2. Plugin passes extracted requirements to CLI
3. CLI generates spec file
4. Plugin handles GitHub issue linking (may keep or delegate)

**Challenge**: The current spec-generator extracts rich context from the conversation which the CLI cannot access directly.

**Solution**: Hybrid approach with temp file:
- Plugin extracts context and structures it as markdown
- Plugin writes structured context to temp file (e.g., `/tmp/spec-context-{timestamp}.md`)
- Plugin passes temp file path to CLI via `--context-file` flag
- CLI generates the spec with template, incorporating the context
- Plugin handles post-creation linking
- Temp file is cleaned up after CLI returns

**Why temp file over --body flag**:
- Handles large conversation contexts (no shell argument limits)
- Avoids shell escaping issues with special characters
- Cleaner error handling
- Consistent with work plugin pattern

#### spec-validator

**Current**: Parses spec, checks requirements, updates frontmatter
**Target**: Full delegation to CLI

**CLI Command**:
```bash
fractary spec validate WORK-00123-feature.md --json
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "valid": true,
    "checks": {
      "frontmatter": "pass",
      "requirements_defined": "pass",
      "acceptance_criteria": "pass"
    },
    "warnings": [],
    "errors": []
  }
}
```

#### spec-updater

**Current**: In-place edits for phase status, task checkboxes, notes
**Target**: Delegate structural updates to CLI

**CLI Command**:
```bash
fractary spec update WORK-00123-feature.md \
  --status validated \
  --work-id 123 \
  --json
```

**Challenge**: Current spec-updater has granular operations (check-task, update-phase-status, add-notes).

**Solution**: Map granular operations to CLI where possible, keep complex operations in plugin:
- Simple updates (status, work-id) → CLI
- Granular edits (checkbox toggle) → Keep in plugin (or extend CLI later)

#### spec-refiner

**Current**: Analyzes spec, generates questions, uses AskUserQuestion, applies refinements
**Target**: Partial delegation - CLI for question generation, plugin for user interaction

**CLI Command**:
```bash
fractary spec refine WORK-00123-feature.md --json
```

**Response**:
```json
{
  "status": "success",
  "data": {
    "questions": [
      {
        "id": 1,
        "topic": "API Design",
        "question": "Should the endpoint support pagination?",
        "importance": "high"
      }
    ],
    "suggestions": [
      {
        "id": 1,
        "section": "Requirements",
        "suggestion": "Add rate limiting requirements"
      }
    ]
  }
}
```

**Integration**:
1. CLI generates questions/suggestions
2. Plugin presents to user via AskUserQuestion
3. Plugin collects answers
4. Plugin applies refinements (may call CLI update)

#### ~~spec-archiver, spec-linker, spec-initializer~~ (REMOVED)

**Decision**: Delete these skills entirely.

**Rationale**: These skills have never been used in practice:
- `spec-archiver`: Cloud storage upload - not used in any workflow
- `spec-linker`: GitHub issue/PR commenting - handled by spec-generator directly
- `spec-initializer`: Local config initialization - unnecessary overhead

**Action**: Delete skill directories in Phase 2:
- `plugins/spec/skills/spec-archiver/` → DELETE
- `plugins/spec/skills/spec-linker/` → DELETE
- `plugins/spec/skills/spec-initializer/` → DELETE

This simplifies the plugin and reduces maintenance burden.

### CLI Availability Check (Hard-Fail)

**Behavior**: Skills MUST check CLI availability before any operation and hard-fail if not found.

**No Fallback**: There is no fallback to direct implementation. This ensures:
- Consistent behavior across all invocations
- Single code path to maintain
- Clear user expectations

**Check Implementation**:
```bash
# At start of every skill script
if ! command -v fractary &> /dev/null; then
  echo '{"status":"error","error":{"code":"CLI_NOT_FOUND","message":"Fractary CLI not found. Install with: npm install -g @fractary/cli"}}'
  exit 1
fi
```

**User-Facing Error**:
```
Error: Fractary CLI not found

The spec plugin requires the Fractary CLI for all operations.

Installation:
  npm install -g @fractary/cli

Or add to your project:
  npm install @fractary/cli
```

### Error Handling

CLI error responses follow standard format:
```json
{
  "status": "error",
  "error": {
    "code": "SPEC_NOT_FOUND",
    "message": "Specification WORK-00999.md does not exist",
    "details": { "id": "WORK-00999.md" }
  }
}
```

Skills map CLI errors to plugin error responses:
```json
{
  "status": "failure",
  "message": "Spec not found: WORK-00999.md",
  "errors": ["Specification WORK-00999.md does not exist"],
  "error_analysis": "The specified spec file was not found in the specs directory",
  "suggested_fixes": ["Verify spec ID is correct", "Create the spec first: /fractary-spec:create"]
}
```

### Configuration

The CLI reads configuration from standard locations:
1. Command-line arguments
2. Environment variables
3. Project config: `.fractary/faber/config.json`
4. User config: `~/.config/fractary/config.json`

Spec-specific configuration section:
```json
{
  "spec": {
    "directory": "specs",
    "templates_dir": "plugins/spec/templates",
    "auto_link_github": true,
    "default_template": "feature"
  }
}
```

## Implementation Plan

### Phase 0: Prerequisites (BLOCKING)
**Status**: ⬜ Not Started

**Objective**: Verify CLI spec module completeness

**Tasks**:
- [ ] Confirm `@fractary/cli >= 1.0.0` includes spec module
- [ ] Test all 8 CLI spec commands for functionality
- [ ] Document any missing features or bugs
- [ ] Verify JSON output mode works correctly for all commands

**Estimated Scope**: Small

### Phase 1: CLI Wrapper Implementation
**Status**: ⬜ Not Started

**Objective**: Create shared CLI helper for spec plugin (following work plugin pattern)

**Tasks**:
- [ ] Copy `plugins/work/skills/cli-helper/` structure to `plugins/spec/skills/cli-helper/`
- [ ] Adapt `SKILL.md` for spec operations
- [ ] Adapt `scripts/invoke-cli.sh` to call `fractary spec` commands
- [ ] Add CLI availability check (hard-fail, no fallback)
- [ ] Add JSON response parsing utilities
- [ ] Add error mapping utilities
- [ ] Add temp file handling for context passing

**Reference**: `plugins/work/skills/cli-helper/` (copy and adapt)

**Estimated Scope**: Small

### Phase 2: Core Skill Migration & Cleanup
**Status**: ⬜ Not Started

**Objective**: Migrate skills with full CLI support and remove unused skills

**Skill Migration Tasks**:
- [ ] Update `spec-generator` to use CLI for core generation (hybrid approach with temp file)
- [ ] Update `spec-validator` to use CLI (full delegation)
- [ ] Update `spec-updater` to use CLI for simple updates
- [ ] Update `spec-refiner` to use CLI for question generation

**Skill Deletion Tasks** (unused skills):
- [ ] Delete `plugins/spec/skills/spec-archiver/` directory
- [ ] Delete `plugins/spec/skills/spec-linker/` directory
- [ ] Delete `plugins/spec/skills/spec-initializer/` directory
- [ ] Remove references to deleted skills from `plugin.json`
- [ ] Remove any commands that invoke deleted skills

**Estimated Scope**: Medium

### Phase 3: Testing & Validation
**Status**: ⬜ Not Started

**Objective**: Ensure all commands work correctly with new backend

**Tasks**:
- [ ] Test each plugin command end-to-end
- [ ] Verify error handling for common failure cases
- [ ] Validate response format compatibility
- [ ] Test with FABER workflows (architect phase)
- [ ] Performance testing (response time comparison)

**Estimated Scope**: Medium

### Phase 4: Documentation & Cleanup
**Status**: ⬜ Not Started

**Objective**: Update documentation and finalize

**Tasks**:
- [ ] Update plugin README with CLI dependency note
- [ ] Document CLI installation requirement
- [ ] Update skill SKILL.md files with CLI integration details
- [ ] Update CLAUDE.md with new architecture notes

**Estimated Scope**: Small

## Files to Create/Modify

### New Files
- `plugins/spec/skills/cli-helper/SKILL.md`: Shared CLI invocation helper
- `plugins/spec/skills/cli-helper/scripts/invoke-cli.sh`: CLI wrapper script

### Modified Files
- `plugins/spec/skills/spec-generator/SKILL.md`: Update to use CLI for generation
- `plugins/spec/skills/spec-validator/SKILL.md`: Update to use CLI for validation
- `plugins/spec/skills/spec-updater/SKILL.md`: Update to use CLI for updates
- `plugins/spec/skills/spec-refiner/SKILL.md`: Update to use CLI for question generation
- `plugins/spec/README.md`: Add CLI dependency documentation

### Deleted Files (unused skills)
- `plugins/spec/skills/spec-archiver/` → DELETE entire directory
- `plugins/spec/skills/spec-linker/` → DELETE entire directory
- `plugins/spec/skills/spec-initializer/` → DELETE entire directory

### Unchanged Files
- `plugins/spec/agents/spec-manager.md`: Minimal changes (routing unchanged, remove references to deleted skills)

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
- Create spec via plugin, verify file created
- Validate spec, check results
- Refine spec, verify questions generated
- Full FABER workflow: architect phase uses spec plugin

### Performance Tests
- Measure baseline with current direct implementation
- Measure with CLI implementation
- Ensure < 10% regression threshold met

## Dependencies

- `@fractary/cli >= 1.0.0` - Must be installed globally or in project (REQUIRED)
- `jq` - JSON parsing in shell scripts (optional but recommended)
- Node.js 18+ - Required for CLI

## Risks and Mitigations

- **Risk**: CLI not installed when plugin invoked
  - **Likelihood**: Medium
  - **Impact**: High (commands fail)
  - **Mitigation**: Hard-fail with clear installation instructions. No fallback mechanism - ensures consistent behavior and single code path.
  - **Accepted**: Users must install CLI. This is intentional to avoid dual-maintenance burden.

- **Risk**: Context-dependent features (spec-refiner user interaction) degraded
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Hybrid approach - CLI generates questions, plugin handles user interaction via AskUserQuestion

- **Risk**: CLI output format changes break parsing
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Pin CLI version, use semantic versioning, add output schema validation

- **Risk**: Performance regression from subprocess overhead
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Benchmark early, optimize if needed

- **Risk**: Temp file cleanup fails leaving orphan files
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Use /tmp directory, implement cleanup in finally block, use timestamp-based naming for easy manual cleanup

## Success Metrics

- **Command success rate**: > 99% (same as current)
- **Response time P95**: < 2s (not regressed > 10%)
- **Lines of code reduced**: > 50% in plugin (including removal of 3 unused skills)
- **Skills removed**: 3 (spec-archiver, spec-linker, spec-initializer)
- **FABER workflow compatibility**: 100% (architect phase unchanged)

## Implementation Notes

### CLI Invocation Pattern

```bash
# Skills should use this pattern:
result=$(fractary spec create "Feature Title" \
  --template feature \
  --work-id "$work_id" \
  --json 2>&1)

exit_code=$?

if [ $exit_code -ne 0 ]; then
  # CLI error - extract message
  error_msg=$(echo "$result" | jq -r '.error.message // "Unknown error"')
  echo "Error: $error_msg"
  exit 1
fi

# Parse success response
spec_id=$(echo "$result" | jq -r '.data.id')
spec_path=$(echo "$result" | jq -r '.data.path')
```

### Hybrid Context Extraction (Temp File Pattern)

For spec-generator, the plugin must extract conversation context and pass via temp file:

```bash
## Plugin Pre-processing (before CLI call)

# 1. Extract context from conversation
context="## Requirements
- User authentication required
- Support OAuth2 and local auth

## Acceptance Criteria
- Login within 2 seconds
- Session persists across tabs

## Technical Constraints
- Must use existing user table
- No new dependencies"

# 2. Write to temp file
context_file="/tmp/spec-context-$(date +%s).md"
echo "$context" > "$context_file"

# 3. Invoke CLI with temp file
result=$(fractary spec create "Feature Title" \
  --template feature \
  --work-id "$work_id" \
  --context-file "$context_file" \
  --json 2>&1)

# 4. Cleanup temp file (always, even on error)
rm -f "$context_file"

# 5. Process result...
```

**Why temp file over alternatives**:
- **--body flag**: Limited by shell argument length, escaping nightmares
- **stdin pipe**: Complicates error handling, harder to debug
- **temp file**: Clean, debuggable, handles any content size

### Backward Compatibility

The plugin continues to work with existing project configurations. The only new requirement is the Fractary CLI being installed. Users without CLI get a helpful error:

```
Error: Fractary CLI not found

The spec plugin requires the Fractary CLI for core operations.

Installation:
  npm install -g @fractary/cli

Or add to your project:
  npm install @fractary/cli
```

## References

- [#356](https://github.com/fractary/claude-plugins/issues/356) - Work plugin CLI migration (reference implementation)
- [#358](https://github.com/fractary/claude-plugins/pull/358) - Work plugin CLI migration PR
- [WORK-00356-implement-faber-cli-work-commands.md](/specs/WORK-00356-implement-faber-cli-work-commands.md) - Reference spec
