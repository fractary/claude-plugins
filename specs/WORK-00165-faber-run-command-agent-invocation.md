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
- [ ] Command accepts multiple work IDs: `/faber:manage 123 124 125`
- [ ] Multiple items are processed via director → agent pattern
- [ ] Each item maintains separate state tracking

## Functional Requirements

- **FR1**: Command MUST load workflow configuration from `.fractary/plugins/faber/config.json` before invoking agent
- **FR2**: Command MUST invoke faber-manager agent (not faber-director) for single work items
- **FR3**: Command MUST pass workflow configuration to the agent in structured format
- **FR4**: Command MUST support `--workflow <id>` flag to override default workflow
- **FR5**: Command MUST support `--autonomy <level>` flag (dry-run, assist, guarded, autonomous)
- **FR6**: Command MUST validate workflow configuration exists before invocation
- **FR7**: Command MUST provide clear error messages if workflow not found
- **FR8**: Command (when renamed to `/faber:manage`) MUST support multi-item processing via director pattern

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

**New (Fixed) Flow**:
```
/faber:manage 123
  └─ Command (loads config, validates)
      └─ Task tool invocation
          └─ faber-manager agent
              ├─ Receives workflow config
              ├─ Executes phases: frame → architect → build → evaluate → release
              └─ Each phase invokes appropriate skills per workflow definition
```

**Multi-Item Flow** (bonus):
```
/faber:manage 123 124 125
  └─ Command (loads config, validates)
      └─ Task tool invocation
          └─ faber-director agent (parallel coordinator)
              ├─ Spawns faber-manager for item 123 (with workflow)
              ├─ Spawns faber-manager for item 124 (with workflow)
              └─ Spawns faber-manager for item 125 (with workflow)
```

### Command Structure

**File**: `plugins/faber/commands/faber-manage.md` (NEW)
**Old File**: `plugins/faber/commands/faber-run.md` (DEPRECATED)

**Command Responsibilities**:
1. Parse arguments (work_id(s), flags)
2. Load workflow configuration from `.fractary/plugins/faber/config.json`
3. Validate configuration completeness
4. Determine single vs multi-item processing
5. Invoke appropriate agent (faber-manager or faber-director)
6. Pass workflow config + parameters to agent
7. Return agent response to user

**Command MUST NOT**:
- Execute any workflow logic itself
- Invoke skills directly
- Make assumptions about workflow structure

### Agent Invocation Pattern

The command uses the Task tool to invoke the faber-manager agent. The workflow configuration is passed in the prompt as a JSON object.

Example invocation for single work item (pseudocode):
```
Task(
  subagent_type="fractary-faber:faber-manager",
  description="Execute FABER workflow for work item 123",
  prompt="Execute workflow for work item #123 using the following configuration: {workflow_json}"
)
```

The agent receives the workflow configuration and executes all phases in order (frame, architect, build, evaluate, release).

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
- `plugins/faber/commands/faber-manage.md`: New command implementation with proper agent invocation
- `plugins/faber/docs/commands/faber-manage.md`: User-facing command documentation

### Modified Files
- `plugins/faber/commands/faber-run.md`: Add deprecation notice and forwarding logic
- `plugins/faber/.claude-plugin/plugin.json`: Register new command
- `plugins/faber/docs/MIGRATION-v2.md`: Add `/faber:run` → `/faber:manage` migration guide
- `plugins/faber/README.md`: Update command references
- `plugins/faber/agents/faber-manager.md`: Ensure agent expects workflow config in request

## Testing Strategy

### Unit Tests
**Test command argument parsing**:
- Single work ID: `/faber:manage 123`
- With workflow override: `/faber:manage 123 --workflow hotfix`
- With autonomy override: `/faber:manage 123 --autonomy dry-run`
- Multiple work IDs: `/faber:manage 123 124 125`
- Invalid arguments: `/faber:manage` (missing work ID)

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

**Test multi-item workflow execution** (if implemented):
1. Run `/faber:manage 100 101 102`
2. Verify faber-director invokes 3 faber-manager instances
3. Verify each instance has separate state tracking
4. Verify parallel execution (not sequential)

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
- faber-manager agent (must accept workflow config in request)
- faber-director agent (for multi-item support - optional)
- fractary-work plugin (for issue fetching)
- fractary-logs plugin (for workflow logging)

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

### Critical: Agent Invocation Pattern

The command MUST use the Task tool to invoke the agent. The workflow configuration must be serialized and passed in the prompt parameter. The agent will parse the configuration and execute the workflow phases accordingly.

### Workflow Configuration Format

The workflow configuration passed to the agent includes:
- Phase definitions (frame, architect, build, evaluate, release)
- Phase steps and validation criteria
- Hooks (pre/post for each phase)
- Autonomy settings
- Integration details (work plugin, repo plugin, etc.)

### State Tracking

The faber-manager agent maintains state in `.fractary/plugins/faber/state.json` to enable workflow resume and retry capabilities. The command does not manage state directly.

### Error Handling Philosophy

All errors should be actionable. Instead of "Configuration invalid", say "Workflow 'custom' missing required phase 'architect'. Run /faber:audit to validate configuration."
