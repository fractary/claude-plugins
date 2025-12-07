---
spec_id: WORK-00262-default-build-skill-planning-and-autonomy
work_id: 262
issue_url: https://github.com/fractary/claude-plugins/issues/262
title: Default build skill planning and autonomy
type: feature
status: draft
created: 2025-12-06
updated: 2025-12-06
author: fractary
validated: false
source: conversation+issue
related_issues:
  - 178  # Better session history management (merged into this spec)
  - 258  # HITL resume handling (leverages context-reconstitution.md)
---

# Feature Specification: Build Skill Autonomy and Session Management

**Issue**: [#262](https://github.com/fractary/claude-plugins/issues/262)
**Related**: [#178](https://github.com/fractary/claude-plugins/issues/178) (Session Management - merged)
**Leverages**: [#258](https://github.com/fractary/claude-plugins/issues/258) (Context Reconstitution - completed)
**Type**: Feature
**Status**: Draft
**Created**: 2025-12-06

---

## Summary

This specification combines two related needs:

1. **Build Skill Autonomy (#262)**: Enhance the FABER build skill to implement specs with deep planning, autonomous execution, and meaningful progress checkpoints.

2. **Session Lifecycle Management (#178)**: Implement a "one phase per session" model with session checkpoints, summaries, and clean handoffs between sessions.

Together, these enable truly autonomous multi-session workflow execution where Claude can implement complex specs across multiple sessions while maintaining full context continuity.

---

## Problem Statement

### Current Issues

1. **Inefficient Hook-Based Progress Tracking**
   - `commit-on-stop` and `comment-on-stop` hooks run on every stop
   - Many stops have nothing to commit/comment, wasting time and context
   - In autonomous sessions with no stops, progress goes unreported

2. **Claude's Premature Stopping**
   - Claude frequently suggests "pausing for now" when context runs low
   - Proposes "breaking into phases" or "future work"
   - Asks for confirmation at each step, breaking autonomy

3. **No Session Lifecycle Management**
   - Context overflow handled by compaction (unpredictable)
   - No proactive session boundaries
   - No session summaries for continuity
   - Cross-session context loss

### Solution: One Phase Per Session Model

```
┌─────────────────────────────────────────────────────────────────┐
│                    MULTI-SESSION WORKFLOW                        │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│  Session 1 (Phase 1)                                            │
│  ┌────────────────────────────────────────────────────────┐     │
│  │ [Context Reconstitution] → [Build Phase 1] → [Checkpoint] │   │
│  │         (#258)                 (#262)         (#262+#178) │   │
│  └────────────────────────────────────────────────────────┘     │
│                              ↓                                   │
│                    Session Summary Saved                         │
│                              ↓                                   │
│  Session 2 (Phase 2)                                            │
│  ┌────────────────────────────────────────────────────────┐     │
│  │ [Context Reconstitution] → [Build Phase 2] → [Checkpoint] │   │
│  └────────────────────────────────────────────────────────┘     │
│                              ↓                                   │
│                           ...                                    │
│                              ↓                                   │
│  Session N (Phase N)                                            │
│  ┌────────────────────────────────────────────────────────┐     │
│  │ [Context Reconstitution] → [Build Phase N] → [Complete]   │   │
│  └────────────────────────────────────────────────────────┘     │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

---

## User Stories

### US1: Autonomous Phase Implementation
**As a** developer using FABER workflows
**I want** the build skill to implement one spec phase completely without stopping
**So that** I can trust each session to complete its assigned work

**Acceptance Criteria**:
- [ ] Build skill reads spec and identifies current phase
- [ ] Uses Opus model with thinking mode for deep planning
- [ ] Creates detailed implementation plan before coding
- [ ] Executes plan without asking for confirmation
- [ ] Does not suggest "stopping" or "future phases"
- [ ] Handles compaction gracefully and continues

### US2: Phase-Boundary Checkpoints
**As a** developer monitoring workflows
**I want** progress checkpoints at phase boundaries
**So that** work is persisted and visible

**Acceptance Criteria**:
- [ ] Spec updated with phase completion status
- [ ] Commit created with phase work
- [ ] Issue comment posted with progress summary
- [ ] Checkpoints triggered by phase completion, not stop events

### US3: Session Lifecycle Management
**As a** developer running multi-phase specs
**I want** clean session boundaries between phases
**So that** context doesn't overflow and continuity is maintained

**Acceptance Criteria**:
- [ ] faber-manager handles session lifecycle
- [ ] Session summary created at phase completion
- [ ] New session loads context via #258's reconstitution
- [ ] Summary + spec + issue provide full context for continuation

### US4: Phase-Structured Specs
**As a** developer creating specs
**I want** specs to be structured into session-sized phases
**So that** the one-phase-per-session model works effectively

**Acceptance Criteria**:
- [ ] Spec generator produces phase-structured output
- [ ] Each phase has clear status indicator
- [ ] Phases include task checklists
- [ ] Phase size guidance included

---

## Functional Requirements

### Build Skill (FR1-FR8)

- **FR1**: Build skill MUST use Opus model with thinking mode enabled
- **FR2**: Build skill MUST read spec and create detailed implementation plan BEFORE coding
- **FR3**: Build skill MUST execute current phase without stopping for confirmation
- **FR4**: Build skill MUST NOT suggest "pausing" or "future phases"
- **FR5**: Build skill MUST trigger checkpoint at phase completion
- **FR6**: Build skill MUST update spec progress via spec-updater skill
- **FR7**: Build skill MUST commit via repo plugin's commit-creator
- **FR8**: Build skill MUST comment on issue via work plugin's comment-creator

### Session Management (FR9-FR13)

- **FR9**: faber-manager MUST manage session lifecycle (not build skill)
- **FR10**: Session checkpoint MUST include: spec update, commit, issue comment, summary
- **FR11**: Session summary MUST be saved to run state for next session
- **FR12**: New sessions MUST load context via context-reconstitution.md (#258)
- **FR13**: faber-manager MUST prompt user to end session after phase completion

### Spec Structure (FR14-FR16)

- **FR14**: Spec generator MUST produce phase-structured specs
- **FR15**: Each phase MUST have status indicator (Not Started / In Progress / Complete)
- **FR16**: Each phase MUST have task checklist

---

## Non-Functional Requirements

- **NFR1**: Context efficiency - Checkpoints minimize context consumption
- **NFR2**: Autonomy - Each phase completes without human intervention
- **NFR3**: Continuity - Full context available at session start via reconstitution
- **NFR4**: Observability - Progress visible via git history, issue timeline, spec status
- **NFR5**: Predictability - One phase per session provides consistent boundaries

---

## Technical Design

### 1. Build Skill Enhancement

**Location**: Modify existing `plugins/faber/skills/build/SKILL.md`

**Key Changes**:

```markdown
---
name: build
description: FABER Phase 3 - Implements solution from specification with autonomous execution
model: claude-opus-4-5  # CHANGED: Use Opus for deep thinking
---

<CRITICAL_RULES>
1. **Use Thinking Mode** - ALWAYS engage extended thinking before implementation
2. **Plan First** - Read spec and create DETAILED step-by-step plan BEFORE any code
3. **Complete Current Phase** - Implement the current spec phase IN ITS ENTIRETY
4. **No Premature Stops** - NEVER suggest "pausing", "future phases", or "picking up later"
5. **Accept Compaction** - If context compacts, CONTINUE from where you left off
6. **Phase Boundary Checkpoint** - After phase completion, trigger checkpoint workflow
7. **Follow Specification** - ALWAYS implement according to the spec
8. **Commit Regularly** - Create semantic commits for logical work units within phase
</CRITICAL_RULES>
```

**Workflow Enhancement** (`workflow/basic.md`):

```markdown
### 1. Load and Analyze Specification

Read the spec file and identify:
- Current phase to implement
- Phase tasks/checklist
- Files to create/modify
- Technical approach

### 2. Create Implementation Plan (THINKING MODE)

Before ANY code changes, create a detailed plan:

<extended_thinking>
Think deeply about:
1. What exactly needs to be implemented in this phase
2. The order of operations
3. Potential challenges and how to address them
4. How each task maps to file changes
5. Testing approach for this phase

Document your complete plan before proceeding.
</extended_thinking>

### 3. Execute Implementation Plan

Implement each planned step:
- Create/modify files as planned
- Make commits at logical boundaries (not waiting for phase end)
- Update task checklist in spec as items complete

### 4. Phase Completion Checkpoint

When phase is complete:
1. Update spec with phase status = Complete
2. Create final phase commit if uncommitted changes
3. Post progress comment to issue
4. Signal faber-manager that phase is complete
```

### 2. Session Checkpoint Workflow

**New file**: `plugins/faber/skills/build/workflow/phase-checkpoint.md`

```markdown
# Phase Checkpoint Workflow

Triggered when a spec phase is completed.

## Actions

### 1. Update Spec Progress

Invoke spec-updater skill:
- Mark current phase as "Complete"
- Check off completed tasks
- Add implementation notes if relevant

### 2. Create Phase Commit

If uncommitted changes exist:
- Stage all changes
- Create semantic commit: `feat({work_id}): Complete {phase_name}`

### 3. Post Progress Comment

Format and post issue comment with:
- Phase completed
- Files changed since last checkpoint
- Tasks completed (checked off)
- Percentage complete (phases done / total)
- Next phase description

### 4. Save Session Summary

Create session summary for next session:
- What was accomplished
- Key decisions made
- Files created/modified
- Remaining phases

### 5. Signal Phase Complete

Return to faber-manager with:
- Phase status: complete
- Next phase: {next_phase_name} or null if done
- Recommend: end_session (for clean handoff)
```

### 3. Session Summary Format

**Location**: Saved to run state at `.fractary/plugins/faber/runs/{run_id}/session-summaries/`

```json
{
  "session_id": "session-20251206-001",
  "phase_completed": "phase-1",
  "timestamp": "2025-12-06T18:30:00Z",
  "summary": {
    "accomplished": [
      "Created SKILL.md with autonomy-focused prompts",
      "Implemented workflow/basic.md with planning steps",
      "Added checkpoint trigger logic"
    ],
    "decisions": [
      "Used Opus model for thinking mode support",
      "Checkpoint at phase boundary only (not mid-phase)"
    ],
    "files_changed": [
      "plugins/faber/skills/build/SKILL.md",
      "plugins/faber/skills/build/workflow/basic.md"
    ],
    "commits": ["abc123", "def456"],
    "remaining_phases": ["phase-2", "phase-3"],
    "context_notes": "Spec is well-structured, no blockers identified"
  }
}
```

### 4. Spec Phase Structure

**Update spec-generator to produce**:

```markdown
## Implementation Plan

### Phase 1: Core Infrastructure
**Status**: ⬜ Not Started | 🔄 In Progress | ✅ Complete

**Objective**: Set up base skill structure

**Tasks**:
- [ ] Create SKILL.md with autonomy prompts
- [ ] Create workflow directory structure
- [ ] Add basic workflow file

**Estimated Scope**: Small (suitable for single session)

---

### Phase 2: Checkpoint Integration
**Status**: ⬜ Not Started

**Objective**: Implement progress checkpoints

**Tasks**:
- [ ] Add spec update logic
- [ ] Add commit integration
- [ ] Add issue comment integration

**Estimated Scope**: Medium (suitable for single session)

---

### Phase 3: Testing and Documentation
**Status**: ⬜ Not Started

**Objective**: Validate and document

**Tasks**:
- [ ] Test with sample specs
- [ ] Document usage
- [ ] Update plugin docs

**Estimated Scope**: Small (suitable for single session)
```

### 5. faber-manager Session Lifecycle

**Update**: `plugins/faber/agents/faber-manager.md`

Add session lifecycle handling after build phase returns:

```markdown
## Session Lifecycle Management

When build skill reports phase completion:

1. **Check if more phases remain**
   - Read spec to determine remaining phases

2. **If more phases**:
   - Prompt user: "Phase {N} complete. End session for clean handoff?"
   - Options: [End Session] [Continue to Next Phase]
   - If End Session: Save state, show resume command
   - If Continue: Proceed (user accepts context risk)

3. **If no more phases**:
   - Proceed to Evaluate phase
   - No session boundary needed
```

### 6. spec-updater Skill

**New skill**: `plugins/spec/skills/spec-updater/SKILL.md`

```markdown
---
name: spec-updater
description: Updates spec files with implementation progress
model: claude-haiku-4-5
---

# Spec Updater Skill

<CONTEXT>
Updates specification files to reflect implementation progress.
Used by build skill to mark phases complete and check off tasks.
</CONTEXT>

<OPERATIONS>

## update-phase-status

Mark a phase as complete/in-progress:
- Read spec file
- Find phase section
- Update status indicator
- Write spec file

## check-task

Check off a completed task:
- Read spec file
- Find task in phase
- Change `- [ ]` to `- [x]`
- Write spec file

## add-implementation-notes

Add notes to a phase:
- Read spec file
- Find phase section
- Append to Implementation Notes subsection
- Write spec file

</OPERATIONS>
```

### 7. Progress Comment Template

**New file**: `plugins/faber/skills/build/templates/progress-comment.md.template`

```markdown
## Phase Complete: {{phase_name}}

**Run ID**: `{{run_id}}`
**Work Item**: #{{work_id}}
**Timestamp**: {{timestamp}}

### Progress Summary

{{summary}}

### Files Changed

{{#files}}
- `{{path}}` - {{description}}
{{/files}}

### Tasks Completed

{{#tasks}}
- [x] {{task}}
{{/tasks}}

### Overall Progress

**Phases**: {{phases_complete}}/{{phases_total}} ({{percent_complete}}%)

{{#next_phase}}
### Next Phase: {{next_phase_name}}

{{next_phase_objective}}
{{/next_phase}}

{{^next_phase}}
### All Phases Complete

Ready for Evaluate phase.
{{/next_phase}}

---
_Session checkpoint by FABER workflow_
```

---

## Implementation Plan

### Phase 1: Enhance Build Skill with Autonomy Prompts
**Status**: ⬜ Not Started

**Objective**: Modify existing build skill for autonomous execution

**Tasks**:
- [ ] Update `plugins/faber/skills/build/SKILL.md` with new CRITICAL_RULES
- [ ] Change model to `claude-opus-4-5` for thinking mode
- [ ] Add explicit anti-stopping instructions
- [ ] Update workflow/basic.md with plan-first approach

**Estimated Scope**: Small (single session)

---

### Phase 2: Create Phase Checkpoint Workflow
**Status**: ⬜ Not Started

**Objective**: Implement checkpoint logic at phase boundaries

**Tasks**:
- [ ] Create `workflow/phase-checkpoint.md`
- [ ] Define checkpoint trigger conditions
- [ ] Create `templates/progress-comment.md.template`
- [ ] Integrate with build workflow

**Estimated Scope**: Small (single session)

---

### Phase 3: Create spec-updater Skill
**Status**: ⬜ Not Started

**Objective**: Enable spec progress updates

**Tasks**:
- [ ] Create `plugins/spec/skills/spec-updater/SKILL.md`
- [ ] Implement update-phase-status operation
- [ ] Implement check-task operation
- [ ] Implement add-implementation-notes operation
- [ ] Add to spec plugin manifest

**Estimated Scope**: Medium (single session)

---

### Phase 4: Session Summary and Lifecycle
**Status**: ⬜ Not Started

**Objective**: Enable session handoffs

**Tasks**:
- [ ] Define session summary format
- [ ] Update faber-manager with session lifecycle handling
- [ ] Integrate with context-reconstitution.md (load summaries)
- [ ] Add session summary to checkpoint workflow

**Estimated Scope**: Medium (single session)

---

### Phase 5: Update Spec Generator for Phases
**Status**: ⬜ Not Started

**Objective**: Ensure specs are phase-structured

**Tasks**:
- [ ] Update spec-feature.md.template with phase structure
- [ ] Add status indicators to phases
- [ ] Add task checklists to phases
- [ ] Add scope estimates to phases

**Estimated Scope**: Small (single session)

---

### Phase 6: Integration Testing
**Status**: ⬜ Not Started

**Objective**: Validate complete workflow

**Tasks**:
- [ ] Test single-phase spec execution
- [ ] Test multi-phase spec with session boundaries
- [ ] Verify context reconstitution between sessions
- [ ] Verify progress tracking (commits, comments, spec updates)
- [ ] Document findings and adjust

**Estimated Scope**: Medium (single session)

---

## Files to Create/Modify

### New Files

| File | Purpose |
|------|---------|
| `plugins/spec/skills/spec-updater/SKILL.md` | Spec progress update skill |
| `plugins/faber/skills/build/workflow/phase-checkpoint.md` | Checkpoint workflow |
| `plugins/faber/skills/build/templates/progress-comment.md.template` | Issue comment template |

### Modified Files

| File | Changes |
|------|---------|
| `plugins/faber/skills/build/SKILL.md` | Add autonomy rules, change model |
| `plugins/faber/skills/build/workflow/basic.md` | Add planning workflow, checkpoint trigger |
| `plugins/faber/agents/faber-manager.md` | Add session lifecycle handling |
| `plugins/faber/skills/faber-manager/workflow/context-reconstitution.md` | Load session summaries |
| `plugins/spec/skills/spec-generator/templates/spec-feature.md.template` | Add phase structure |

---

## Integration with Existing Work

### #258 Context Reconstitution (LEVERAGES)

The context-reconstitution.md workflow already:
- Loads run state, spec, issue, branch, events
- Determines resume point
- Builds consolidated context

**Enhancement needed**: Add session summary loading:

```markdown
### 0.9 Load Previous Session Summary (if exists)

IF session_summaries directory exists THEN
  # Load most recent summary
  latest_summary = get_latest_file(".fractary/plugins/faber/runs/{run_id}/session-summaries/")

  IF latest_summary exists THEN
    summary = read(latest_summary)
    LOG "✓ Loaded session summary from: ${latest_summary}"
    LOG "  Phase completed: ${summary.phase_completed}"
    LOG "  Accomplishments: ${summary.accomplished.length} items"

    context.session_summary = summary
```

### Hook Deprecation (FUTURE)

Once this is working, the following hooks can be disabled:
- `commit-on-stop` (replaced by phase checkpoints)
- `comment-on-stop` (replaced by phase checkpoints)

This is out of scope for this issue but noted for future.

---

## Dependencies

| Dependency | Status | Notes |
|------------|--------|-------|
| `fractary-spec:spec-updater` | To Create | Part of this issue (Phase 3) |
| `fractary-repo:commit-creator` | Exists | No changes needed |
| `fractary-work:comment-creator` | Exists | No changes needed |
| `context-reconstitution.md` | Exists (#258) | Minor enhancement for summaries |

---

## Risks and Mitigations

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Claude still suggests stopping | Medium | High | Multiple reinforcing prompts, testing, iteration |
| Phase too large for one session | Medium | Medium | Spec generator guidance on phase sizing |
| Session summary insufficient | Low | Medium | Include key decisions and context notes |
| Checkpoint context overhead | Low | Low | Use Haiku for spec-updater, efficient templates |

---

## Success Metrics

| Metric | Target |
|--------|--------|
| Phase completion rate | >95% phases complete without manual intervention |
| Context overflow rate | <5% sessions hit compaction |
| Checkpoint overhead | <3% of session context per checkpoint |
| Resume success rate | >98% resumes have full context |
| Progress visibility | 100% phases have commit + issue comment |

---

## Implementation Notes

### Key Design Decisions

1. **Modify existing build skill** (not create new one) - Avoids duplication
2. **Checkpoints at phase boundaries** (not mid-phase) - Aligns with spec structure
3. **faber-manager owns session lifecycle** (not build skill) - Separation of concerns
4. **User prompted to end session** (not automatic) - User retains control
5. **Session summaries in run state** (not separate storage) - Context reconstitution finds them

### The "Think Hard" Prompt Pattern

```
Read the latest spec and think hard about a detailed step-by-step plan
to implement the current phase and then proceed to implement it in its
entirety without stopping.
```

Combined with:
- Opus model (supports extended thinking)
- Explicit NEVER rules against stopping
- Plan-before-code enforcement

### Anti-Patterns to Counter

| Claude Tendency | Counter Measure |
|-----------------|-----------------|
| "Let's pause here" | CRITICAL_RULE: NEVER suggest pausing |
| "We can do this next time" | CRITICAL_RULE: Complete current phase |
| "Should I proceed?" | CRITICAL_RULE: No confirmation needed |
| "Let's start with X and see" | Workflow: Plan BEFORE code |

### Context Flow Between Sessions

```
Session N ends:
  → Phase checkpoint saves work
  → Session summary captures decisions
  → Run state updated

Session N+1 starts:
  → Context reconstitution runs
  → Loads: state, spec, issue, branch, events, summary
  → Resume point determined
  → Full context available
```
