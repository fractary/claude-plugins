---
spec_id: WORK-00232-faber-workflow-step-id-validation
work_id: 232
issue_url: https://github.com/fractary/claude-plugins/issues/232
title: FABER Workflow Step ID Validation and Refactoring
type: feature
status: draft
created: 2025-12-05
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: FABER Workflow Step ID Validation and Refactoring

**Issue**: [#232](https://github.com/fractary/claude-plugins/issues/232)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-05

## Summary

Refactor FABER workflow step identification to use a required, unique `id` field instead of `name`. This enables targeted step execution (e.g., running just one step via `faber run --step`), supports running the same skill multiple times within a phase with different identifiers, and ensures proper logging/state tracking. Add workflow validation to enforce ID uniqueness across all steps.

## Problem Statement

Currently, FABER workflow steps use a `name` field that serves as both identifier and display name. This creates several issues:

1. **Non-unique identifiers**: The same skill can be used multiple times in a workflow (e.g., `dataset-inspection` in both Frame and Evaluate phases), but there's no requirement for unique identification
2. **Ambiguous step targeting**: The `faber run --step` command needs to reference a specific step, but `{phase}/{step-name}` format is insufficient when the same skill runs multiple times in the same phase
3. **Inconsistent usage**: Some systems (logging, state management) may use `name` as identifier, while it should serve as human-readable display text

## User Stories

### Step Execution Targeting
**As a** developer using FABER workflows
**I want** to run a specific step by its unique ID
**So that** I can re-run individual steps without ambiguity, even when the same skill appears multiple times

**Acceptance Criteria**:
- [ ] Can target any step by unique ID in `faber run --step <id>` command
- [ ] Error message if ID not found
- [ ] Works even when same skill appears multiple times in workflow

### Workflow Validation
**As a** workflow author
**I want** validation errors when step IDs are duplicated
**So that** I catch configuration mistakes before running the workflow

**Acceptance Criteria**:
- [ ] Validation runs on workflow load
- [ ] Clear error message identifies duplicate IDs
- [ ] Validation fails fast (doesn't continue after finding duplicates)

### Human-Readable Step Names
**As a** developer reviewing workflow logs
**I want** human-friendly step names displayed in output
**So that** I can understand what each step does without decoding IDs

**Acceptance Criteria**:
- [ ] Optional `name` field for display purposes
- [ ] If `name` not provided, falls back to `id` for display
- [ ] Logs show human-friendly name where appropriate

## Functional Requirements

- **FR1**: Add required `id` field to workflow step schema - unique identifier for step
- **FR2**: Add optional `name` field to workflow step schema - human-readable display name
- **FR3**: Validate all step `id` values are distinct across entire workflow (all phases)
- **FR4**: Update `faber run --step` command to use `id` for step targeting
- **FR5**: Update logging to use `id` for structured logging, `name` (or `id` fallback) for display
- **FR6**: Update state management to use `id` for tracking step status
- **FR7**: Maintain backward compatibility with existing workflows that only have `name` field (treat `name` as `id` during migration period)

## Non-Functional Requirements

- **NFR1**: Validation should complete in < 100ms for workflows up to 50 steps (performance)
- **NFR2**: Error messages should include step location (phase, position) for debugging (usability)
- **NFR3**: Schema changes should be documented in workflow configuration guide (documentation)

## Technical Design

### Schema Changes

**Current step schema**:
```json
{
  "name": "generate-spec",
  "skill": "fractary-spec:spec-generator",
  "description": "Generate specification from issue"
}
```

**New step schema**:
```json
{
  "id": "generate-spec",
  "name": "Generate Specification",
  "skill": "fractary-spec:spec-generator",
  "description": "Generate specification from issue"
}
```

**Field definitions**:
| Field | Required | Purpose |
|-------|----------|---------|
| `id` | Yes | Unique identifier for targeting, logging, state tracking |
| `name` | No | Human-readable display name (defaults to `id` if omitted) |
| `skill` | No | Skill to invoke (mutually exclusive with `script`) |
| `script` | No | Script to run (mutually exclusive with `skill`) |
| `description` | No | Documentation for the step |

### Validation Logic

```
For each workflow:
  collected_ids = []
  For each phase in [frame, architect, build, evaluate, release]:
    For each step in phase.steps:
      If step.id in collected_ids:
        ERROR: "Duplicate step ID '{step.id}' found in {phase} phase"
      collected_ids.append(step.id)
  Return VALID if no duplicates
```

### Migration Strategy

**Phase 1 (Backward Compatible)**:
- If step has only `name` field (no `id`), treat `name` as `id`
- Log deprecation warning: "Step uses 'name' as identifier. Please add explicit 'id' field."

**Phase 2 (Strict Mode)**:
- Require `id` field on all steps
- `name` becomes purely optional display field

### Files Affected

The following files need updates to use `id` instead of `name` for step identification:

**Core Workflow Execution**:
- `plugins/faber/skills/faber-manager/SKILL.md` - Main workflow orchestration
- `plugins/faber/skills/faber-manager/workflow/*.md` - Phase workflow files

**State Management**:
- `plugins/faber/skills/state-manager/SKILL.md` - Step status tracking
- State JSON schema using step identifiers

**Logging**:
- `plugins/logs/skills/log-manager/SKILL.md` - Step logging references
- Any log format that includes step identification

**Command Parsing**:
- `plugins/faber/commands/run.md` - `--step` argument handling
- Director/dispatcher logic for step targeting

**Validation**:
- `plugins/faber/skills/workflow-validator/SKILL.md` (if exists, or new)
- Or add to existing config validation

## Implementation Plan

### Phase 1: Schema and Validation
Add ID field to schema and implement uniqueness validation

**Tasks**:
- [ ] Define updated step schema with `id` and optional `name` fields
- [ ] Implement step ID uniqueness validation function
- [ ] Add validation to workflow load/parse logic
- [ ] Write tests for validation (duplicate IDs, valid IDs, empty IDs)
- [ ] Update workflow documentation with new schema

### Phase 2: Update Consumers
Update all systems that reference steps by identifier

**Tasks**:
- [ ] Update faber-manager to track steps by `id`
- [ ] Update `faber run --step` to use `id` for targeting
- [ ] Update state-manager to use `id` in state.json
- [ ] Update log-manager to use `id` in structured logs
- [ ] Update any display/output to use `name` (with `id` fallback)

### Phase 3: Migration Support
Add backward compatibility and migration tooling

**Tasks**:
- [ ] Add fallback logic: treat `name` as `id` if `id` missing
- [ ] Add deprecation warning for steps without explicit `id`
- [ ] Document migration guide for existing workflows
- [ ] Update example workflows to use new schema

## Files to Create/Modify

### New Files
- `plugins/faber/skills/workflow-validator/SKILL.md`: Workflow validation skill (if not exists)
- `plugins/faber/skills/workflow-validator/scripts/validate-step-ids.sh`: ID uniqueness validation script

### Modified Files
- `plugins/faber/skills/faber-manager/SKILL.md`: Use `id` for step identification
- `plugins/faber/skills/faber-manager/workflow/*.md`: Update step references
- `plugins/faber/commands/run.md`: Update `--step` argument to use ID
- `plugins/faber/docs/CONFIGURATION.md`: Document new schema
- `plugins/faber/presets/*.toml`: Update example workflows with explicit IDs
- `plugins/logs/skills/*/SKILL.md`: Update step identification in logs

## Testing Strategy

### Unit Tests
- Validation detects duplicate IDs correctly
- Validation passes for unique IDs
- Fallback logic treats `name` as `id` when `id` missing
- Display logic uses `name` when available, `id` when not

### Integration Tests
- Full workflow execution with new schema
- `faber run --step <id>` targets correct step
- State tracking correctly identifies steps by ID
- Logging correctly identifies steps by ID

### E2E Tests
- Run workflow with duplicate IDs - expect validation error
- Run workflow with unique IDs - expect success
- Target specific step in multi-step workflow - expect only that step runs

### Performance Tests
- Validation performance with 50+ step workflow
- No regression in workflow execution time

## Dependencies

- No new external dependencies
- Internal: faber-manager, state-manager, log-manager skills

## Risks and Mitigations

- **Risk**: Breaking existing workflows that only use `name` field
  - **Likelihood**: High (all existing workflows)
  - **Impact**: High (workflows would fail)
  - **Mitigation**: Implement backward-compatible fallback, treat `name` as `id` during transition

- **Risk**: ID naming collisions when users create workflows
  - **Likelihood**: Medium
  - **Impact**: Low (validation catches it early)
  - **Mitigation**: Clear error messages with suggestions, documentation of naming conventions

- **Risk**: Inconsistent updates across all consumers
  - **Likelihood**: Medium
  - **Impact**: Medium (some features might use wrong identifier)
  - **Mitigation**: Comprehensive audit of all step references before implementation

## Documentation Updates

- `plugins/faber/docs/CONFIGURATION.md`: Update step schema documentation
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Add step ID naming conventions
- `CLAUDE.md`: Update FABER workflow config examples

## Rollout Plan

1. Implement validation with backward-compatible fallback
2. Update all internal workflows to use explicit `id` fields
3. Release with deprecation warnings for `name`-only steps
4. Future release: make `id` strictly required

## Success Metrics

- All existing workflows continue to work (backward compatibility): 100%
- New workflows created with explicit `id` fields: Target 100%
- Step targeting accuracy with `faber run --step`: 100%

## Implementation Notes

**Naming Convention for IDs**:
Recommend kebab-case identifiers that are descriptive but concise:
- `initial-inspection` (not `inspection` - too generic)
- `final-validation` (not `validate` - too generic)
- `fetch-issue-data` (action-oriented)

**Example: Same Skill, Different IDs**:
```json
{
  "phases": {
    "frame": {
      "steps": [
        {"id": "initial-inspection", "name": "Initial Dataset Inspection", "skill": "data-inspector"}
      ]
    },
    "evaluate": {
      "steps": [
        {"id": "final-inspection", "name": "Final Dataset Validation", "skill": "data-inspector"}
      ]
    }
  }
}
```

Both use `data-inspector` skill but have unique IDs for targeting.
