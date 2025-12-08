# WORK-00309: faber-director Skill TodoWrite Enforcement

**Issue:** [#309](https://github.com/fractary/claude-plugins/issues/309)
**Type:** Bug Fix
**Status:** In Progress
**Created:** 2025-12-08
**Branch:** `fix/309-faber-director-skill-fails-to-complete-workflow-ex`

## Problem Statement

The `faber-director` skill stops prematurely after sub-skill invocations instead of continuing through all 9 workflow steps. When invoked via `/fractary-faber:run --work-id <id>`, the skill:

1. Loads configuration correctly
2. Invokes `faber-config` skill to resolve workflow inheritance
3. **STOPS HERE** - Returns workflow resolution as final output
4. Never fetches issue data via `fractary-work` plugin
5. Never invokes `faber-manager` agent to execute the workflow

## Root Cause Analysis

The `faber-director` SKILL.md contains comprehensive documentation for a 9-step workflow, but lacks **execution enforcement**. The LLM interprets sub-skill completion (faber-config returning) as a natural stopping point rather than a checkpoint in a longer sequence.

### Why This Happens

1. **Natural Language Ambiguity**: The workflow steps read like documentation, not executable commands
2. **No Execution Tracking**: Nothing forces the LLM to track progress through all 9 steps
3. **Sub-skill Return Pattern**: When a sub-skill completes and returns a result, the LLM treats this as a "done" signal
4. **Missing Explicit Continuation**: No mechanism tells the LLM "this is step 2 of 9, keep going"

## Proposed Solution: TodoWrite-Enforced Execution

Leverage Claude Code's built-in `TodoWrite` tool to create a mandatory execution tracker that the skill must work through, marking items complete as it progresses.

### Solution Components

1. **`<MANDATORY_FIRST_ACTION>` Section**: Force TodoWrite initialization before any other action
2. **Step Transition Markers**: After each workflow step, explicitly state "mark X complete, proceed to Y"
3. **`<TERMINATION_RULES>` Section**: Define when the skill is allowed to return
4. **`<COMPLETION_VERIFICATION>` Section**: Final checklist before returning

## Implementation Plan

### File to Modify

`plugins/faber/skills/faber-director/SKILL.md`

### Changes Required

#### 1. Add `<MANDATORY_FIRST_ACTION>` Section (after `<CRITICAL_RULES>`)

```markdown
<MANDATORY_FIRST_ACTION>
**BEFORE ANY OTHER ACTION**, you MUST initialize the execution tracker:

Use TodoWrite tool with this EXACT todo list:
```json
[
  {"content": "Step 0a: Load project configuration", "status": "pending", "activeForm": "Loading project configuration"},
  {"content": "Step 0b: Resolve workflow inheritance via faber-config", "status": "pending", "activeForm": "Resolving workflow inheritance"},
  {"content": "Step 0.5: Handle resume/rerun (if applicable)", "status": "pending", "activeForm": "Handling resume/rerun"},
  {"content": "Step 1: Fetch issue data (if work_id provided)", "status": "pending", "activeForm": "Fetching issue data"},
  {"content": "Step 2: Detect configuration from labels", "status": "pending", "activeForm": "Detecting label configuration"},
  {"content": "Step 3: Apply configuration priority", "status": "pending", "activeForm": "Applying configuration priority"},
  {"content": "Step 4: Resolve target", "status": "pending", "activeForm": "Resolving target"},
  {"content": "Step 5: Validate phases/steps", "status": "pending", "activeForm": "Validating phases/steps"},
  {"content": "Step 6: Check for prompt sources", "status": "pending", "activeForm": "Checking prompt sources"},
  {"content": "Step 7: Build manager parameters", "status": "pending", "activeForm": "Building manager parameters"},
  {"content": "Step 8: Route to faber-manager execution", "status": "pending", "activeForm": "Routing to faber-manager"},
  {"content": "Step 9: Aggregate and return results", "status": "pending", "activeForm": "Aggregating results"}
]
```

**DO NOT proceed to Step 0a until TodoWrite confirms todos are created.**

This tracker is your execution contract. You MUST:
- Mark each step "in_progress" when starting it
- Mark each step "completed" when finishing it
- NEVER skip steps (mark N/A steps as completed with note)
- NEVER return until Step 9 is marked completed
</MANDATORY_FIRST_ACTION>
```

#### 2. Add Step Transition Markers (within each workflow step)

After each step's content, add explicit transition:

```markdown
**Step Transition**:
1. Use TodoWrite to mark "Step X" as "completed"
2. Use TodoWrite to mark "Step X+1" as "in_progress"
3. Proceed to Step X+1 below
```

Example for Step 0b:

```markdown
## Step 0b: Resolve workflow with inheritance (MANDATORY)

[... existing content ...]

**Step 0b Transition**:
1. Store resolved_workflow result
2. Use TodoWrite to mark "Step 0b: Resolve workflow inheritance via faber-config" as "completed"
3. Use TodoWrite to mark "Step 0.5: Handle resume/rerun (if applicable)" as "in_progress"
4. **IMMEDIATELY proceed to Step 0.5 below - DO NOT RETURN HERE**
```

#### 3. Add `<TERMINATION_RULES>` Section (before `<COMPLETION_CRITERIA>`)

```markdown
<TERMINATION_RULES>
**YOU ARE ONLY ALLOWED TO RETURN WHEN:**

1. Step 9 "Aggregate and return results" is marked "completed" in TodoWrite
2. The faber-manager Task tool invocation has returned a result
3. The result has been formatted for user display

**OR when an error occurs** (see ERROR HANDLING below)

**YOU ARE NOT ALLOWED TO RETURN WHEN:**

- Any step from 0a through 8 is still "pending" or "in_progress" (unless error)
- faber-config has returned but faber-manager has not been invoked
- A sub-skill or sub-agent returns an intermediate result

**IF YOU FIND YOURSELF ABOUT TO RETURN EARLY:**

1. STOP
2. Check TodoWrite - which steps are incomplete?
3. Resume from the first incomplete step
4. Continue until Step 9 is complete

**ERROR HANDLING:**

When an error occurs at ANY step:
1. IMMEDIATELY abort further execution
2. Report the error with FULL context:
   - Which step failed
   - What the error was
   - What state was achieved before failure
3. Suggest specific next steps to resolve the error
4. Mark the failed step as "in_progress" (not completed)
5. Return to user with error report

**Do NOT:**
- Silently fail and return nothing
- Continue to next step after error
- Retry without user instruction

**RETURNING WORKFLOW RESOLUTION AS FINAL OUTPUT IS A BUG. THE FIX FOR #304 REQUIRES FABER-MANAGER INVOCATION.**
</TERMINATION_RULES>
```

#### 4. Enhance `<COMPLETION_VERIFICATION>` Section

Update the existing `<COMPLETION_CRITERIA>` section:

```markdown
<COMPLETION_VERIFICATION>
**BEFORE returning ANY response, verify ALL of these:**

TodoWrite Verification (check your todo list):
- [ ] Step 0a: completed
- [ ] Step 0b: completed (faber-config invoked and result stored)
- [ ] Step 0.5: completed (or skipped if not resume/rerun)
- [ ] Step 1: completed (or skipped if no work_id)
- [ ] Step 2: completed
- [ ] Step 3: completed
- [ ] Step 4: completed
- [ ] Step 5: completed
- [ ] Step 6: completed
- [ ] Step 7: completed
- [ ] Step 8: completed (faber-manager Task tool invoked)
- [ ] Step 9: completed (results aggregated)

Execution Verification:
- [ ] faber-config skill was invoked in Step 0b
- [ ] resolved_workflow is populated with merged inheritance
- [ ] faber-manager agent was invoked via Task tool in Step 8
- [ ] faber-manager result is present in this response
- [ ] All manager results present (if multiple work items)

**IF ANY CHECKBOX IS UNCHECKED, YOU ARE NOT DONE.**

Find the first unchecked item and resume from that step.
</COMPLETION_VERIFICATION>
```

## Design Decisions

### Q1: Todo Scope
**Decision**: All 12 steps tracked

All steps will be tracked in TodoWrite for maximum visibility and debugging capability. The overhead is acceptable given the importance of ensuring complete execution.

### Q2: Error Handling Strategy
**Decision**: Abort and report with suggestions

When an error occurs during any step:
1. Immediately abort execution
2. Report the error with full context
3. Suggest next steps to resolve the error
4. Do NOT continue to subsequent steps or silently fail

### Q3: Existing Todo List Handling
**Decision**: Replace entirely

When faber-director starts:
1. Clear any existing todo items completely
2. Initialize fresh faber-director execution tracker
3. This ensures clean state for each workflow run

### Q4: Resume Support
**Decision**: Basic resume within session

- **Default behavior**: Check todo state and resume from first incomplete step (within same session)
- **New command behavior**: A fresh `/faber:run` command always clears todos and starts fresh
- **Cross-session**: Not supported initially (would require custom file-based state management)

Note: Full checkpoint (saving state to `.fractary/plugins/faber/director-state.json`) was considered for cross-session resume but deemed unnecessary since faber-director typically completes in a single session. This could be added later if needed.

## Success Criteria

1. **Full Execution**: `/fractary-faber:run --work-id <id>` completes all 12 steps
2. **No Premature Return**: Workflow resolution alone does NOT end the skill
3. **Manager Invocation**: faber-manager agent is always invoked with resolved workflow
4. **Visible Progress**: User sees TodoWrite status updates as steps progress
5. **Error Handling**: If a step fails, execution aborts immediately with full error context and suggested next steps

## Testing Plan

1. Run `/fractary-faber:run --work-id 309` after implementation
2. Verify TodoWrite shows all 12 steps progressing
3. Verify faber-config is invoked (Step 0b)
4. Verify issue is fetched (Step 1)
5. Verify faber-manager is invoked (Step 8)
6. Verify final result includes manager output (Step 9)

## Related Issues

- **#304**: Workflow inheritance resolution fix (this builds on that fix)
- This issue addresses the execution enforcement that was missing even after #304

## Implementation Checklist

- [x] Add `<MANDATORY_FIRST_ACTION>` section with TodoWrite template
- [x] Add step transition markers after each workflow step (0a, 0b, 0.5, 1-9)
- [x] Add `<TERMINATION_RULES>` section
- [x] Update `<COMPLETION_VERIFICATION>` section with TodoWrite checks
- [ ] Test with `/fractary-faber:run --work-id 309`
- [ ] Verify all 12 steps execute
- [ ] Verify faber-manager is invoked
- [ ] Create PR for review

## Notes

- This pattern (TodoWrite enforcement) could be applied to other complex skills that have execution flow problems
- The explicit step numbering in TodoWrite makes debugging easier
- This approach works WITH the LLM's natural tendencies rather than against them

---

## Changelog

### 2025-12-08 - Refinement Round 1

**Questions Addressed:**

1. **Todo Scope**: All 12 steps tracked (maximum visibility)
2. **Error Handling**: Abort and report with suggestions (no silent failures or continuing after errors)
3. **Existing Todos**: Replace entirely when faber-director starts
4. **Resume Support**: Basic within-session resume; fresh command clears and restarts

**Changes Applied:**
- Added "Design Decisions" section documenting refinement choices
- Updated TERMINATION_RULES with explicit ERROR HANDLING subsection
- Updated Success Criteria #5 to reflect abort-and-report error strategy
- Clarified that cross-session checkpoint could be added later if needed
