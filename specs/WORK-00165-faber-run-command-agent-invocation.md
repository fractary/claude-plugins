---
spec_id: WORK-00165-faber-run-command-agent-invocation
issue_number: 165
issue_url: https://github.com/fractary/claude-plugins/issues/165
title: Fix /faber:run command to properly invoke faber-manager agent
type: feature
status: draft
created: 2025-11-22
author: Claude Code (via spec-generator)
validated: false
---

# Feature Specification: Fix /faber:run command to properly invoke faber-manager agent

**Issue**: [#165](https://github.com/fractary/claude-plugins/issues/165)
**Type**: Feature Enhancement
**Status**: Draft
**Created**: 2025-11-22

## Summary

The `/faber:run` command currently fails to properly engage the FABER workflow system. When executed, it does not reference or use the configured workflow, defeating the entire purpose of having a workflow-based system. This specification defines the changes needed to ensure the command correctly invokes the faber-manager agent with proper workflow configuration.

**Key Problem**: In a real-world scenario (etl.corthion.ai project), running `/faber:run 39` resulted in Claude repeatedly failing to invoke the configured `corthion-audit` skill, getting stuck in a loop trying different ad-hoc approaches instead of following the defined workflow.

**Proposed Solution**: Rename the command to `/faber:manage` (for consistency) and ensure it always:
1. Identifies the issue and workflow to use
2. Engages the Faber Manager agent with workflow information
3. Lets the agent orchestrate execution
4. Supports multi-item processing via director/agent pattern
5. **Always references the workflow** (never skips this critical step)

## User Stories

### Command Correctly Invokes Workflow
**As a** developer using FABER
**I want** the `/faber:run` (or `/faber:manage`) command to properly engage the workflow system
**So that** Claude follows my configured workflow instead of improvising ad-hoc approaches

**Acceptance Criteria**:
- [ ] Command loads workflow configuration from `.fractary/plugins/faber/config.json`
- [ ] Command invokes faber-manager agent (not faber-director)
- [ ] Workflow configuration is passed to the agent
- [ ] Agent executes the workflow phases as defined
- [ ] No ad-hoc skill invocations bypass the workflow

### Consistent Naming Convention
**As a** developer familiar with other Fractary plugins
**I want** the command to follow the `{plugin}:{manager}` naming pattern
**So that** the command structure is consistent across the plugin ecosystem

**Acceptance Criteria**:
- [ ] Command is renamed from `/faber:run` to `/faber:manage`
- [ ] Old `/faber:run` is deprecated with clear migration message
- [ ] Documentation updated to reflect new command name
- [ ] Both commands work during transition period (with deprecation warning)

### Worktree Isolation for All Workflows
**As a** developer running FABER workflows
**I want** every workflow to use its own isolated worktree
**So that** workflows never interfere with each other (even if I accidentally start multiple)

**Acceptance Criteria**:
- [ ] ALL workflows use worktrees (single and multi-item)
- [ ] Worktrees created as subfolders: `.worktrees/feat-123-description` (within Claude's scope)
- [ ] Prevents scenario: start #123, pause, start #124 → no conflict
- [ ] State files isolated: each worktree has its own `.fractary/plugins/faber/state.json`
- [ ] Branch-manager detects existing worktree for issue and reuses it
- [ ] No duplicate worktrees created for same issue
- [ ] Worktrees cleaned up automatically on PR merge (via `--worktree-cleanup` flag)
- [ ] Manual cleanup available: `/repo:worktree-cleanup --merged`

### Multi-Item Processing Support
**As a** developer managing multiple work items
**I want** to process multiple issues in parallel via the command
**So that** I can efficiently manage batch workflows

**Acceptance Criteria**:
- [ ] Command accepts single work ID: `/faber:manage 123`
- [ ] Command accepts multiple work IDs (comma-separated): `/faber:manage 123,124,125`
- [ ] Command ALWAYS invokes faber-director skill (not conditional)
- [ ] faber-director skill determines single vs multi-item processing
- [ ] faber-director invokes 1 faber-manager agent (single) or N agents (multi)
- [ ] All instances use worktrees (single and multi)
- [ ] Each item maintains separate state tracking in its worktree

## Functional Requirements

- **FR1**: Command MUST load workflow configuration from `.fractary/plugins/faber/config.json`
- **FR2**: Command MUST ALWAYS invoke faber-director skill (no conditional logic)
- **FR3**: Command MUST pass workflow configuration + work_id to faber-director skill
- **FR4**: faber-director skill MUST determine single vs multi-item processing
- **FR5**: faber-director skill MUST invoke faber-manager agent(s) with appropriate parameters
- **FR6**: Command MUST support `--workflow <id>` flag to override default workflow
- **FR7**: Command MUST support `--autonomy <level>` flag (dry-run, assist, guarded, autonomous)
- **FR8**: Command MUST validate workflow configuration exists before skill invocation
- **FR9**: Command MUST provide clear error messages if workflow not found
- **FR10**: Multi-item processing MUST use comma-separated syntax (no spaces): `123,124,125`
- **FR11**: ALL workflows (single and multi) MUST use worktrees to prevent interference
- **FR12**: Worktrees MUST be created as subfolders (`.worktrees/{branch-slug}`) to remain within Claude's working directory scope
- **FR13**: faber-director MUST be a skill (not an agent) to retain context and enable skill→agent invocation
- **FR14**: branch-manager skill MUST detect existing worktree for issue and reuse (not create duplicate)
- **FR15**: branch-manager skill MUST track worktree→issue mapping for reuse detection
- **FR16**: pr-merge command MUST support `--worktree-cleanup` flag to automatically remove worktrees after merge
- **FR17**: Worktree registry MUST be updated when worktrees are created or removed

## Non-Functional Requirements

- **NFR1**: Command invocation overhead < 500ms (configuration loading + validation) (Performance)
- **NFR2**: Error messages MUST be actionable (tell user how to fix) (Usability)
- **NFR3**: Command MUST follow plugin standards for argument parsing (space-separated, quoted multi-word values) (Consistency)
- **NFR4**: Deprecation warnings MUST be clear and include migration path (Usability)

## Technical Design

### Architecture Changes

**Current (Broken) Flow**:
```
/faber:run 123
  └─ faber-director (parses args)
      └─ ??? (unclear invocation)
          └─ Claude improvises (doesn't use workflow)
```

**New (Fixed) Flow - Single Item**:
```
/faber:manage 123
  └─ Command (loads config, validates, invokes skill)
      └─ Skill invocation (faber-director)
          └─ faber-director skill
              ├─ Identifies workflow
              ├─ Parses work_id: "123" (no comma)
              ├─ Determines: single-item mode
              └─ Invokes faber-manager agent (worktree=true)
                  ├─ Frame phase: fetch issue #123
                  ├─ Calls branch-manager with --worktree
                  │   └─ branch-manager checks: worktree exists for #123?
                  │       ├─ Yes → switch to .worktrees/feat-123-* (reuse)
                  │       └─ No → create .worktrees/feat-123-* (subfolder)
                  ├─ Working directory: .worktrees/feat-123-* (within scope ✅)
                  ├─ Executes all phases in worktree
                  ├─ State: .worktrees/feat-123-*/.fractary/plugins/faber/state.json
                  └─ Isolated from any other workflows
```

**New (Fixed) Flow - Multi-Item**:
```
/faber:manage 123,124,125
  └─ Command (loads config, validates, invokes skill)
      └─ Skill invocation (faber-director)
          └─ faber-director skill
              ├─ Identifies workflow
              ├─ Parses work_id: "123,124,125" (comma detected)
              ├─ Splits: ["123", "124", "125"]
              ├─ Determines: multi-item mode
              └─ Invokes faber-manager agents in parallel (3x, all with worktree=true)
                  ├─ faber-manager agent (work_id=123, worktree=true)
                  │   ├─ Calls branch-manager: check/create .worktrees/feat-123-*
                  │   ├─ Working directory: .worktrees/feat-123-* (within scope ✅)
                  │   ├─ Executes all 5 phases in worktree
                  │   └─ State: .worktrees/feat-123-*/.fractary/plugins/faber/state.json
                  ├─ faber-manager agent (work_id=124, worktree=true)
                  │   ├─ Calls branch-manager: check/create .worktrees/feat-124-*
                  │   ├─ Working directory: .worktrees/feat-124-* (within scope ✅)
                  │   ├─ Executes all 5 phases in worktree
                  │   └─ State: .worktrees/feat-124-*/.fractary/plugins/faber/state.json
                  └─ faber-manager agent (work_id=125, worktree=true)
                      ├─ Calls branch-manager: check/create .worktrees/feat-125-*
                      ├─ Working directory: .worktrees/feat-125-* (within scope ✅)
                      ├─ Executes all 5 phases in worktree
                      └─ State: .worktrees/feat-125-*/.fractary/plugins/faber/state.json

Key:
- All workflows use worktrees (prevents interference)
- branch-manager handles reuse detection (not faber)
- Skill invokes multiple agents in parallel (skill→agents pattern)
```

### Command Structure

**File**: `plugins/faber/commands/faber-manage.md` (NEW)
**Old File**: `plugins/faber/commands/faber-run.md` (DEPRECATED)

**Command Responsibilities**:
1. Parse arguments (work_id, flags)
2. Load workflow configuration from `.fractary/plugins/faber/config.json`
3. Validate configuration completeness
4. ALWAYS invoke faber-director skill (no conditional logic)
5. Pass to skill:
   - work_id (single or comma-separated)
   - workflow configuration
   - flags (--workflow, --autonomy)
6. Return skill response to user

**Simplified**: Command is a thin wrapper - parse, load config, invoke skill, return result

**Command MUST NOT**:
- Execute any workflow logic itself
- Detect single vs multi-item (that's the skill's job)
- Invoke agents directly (must go through skill)

### Skill Structure (NEW)

**File**: `plugins/faber/skills/faber-director/SKILL.md` (NEW)

**faber-director Skill Responsibilities**:
1. Receive work_id + workflow config from command
2. Parse work_id to detect single vs multi-item (check for comma)
3. For single-item:
   - Invoke faber-manager agent with workflow config + `worktree=true`
4. For multi-item:
   - Split work_id by comma: `["123", "124", "125"]`
   - Invoke multiple faber-manager agents in parallel (using Task tool)
   - Pass `worktree=true` to ALL agents
   - Coordinate parallel execution
   - Aggregate results
5. Return results to command

**Key**: ALWAYS pass `worktree=true` (single and multi) to prevent workflow interference

**Why Skill (not Agent)**:
- ✅ Retains conversation context from command
- ✅ Can invoke multiple agents in parallel (skill→agents works, agent→agents doesn't)
- ✅ Simpler architecture (no agent-to-agent calls)
- ✅ Follows pattern: commands invoke skills, skills invoke agents

### Branch-Manager Worktree Reuse (NEW)

The `fractary-repo:branch-manager` skill is enhanced to detect and reuse existing worktrees.

**File**: `plugins/repo/skills/branch-manager/SKILL.md` (MODIFIED)

**New Worktree Reuse Logic**:
```pseudo
# When invoked with --worktree flag and work_id
1. Check worktree registry: ~/.fractary/repo/worktrees.json
   {
     "123": {
       "worktree_path": ".worktrees/feat-123-description",
       "branch": "feat/123-description",
       "created": "2025-11-22T14:30:00Z",
       "last_used": "2025-11-22T15:45:00Z",
       "repo_root": "/path/to/repo"
     }
   }

2. If work_id in registry:
   a. Verify worktree still exists (path check)
   b. If exists:
      - Switch to worktree: cd {worktree_path}
      - Update last_used timestamp
      - Return: "Reusing existing worktree for issue #123"
   c. If not exists:
      - Remove stale entry from registry
      - Proceed to create new worktree

3. If work_id NOT in registry:
   - Create new worktree
   - Add to registry with work_id mapping
   - Return: "Created new worktree for issue #123"
```

**Benefits**:
- ✅ Prevents duplicate worktrees for same issue
- ✅ Enables workflow resume (pause #123, restart → same worktree)
- ✅ Automatic cleanup of stale entries
- ✅ Centralized in repo plugin (reusable across all plugins)

**Location**: This logic lives in `fractary-repo:branch-manager` skill, NOT in faber plugin

### Worktree Cleanup on PR Merge (NEW)

The `fractary-repo:pr-merge` command is enhanced to automatically clean up worktrees.

**File**: `plugins/repo/commands/pr-merge.md` (MODIFIED)

**Cleanup Integration**:
```bash
# Automatic cleanup (recommended)
/repo:pr-merge 123 --delete-branch --worktree-cleanup

Flow:
1. Merge PR #123
2. Delete remote branch (if --delete-branch)
3. Delete local branch
4. Check worktree registry for branch
5. If worktree exists:
   - Remove worktree directory: .worktrees/feat-123-*
   - Remove from registry
   - Clean up .fractary state files
6. Return success

# Manual cleanup (if needed later)
/repo:worktree-cleanup --merged
```

**FABER Release Phase Integration**:
The Release phase should recommend cleanup after PR merge:
```
✅ PR merged successfully
ℹ️  Worktree cleanup recommended: /repo:pr-merge 123 --worktree-cleanup
   Or use: /repo:worktree-cleanup --merged
```

**Why in pr-merge**:
- Natural workflow endpoint
- Ensures cleanup happens when work is done
- Prevents accumulation of stale worktrees

### Skill→Agent Invocation Pattern

The command ALWAYS invokes the faber-director skill using the Skill tool. The skill then determines whether to invoke 1 or multiple faber-manager agents.

**Command Invocation** (same for single and multi):
```
/faber:manage 123  OR  /faber:manage 123,124,125

→ Command invokes faber-director skill:
  Skill(
    skill="fractary-faber:faber-director"
  )

  Then passes via conversation context:
  - work_id: "123" or "123,124,125"
  - workflow: {workflow_config}
  - autonomy: "guarded" (or user override)
```

**Skill Logic** (faber-director):
```
1. Receive parameters from command
2. Parse work_id:
   - No comma → single-item mode
   - Comma → multi-item mode
3. Single-item mode:
   Task(
     subagent_type="fractary-faber:faber-manager",
     description="Execute FABER workflow for work item 123",
     prompt="Execute workflow for #123.
             Use worktree: true  (ALWAYS, prevents interference)
             Config: {workflow_json}"
   )

4. Multi-item mode:
   Split work_id → ["123", "124", "125"]
   For each ID in parallel:
     Task(
       subagent_type="fractary-faber:faber-manager",
       description="Execute FABER workflow for work item {id}",
       prompt="Execute workflow for #{id}.
               Use worktree: true  (ALWAYS)
               Config: {workflow_json}"
     )
   Aggregate results and return
```

**Key Architecture**:
- Command → Skill (using Skill tool)
- Skill → Agent(s) (using Task tool)
- No conditional logic in command
- All orchestration in skill
- Skill retains context, can invoke multiple agents

### Configuration Loading

**Location**: `.fractary/plugins/faber/config.json`

**Command reads**:
- `workflows[0]` (default workflow) OR
- `workflows.find(w => w.id === specified_workflow_id)`

**Validation checks**:
- [ ] Configuration file exists
- [ ] Workflow with specified ID exists (or default exists)
- [ ] All required phases are defined
- [ ] Phase steps are non-empty arrays
- [ ] Autonomy settings are valid

**Error handling**:
```bash
# Config not found
Error: FABER configuration not found
Expected: .fractary/plugins/faber/config.json
Run: /faber:init to generate configuration

# Workflow not found
Error: Workflow 'custom' not found in configuration
Available workflows: default, hotfix
Use: /faber:manage 123 --workflow default

# Incomplete workflow
Error: Workflow 'default' is missing required phase: architect
Run: /faber:audit to validate configuration
```

## Implementation Plan

### Phase 1: Create New Command Structure
**Goal**: Implement `/faber:manage` command with proper agent invocation

**Tasks**:
- [ ] Create `plugins/faber/commands/faber-manage.md`
- [ ] Implement argument parsing (work_id, --workflow, --autonomy flags)
- [ ] Implement configuration loading from `.fractary/plugins/faber/config.json`
- [ ] Implement workflow validation logic
- [ ] Implement Task tool invocation for faber-manager agent
- [ ] Add error handling with actionable messages
- [ ] Test with single work item

### Phase 2: Add Command to Plugin Manifest
**Goal**: Register new command in plugin system

**Tasks**:
- [ ] Update `plugins/faber/.claude-plugin/plugin.json` commands array
- [ ] Verify command appears in `/help` output
- [ ] Test command invocation from Claude Code

### Phase 3: Deprecate Old Command
**Goal**: Gracefully migrate users from `/faber:run` to `/faber:manage`

**Tasks**:
- [ ] Update `plugins/faber/commands/faber-run.md` with deprecation notice
- [ ] Add forwarding logic: `/faber:run` → `/faber:manage` with warning
- [ ] Update all documentation references
- [ ] Add migration guide to `plugins/faber/docs/MIGRATION-v2.md`

### Phase 4: Multi-Item Support (Optional)
**Goal**: Enable parallel processing of multiple work items

**Tasks**:
- [ ] Extend argument parsing to accept multiple work IDs
- [ ] Implement director invocation logic for multi-item case
- [ ] Update faber-director agent to handle parallel workflow execution
- [ ] Test with multiple work items
- [ ] Document multi-item usage

### Phase 5: Integration Testing
**Goal**: Verify end-to-end workflow execution

**Tasks**:
- [ ] Test with simple workflow (all phases enabled)
- [ ] Test with partial workflow (some phases disabled)
- [ ] Test with custom workflow (non-default)
- [ ] Test with different autonomy levels
- [ ] Test error cases (missing config, invalid workflow, etc.)
- [ ] Verify workflow state tracking works correctly

## Files to Create/Modify

### New Files
- `plugins/faber/commands/faber-manage.md`: New command implementation (invokes faber-director skill)
- `plugins/faber/skills/faber-director/SKILL.md`: Orchestration skill (single vs multi-item logic)
- `plugins/faber/skills/faber-director/workflow/single-item.md`: Single-item workflow steps
- `plugins/faber/skills/faber-director/workflow/multi-item.md`: Multi-item workflow steps (worktrees)
- `plugins/faber/docs/commands/faber-manage.md`: User-facing command documentation
- `plugins/faber/docs/skills/faber-director.md`: Skill documentation

### Modified Files
- `plugins/faber/commands/faber-run.md`: Add deprecation notice and forwarding to faber-manage
- `plugins/faber/.claude-plugin/plugin.json`: Register new command and skill
- `plugins/faber/docs/MIGRATION-v2.md`: Add `/faber:run` → `/faber:manage` migration guide
- `plugins/faber/README.md`: Update command references, document skill-based architecture
- `plugins/faber/agents/faber-manager.md`: Ensure agent expects workflow config + worktree parameter (ALWAYS true)
- `plugins/repo/skills/branch-manager/SKILL.md`: Add worktree reuse logic (check registry before create), use `.worktrees/` subfolder
- `plugins/repo/skills/branch-manager/scripts/check-worktree.sh`: Check if worktree exists for work_id
- `plugins/repo/skills/branch-manager/scripts/register-worktree.sh`: Add/update worktree registry entry
- `plugins/repo/skills/branch-manager/scripts/create-worktree.sh`: Create worktree in `.worktrees/` subfolder (not parallel directory)
- `plugins/repo/commands/pr-merge.md`: Add `--worktree-cleanup` flag for automatic worktree removal
- `plugins/repo/skills/pr-manager/SKILL.md`: Add worktree cleanup logic on merge
- `.gitignore`: Add `.worktrees/` to ignore worktree directories

### New Registry File
- `~/.fractary/repo/worktrees.json`: Tracks work_id → worktree mapping for reuse detection

## Testing Strategy

### Unit Tests
**Test command argument parsing**:
- Single work ID: `/faber:manage 123`
- With workflow override: `/faber:manage 123 --workflow hotfix`
- With autonomy override: `/faber:manage 123 --autonomy dry-run`
- Multiple work IDs (comma-separated): `/faber:manage 123,124,125`
- Comma detection: verify `contains(',')` triggers faber-director
- Invalid arguments: `/faber:manage` (missing work ID)
- Invalid multi-item syntax: `/faber:manage 123 124 125` (should fail or warn)

**Test configuration loading**:
- Load default workflow
- Load custom workflow by ID
- Handle missing configuration file
- Handle missing workflow ID
- Handle invalid JSON

**Test validation**:
- Valid workflow passes
- Invalid workflow fails with clear error
- Missing phases detected
- Empty phase steps detected

### Integration Tests
**Test single-item workflow execution with worktree**:
1. Run `/faber:manage 123` on test repository
2. Verify faber-manager receives workflow config + worktree=true
3. Verify branch-manager creates worktree: `.worktrees/feat-123-*` (subfolder ✅)
4. Verify working directory switch succeeds (within Claude's scope)
5. Verify agent executes all 5 phases in worktree
6. Verify state is tracked in worktree's `state.json`
7. Verify worktree registered in `~/.fractary/repo/worktrees.json`
8. Verify logs are written via fractary-logs plugin
9. Verify `.worktrees/` is in `.gitignore`

**Test worktree reuse**:
1. Run `/faber:manage 123` (creates worktree)
2. Workflow pauses at Evaluate phase (waiting for feedback)
3. Run `/faber:manage 123` again
4. Verify branch-manager detects existing worktree
5. Verify no duplicate worktree created
6. Verify workflow resumes in same worktree
7. Verify state file shows resume from Evaluate phase

**Test workflow isolation**:
1. Run `/faber:manage 123` (creates worktree A)
2. Workflow pauses at Architect phase
3. Run `/faber:manage 124` (creates worktree B)
4. Verify both workflows run independently
5. Verify no cross-contamination of branches or state
6. Verify each has isolated `.fractary/plugins/faber/state.json`

**Test worktree cleanup on PR merge**:
1. Run `/faber:manage 123` (complete workflow, creates PR)
2. Verify worktree exists: `.worktrees/feat-123-*`
3. Verify registry entry exists in `~/.fractary/repo/worktrees.json`
4. Run `/repo:pr-merge 123 --delete-branch --worktree-cleanup`
5. Verify PR merged successfully
6. Verify remote branch deleted
7. Verify local branch deleted
8. Verify worktree directory removed: `.worktrees/feat-123-*`
9. Verify registry entry removed from `~/.fractary/repo/worktrees.json`
10. Verify state files cleaned up

**Test manual worktree cleanup**:
1. Create multiple worktrees for issues 100, 101, 102
2. Merge PRs for 100 and 101 (without --worktree-cleanup)
3. Run `/repo:worktree-cleanup --merged`
4. Verify worktrees for 100 and 101 removed
5. Verify worktree for 102 remains (not merged)
6. Verify registry updated correctly

**Test multi-item workflow execution**:
1. Run `/faber:manage 100,101,102`
2. Verify command detects comma and invokes faber-director (not faber-manager)
3. Verify faber-director spawns 3 faber-manager instances in parallel
4. Verify each instance creates its own worktree:
   - `../repo-wt-feat-100-*`
   - `../repo-wt-feat-101-*`
   - `../repo-wt-feat-102-*`
5. Verify each instance has separate state tracking in its worktree
6. Verify parallel execution (not sequential)
7. Verify worktrees are cleaned up after workflow completion

**Test error handling**:
1. Run command with missing config → clear error message
2. Run command with invalid workflow ID → list available workflows
3. Run command with incomplete workflow → suggest `/faber:audit`

### E2E Tests
**Real-world scenario (etl.corthion.ai reproduction)**:
1. Create dataset-audit workflow in `.fractary/plugins/faber/config.json`
2. Run `/faber:manage 39` (dataset audit issue)
3. Verify workflow phases execute:
   - Frame: Fetch issue, classify as audit
   - Architect: Inspect dataset, analyze patterns
   - Build: Generate audit report, propose fixes
   - Evaluate: Review findings
   - Release: Comment on issue with results
4. Verify NO ad-hoc skill invocations outside workflow
5. Verify corthion-audit skill is invoked as defined in workflow

## Dependencies

- FABER v2.0 configuration system (`.fractary/plugins/faber/config.json`)
- faber-manager agent (must accept workflow config + worktree parameter - ALWAYS true)
- faber-director skill (NEW - orchestration layer for single/multi-item)
- fractary-work plugin (for issue fetching)
- fractary-repo plugin:
  - branch-manager skill (enhanced with worktree reuse logic)
  - worktree registry (`~/.fractary/repo/worktrees.json`)
  - `--worktree` flag support
- fractary-logs plugin (for workflow logging)
- Git worktree support (for all workflow execution)
- Skill tool (for command→skill invocation)
- Task tool (for skill→agent invocation)

## Risks and Mitigations

- **Risk**: Breaking existing users who rely on `/faber:run`
  - **Likelihood**: High
  - **Impact**: Medium
  - **Mitigation**: Implement forwarding + deprecation warning during transition period. Provide clear migration guide.

- **Risk**: Command becomes too complex with multi-item logic
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Keep multi-item support in Phase 4 (optional). Core fix is single-item invocation.

- **Risk**: Configuration loading adds significant overhead
  - **Likelihood**: Low
  - **Impact**: Low
  - **Mitigation**: Cache configuration in memory. Benchmark loading time (target < 500ms).

- **Risk**: Users don't understand why command was renamed
  - **Likelihood**: Medium
  - **Impact**: Low
  - **Mitigation**: Clear deprecation message explaining consistency with `{plugin}:{manager}` pattern.

- **Risk**: Worktree cleanup failures leave orphaned directories
  - **Likelihood**: Medium
  - **Impact**: Medium
  - **Mitigation**: Implement robust cleanup in faber-director. Add `/repo:worktree-cleanup` command for manual cleanup. Document worktree management best practices.

- **Risk**: Users accidentally use space-separated IDs instead of comma-separated
  - **Likelihood**: High
  - **Impact**: Low
  - **Mitigation**: Detect space-separated pattern and show clear error: "Use comma-separated IDs: /faber:manage 123,124,125"

## Documentation Updates

- `plugins/faber/README.md`: Replace `/faber:run` examples with `/faber:manage`
- `plugins/faber/docs/USAGE.md`: Update all command references
- `plugins/faber/docs/MIGRATION-v2.md`: Add migration section for command rename
- `plugins/faber/docs/commands/faber-manage.md`: Create comprehensive command documentation
- `plugins/faber/docs/commands/faber-run.md`: Add deprecation notice
- `docs/standards/FRACTARY-PLUGIN-STANDARDS.md`: Reference as example of command → agent pattern

## Rollout Plan

### Stage 1: Development (Week 1)
- Implement `/faber:manage` command (Phases 1-2)
- Test with single work items
- Verify agent receives workflow config correctly

### Stage 2: Deprecation (Week 2)
- Add deprecation notice to `/faber:run` (Phase 3)
- Update all documentation
- Test forwarding logic

### Stage 3: Migration Period (Weeks 3-4)
- Both commands work (with warning on old command)
- Monitor user feedback
- Fix any issues discovered

### Stage 4: Optional Enhancement (Week 5+)
- Implement multi-item support (Phase 4)
- Extended testing
- Documentation updates

### Stage 5: Removal (TBD)
- Remove `/faber:run` command entirely
- Update plugin manifest
- Final documentation cleanup

## Success Metrics

- **Workflow Execution Accuracy**: 100% of `/faber:manage` invocations MUST engage faber-manager agent with workflow config
- **Command Invocation Overhead**: < 500ms from command input to agent invocation
- **Error Recovery**: Users can resolve 90% of errors using provided error messages (no need to inspect code)
- **Migration Success**: 95% of users successfully migrate from `/faber:run` to `/faber:manage` within 2 weeks
- **Zero Ad-Hoc Invocations**: No skill invocations bypass the workflow system when using `/faber:manage`

## Implementation Notes

### Critical: Command→Skill→Agent Pattern

The architecture follows a clear 3-layer pattern:
1. **Command** (faber-manage) - Parse args, load config, invoke skill
2. **Skill** (faber-director) - Orchestrate: determine single vs multi, invoke agent(s)
3. **Agent(s)** (faber-manager) - Execute: run workflow phases

The command uses the Skill tool to invoke the faber-director skill. The skill then uses the Task tool to invoke one or more faber-manager agents.

### Command Invocation (Simplified)

The command does NOT do conditional logic. It ALWAYS invokes the faber-director skill:

```pseudo
# Command logic (faber-manage.md)
work_id = parse_first_argument()
workflow_config = load_config()
validate_config(workflow_config)

# ALWAYS invoke skill (no conditional)
Skill(skill="fractary-faber:faber-director")

# Pass parameters via conversation context:
# - work_id: "123" or "123,124,125"
# - workflow: workflow_config
# - autonomy: user_override or default
```

### Skill Detection Logic (faber-director)

The skill determines single vs multi-item and invokes appropriate agent(s):

```pseudo
# Skill logic (faber-director/SKILL.md)
work_id = receive_from_command()
workflow = receive_from_command()

if work_id.contains(','):
  # Multi-item mode
  work_ids = work_id.split(',')

  results = []
  for each id in work_ids (parallel):
    result = Task(
      subagent_type="fractary-faber:faber-manager",
      prompt={
        "work_id": id,
        "workflow": workflow,
        "worktree": true
      }
    )
    results.append(result)

  return aggregate(results)
else:
  # Single-item mode
  return Task(
    subagent_type="fractary-faber:faber-manager",
    prompt={
      "work_id": work_id,
      "workflow": workflow
    }
  )
```

### Worktree Integration

ALL faber-manager instances (single and multi) MUST:
1. Receive `worktree=true` parameter from faber-director (ALWAYS)
2. Pass `--worktree` flag when invoking branch-manager skill
3. branch-manager checks registry for existing worktree:
   - If exists → reuse (enables resume)
   - If not → create new and register
4. Execute all operations within assigned worktree
5. Track state in worktree's `.fractary/plugins/faber/state.json`
6. Worktree persists after completion (for review, cleanup handled separately)

**Worktree naming convention** (managed by repo plugin):
- Pattern: `.worktrees/{branch-slug}`
- Location: **Subfolder inside main repository** (CRITICAL for Claude's working directory scope)
- Example: `/path/to/repo/.worktrees/feat-123-fix-command`
- Why subfolder: Parallel directories (`../repo-wt-*`) are outside Claude's project scope

**Working Directory Scope Issue**:
- Claude cannot switch to directories outside the project root
- Parallel worktrees (`../repo-wt-*`) are inaccessible
- Subfolder worktrees (`.worktrees/*`) remain within scope
- Enables proper working directory switching within agent context

### Workflow Configuration Format

The workflow configuration passed to the agent includes:
- Phase definitions (frame, architect, build, evaluate, release)
- Phase steps and validation criteria
- Hooks (pre/post for each phase)
- Autonomy settings
- Integration details (work plugin, repo plugin, etc.)

### State Tracking

ALL workflows use worktrees, so state is ALWAYS in the worktree:
- **Location**: `{worktree}/.fractary/plugins/faber/state.json`
- **Isolation**: Each workflow has its own state file
- **Resume**: Reusing worktree enables resume from last phase
- **No conflicts**: Multiple workflows can run simultaneously without interference

The command and skill do not manage state directly - that's the faber-manager agent's responsibility.

### Error Handling Philosophy

All errors should be actionable. Instead of "Configuration invalid", say "Workflow 'custom' missing required phase 'architect'. Run /faber:audit to validate configuration."

**Space-separated ID detection**:
If user provides `/faber:manage 123 124`, detect and error:
```
Error: Invalid syntax - use comma-separated IDs (no spaces)
Correct: /faber:manage 123,124
```
