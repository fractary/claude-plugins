---
spec_id: WORK-00075-faber-manager-agent-refactor
work_id: 75
issue_url: https://github.com/corthosai/etl.corthion.ai/issues/75
title: Refactor FABER Manager - Consolidate Skill into Agent with Extracted Helpers
type: feature
status: draft
created: 2025-12-03
author: jmcwilliam
validated: false
source: conversation+issue
related_specs:
  - WORK-00075-dataset-maintain-faber-workflow.md
---

# Feature Specification: Refactor FABER Manager Architecture

**Issue**: [#75](https://github.com/corthosai/etl.corthion.ai/issues/75)
**Type**: Feature (Architectural Refactor)
**Status**: Draft
**Created**: 2025-12-03

## Summary

Refactor the FABER manager architecture to eliminate the redundant manager skill, consolidating orchestration logic into the manager agent while extracting focused helper skills for deterministic operations. This simplifies the architecture, improves clarity, and maintains context efficiency.

## Background and Reasoning

### The Problem with Current Architecture

The current FABER plugin has both:
- **faber-manager.md** (agent) - ~180 lines, lightweight wrapper
- **faber-manager/SKILL.md** (skill) - ~1,000 lines, all orchestration logic

The agent's only job is to invoke the skill:
> "You are a lightweight wrapper that delegates all orchestration logic to the faber-manager skill. Your sole responsibility is to invoke the skill with the proper context."

This creates several issues:

1. **Naming Confusion**: Both components share the name "faber-manager" - when someone says "invoke the faber-manager", which one?

2. **Pointless Indirection**: If the agent just passes through to the skill, why have the agent at all?

3. **Context Loss**: When an agent invokes a skill, context can be lost. The skill starts with minimal context.

4. **Tool Access**: Agents have direct tool access (Bash, Read, Write, etc.). Skills need tools invoked on their behalf. The manager needs these tools for:
   - Reading config files
   - Writing state files
   - Executing hooks
   - Asking user for approval

### The Conclusion

Through discussion, we concluded:

1. **Always go through manager agent** - never invoke manager skill directly
2. **If that's the rule, the agent should BE the orchestrator** - not a pass-through
3. **Extract helper skills for focused utilities** - keeps agent context concise
4. **Deterministic operations make good skills** - especially those that can be scripts

### The Director Skill Stays

We also discussed whether the director skill should be merged into a command. The conclusion was **no** because:

- Director is **stateless** - perfect for a skill
- Director has **significant intelligence** (NLP parsing, parallelization)
- Director is **reusable** (command, webhook, programmatic invocation)
- Director **doesn't need extensive tool access** - just spawns agents

The pattern `Command → Director Skill → Manager Agent` makes sense.

## Proposed Architecture

### Before (Current)
```
/faber:direct (command)
    ↓
faber-director (skill - routing, parallelization)
    ↓
faber-manager (agent - just invokes skill)
    ↓
faber-manager (skill - ALL orchestration logic ~1,000 lines)
    ↓
phase skills (frame, architect, build, evaluate, release)
```

### After (Proposed)
```
/faber:direct (command)
    ↓
faber-director (skill - routing, parallelization) [UNCHANGED]
    ↓
faber-manager (agent - orchestration, tool access, ~800 lines)
    ↓ invokes as needed
Helper Skills:
    - faber-state (read/write state.json)
    - faber-config (load/validate config)
    - faber-hooks (execute pre/post hooks)
    - phase skills (frame, architect, build, evaluate, release) [UNCHANGED]
```

## Technical Design

### Component Responsibilities

#### faber-manager Agent (Refactored)
**Location**: `agents/faber-manager.md`
**Size**: ~800 lines (consolidated from agent + skill)
**Tools**: Bash, Skill, Read, Write, Glob, Grep, AskUserQuestion

**Responsibilities**:
- Workflow orchestration (phase sequencing)
- Decision making (retry logic, approval gates)
- Tool usage (reading files, writing state)
- Invoking helper skills
- Error handling and recovery
- User interaction (approval prompts)

**Does NOT contain**:
- Deterministic config parsing (extracted to faber-config)
- Deterministic state operations (extracted to faber-state)
- Hook execution mechanics (extracted to faber-hooks)

#### faber-state Skill (New)
**Location**: `skills/faber-state/SKILL.md`
**Size**: ~200 lines
**Scripts**: `scripts/state-*.sh`

**Operations**:
- `init-state` - Create new workflow state file
- `read-state` - Read current state
- `update-phase` - Update phase status
- `record-artifact` - Add artifact to state
- `mark-complete` - Mark workflow complete/failed

**Why a skill**: State operations are deterministic, scriptable, and don't need decision-making. The agent decides WHAT to update, the skill handles HOW.

#### faber-config Skill (New)
**Location**: `skills/faber-config/SKILL.md`
**Size**: ~150 lines
**Scripts**: `scripts/config-*.sh`

**Operations**:
- `load-config` - Load and parse config.json
- `load-workflow` - Load workflow definition file
- `validate-config` - Validate config against schema
- `get-workflow-phases` - Extract phase definitions

**Why a skill**: Config loading is deterministic. Parse JSON, validate schema, return structured data. No decisions needed.

#### faber-hooks Skill (New)
**Location**: `skills/faber-hooks/SKILL.md`
**Size**: ~200 lines
**Scripts**: `scripts/hook-*.sh`

**Operations**:
- `list-hooks` - List hooks for a phase boundary
- `execute-hook` - Execute a single hook (document/script/skill)
- `execute-hooks` - Execute all hooks for a boundary

**Why a skill**: Hook execution is mechanical. The agent decides WHEN to run hooks, the skill handles the execution mechanics.

### Files to Delete

After refactoring:
- `skills/faber-manager/SKILL.md` - Consolidated into agent
- `skills/faber-manager/workflow/` - Logic moved to agent

### Migration Path

1. **Extract helper skills first** (non-breaking)
   - Create faber-state, faber-config, faber-hooks
   - Test in isolation

2. **Refactor manager agent** (breaking)
   - Move orchestration logic from skill to agent
   - Update to use helper skills
   - Test end-to-end

3. **Delete manager skill** (cleanup)
   - Remove `skills/faber-manager/`
   - Update any references

## Implementation Plan

### Phase 1: Create Helper Skills
Create the three helper skills with their scripts.

**Tasks**:
- [ ] Create `skills/faber-state/SKILL.md`
- [ ] Create `skills/faber-state/scripts/state-init.sh`
- [ ] Create `skills/faber-state/scripts/state-read.sh`
- [ ] Create `skills/faber-state/scripts/state-update.sh`
- [ ] Create `skills/faber-config/SKILL.md`
- [ ] Create `skills/faber-config/scripts/config-load.sh`
- [ ] Create `skills/faber-config/scripts/workflow-load.sh`
- [ ] Create `skills/faber-hooks/SKILL.md`
- [ ] Create `skills/faber-hooks/scripts/hook-execute.sh`
- [ ] Test each skill in isolation

### Phase 2: Refactor Manager Agent
Move orchestration logic into the agent.

**Tasks**:
- [ ] Copy orchestration logic from `skills/faber-manager/SKILL.md`
- [ ] Adapt to use helper skills instead of inline logic
- [ ] Update tool usage (agent has direct access now)
- [ ] Update error handling
- [ ] Test with simple workflow

### Phase 3: Integration Testing
Verify the refactored architecture works end-to-end.

**Tasks**:
- [ ] Test `/faber:direct` with single issue
- [ ] Test parallel execution (multiple issues)
- [ ] Test phase-specific commands (`/faber:frame`, etc.)
- [ ] Test resume from state
- [ ] Test approval gates
- [ ] Test retry logic

### Phase 4: Cleanup
Remove deprecated components.

**Tasks**:
- [ ] Delete `skills/faber-manager/SKILL.md`
- [ ] Delete `skills/faber-manager/workflow/`
- [ ] Update documentation
- [ ] Update any references in other skills/commands

## Files to Create/Modify

### New Files
- `skills/faber-state/SKILL.md`
- `skills/faber-state/scripts/state-init.sh`
- `skills/faber-state/scripts/state-read.sh`
- `skills/faber-state/scripts/state-update.sh`
- `skills/faber-config/SKILL.md`
- `skills/faber-config/scripts/config-load.sh`
- `skills/faber-config/scripts/workflow-load.sh`
- `skills/faber-hooks/SKILL.md`
- `skills/faber-hooks/scripts/hook-execute.sh`

### Modified Files
- `agents/faber-manager.md` - Major refactor (consolidate skill logic)
- `README.md` - Update architecture documentation

### Deleted Files
- `skills/faber-manager/SKILL.md`
- `skills/faber-manager/workflow/automatic-primitives.md`

## Success Criteria

1. [ ] No `faber-manager` skill exists (only agent)
2. [ ] Manager agent contains orchestration logic
3. [ ] Helper skills exist: faber-state, faber-config, faber-hooks
4. [ ] Helper skills are script-backed where possible
5. [ ] All existing functionality preserved
6. [ ] All tests pass
7. [ ] Documentation updated

## Testing Strategy

### Unit Tests
- Test each helper skill operation
- Test script outputs for deterministic functions

### Integration Tests
- Test full workflow execution
- Test parallel execution
- Test resume from state
- Test error scenarios

### Regression Tests
- Compare behavior before/after refactor
- Ensure no functionality lost

## Risks and Mitigations

- **Risk**: Breaking existing workflows during refactor
  - **Mitigation**: Create helper skills first (additive), then refactor agent, then delete skill

- **Risk**: Manager agent becomes too large
  - **Mitigation**: Extract more helpers if needed; focus on decision logic in agent

- **Risk**: Context limits in larger agent
  - **Mitigation**: Helper skills keep focused operations out of agent context

## Appendix: Architecture Principles

### When to Use Agent vs Skill

| Use Agent When | Use Skill When |
|----------------|----------------|
| Needs tool access (Bash, Read, Write) | Stateless operation |
| Makes decisions | Deterministic logic |
| Maintains state | Scriptable |
| Interacts with user | Reusable utility |
| Orchestrates workflow | Focused single-purpose |

### The Manager Pattern

**Correct**:
```
Manager Agent (orchestration, decisions, tools)
    ↓ invokes
Helper Skills (focused utilities, scriptable)
```

**Incorrect**:
```
Manager Agent (wrapper only)
    ↓ invokes
Manager Skill (all logic) ← WRONG: same name, agent does nothing
```

### The Director Pattern

**Correct**:
```
Director Skill (stateless routing, parallelization)
    ↓ spawns
Manager Agent(s) (orchestration)
```

Director is a skill because it's stateless and doesn't need extensive tools - it just parses intent and spawns agents.
