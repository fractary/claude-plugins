---
spec_id: WORK-00160-finish-faber-2-implementation
issue_number: 160
issue_url: https://github.com/fractary/claude-plugins/issues/160
title: Finish Implementation of Faber 2.0
type: feature
status: draft
created: 2025-11-20
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Finish Implementation of Faber 2.0

**Issue**: [#160](https://github.com/fractary/claude-plugins/issues/160)
**Type**: Feature Enhancement
**Status**: Draft
**Created**: 2025-11-20

## Summary

Complete the implementation of Faber 2.0 workflow framework that was architecturally defined in issue #158 but left with incomplete skill implementations. This work encompasses implementing the missing scripts, state management, error handling, hook execution, and validation infrastructure required for a production-ready FABER workflow system. The implementation follows a hybrid architecture (deterministic scripts + LLM orchestration) across approximately 60 files organized into 7 implementation phases.

## Context from Issue #158

Issue #158 established the Faber 2.0 architecture with:
- Universal workflow-manager design
- JSON-based configuration (replacing TOML v1.x)
- Dual-state tracking (current state + historical logs)
- Phase-level hooks (10 total: pre/post for each of 5 phases)
- 60% context reduction (from ~98K to ~40K tokens)

However, the PR for #158 was specification-heavy with limited actual implementation, leaving many components unimplemented.

## User Stories

### As a plugin developer
**I want** a complete, production-ready Faber 2.0 implementation
**So that** I can reliably orchestrate FABER workflows across all project types

**Acceptance Criteria**:
- [ ] All phase skills have complete script implementations
- [ ] State management handles concurrency safely
- [ ] Error codes are comprehensive with clear recovery guidance
- [ ] Hook execution system supports all 3 hook types (document, script, skill)
- [ ] Configuration validation provides IDE support via JSON Schema
- [ ] Audit tools report completeness scores and identify issues
- [ ] Documentation is complete and accurate

### As a Faber workflow user
**I want** clear error messages and guidance when issues occur
**So that** I can quickly resolve problems without deep system knowledge

**Acceptance Criteria**:
- [ ] Error codes follow FABER-XXX format with categories
- [ ] Error messages include recovery suggestions
- [ ] Troubleshooting guide maps errors to solutions
- [ ] Diagnostics script identifies configuration and integration problems

### As a system integrator
**I want** direct usage of Faber commands without wrapper abstractions
**So that** I can integrate FABER workflows efficiently

**Acceptance Criteria**:
- [ ] PROJECT-INTEGRATION-GUIDE.md clearly documents direct usage
- [ ] No suggestions to create wrapper agents or commands
- [ ] Examples show `/fractary-faber:*` command usage directly

## Functional Requirements

- **FR1**: Rename `plugins/faber/agents/director.md` to `faber-director.md` for consistency
- **FR2**: Rename `plugins/faber/agents/workflow-manager.md` to `faber-manager.md` for consistency
- **FR3**: Update PROJECT-INTEGRATION-GUIDE.md to eliminate wrapper agent suggestions
- **FR4**: Implement configuration JSON Schema for IDE validation and autocompletion
- **FR5**: Implement state file I/O operations (read, write, init, validate, backup)
- **FR6**: Implement concurrency control with file-based locking (flock)
- **FR7**: Implement error code system (FABER-001 to FABER-599) with categorization
- **FR8**: Implement hook execution engine supporting document, script, and skill hook types
- **FR9**: Implement validation and audit tools for configuration completeness
- **FR10**: Implement phase-specific scripts for frame, architect, build, evaluate, release
- **FR11**: Create comprehensive troubleshooting and error code documentation
- **FR12**: Create test suite covering config validation, state I/O, concurrency, hooks, and error handling

## Non-Functional Requirements

- **NFR1**: Context Efficiency - Maintain 60% context reduction through deterministic scripts (Performance)
- **NFR2**: Concurrency Safety - Prevent state corruption from simultaneous workflow execution (Reliability)
- **NFR3**: Error Recovery - Provide actionable guidance for all error conditions (Usability)
- **NFR4**: IDE Integration - JSON Schema enables autocompletion and validation (Developer Experience)
- **NFR5**: Backward Compatibility - No v1.x TOML support (clean break) (Maintainability)

## Technical Design

### Architecture Changes

**Three-Layer Architecture** (maintained from v2.0 design):
```
Layer 1: Commands (Entry Points) → /fractary-faber:init, /fractary-faber:run, etc.
Layer 2: Agents (Orchestration) → faber-director, faber-manager
Layer 3: Skills (Execution) → Phase skills + core utilities
Layer 4: Scripts (Deterministic Ops) → NEW: Complete implementation
```

**Key Architectural Principles**:
1. **Scripts handle**: I/O operations, validation, locking, hook execution, state management
2. **LLM handles**: Workflow orchestration, phase coordination, decision-making, integration calls
3. **Benefits**: Deterministic operations reduce errors, LLM flexibility for complex decisions

### Agent Renaming

**Current → New**:
- `plugins/faber/agents/director.md` → `plugins/faber/agents/faber-director.md`
- `plugins/faber/agents/workflow-manager.md` → `plugins/faber/agents/faber-manager.md`

**Rationale**: Consistency with plugin naming conventions and clarity in agent references

### Configuration Schema

Location: `plugins/faber/config/config.schema.json`

**Features**:
- JSON Schema v7 specification matching `faber.example.json` structure
- Required field validation (schema_version, workflows, integrations)
- Enum constraints for autonomy levels, hook types, phase names
- Pattern validation for plugin names, workflow IDs
- IDE integration via `$schema` reference in config files

### State Management System

**New Scripts** (all in `plugins/faber/skills/core/scripts/`):
- `state-read.sh` - Read state.json safely with jq
- `state-write.sh` - Write state.json atomically (temp file → mv)
- `state-init.sh` - Initialize new state file with defaults
- `state-validate.sh` - Validate against state.schema.json
- `state-backup.sh` - Create timestamped backup before modifications

**State File Location**: `.fractary/plugins/faber/state.json`

**Concurrency Control** (new scripts):
- `lock-acquire.sh` - Acquire file lock with timeout (default: 30s)
- `lock-release.sh` - Release file lock safely
- `lock-check.sh` - Check if workflow is locked

**Lock File**: `.fractary/plugins/faber/state.json.lock`

**Lock Features**:
- Uses `flock` for file-based locking
- Configurable timeout (default: 30 seconds)
- Auto-cleanup stale locks (>5 minutes old)
- Error FABER-501 on concurrent execution detection

### Error Handling Framework

**Error Code Registry**: `plugins/faber/config/error-codes.json`

**Structure**:
```json
{
  "FABER-001": {
    "message": "Configuration file not found",
    "severity": "error",
    "recovery": "Run /faber:init to create default configuration"
  }
}
```

**Error Categories**:
- FABER-001-099: Configuration errors
- FABER-100-199: State management errors
- FABER-200-299: Phase execution errors
- FABER-300-399: Hook execution errors
- FABER-400-499: Integration errors (work/repo/spec plugins)
- FABER-500-599: Concurrency errors

**New Scripts**:
- `error-report.sh` - Format and report errors with codes
- `error-recovery.sh` - Suggest recovery actions based on error code

### Hook Execution System

**New Scripts**:
- `hook-execute.sh` - Execute single hook with timeout
- `hook-validate.sh` - Validate hook configuration
- `hook-batch.sh` - Execute array of hooks (pre/post phase)

**Hook Features**:
- Support 3 hook types: document, script, skill
- Timeout enforcement (default: 5 minutes, configurable per hook)
- Error handling modes: continue, abort, retry
- Output capture and logging
- Environment variable injection (FABER_PHASE, FABER_WORK_ID, etc.)

**Hook Utilities**:
- `hook-list.sh` - List all configured hooks
- `hook-test.sh` - Dry-run hook execution

### Validation & Audit Tools

**New Scripts**:
- `config-validate.sh` - Validate config against schema using jq
- `config-init.sh` - Generate default config with validation
- `audit-config.sh` - Validate configuration completeness
- `audit-hooks.sh` - Validate all hooks are executable
- `audit-integrations.sh` - Verify plugin dependencies
- `state-audit.sh` - Validate state file integrity
- `state-migrate.sh` - Migrate state between schema versions
- `state-cleanup.sh` - Archive old state files
- `diagnostics.sh` - System health check (config, state, integrations, hooks, dependencies)

**Audit Features**:
- Completeness score (0-100%)
- Missing required fields identification
- Invalid values detection
- Unused configurations warning
- Security warnings (e.g., hardcoded secrets)

### Phase Skill Implementations

**Per-Phase Scripts** (for each of frame, architect, build, evaluate, release):
- `validate-inputs.sh` - Validate phase can start
- `prepare-environment.sh` - Setup phase environment
- `record-artifacts.sh` - Document phase outputs
- `validate-completion.sh` - Verify phase completion criteria

**Example for Frame Phase**:
- `validate-work-item.sh` - Verify work item exists
- `setup-workspace.sh` - Create branch, worktree
- `record-classification.sh` - Save work classification

**Workflow Execution Scripts**:
- `workflow-execute.sh` - Main workflow executor (faber-manager)
- `phase-execute.sh` - Single phase executor
- `retry-handler.sh` - Handle phase retries

## Implementation Plan

### Phase 1: Agent Renaming & Integration Guide
**Duration**: Quick fixes, highest priority

**Tasks**:
- [ ] Rename `plugins/faber/agents/director.md` to `faber-director.md`
- [ ] Rename `plugins/faber/agents/workflow-manager.md` to `faber-manager.md`
- [ ] Update all references to these agents in documentation
- [ ] Update PROJECT-INTEGRATION-GUIDE.md to remove wrapper suggestions
- [ ] Add clear examples of direct `/fractary-faber:*` command usage
- [ ] Add warning against creating wrapper agents/commands

### Phase 2: Configuration & Validation Infrastructure
**Duration**: Foundation for all subsequent work

**Tasks**:
- [ ] Create `config/config.schema.json` with full JSON Schema v7 spec
- [ ] Implement `skills/core/scripts/config-validate.sh`
- [ ] Implement `skills/core/scripts/config-init.sh`
- [ ] Create `config/templates/minimal.json`
- [ ] Create `config/templates/standard.json`
- [ ] Create `config/templates/enterprise.json`
- [ ] Implement `skills/core/scripts/template-apply.sh`
- [ ] Test schema validation with valid/invalid configs

### Phase 3: State Management & Concurrency
**Duration**: Critical infrastructure

**Tasks**:
- [ ] Create `config/state.schema.json`
- [ ] Implement `skills/core/scripts/state-read.sh` (jq-based)
- [ ] Implement `skills/core/scripts/state-write.sh` (atomic writes)
- [ ] Implement `skills/core/scripts/state-init.sh`
- [ ] Implement `skills/core/scripts/state-validate.sh`
- [ ] Implement `skills/core/scripts/state-backup.sh`
- [ ] Implement `skills/core/scripts/lock-acquire.sh` (flock)
- [ ] Implement `skills/core/scripts/lock-release.sh`
- [ ] Implement `skills/core/scripts/lock-check.sh`
- [ ] Test concurrent execution prevention

### Phase 4: Error Handling & User Feedback
**Duration**: User-facing quality

**Tasks**:
- [ ] Create `config/error-codes.json` with all FABER-XXX codes
- [ ] Implement `skills/core/scripts/error-report.sh`
- [ ] Implement `skills/core/scripts/error-recovery.sh`
- [ ] Create `docs/ERROR-CODES.md` with complete error catalog
- [ ] Create `docs/TROUBLESHOOTING.md` with error-to-solution mapping
- [ ] Implement `skills/core/scripts/diagnostics.sh`
- [ ] Test error reporting with various scenarios

### Phase 5: Hook Execution System
**Duration**: Workflow extensibility

**Tasks**:
- [ ] Implement `skills/core/scripts/hook-execute.sh` (all 3 types)
- [ ] Implement `skills/core/scripts/hook-validate.sh`
- [ ] Implement `skills/core/scripts/hook-batch.sh`
- [ ] Implement `skills/core/scripts/hook-list.sh`
- [ ] Implement `skills/core/scripts/hook-test.sh`
- [ ] Create `docs/HOOK-EXAMPLES.md` with pattern library
- [ ] Test hook execution with document, script, and skill types
- [ ] Test timeout enforcement and error handling modes

### Phase 6: Validation & Audit Tools
**Duration**: Quality assurance tools

**Tasks**:
- [ ] Implement `skills/core/scripts/audit-config.sh`
- [ ] Implement `skills/core/scripts/audit-hooks.sh`
- [ ] Implement `skills/core/scripts/audit-integrations.sh`
- [ ] Implement `skills/core/scripts/state-audit.sh`
- [ ] Implement `skills/core/scripts/state-migrate.sh`
- [ ] Implement `skills/core/scripts/state-cleanup.sh`
- [ ] Enhance `/faber:audit` command to use new audit scripts
- [ ] Test audit completeness scoring

### Phase 7: Phase Skill Implementation
**Duration**: Core workflow execution

**Tasks**:
- [ ] Implement Frame phase scripts (validate-inputs, prepare-environment, record-artifacts, validate-completion)
- [ ] Implement Frame-specific scripts (validate-work-item, setup-workspace, record-classification)
- [ ] Implement Architect phase scripts (same pattern)
- [ ] Implement Build phase scripts (same pattern)
- [ ] Implement Evaluate phase scripts (same pattern)
- [ ] Implement Release phase scripts (same pattern)
- [ ] Implement `skills/faber-manager/scripts/workflow-execute.sh`
- [ ] Implement `skills/faber-manager/scripts/phase-execute.sh`
- [ ] Implement `skills/faber-manager/scripts/retry-handler.sh`
- [ ] Test end-to-end workflow execution

### Phase 8: Documentation & Integration
**Duration**: Final polish

**Tasks**:
- [ ] Update `docs/ARCHITECTURE.md` with hybrid architecture details
- [ ] Create `docs/SCRIPT-REFERENCE.md` documenting all scripts
- [ ] Update `README.md` with v2.0 features
- [ ] Update `docs/CONFIGURATION.md` with schema references
- [ ] Update `docs/STATE-TRACKING.md` with concurrency details
- [ ] Create test suite in `tests/` directory (5 test files)
- [ ] Run full integration test
- [ ] Update CHANGELOG with v2.0 completion

## Files to Create/Modify

### New Files (Configuration)
- `plugins/faber/config/config.schema.json` - JSON Schema for configuration validation
- `plugins/faber/config/state.schema.json` - JSON Schema for state validation
- `plugins/faber/config/error-codes.json` - Error code registry
- `plugins/faber/config/templates/minimal.json` - Minimal config template
- `plugins/faber/config/templates/standard.json` - Standard config template
- `plugins/faber/config/templates/enterprise.json` - Full-featured config template

### New Files (Core Scripts - 23 files)
- `plugins/faber/skills/core/scripts/config-validate.sh`
- `plugins/faber/skills/core/scripts/config-init.sh`
- `plugins/faber/skills/core/scripts/template-apply.sh`
- `plugins/faber/skills/core/scripts/state-read.sh`
- `plugins/faber/skills/core/scripts/state-write.sh`
- `plugins/faber/skills/core/scripts/state-init.sh`
- `plugins/faber/skills/core/scripts/state-validate.sh`
- `plugins/faber/skills/core/scripts/state-backup.sh`
- `plugins/faber/skills/core/scripts/lock-acquire.sh`
- `plugins/faber/skills/core/scripts/lock-release.sh`
- `plugins/faber/skills/core/scripts/lock-check.sh`
- `plugins/faber/skills/core/scripts/hook-execute.sh`
- `plugins/faber/skills/core/scripts/hook-validate.sh`
- `plugins/faber/skills/core/scripts/hook-batch.sh`
- `plugins/faber/skills/core/scripts/hook-list.sh`
- `plugins/faber/skills/core/scripts/hook-test.sh`
- `plugins/faber/skills/core/scripts/error-report.sh`
- `plugins/faber/skills/core/scripts/error-recovery.sh`
- `plugins/faber/skills/core/scripts/audit-config.sh`
- `plugins/faber/skills/core/scripts/audit-hooks.sh`
- `plugins/faber/skills/core/scripts/audit-integrations.sh`
- `plugins/faber/skills/core/scripts/state-audit.sh`
- `plugins/faber/skills/core/scripts/state-migrate.sh`
- `plugins/faber/skills/core/scripts/state-cleanup.sh`
- `plugins/faber/skills/core/scripts/diagnostics.sh`

### New Files (Phase Scripts - 20 files)
**Frame Phase** (4 scripts):
- `plugins/faber/skills/frame/scripts/validate-inputs.sh`
- `plugins/faber/skills/frame/scripts/prepare-environment.sh`
- `plugins/faber/skills/frame/scripts/record-artifacts.sh`
- `plugins/faber/skills/frame/scripts/validate-completion.sh`

**Architect Phase** (4 scripts):
- `plugins/faber/skills/architect/scripts/validate-inputs.sh`
- `plugins/faber/skills/architect/scripts/prepare-environment.sh`
- `plugins/faber/skills/architect/scripts/record-artifacts.sh`
- `plugins/faber/skills/architect/scripts/validate-completion.sh`

**Build Phase** (4 scripts):
- `plugins/faber/skills/build/scripts/validate-inputs.sh`
- `plugins/faber/skills/build/scripts/prepare-environment.sh`
- `plugins/faber/skills/build/scripts/record-artifacts.sh`
- `plugins/faber/skills/build/scripts/validate-completion.sh`

**Evaluate Phase** (4 scripts):
- `plugins/faber/skills/evaluate/scripts/validate-inputs.sh`
- `plugins/faber/skills/evaluate/scripts/prepare-environment.sh`
- `plugins/faber/skills/evaluate/scripts/record-artifacts.sh`
- `plugins/faber/skills/evaluate/scripts/validate-completion.sh`

**Release Phase** (4 scripts):
- `plugins/faber/skills/release/scripts/validate-inputs.sh`
- `plugins/faber/skills/release/scripts/prepare-environment.sh`
- `plugins/faber/skills/release/scripts/record-artifacts.sh`
- `plugins/faber/skills/release/scripts/validate-completion.sh`

### New Files (Workflow Manager Scripts - 3 files)
- `plugins/faber/skills/faber-manager/scripts/workflow-execute.sh`
- `plugins/faber/skills/faber-manager/scripts/phase-execute.sh`
- `plugins/faber/skills/faber-manager/scripts/retry-handler.sh`

### New Files (Documentation - 4 files)
- `plugins/faber/docs/SCRIPT-REFERENCE.md` - Complete script documentation
- `plugins/faber/docs/ERROR-CODES.md` - Error code catalog
- `plugins/faber/docs/TROUBLESHOOTING.md` - Error-to-solution mapping
- `plugins/faber/docs/HOOK-EXAMPLES.md` - Hook pattern library

### New Files (Tests - 5 files)
- `plugins/faber/tests/test-config-validation.sh`
- `plugins/faber/tests/test-state-io.sh`
- `plugins/faber/tests/test-concurrency.sh`
- `plugins/faber/tests/test-hooks.sh`
- `plugins/faber/tests/test-error-handling.sh`

### Modified Files (Agent Renaming - 2 files)
- `plugins/faber/agents/director.md` → **RENAME TO** `plugins/faber/agents/faber-director.md`
- `plugins/faber/agents/workflow-manager.md` → **RENAME TO** `plugins/faber/agents/faber-manager.md`

### Modified Files (Documentation Updates - 5 files)
- `plugins/faber/README.md` - Update with v2.0 completion status
- `plugins/faber/docs/ARCHITECTURE.md` - Add hybrid architecture details
- `plugins/faber/docs/CONFIGURATION.md` - Add schema references
- `plugins/faber/docs/STATE-TRACKING.md` - Add concurrency details
- `docs/PROJECT-INTEGRATION-GUIDE.md` - Remove wrapper suggestions, add direct usage examples

### Total File Count
- **New**: ~62 files (6 config + 25 core scripts + 20 phase scripts + 3 workflow scripts + 4 docs + 5 tests)
- **Renamed**: 2 files
- **Modified**: 5 files
- **Grand Total**: ~69 file operations

## Testing Strategy

### Unit Tests

**Test Files**:
- `tests/test-config-validation.sh` - Test all config validation scenarios
- `tests/test-state-io.sh` - Test state read/write/init/validate/backup operations
- `tests/test-error-handling.sh` - Test error reporting and recovery suggestion

**Coverage**:
- Valid and invalid configuration inputs
- State file corruption scenarios
- Error code formatting and lookup
- Template variable substitution
- JSON Schema validation

### Integration Tests

**Test Files**:
- `tests/test-hooks.sh` - Test hook execution engine with all 3 hook types
- `tests/test-concurrency.sh` - Test lock acquisition, release, and concurrent execution prevention

**Coverage**:
- Hook timeout enforcement
- Hook error handling modes (continue, abort, retry)
- Environment variable injection in hooks
- File lock acquisition and release
- Stale lock cleanup
- Concurrent workflow execution detection

### E2E Tests

**Scenarios**:
1. Complete workflow execution from frame to release
2. Workflow resume after interruption
3. Phase retry on failure
4. Hook execution at each phase boundary
5. Configuration audit with completeness scoring
6. State migration between schema versions

**Validation**:
- All phases complete successfully
- State file updated correctly at each phase
- Hooks execute in correct order
- Artifacts created in expected locations
- Error codes reported correctly
- Logs captured properly

### Performance Tests

**Metrics**:
- Context usage (target: 40K tokens for orchestration)
- Workflow execution time (baseline vs actual)
- Hook execution overhead
- State file I/O latency
- Lock acquisition/release time

**Target**: Maintain 60% context reduction from v1.x

## Dependencies

**System Dependencies**:
- `jq` (>=1.6) - JSON parsing and manipulation
- `flock` - File-based locking
- `bash` (>=4.0) - Script execution
- `git` - Repository operations

**Plugin Dependencies**:
- `fractary-work` - Work item integration (fetch, update, classify)
- `fractary-repo` - Repository operations (branch, commit, PR)
- `fractary-spec` - Specification management (create, validate, archive)
- `fractary-logs` - Historical workflow logging

**Optional Dependencies**:
- `shellcheck` - Script validation (development)
- `bats` - Bash test framework (testing)

## Risks and Mitigations

- **Risk**: Script complexity leads to maintenance burden
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Follow consistent script patterns, comprehensive documentation in SCRIPT-REFERENCE.md, inline comments for complex logic

- **Risk**: Concurrency edge cases not covered by flock
  - **Likelihood**: Low
  - **Impact**: High (state corruption)
  - **Mitigation**: Thorough testing of concurrent scenarios, atomic write patterns, state validation on every read

- **Risk**: Hook execution timeout too restrictive or permissive
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Make timeout configurable per hook, document recommended values, allow override in config

- **Risk**: Error code system becomes fragmented or inconsistent
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Centralized error-codes.json, clear categorization, code review focus on error handling

- **Risk**: Phase scripts too tightly coupled to specific project types
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Use configuration-driven behavior, make phase scripts reusable, document extension points

- **Risk**: JSON Schema validation adds latency to workflow startup
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Cache validation results, only validate on config changes, make validation optional in production

## Documentation Updates

### Primary Documentation
- `plugins/faber/README.md` - Update with v2.0 completion, feature summary
- `plugins/faber/docs/ARCHITECTURE.md` - Add hybrid architecture section, script layer details
- `plugins/faber/docs/CONFIGURATION.md` - Add JSON Schema references, validation examples
- `plugins/faber/docs/STATE-TRACKING.md` - Add concurrency control details, lock mechanism
- `plugins/faber/docs/HOOKS.md` - Add hook execution details, examples for all 3 types

### New Documentation
- `plugins/faber/docs/SCRIPT-REFERENCE.md` - Complete reference for all scripts with usage examples
- `plugins/faber/docs/ERROR-CODES.md` - Error code catalog with recovery actions
- `plugins/faber/docs/TROUBLESHOOTING.md` - Problem-solution mapping guide
- `plugins/faber/docs/HOOK-EXAMPLES.md` - Pattern library for common hook use cases

### Integration Guide
- `docs/PROJECT-INTEGRATION-GUIDE.md` - **CRITICAL**: Remove wrapper agent suggestions, add direct command usage examples, clarify that `/fractary-faber:*` commands should be used directly

## Rollout Plan

### Phase 1: Quick Wins (Days 1-2)
- Agent renaming (immediate, no dependencies)
- Integration guide updates (immediate, high user impact)

### Phase 2: Foundation (Days 3-5)
- Configuration infrastructure (JSON Schema, validation, templates)
- State management (I/O, concurrency control)

### Phase 3: Quality (Days 6-8)
- Error handling framework (error codes, reporting, troubleshooting)
- Hook execution system (execute, validate, batch)

### Phase 4: Tools (Days 9-11)
- Validation and audit scripts
- Diagnostics and health checks

### Phase 5: Execution (Days 12-16)
- Phase skill implementations (frame, architect, build, evaluate, release)
- Workflow manager scripts (execute, phase control, retry)

### Phase 6: Polish (Days 17-19)
- Documentation completion
- Test suite creation
- Integration testing

### Phase 7: Validation (Day 20)
- Full E2E test
- Performance validation
- Documentation review
- Release preparation

**Total Duration**: ~20 working days (~4 weeks)

## Success Metrics

- **Context Reduction**: Maintain 60% reduction (40K tokens vs 98K in v1.x)
- **Code Coverage**: >80% of scripts covered by tests
- **Error Handling**: All error paths return FABER-XXX codes with recovery guidance
- **Configuration Completeness**: Audit tool reports 100% for default templates
- **Concurrency Safety**: No state corruption in concurrent execution tests
- **Hook Reliability**: 99.9% successful hook execution rate in tests
- **Documentation Coverage**: All scripts documented in SCRIPT-REFERENCE.md
- **Integration Clarity**: Zero confusion about direct command usage after guide update

## Implementation Notes

### Code Review Focus Areas
1. **Script Patterns**: Ensure consistency across all scripts (error handling, output format, parameter validation)
2. **Error Codes**: Verify all error conditions return appropriate FABER-XXX codes
3. **Atomic Operations**: Validate all write operations use atomic patterns
4. **Lock Safety**: Ensure lock acquire/release is properly paired in all paths
5. **Hook Security**: Validate hook execution doesn't allow code injection
6. **Documentation Accuracy**: Cross-reference docs with actual implementation

### Migration from #158 PR
- No code changes needed in agents (already updated in #158)
- Focus is entirely on script implementation and tooling
- Configuration format is stable (JSON v2.0)
- State schema is defined but implementation is new

### No v1.x Compatibility
- Clean break from TOML-based v1.x
- No migration path provided (manual process only)
- Allows simpler codebase without legacy support
- Document migration as one-time manual effort

### Performance Considerations
- Keep scripts focused and fast (target: <100ms per script)
- Minimize external command invocations
- Use jq efficiently (single pass when possible)
- Cache expensive operations (config validation, plugin checks)
- Profile end-to-end workflow to identify bottlenecks

### Security Considerations
- Validate all hook paths before execution
- Sanitize environment variables passed to hooks
- Use flock timeout to prevent indefinite blocking
- Validate JSON content before parsing with jq
- Document security best practices in HOOK-EXAMPLES.md
