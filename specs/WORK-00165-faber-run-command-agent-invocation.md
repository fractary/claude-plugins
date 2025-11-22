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
- [ ] Each multi-item instance uses its own worktree (via `--worktree` flag)
- [ ] Each item maintains separate state tracking (in worktree if multi)

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
- **FR11**: Each parallel workflow instance MUST use a separate worktree (via `--worktree` flag to branch-manager)
- **FR12**: faber-director MUST be a skill (not an agent) to retain context and enable skill→agent invocation

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
              └─ Invokes faber-manager agent
                  ├─ Receives workflow config
                  ├─ Executes phases: frame → architect → build → evaluate → release
                  └─ Each phase invokes appropriate skills per workflow definition
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
              ├─ Determines: multi-item mode (use worktrees)
              └─ Invokes faber-manager agents in parallel (3x)
                  ├─ faber-manager agent (work_id=123, worktree=true)
                  │   ├─ Creates worktree: ../repo-wt-feat-123-*
                  │   ├─ Executes all 5 phases in worktree
                  │   └─ State: {worktree}/.fractary/plugins/faber/state.json
                  ├─ faber-manager agent (work_id=124, worktree=true)
                  │   ├─ Creates worktree: ../repo-wt-feat-124-*
                  │   ├─ Executes all 5 phases in worktree
                  │   └─ State: {worktree}/.fractary/plugins/faber/state.json
                  └─ faber-manager agent (work_id=125, worktree=true)
                      ├─ Creates worktree: ../repo-wt-feat-125-*
                      ├─ Executes all 5 phases in worktree
                      └─ State: {worktree}/.fractary/plugins/faber/state.json

Key: Skill invokes multiple agents in parallel (skill→agents pattern)
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
   - Invoke faber-manager agent with workflow config
4. For multi-item:
   - Split work_id by comma: `["123", "124", "125"]`
   - Invoke multiple faber-manager agents in parallel (using Task tool)
   - Pass `worktree=true` parameter to each agent
   - Coordinate parallel execution
   - Aggregate results
5. Return results to command

**Why Skill (not Agent)**:
- ✅ Retains conversation context from command
- ✅ Can invoke multiple agents in parallel (skill→agents works, agent→agents doesn't)
- ✅ Simpler architecture (no agent-to-agent calls)
- ✅ Follows pattern: commands invoke skills, skills invoke agents

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
     prompt="Execute workflow for #123. Config: {workflow_json}"
   )

4. Multi-item mode:
   Split work_id → ["123", "124", "125"]
   For each ID in parallel:
     Task(
       subagent_type="fractary-faber:faber-manager",
       description="Execute FABER workflow for work item {id}",
       prompt="Execute workflow for #{id}.
               Use worktree: true
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
- `plugins/faber/agents/faber-manager.md`: Ensure agent expects workflow config + worktree parameter

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
**Test single-item workflow execution**:
1. Run `/faber:manage 123` on test repository
2. Verify faber-manager agent receives workflow config
3. Verify agent executes all 5 phases in order
4. Verify state is tracked in `state.json`
5. Verify logs are written via fractary-logs plugin

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
- faber-manager agent (must accept workflow config + worktree parameter)
- faber-director skill (NEW - orchestration layer for single/multi-item)
- fractary-work plugin (for issue fetching)
- fractary-repo plugin (for branch creation with `--worktree` flag)
- fractary-logs plugin (for workflow logging)
- Git worktree support (for parallel workflow execution)
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

For multi-item workflows, each faber-manager instance MUST:
1. Receive `use_worktrees=true` parameter from faber-director
2. Pass `--worktree` flag when invoking branch-manager skill
3. Execute all operations within its assigned worktree
4. Track state in worktree's `.fractary/plugins/faber/state.json`
5. Clean up worktree on successful completion (via faber-director)

**Worktree naming convention** (managed by repo plugin):
- Pattern: `{repo-name}-wt-{branch-slug}`
- Location: Sibling directory to main repository
- Example: `claude-plugins-wt-feat-123-fix-command`

### Workflow Configuration Format

The workflow configuration passed to the agent includes:
- Phase definitions (frame, architect, build, evaluate, release)
- Phase steps and validation criteria
- Hooks (pre/post for each phase)
- Autonomy settings
- Integration details (work plugin, repo plugin, etc.)

### State Tracking

**Single-item**: faber-manager maintains state in `.fractary/plugins/faber/state.json`

**Multi-item**: Each faber-manager instance maintains state in its worktree:
- `{worktree}/.fractary/plugins/faber/state.json`
- Isolated from other instances
- Enables independent resume/retry per workflow

The command does not manage state directly.

### Error Handling Philosophy

All errors should be actionable. Instead of "Configuration invalid", say "Workflow 'custom' missing required phase 'architect'. Run /faber:audit to validate configuration."

**Space-separated ID detection**:
If user provides `/faber:manage 123 124`, detect and error:
```
Error: Invalid syntax - use comma-separated IDs (no spaces)
Correct: /faber:manage 123,124
```
