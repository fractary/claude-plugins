---
spec_id: spec-92-add-git-worktree-support
issue_number: 92
issue_url: https://github.com/fractary/claude-plugins/issues/92
title: add git worktree support
type: feature
status: draft
created: 2025-11-12
author: Claude Code
validated: false
---

# Feature Specification: add git worktree support

**Issue**: [#92](https://github.com/fractary/claude-plugins/issues/92)
**Type**: Feature
**Status**: Draft
**Created**: 2025-11-12

## Summary

Add seamless git worktree support to the Fractary plugins ecosystem, enabling users to work on multiple branches simultaneously in parallel Claude Code instances. This enhancement will integrate worktree creation, management, and cleanup into either the `fractary-work` or `fractary-repo` plugin, making parallel development workflows effortless and transparent.

## User Stories

### Parallel Development Workflow
**As a** developer using Claude Code
**I want** to create and manage git worktrees through plugin commands
**So that** I can work on multiple branches simultaneously without manual worktree management

**Acceptance Criteria**:
- [ ] Can create a branch with associated worktree using a single command
- [ ] Claude Code instance automatically starts in the new worktree directory
- [ ] Working directory context is properly maintained in the worktree
- [ ] Multiple terminal windows can run separate Claude instances in different worktrees
- [ ] Worktree cleanup happens automatically when PR is merged or closed

### Seamless Branch Creation
**As a** developer starting new work
**I want** worktree creation integrated into existing branch/issue commands
**So that** I don't need to think about worktree management separately

**Acceptance Criteria**:
- [ ] Existing commands accept a `--worktree` flag or similar option
- [ ] Worktree naming follows a predictable convention
- [ ] Base repository state is not affected by worktree operations
- [ ] Branch tracking is maintained between worktree and main repository

### Automatic Cleanup
**As a** developer finishing work
**I want** worktrees to be cleaned up when branches are merged/deleted
**So that** I don't accumulate stale worktree directories

**Acceptance Criteria**:
- [ ] PR merge operations detect and clean up associated worktrees
- [ ] Branch deletion operations clean up associated worktrees
- [ ] User is notified when cleanup occurs
- [ ] Cleanup is safe (warns if uncommitted changes exist)

## Functional Requirements

- **FR1**: Add worktree support flag to branch creation commands (`/repo:branch-create`, `/work:issue-create`)
- **FR2**: Implement worktree creation with automatic directory switching
- **FR3**: Integrate worktree cleanup into PR merge/close operations
- **FR4**: Provide worktree listing and status commands
- **FR5**: Handle edge cases (existing worktrees, uncommitted changes, locked worktrees)
- **FR6**: Support worktree-specific Claude Code instance launching
- **FR7**: Maintain proper git repository state across worktrees

## Non-Functional Requirements

- **NFR1**: Operations must be idempotent (safe to retry) (Reliability)
- **NFR2**: Worktree paths must be deterministic and discoverable (Maintainability)
- **NFR3**: Performance overhead should be minimal (<2s for worktree creation) (Performance)
- **NFR4**: Clear error messages for common failure scenarios (Usability)
- **NFR5**: Compatible with existing plugin architecture (3-layer design) (Compatibility)

## Technical Design

### Architecture Changes

The feature will be implemented in the **`fractary-repo` plugin** as it deals with git repository structure and operations. This follows the separation of concerns where:
- `fractary-work` handles issue tracking integration
- `fractary-repo` handles git operations (branches, commits, worktrees)

**New components**:
1. **`worktree-manager` skill**: Core worktree operations (create, list, remove)
2. **Enhanced `branch-manager` skill**: Integration with worktree creation
3. **Enhanced `pr-manager` skill**: Worktree cleanup on merge/close
4. **Worktree scripts**: Platform-agnostic git worktree operations

**Integration points**:
- `/repo:branch-create` accepts `--worktree` flag
- `/repo:pr-merge` and related commands detect and clean worktrees
- New `/repo:worktree` command family for direct worktree management

### Data Model

**Worktree Metadata** (stored in `.fractary/plugins/repo/worktrees.json`):
```json
{
  "worktrees": [
    {
      "path": "../claude-plugins-wt-feat-92",
      "branch": "feat/92-add-git-worktree-support",
      "work_id": "92",
      "created": "2025-11-12T10:30:00Z",
      "status": "active"
    }
  ]
}
```

**Naming Convention**:
- Pattern: `{repo-name}-wt-{branch-slug}`
- Example: `claude-plugins-wt-feat-92-add-git-worktree-support`
- Location: Sibling directory to main repository

### API Design

**New Commands**:
- `/repo:branch-create <args> --worktree`: Create branch with worktree
- `/repo:worktree-list`: List active worktrees
- `/repo:worktree-remove <branch>`: Remove specific worktree
- `/repo:worktree-cleanup`: Clean up merged/stale worktrees

**Enhanced Commands**:
- `/repo:pr-merge <number> [--cleanup-worktree]`: Add worktree cleanup option
- `/repo:branch-delete <name> [--cleanup-worktree]`: Add worktree cleanup option

**Skill Operations**:
- `create-worktree`: Create worktree for branch
- `list-worktrees`: List all worktrees
- `remove-worktree`: Remove specific worktree
- `cleanup-worktrees`: Batch cleanup of stale worktrees

### UI/UX Changes

**Command Output Enhancement**:
```
✅ Branch and worktree created successfully!

Branch: feat/92-add-git-worktree-support
Worktree: ../claude-plugins-wt-feat-92-add-git-worktree-support
Status: Active

Next steps:
1. cd ../claude-plugins-wt-feat-92-add-git-worktree-support
2. claude (to start Claude Code in worktree)

Or use: /repo:worktree-switch feat/92
```

**Error Messages**:
- "Worktree already exists at {path}. Use /repo:worktree-remove first."
- "Cannot remove worktree: uncommitted changes detected. Commit or stash first."
- "Worktree cleanup: Removed 3 worktrees for merged branches"

## Implementation Plan

### Phase 1: Core Worktree Operations
Implement basic worktree management skills and scripts

**Tasks**:
- [ ] Create `worktree-manager` skill structure
- [ ] Implement `scripts/worktree/create.sh` script
- [ ] Implement `scripts/worktree/list.sh` script
- [ ] Implement `scripts/worktree/remove.sh` script
- [ ] Add worktree metadata tracking (`.fractary/plugins/repo/worktrees.json`)
- [ ] Test basic worktree operations

### Phase 2: Command Integration
Integrate worktree support into existing commands

**Tasks**:
- [ ] Add `--worktree` flag to `/repo:branch-create` command
- [ ] Update `branch-manager` skill to invoke `worktree-manager`
- [ ] Implement `/repo:worktree-list` command
- [ ] Implement `/repo:worktree-remove` command
- [ ] Update command documentation with worktree examples

### Phase 3: Cleanup Integration
Add automatic cleanup to PR and branch operations

**Tasks**:
- [ ] Enhance `pr-manager` skill with worktree detection
- [ ] Add worktree cleanup to PR merge operations
- [ ] Add worktree cleanup to branch deletion operations
- [ ] Implement safety checks (uncommitted changes, active sessions)
- [ ] Add `/repo:worktree-cleanup` command for manual cleanup

### Phase 4: Claude Code Integration
Enable seamless Claude Code instance launching in worktrees

**Tasks**:
- [ ] Research Claude Code directory context handling
- [ ] Implement directory switching helpers
- [ ] Add `/repo:worktree-switch` command (cd + optional claude launch)
- [ ] Document multi-instance workflow patterns
- [ ] Test parallel Claude Code instances in separate worktrees

### Phase 5: Documentation and Testing
Complete documentation and comprehensive testing

**Tasks**:
- [ ] Write user guide for worktree workflows
- [ ] Add worktree examples to command documentation
- [ ] Create integration tests for worktree operations
- [ ] Test edge cases (locked worktrees, network failures, etc.)
- [ ] Update CLAUDE.md with worktree patterns

## Files to Create/Modify

### New Files
- `plugins/repo/skills/worktree-manager/SKILL.md`: Worktree management skill
- `plugins/repo/skills/worktree-manager/scripts/create.sh`: Create worktree script
- `plugins/repo/skills/worktree-manager/scripts/list.sh`: List worktrees script
- `plugins/repo/skills/worktree-manager/scripts/remove.sh`: Remove worktree script
- `plugins/repo/skills/worktree-manager/scripts/cleanup.sh`: Cleanup stale worktrees script
- `plugins/repo/commands/worktree-list.md`: List worktrees command
- `plugins/repo/commands/worktree-remove.md`: Remove worktree command
- `plugins/repo/commands/worktree-cleanup.md`: Cleanup worktrees command
- `plugins/repo/commands/worktree-switch.md`: Switch to worktree command (if implemented)
- `docs/guides/worktree-workflows.md`: User guide for git worktree workflows

### Modified Files
- `plugins/repo/commands/branch-create.md`: Add `--worktree` flag documentation
- `plugins/repo/commands/pr-merge.md`: Add `--cleanup-worktree` flag documentation
- `plugins/repo/commands/branch-delete.md`: Add `--cleanup-worktree` flag documentation
- `plugins/repo/skills/branch-manager/SKILL.md`: Add worktree integration logic
- `plugins/repo/skills/pr-manager/SKILL.md`: Add worktree cleanup integration
- `plugins/repo/agents/repo-manager.md`: Add worktree operation routing
- `CLAUDE.md`: Add worktree workflow examples and patterns
- `README.md`: Mention worktree support in features list

## Testing Strategy

### Unit Tests
- Test worktree creation with various branch names and conventions
- Test worktree listing and filtering
- Test worktree removal with and without uncommitted changes
- Test metadata tracking (worktrees.json read/write)
- Test path generation and naming conventions

### Integration Tests
- Test full workflow: create branch with worktree → make changes → merge PR → cleanup
- Test parallel worktree creation (multiple branches)
- Test worktree operations from different working directories
- Test interaction between main repo and worktree operations
- Test cleanup of merged branches with associated worktrees

### E2E Tests
- Test multi-terminal workflow (parallel Claude instances)
- Test worktree creation from `/work:issue-create` → `/repo:branch-create --worktree`
- Test PR merge workflow with automatic cleanup
- Test error recovery (failed worktree creation, cleanup interruption)
- Test worktree operations across plugin updates

### Performance Tests
- Benchmark worktree creation time (target: <2s)
- Benchmark cleanup operations with many stale worktrees (target: <5s for 10 worktrees)
- Test performance impact on git operations in worktrees
- Measure overhead of worktree metadata tracking

## Dependencies

- Git version ≥2.5 (git worktree support introduced)
- Bash shell environment for scripts
- Sufficient disk space for multiple worktrees
- Claude Code multi-instance support (verify no conflicts)
- `.fractary/plugins/repo/config.json` configuration
- GitHub/GitLab/Bitbucket CLI tools (for remote operations)

## Risks and Mitigations

- **Risk**: Users accidentally delete worktree with uncommitted work
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Add safety checks in removal scripts, require `--force` flag for dirty worktrees, provide clear warnings

- **Risk**: Worktree paths conflict with existing directories
  - **Likelihood**: Low
  - **Impact**: Medium
  - **Mitigation**: Check for existing directories before creation, use unique naming convention, allow custom path override

- **Risk**: Claude Code instances conflict when running in parallel worktrees
  - **Likelihood**: Medium
  - **Impact**: High
  - **Mitigation**: Research Claude Code multi-instance behavior, document known limitations, test thoroughly

- **Risk**: Stale worktrees accumulate over time
  - **Likelihood**: High
  - **Impact**: Low
  - **Mitigation**: Provide cleanup commands, add automatic stale detection, document cleanup best practices

- **Risk**: Git worktree operations fail on Windows/WSL environments
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Test on Windows/WSL, use platform-agnostic paths, provide fallback error messages

## Documentation Updates

- `docs/commands/repo-branch-create.md`: Add worktree flag documentation and examples
- `docs/commands/repo-pr-merge.md`: Document automatic worktree cleanup behavior
- `docs/guides/parallel-workflows.md`: New guide for multi-worktree development patterns
- `CLAUDE.md`: Add worktree best practices and common patterns
- `README.md`: Feature list and quick start example with worktrees
- `plugins/repo/README.md`: Worktree management capabilities overview

## Rollout Plan

1. **Phase 1 (Internal Testing)**: Deploy to development environment, test core operations
2. **Phase 2 (Alpha)**: Enable for maintainers, gather feedback on UX and edge cases
3. **Phase 3 (Beta)**: Document workflows, enable for early adopters, collect usage patterns
4. **Phase 4 (GA)**: Release publicly with comprehensive documentation and examples
5. **Post-Release**: Monitor adoption, collect feedback, iterate on UX improvements

**Feature Flags**:
```toml
[repo.features]
worktree_support = true  # Enable/disable worktree features
worktree_auto_cleanup = true  # Enable automatic cleanup on merge
```

## Success Metrics

- **Adoption Rate**: 30% of users create at least one worktree within first month
- **Parallel Sessions**: Average of 2+ concurrent Claude Code instances per active user
- **Cleanup Success**: 95% of merged branches have worktrees automatically cleaned up
- **Error Rate**: <5% of worktree operations fail (excluding user errors)
- **User Satisfaction**: Positive feedback from 80%+ of users trying worktree features
- **Performance**: Worktree creation completes in <2s for 95% of operations

## Implementation Notes

**Design Decision: Why fractary-repo?**
While the issue mentions both `fractary-work` and `fractary-repo` as candidates, `fractary-repo` is the appropriate home because:
- Worktrees are a git repository structure feature
- All git operations (branches, commits, PRs) are in repo plugin
- Work plugin focuses on issue tracking system integration
- Separation of concerns: work = tracking, repo = source control

**Integration with fractary-work**:
The `/work:issue-create` command can pass through to `/repo:branch-create --worktree` when the user opts to create a branch, maintaining the existing integration pattern while adding worktree support.

**Naming Convention Rationale**:
- Sibling directories keep worktrees close to main repo
- Prefix `{repo-name}-wt-` makes relationship clear
- Branch slug ensures uniqueness and readability
- Example: `claude-plugins-wt-feat-92` for `feat/92-add-git-worktree-support`

**Claude Code Multi-Instance Considerations**:
- Research needed on Claude Code's handling of parallel instances
- May need session isolation or instance ID tracking
- Document any known limitations or conflicts
- Consider adding worktree-aware status indicators

**Platform Support**:
- Git worktrees are cross-platform (Linux, macOS, Windows)
- Scripts should use platform-agnostic path handling
- Test on WSL (Windows Subsystem for Linux) specifically
- CI/CD should test all supported platforms
