---
spec_id: WORK-00328-deterministic-step-execution
work_id: 328
issue_url: https://github.com/fractary/claude-plugins/issues/328
title: "FABER: Deterministic step execution via Task tool and command-based workflow config"
type: enhancement
status: draft
created: 2025-12-09
updated: 2025-12-09
author: claude
validated: false
severity: high
source: conversation+issue
---

# Enhancement Specification: Deterministic Step Execution

**Issue**: [#328](https://github.com/fractary/claude-plugins/issues/328)
**Type**: Enhancement
**Severity**: High
**Status**: Draft
**Created**: 2025-12-09

## Summary

This specification defines the architectural changes needed to make FABER workflow step execution deterministic by using Claude's Task tool as a hard execution boundary, replacing the current skill-based approach where the LLM must remember to continue iteration.

## Background

### Problem Origin

Issue #327 revealed that the faber-manager agent stops after the first step in a phase instead of continuing to subsequent steps. While #327 implemented guards and explicit loop instructions, the fundamental issue remains: **LLM-based step iteration is inherently fragile**.

The current architecture:
```
faber-manager (agent)
  └─ Skill(skill="fractary-spec:spec-generator")  ← LLM must remember to continue
  └─ Skill(skill="fractary-spec:spec-refiner")    ← Can be skipped if LLM exits early
```

Despite CRITICAL_RULES, explicit WHILE loop pseudocode, and mandatory continuation sections (#327 fixes), the LLM can still "forget" to continue the loop after a skill completes.

### Root Cause Analysis

1. **Skill tool has no hard boundary**: When a skill completes, the LLM receives the result inline and must remember to check for remaining steps
2. **Context pollution**: Step execution details accumulate in manager context, potentially causing confusion or early exit
3. **Non-deterministic behavior**: LLM behavior varies between invocations; guards reduce but don't eliminate risk

## Proposed Solution

### Architecture Overview

Replace skill-based step execution with Task-based command execution:

**Before (Current)**:
```
faber-manager
  ├─ FOR each step:
  │     Skill(skill="...")  ← Returns inline, LLM must continue loop
  │     (check for more steps)  ← Can be forgotten
  └─ END
```

**After (Proposed)**:
```
faber-manager
  ├─ FOR each step:
  │     Task(command="...")  ← Returns when agent completes (HARD BOUNDARY)
  │     (result received)  ← Explicit signal, can't be missed
  └─ END
```

The Task tool returning is a **hard execution boundary** that the LLM cannot accidentally skip past.

### Change 1: Commands in Workflow Config

**Current (skill-based)**:
```json
{
  "phases": {
    "architect": {
      "steps": [
        {"name": "generate-spec", "skill": "fractary-spec:spec-generator"},
        {"name": "refine-spec", "skill": "fractary-spec:spec-refiner"}
      ]
    }
  }
}
```

**Proposed (command-based)**:
```json
{
  "phases": {
    "architect": {
      "steps": [
        {"name": "generate-spec", "command": "/fractary-spec:generate"},
        {"name": "refine-spec", "command": "/fractary-spec:refine"}
      ]
    }
  }
}
```

**Benefits**:
- Commands are the "public API" - users already know and use them
- More intuitive for users configuring custom workflows
- Commands have well-defined inputs/outputs documented in their `.md` files
- Skills are implementation details that shouldn't leak into user-facing config
- Matches the mental model of "what would I run manually?"

### Change 2: Task Tool for Step Execution

When faber-manager encounters a step with `command` field:

```python
for step in steps_to_execute:
    if step.command:
        # Hard boundary - Task tool returns when command's agent completes
        result = Task(
            subagent_type=get_agent_for_command(step.command),
            description=f"Execute step: {step.name}",
            prompt=build_command_prompt(step.command, context)
        )
        # We MUST be here - Task tool returned
        process_result(result)
        update_state(step, result)
        # Continue to next step...
    elif step.skill:
        # Legacy: direct skill invocation (deprecated)
        Skill(skill=step.skill)
```

**Why Task tool provides hard boundary**:
1. Task tool spawns a separate agent context
2. Parent (faber-manager) is blocked until child completes
3. When Task returns, parent receives explicit result
4. Parent cannot "forget" - it literally wasn't executing during child's work

### Change 3: TodoWrite Integration (Optional Enhancement)

Use Claude's built-in task management for visual progress:

```python
# At phase start, add all steps as todos
for step in phase.steps:
    add_todo(step.name, status="pending")

# During execution
for step in phase.steps:
    update_todo(step.name, status="in_progress")
    result = Task(...)
    update_todo(step.name, status="completed" if result.success else "failed")
```

**Benefits**:
- Visual progress indicator for users
- Accountability mechanism
- Consistent with how Claude tracks tasks elsewhere

**Note**: This is complementary to Task-based execution, not a replacement.

## Context Tradeoff Analysis

### Concern: Agent Context Overhead

Each Task invocation loads baseline context (CLAUDE.md, plugin instructions, etc.). Is this overhead worth it?

### Analysis

| Factor | Skill-based | Task-based |
|--------|-------------|------------|
| **Reliability** | LLM can forget to continue | Hard boundary, cannot skip |
| **Manager context** | Polluted with step details | Stays clean |
| **Compaction frequency** | More frequent (larger context) | Less frequent |
| **Context loading** | Once per workflow | Once per step |
| **Matches manual usage** | No | Yes (users run commands) |

### Conclusion

**Reliability over efficiency**: The small overhead of loading context per step is worth the guarantee of deterministic execution. Additionally:

1. **Manager context stays cleaner** - step execution doesn't pollute manager's working memory
2. **Manager can run longer** - fewer tokens means less frequent compaction, which itself has overhead
3. **Matches user experience** - when users run workflows manually, they use commands/agents without issues
4. **Predictable behavior** - same result every time, not dependent on LLM mood

## Technical Design

### Workflow Schema Changes

**New step schema** (backward compatible):
```json
{
  "type": "object",
  "properties": {
    "name": {"type": "string", "description": "Step identifier"},
    "command": {"type": "string", "description": "Command to execute (preferred)"},
    "skill": {"type": "string", "description": "Skill to invoke (deprecated)"},
    "config": {"type": "object", "description": "Step-specific configuration"},
    "result_handling": {"type": "object", "description": "How to handle results"}
  },
  "oneOf": [
    {"required": ["name", "command"]},
    {"required": ["name", "skill"]}
  ]
}
```

**Validation rules**:
- Step must have either `command` OR `skill`, not both
- If both present, `command` takes precedence (with deprecation warning)
- `skill` field marked as deprecated in schema

### Command-to-Agent Mapping

faber-manager needs to map commands to their agents:

```python
def get_agent_for_command(command: str) -> str:
    """
    Map command to its agent type for Task invocation.

    Examples:
    - /fractary-spec:generate → fractary-spec:spec-manager
    - /fractary-repo:commit → fractary-repo:repo-manager
    - /fractary-work:issue-fetch → fractary-work:work-manager
    """
    # Parse command namespace
    plugin, cmd = parse_command(command)  # e.g., "fractary-spec", "generate"

    # Standard mapping: plugin → plugin:*-manager
    return f"{plugin}:{plugin.split('-')[1]}-manager"
```

**Alternative**: Commands could self-declare their agent in frontmatter:
```yaml
---
name: fractary-spec:generate
agent: fractary-spec:spec-manager  # For Task invocation
---
```

### Context Passing

When spawning Task for a step:

```python
task_prompt = {
    "command": step.command,
    "context": {
        "work_id": workflow_context.work_id,
        "run_id": workflow_context.run_id,
        "phase": current_phase,
        "step": step.name,
        "issue_data": workflow_context.issue_data,
        "previous_results": collect_previous_results(),
        "additional_instructions": workflow_context.additional_instructions
    }
}

result = Task(
    subagent_type=get_agent_for_command(step.command),
    description=f"FABER {current_phase}:{step.name}",
    prompt=json.dumps(task_prompt)
)
```

### Result Handling

Task returns structured result. faber-manager processes:

```python
result = Task(...)

# Validate result structure
if not result or not hasattr(result, 'status'):
    result = {"status": "failure", "errors": ["Invalid result from step"]}

# Standard result handling
match result.status:
    case "success":
        update_state(step, "completed", result)
        continue_to_next_step()
    case "warning":
        update_state(step, "completed", result)
        if result_handling.on_warning == "prompt":
            ask_user_to_continue()
        continue_to_next_step()
    case "failure":
        update_state(step, "failed", result)
        handle_failure(result)  # May abort or prompt user
```

## Implementation Plan

### Phase 1: Schema Update
**Estimated scope**: Small

- [ ] Add `command` field to workflow step schema
- [ ] Update schema validation to accept either `command` or `skill`
- [ ] Add deprecation notice for `skill` field in documentation
- [ ] Update faber-config skill to validate new schema

### Phase 2: faber-manager Execution Update
**Estimated scope**: Medium

- [ ] Add command-to-agent mapping function
- [ ] Modify step execution in Section 4.2 to detect `command` vs `skill`
- [ ] Implement Task-based execution for `command` steps
- [ ] Build context passing structure for spawned agents
- [ ] Handle Task results with standard FABER response format
- [ ] Maintain backward compatibility for `skill` steps

### Phase 3: TodoWrite Integration
**Estimated scope**: Small (optional)

- [ ] Add todo creation at phase start
- [ ] Update todo status during step execution
- [ ] Evaluate impact on reliability and UX
- [ ] Document as optional enhancement

### Phase 4: Default Workflow Migration
**Estimated scope**: Medium

- [ ] Convert `fractary-faber:core` workflow to use commands
- [ ] Convert `fractary-faber:default` workflow to use commands
- [ ] Update workflow documentation
- [ ] Create migration guide for custom workflows
- [ ] Add deprecation warnings when `skill` field used

## Files to Modify

### Core Changes
- `plugins/faber/agents/faber-manager.md` - Add Task-based execution logic
- `plugins/faber/config/schemas/workflow.schema.json` - Add `command` field
- `plugins/faber/skills/faber-config/SKILL.md` - Update validation

### Workflow Files
- `plugins/faber/workflows/core.json` - Convert to commands
- `plugins/faber/workflows/default.json` - Convert to commands

### Documentation
- `plugins/faber/docs/CONFIGURATION.md` - Document command-based steps
- `plugins/faber/docs/MIGRATION-v3.md` - Migration guide for skill→command

## Testing Strategy

### Unit Tests

1. **Schema validation**: Verify `command` and `skill` fields work correctly
2. **Command mapping**: Test get_agent_for_command() with various inputs
3. **Context building**: Verify context passed to Task is complete

### Integration Tests

1. **Single command step**: Execute workflow with one command step
2. **Multi-command phase**: Execute phase with 3+ command steps - all must complete
3. **Mixed mode**: Workflow with both `command` and `skill` steps
4. **Error handling**: Step failure stops workflow appropriately
5. **Resume after failure**: Resume from exact step works with command-based steps

### Regression Tests

1. **Skill-based workflows still work**: Existing `skill` configs don't break
2. **State tracking**: State correctly tracks command-based step progress
3. **Context passing**: All required context reaches spawned agents

## Acceptance Criteria

- [ ] Workflow steps can specify `command` instead of `skill`
- [ ] Steps with `command` execute via Task tool (hard boundary)
- [ ] faber-manager cannot accidentally skip steps (verified by multi-step test)
- [ ] Backward compatibility: `skill` steps still work
- [ ] Default workflows (`core`, `default`) use commands
- [ ] Deprecation warnings shown for `skill` usage
- [ ] Documentation updated with migration guide
- [ ] No regression in workflow functionality

## Risk Assessment

### Risks

1. **Agent overhead**: Each Task loads context
   - **Mitigation**: Testing shows overhead is acceptable; cleaner manager context compensates

2. **Command-agent mapping errors**: Wrong agent invoked
   - **Mitigation**: Standard naming convention; commands can self-declare agent

3. **Context loss between steps**: Important data not passed
   - **Mitigation**: Explicit context structure; integration testing

4. **Migration complexity**: Users with custom workflows
   - **Mitigation**: Backward compatibility; clear migration guide; deprecation warnings

### Risks of Not Implementing

- FABER workflows remain unreliable
- Users cannot trust multi-step phases to complete
- Guards from #327 are necessary but not sufficient
- Continued support burden for step iteration issues

## Dependencies

- Issue #327 merged (provides foundation)
- Task tool behavior is stable
- Command→agent mapping is deterministic

## Related Issues

- #327 - FABER: Workflow stops prematurely (initial fix, guards-based)
- This issue provides architectural solution to same root cause

## Future Considerations

### Potential Enhancements

1. **Parallel step execution**: Steps without dependencies could run in parallel Tasks
2. **Step caching**: Cache successful step results for faster resume
3. **Step timeouts**: Task tool supports timeout; could add per-step timeouts

### Deprecation Timeline

- **v3.0**: Add `command` field, `skill` still supported with warning
- **v3.5**: `skill` field deprecated in docs, warning on every use
- **v4.0**: Consider removing `skill` field support (breaking change)
