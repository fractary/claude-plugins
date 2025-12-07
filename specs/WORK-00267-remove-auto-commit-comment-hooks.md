---
spec_id: WORK-00267-remove-auto-commit-comment-hooks
work_id: 267
issue_url: https://github.com/fractary/claude-plugins/issues/267
title: Remove Auto Commit and Auto Comment Stop Hooks
type: feature
status: draft
created: 2025-12-07
author: jmcwilliam
validated: false
source: conversation+issue
refined: 2025-12-07
refinement_round: 1
---

# Feature Specification: Remove Auto Commit and Auto Comment Stop Hooks

**Issue**: [#267](https://github.com/fractary/claude-plugins/issues/267)
**Type**: Feature (Deprecation/Refactoring)
**Status**: Draft
**Created**: 2025-12-07

## Summary

Deprecate and remove the auto-commit (repo plugin) and auto-comment (work plugin) stop hooks that are automatically added to `.claude/settings.json` during plugin initialization. These hooks have proven to be unreliable, slow, and counterproductive as the FABER workflows evolve toward greater autonomy with intelligent commit/comment timing within skills themselves.

## Problem Statement

The current auto-commit and auto-comment stop hooks have several critical issues:

1. **Performance**: Takes 1-2 minutes to run even when nothing changed, consuming context and slowing workflows
2. **Unreliability**: Hooks often fail, leaving uncertainty about whether commits/comments actually happened
3. **Status Cache Coupling**: Git status cache updates are coupled to these hooks, making the status line unreliable
4. **Autonomy Conflict**: As FABER skills (like build) now intelligently decide when to commit/comment (e.g., after each phase), blanket stop hooks are redundant
5. **Loss of Control**: Removes workflow author control over when commits/comments should occur

## Goals

1. Remove auto-commit hook from repo plugin
2. Remove auto-comment hook from work plugin
3. Ensure git status cache updates reliably via dedicated hook
4. Maintain status line reliability showing uncommitted/unstaged changes
5. Support intelligent commit/comment timing within FABER skills

## Non-Goals

- Removing the ability to manually commit/comment (commands remain)
- Changing how FABER skills handle their own commits/comments
- Removing the status line functionality

## Functional Requirements

- **FR1**: Remove auto-commit hook (`Stop` event) from repo plugin's `hooks/hooks.json`
- **FR2**: Remove auto-comment hook (`Stop` event) from work plugin's `hooks/hooks.json`
- **FR3**: Keep existing `UserPromptSubmit` hook in repo plugin (updates status cache on each prompt)
- **FR4**: Add dedicated `Stop` hook for status cache update (redundancy with UserPromptSubmit)
- **FR5**: Remove `auto-commit-on-stop.sh` script (or mark deprecated)
- **FR6**: Remove `auto-comment-on-stop.sh` script (or mark deprecated)
- **FR7**: Keep lock file mechanism in `update-status-cache.sh` (future-proofing for parallel operations)
- **FR8**: Update documentation to reflect new behavior

**Note**: No cleanup script needed - existing projects will manually remove hooks from `.claude/settings.json` as desired.

## Non-Functional Requirements

- **NFR1**: Status cache update should complete in < 5 seconds (performance)
- **NFR2**: Status line should accurately reflect git state within 10 seconds of stop (reliability)
- **NFR3**: Backward compatible - existing projects with hooks should not break (compatibility)

## Technical Design

### Architecture Changes

The key change is removing auto-commit/comment from Stop hooks while maintaining reliable status cache updates:

**Current Flow (to be deprecated)**:
```
UserPromptSubmit → update-status-cache.sh --quiet    (KEEP)
Stop → auto-commit-on-stop.sh → (commits) → updates cache    (REMOVE)
Stop → auto-comment-on-stop.sh → (posts comment)    (REMOVE)
```

**New Flow**:
```
UserPromptSubmit → update-status-cache.sh --quiet    (KEPT - primary trigger)
Stop → update-status-cache.sh    (NEW - redundant backup)
(commits handled by FABER skills as needed)
(comments handled by FABER skills as needed)
```

**Rationale for dual-trigger status cache**:
- `UserPromptSubmit`: Ensures status line is accurate during active work
- `Stop`: Captures final state for next session, handles edge cases where prompts were skipped
- Lock file mechanism retained: Future-proofs for parallel batch workers doing commits

### Files Analysis

#### Repo Plugin Hook Structure

Current `plugins/repo/hooks/hooks.json`:
```json
{
  "hooks": {
    "Stop": [{ "command": "auto-commit-on-stop.sh" }],           // REMOVE
    "UserPromptSubmit": [{ "command": "update-status-cache.sh --quiet" }]  // KEEP
  }
}
```

Target state:
```json
{
  "hooks": {
    "Stop": [{ "command": "update-status-cache.sh" }],           // NEW (no --quiet for visibility)
    "UserPromptSubmit": [{ "command": "update-status-cache.sh --quiet" }]  // KEEP
  }
}
```

#### Work Plugin Hook Structure

Current `plugins/work/hooks/hooks.json`:
```json
{
  "hooks": {
    "Stop": [{ "command": "auto-comment-on-stop.sh" }]    // REMOVE
  }
}
```

Target state:
```json
{
  "hooks": {}    // Empty - no automatic hooks
}
```

### Data Model

No data model changes required. Status cache format remains the same.

### API Design

No API changes. CLI commands remain available for manual use:
- `/repo:commit` - Manual commit
- `/work:comment-create` - Manual comment

### UI/UX Changes

Status line behavior should remain the same but become more reliable due to dedicated cache update hook.

## Implementation Plan

### Phase 1: Update Repo Plugin Hooks
**Status**: Not Started

**Objective**: Remove auto-commit, add Stop hook for status cache

**Tasks**:
- [ ] Edit `plugins/repo/hooks/hooks.json`:
  - Remove `Stop` → `auto-commit-on-stop.sh` entry
  - Add `Stop` → `update-status-cache.sh` entry (without --quiet flag)
  - Keep `UserPromptSubmit` → `update-status-cache.sh --quiet` unchanged
- [ ] Verify `update-status-cache.sh` works correctly on Stop event
- [ ] Test: Stop hook updates cache without committing

**Estimated Scope**: Small

### Phase 2: Update Work Plugin Hooks
**Status**: Not Started

**Objective**: Remove auto-comment hook entirely

**Tasks**:
- [ ] Edit `plugins/work/hooks/hooks.json`:
  - Remove `Stop` → `auto-comment-on-stop.sh` entry
  - Leave hooks object empty (or remove hooks section)
- [ ] Test: Stop event no longer triggers auto-comment

**Estimated Scope**: Small

### Phase 3: Script Cleanup (Optional)
**Status**: Not Started

**Objective**: Mark deprecated scripts or remove them

**Tasks**:
- [ ] Decide: Remove scripts or mark as deprecated with comments
- [ ] If keeping: Add deprecation notice to `plugins/repo/scripts/auto-commit-on-stop.sh`
- [ ] If keeping: Add deprecation notice to `plugins/work/scripts/auto-comment-on-stop.sh`
- [ ] If removing: Delete both scripts
- [ ] Keep lock file mechanism in `update-status-cache.sh` (per FR7)

**Estimated Scope**: Small

### Phase 4: Testing and Documentation
**Status**: Not Started

**Objective**: Verify changes and update docs

**Tasks**:
- [ ] Test fresh plugin installation (no auto-commit/comment hooks)
- [ ] Test status cache updates on both UserPromptSubmit and Stop
- [ ] Verify status line shows accurate git state
- [ ] Verify FABER skills still commit/comment via their own logic
- [ ] Update plugin documentation as needed

**Estimated Scope**: Small

**Note**: No cleanup script or migration guide needed - existing projects manually remove hooks from `.claude/settings.json`.

## Files to Create/Modify

### New Files
- None required

### Modified Files
- `plugins/repo/hooks/hooks.json`: Replace Stop hook (auto-commit → update-status-cache)
- `plugins/work/hooks/hooks.json`: Remove Stop hook entirely

### Scripts to Deprecate/Remove
- `plugins/repo/scripts/auto-commit-on-stop.sh`: Deprecate or remove
- `plugins/work/scripts/auto-comment-on-stop.sh`: Deprecate or remove

### Scripts to Keep (No Changes)
- `plugins/repo/scripts/update-status-cache.sh`: Keep with lock mechanism intact

## Testing Strategy

### Unit Tests
- Verify hook configuration files are valid JSON
- Verify status cache script returns expected format

### Integration Tests
- Test repo plugin init doesn't add auto-commit hook
- Test work plugin init doesn't add auto-comment hook
- Test SessionStop triggers status cache update
- Test status line reflects correct git state after stop

### E2E Tests
- Run full FABER workflow and verify:
  - Build skill commits at appropriate points
  - No duplicate commits from stop hook
  - Status line accurate throughout

### Performance Tests
- Measure SessionStop latency before/after (should decrease significantly)
- Measure status cache update time (target < 5s)

## Dependencies

- Git CLI (for status cache operations)
- jq (for JSON parsing in scripts)
- Existing repo/work plugin infrastructure

## Risks and Mitigations

- **Risk**: Existing projects have hooks in settings.json that will continue to run
  - **Likelihood**: High
  - **Impact**: Low (hooks just become no-ops or manual removal)
  - **Mitigation**: Document manual removal process; hooks with missing scripts fail gracefully

- **Risk**: FABER skills not consistently committing/commenting
  - **Likelihood**: Medium
  - **Impact**: Medium (work could be lost)
  - **Mitigation**: Audit and enhance FABER skills to commit after significant work; recommend periodic manual commits

- **Risk**: Status cache becomes stale if SessionStop hook fails
  - **Likelihood**: Low
  - **Impact**: Low (status line inaccurate but no data loss)
  - **Mitigation**: Add fallback cache update triggers (UserPromptSubmit as backup)

## Documentation Updates

- `plugins/repo/README.md`: Update hook behavior documentation (if exists)
- `plugins/work/README.md`: Update hook behavior documentation (if exists)

**Not needed**:
- Migration guide (manual removal is straightforward)
- Cleanup script (few existing projects)

## Rollout Plan

1. **Merge to main**: Changes take effect for all new installations
2. **Existing projects**: Users manually remove hook entries from `.claude/settings.json` if desired
   - Scripts remain backward compatible (will no-op or fail gracefully if hooks still registered)
3. **No cleanup script**: Manual removal is sufficient given small number of existing projects

## Success Metrics

- SessionStop latency: < 10 seconds (down from 1-2 minutes)
- Status line accuracy: 100% after SessionStop (vs current ~80%)
- FABER workflow completion: No increase in uncommitted work loss
- User satisfaction: Fewer complaints about slow stops

## Implementation Notes

### Key Insight from Issue Comment

The issue comment highlights a critical insight: the status cache update was embedded in the auto-commit hook to avoid git locking conflicts. When removing auto-commit, we must ensure:

1. Status cache update becomes a first-class, standalone hook
2. The hook runs reliably on SessionStop
3. Consider adding backup triggers (UserPromptSubmit) for robustness

### FABER Skill Responsibility

As FABER skills (especially build) now implement entire specs with multiple phases, they have begun implementing intelligent commit/comment timing. This is the right approach - domain logic belongs in the skill, not in blanket hooks.

### Backward Compatibility

Existing `.claude/settings.json` files with the old hooks will continue to work but will reference scripts/functions that either:
- No longer exist (graceful failure)
- Are no-ops (explicit deprecation)

Users can manually clean up their settings files as desired.

---

## Changelog

### Refinement Round 1 (2025-12-07)

**Questions Asked**: 5 (3 answered directly, 2 best-effort decisions)

**Q&A Summary**:
1. **UserPromptSubmit Hook Fate** → Keep both UserPromptSubmit AND Stop hooks for redundancy
2. **Deprecation Approach** → Remove hooks entirely (clean break, not config-based disable)
3. **Cleanup Script Scope** → No cleanup script needed; manual removal for existing projects

**Best-Effort Decisions**:
- Lock file mechanism retained: Future-proofs for parallel batch workers
- Throttle feature in auto-commit script: Will be removed with script

**Changes Applied**:
- Updated FR1-FR8 to reflect cleaner hook structure
- Revised architecture diagram showing dual-trigger status cache
- Simplified implementation plan from 5 phases to 4
- Added concrete before/after JSON for hook files
- Removed cleanup script and migration guide from scope
- Clarified that UserPromptSubmit hook is kept (was ambiguous)
