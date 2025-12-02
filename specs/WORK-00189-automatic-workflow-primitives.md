---
spec_id: WORK-00189-automatic-workflow-primitives
work_id: 189
issue_url: https://github.com/fractary/claude-plugins/issues/189
title: Automatic FABER Workflow Primitives
type: feature
status: draft
created: 2025-12-01
author: jmcwilliam
validated: false
source: conversation+issue
---

# Feature Specification: Automatic FABER Workflow Primitives

**Issue**: [#189](https://github.com/fractary/claude-plugins/issues/189)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-01

## Summary

Refactor FABER workflow to make core primitives (issue fetch, branch creation, spec creation, PR creation) automatic and intelligent rather than requiring explicit step definitions in every workflow configuration. The system should intelligently determine when each primitive is needed based on context (e.g., work_id presence, workflow results) rather than hardcoding these as mandatory steps.

## Problem Statement

Currently, FABER workflow configurations require explicit definition of core steps like:
- `fetch-work` - Fetching issue details
- `create-branch` - Creating semantic branches
- `create-spec` - Generating specifications
- `create-pr` - Creating pull requests

This approach has several problems:

1. **Redundancy**: Defining these steps in every workflow config is repetitive
2. **Inflexibility**: Some workflows are issue-based (need fetch), others are local-only (don't need fetch)
3. **Static vs Dynamic**: Whether to create a branch depends on workflow results (analysis workflows may or may not produce commits)
4. **Maintenance burden**: Changes to these core behaviors require updating every workflow config

## User Stories

### Automatic Issue Fetch
**As a** developer
**I want** FABER to automatically fetch issue details when I provide a work_id
**So that** I don't have to explicitly define a `fetch-work` step in every workflow

**Acceptance Criteria**:
- [ ] When work_id is provided to faber-director, issue is fetched automatically
- [ ] When no work_id is provided, issue fetch is skipped (no error)
- [ ] Fetched issue data is available to all subsequent phases
- [ ] Issue fetch failure is handled gracefully with clear error message

### Intelligent Branch Creation
**As a** developer
**I want** FABER to automatically create a branch when the workflow will produce commits
**So that** I don't have to predict whether a branch is needed in advance

**Acceptance Criteria**:
- [ ] Branch is created automatically at start of Build phase (not Frame)
- [ ] Branch is NOT created for analysis-only workflows that produce no commits
- [ ] Branch naming follows existing semantic conventions
- [ ] Worktree isolation is preserved (branch created in worktree context)
- [ ] Existing branch is reused if workflow is resumed/retried

### Automatic PR Creation
**As a** developer
**I want** FABER to automatically create a PR when work is ready for review
**So that** I don't have to explicitly define a `create-pr` step

**Acceptance Criteria**:
- [ ] PR is created automatically at end of Release phase
- [ ] PR is NOT created if no commits were made
- [ ] PR description includes spec reference and work item link
- [ ] PR creation respects autonomy settings (may pause for approval)

### Conditional Spec Generation
**As a** developer
**I want** FABER to generate specs only when architectural planning is needed
**So that** simple tasks don't require unnecessary specification

**Acceptance Criteria**:
- [ ] Spec generation happens during Architect phase when work type warrants it
- [ ] Simple tasks (typo fixes, config changes) skip spec generation
- [ ] Complex tasks (features, refactors) trigger spec generation
- [ ] Work type classification determines spec necessity

## Functional Requirements

- **FR1**: faber-director MUST automatically fetch issue data when work_id is provided
- **FR2**: faber-director MUST skip issue fetch when no work_id is provided (local workflow)
- **FR3**: faber-manager MUST create branch at Build phase entry (not Frame) when commits are expected
- **FR4**: faber-manager MUST detect when workflow will not produce commits and skip branch creation
- **FR5**: faber-manager MUST create PR at Release phase completion when commits exist
- **FR6**: faber-manager MUST skip PR creation when no commits were made
- **FR7**: Architect phase MUST determine spec necessity based on work type classification
- **FR8**: All automatic primitives MUST respect autonomy settings
- **FR9**: Workflow configs MUST NOT require explicit primitive steps (fetch-work, create-branch, etc.)
- **FR10**: Backward compatibility: explicit primitive steps in configs SHOULD still work (deprecated but functional)

## Non-Functional Requirements

- **NFR1**: Context efficiency - Automatic primitives MUST NOT increase token usage significantly (performance)
- **NFR2**: Workflow configs SHOULD be 50%+ smaller after removing redundant primitive definitions (maintainability)
- **NFR3**: Automatic behavior MUST be deterministic and predictable (reliability)
- **NFR4**: All automatic decisions MUST be logged for debugging (observability)

## Technical Design

### Architecture Changes

The key architectural change is moving primitive execution from **explicit workflow steps** to **implicit phase hooks**.

**Current Architecture**:
```
Workflow Config
  └── steps: [fetch-work, create-branch, ... user steps ..., create-pr]
                ↑ explicit, redundant
```

**Proposed Architecture**:
```
faber-manager
  ├── Frame Phase
  │     └── [automatic] Issue fetch (if work_id)
  ├── Architect Phase
  │     └── [automatic] Spec generation (if work type warrants)
  ├── Build Phase
  │     └── [automatic] Branch creation (if commits expected)
  │     └── ... user steps ...
  ├── Evaluate Phase
  │     └── ... user steps ...
  └── Release Phase
        └── ... user steps ...
        └── [automatic] PR creation (if commits exist)
```

**Key Insight**: Primitives become **phase entry/exit hooks** rather than steps.

### Implementation Approach

#### Phase 1: Issue Fetch Integration (faber-director)

Move issue fetch logic from workflow steps into `faber-director` skill:

```markdown
## In faber-director, Step 0.5 (already exists!):

If work_id provided:
  1. Fetch issue via /work:issue-fetch
  2. Store in workflow context
  3. Detect workflow from labels
  4. Pass issue context to faber-manager

If work_id NOT provided:
  1. Skip issue fetch
  2. Use default workflow
  3. Allow local-only execution
```

**Status**: This is ALREADY IMPLEMENTED in current faber-director! We just need to remove the explicit `fetch-work` step from workflow configs.

#### Phase 2: Intelligent Branch Creation (faber-manager)

Add branch creation logic at Build phase entry:

```markdown
## At Build phase entry in faber-manager:

Check conditions:
  - Does workflow produce commits? (work type != analysis)
  - Is branch already created? (resume scenario)
  - Is worktree already set up?

If branch needed AND not exists:
  1. Generate branch name from work_id and work type
  2. Create branch via /repo:branch-create
  3. Set up worktree if configured
  4. Store branch context for later PR creation

If branch exists (resume):
  1. Verify branch is checked out
  2. Continue with existing context
```

**Work Type Detection**:
```
analysis → no commits expected → skip branch
feature → commits expected → create branch
bug → commits expected → create branch
refactor → commits expected → create branch
docs → commits expected → create branch
```

#### Phase 3: Automatic PR Creation (faber-manager)

Add PR creation logic at Release phase completion:

```markdown
## At Release phase completion in faber-manager:

Check conditions:
  - Were commits made? (git diff from base branch)
  - Is PR already created? (resume scenario)
  - Is autonomy level allowing auto-PR?

If PR needed AND not exists:
  1. Generate PR title from work item/spec
  2. Generate PR body with:
     - Summary from spec
     - Link to issue
     - Testing notes from Evaluate phase
  3. Create PR via /repo:pr-create
  4. Link PR to issue

If PR exists (resume):
  1. Update PR description if needed
  2. Continue
```

#### Phase 4: Conditional Spec Generation (Architect phase)

Current behavior: Architect phase always generates spec.

New behavior: Check work type first:

```markdown
## At Architect phase in faber-manager:

Classify work type from issue/context:
  - SIMPLE: typo, config change, dependency bump
  - MODERATE: bug fix, small enhancement
  - COMPLEX: feature, refactor, architecture change

If SIMPLE:
  - Skip formal spec
  - Use issue description as implementation guide

If MODERATE:
  - Generate lightweight spec (basic template)

If COMPLEX:
  - Generate full spec (feature/infrastructure template)
```

### Data Model

**Workflow Context** (passed through phases):

```json
{
  "work_id": "189",
  "issue": {
    "title": "...",
    "description": "...",
    "labels": [],
    "url": "..."
  },
  "work_type": "feature",
  "branch": {
    "name": "feat/189-automatic-workflow-primitives",
    "created_at": "2025-12-01T...",
    "worktree_path": ".worktrees/feat-189-..."
  },
  "spec": {
    "path": "/specs/WORK-00189-automatic-workflow-primitives.md",
    "generated": true
  },
  "commits": [
    {"sha": "abc123", "message": "..."}
  ],
  "pr": {
    "number": null,
    "url": null
  }
}
```

### API Design

No new APIs needed. Uses existing plugin commands:
- `/work:issue-fetch` - Issue retrieval
- `/repo:branch-create` - Branch creation
- `/repo:pr-create` - PR creation
- `/spec:create` - Spec generation

### UI/UX Changes

None. This is backend/automation behavior. Users will notice:
- Simpler workflow configs (fewer steps to define)
- Same outcomes (branches, PRs, specs created when appropriate)
- Better logging of automatic decisions

## Implementation Plan

### Phase 1: Remove Explicit Primitives from Configs
Remove `fetch-work`, `create-branch`, `create-pr` steps from workflow configs. faber-director already handles issue fetch.

**Tasks**:
- [ ] Audit all workflow configs for explicit primitive steps
- [ ] Remove primitive steps from default workflow
- [ ] Update workflow documentation
- [ ] Test that issue fetch still works (via faber-director)

### Phase 2: Add Branch Creation at Build Phase
Implement automatic branch creation in faber-manager.

**Tasks**:
- [ ] Add work type detection logic
- [ ] Add branch creation check at Build phase entry
- [ ] Implement branch name generation from context
- [ ] Handle resume scenario (branch already exists)
- [ ] Add logging for branch decisions

### Phase 3: Add PR Creation at Release Phase
Implement automatic PR creation in faber-manager.

**Tasks**:
- [ ] Add commit detection logic (diff from base)
- [ ] Add PR creation at Release phase completion
- [ ] Implement PR description generation from spec/context
- [ ] Handle resume scenario (PR already exists)
- [ ] Respect autonomy settings for PR creation

### Phase 4: Conditional Spec Generation
Implement work type classification for spec necessity.

**Tasks**:
- [ ] Implement work type classifier (simple/moderate/complex)
- [ ] Add spec necessity check at Architect phase entry
- [ ] Skip spec for simple work types
- [ ] Use lightweight template for moderate work types
- [ ] Add logging for spec decisions

## Files to Create/Modify

### Modified Files
- `plugins/faber/skills/faber-director/SKILL.md`: Document automatic issue fetch behavior (already there, needs emphasis)
- `plugins/faber/agents/faber-manager.md`: Add automatic branch creation, PR creation logic
- `plugins/faber/skills/frame/SKILL.md`: Remove branch creation responsibility
- `plugins/faber/skills/build/SKILL.md`: Add branch creation responsibility
- `plugins/faber/skills/release/SKILL.md`: Add PR creation responsibility
- `plugins/faber/skills/architect/SKILL.md`: Add work type classification and conditional spec
- `.fractary/plugins/faber/workflows/default.json`: Remove explicit primitive steps

### New Files
- `plugins/faber/skills/core/work-type-classifier.md`: Shared work type classification logic

## Testing Strategy

### Unit Tests
- Work type classification: Given issue title/labels, returns correct type
- Branch necessity: Given work type, returns correct branch decision
- PR necessity: Given commit count, returns correct PR decision

### Integration Tests
- Full workflow with work_id → issue fetched, branch created, PR created
- Full workflow without work_id → no issue fetch, local execution
- Analysis workflow → no branch created, no PR created
- Simple work type → no spec generated

### E2E Tests
- Run `/faber:direct 189` and verify all primitives execute automatically
- Run `/faber:direct "local task"` and verify local-only execution

### Performance Tests
- Measure token usage before/after (should be similar or lower)
- Measure execution time (should be similar)

## Dependencies

- `fractary-work` plugin (issue fetch)
- `fractary-repo` plugin (branch, PR creation)
- `fractary-spec` plugin (spec generation)
- Existing FABER infrastructure

## Risks and Mitigations

- **Risk**: Breaking existing workflow configs that use explicit primitive steps
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Maintain backward compatibility - explicit steps still work, just become no-ops if primitive already executed

- **Risk**: Incorrect work type classification leads to wrong decisions
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Allow override via workflow config; log all decisions; err on side of creating artifacts

- **Risk**: Automatic PR creation when user wanted manual control
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Respect autonomy settings; "guarded" mode pauses before PR

## Documentation Updates

- `plugins/faber/docs/CONFIGURATION.md`: Update to reflect automatic primitives
- `plugins/faber/docs/WORKFLOWS.md`: Remove primitive step examples
- `CLAUDE.md`: Update FABER section with new behavior

## Rollout Plan

1. **Phase 1**: Implement in dev, test with new workflows
2. **Phase 2**: Update default workflow, maintain backward compat
3. **Phase 3**: Document new behavior
4. **Phase 4**: Deprecation warnings for explicit primitive steps
5. **Future**: Remove backward compatibility (major version)

## Success Metrics

- Workflow config size: 50% reduction in step count
- User feedback: No complaints about missing primitives
- Execution success: Same or better success rate for workflows
- Token usage: No increase (ideally decrease)

## Implementation Notes

The key insight from issue #189 is that FABER should be **intelligent about core primitives** rather than requiring explicit configuration. The five phases (Frame, Architect, Build, Evaluate, Release) provide natural hook points:

- **Frame**: Issue context acquisition (already automatic via director)
- **Architect**: Spec generation (conditional on work type)
- **Build Entry**: Branch creation (conditional on commit expectation)
- **Release Exit**: PR creation (conditional on commits existing)

This moves FABER from "explicitly configured" to "intelligently defaulted with override capability."
