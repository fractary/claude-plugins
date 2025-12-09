# WORK-00322: Ensure Approval on Phase Entry If Needed

| Field | Value |
|-------|-------|
| **Spec ID** | WORK-00322 |
| **Title** | Ensure Approval on Phase Entry If Needed |
| **Type** | Bug Fix |
| **Status** | Draft |
| **Created** | 2025-12-09 |
| **Author** | Claude (Opus 4.5) |
| **Priority** | High |
| **Issue** | [#322](https://github.com/fractary/claude-plugins/issues/322) |
| **Refined** | 2025-12-09 (Round 1) |

---

## 1. Executive Summary

This specification defines the fix for a critical security vulnerability in the FABER workflow system where approval gates can be bypassed during workflow resume scenarios. The issue was discovered when PR #318 was merged without explicit user approval due to the approval check occurring at phase transition rather than phase entry.

### 1.1 Problem Statement

The FABER workflow approval gate in `faber-manager.md` section 4.3 (Post-Phase Actions) checks for approval **before transitioning to the next phase**, not **at the entry of each phase**. This creates a security gap:

1. When a workflow is resumed, execution starts directly in the target phase
2. The pre-transition approval check is skipped because we're not transitioning
3. The `decision_point` event is emitted but `AskUserQuestion` is not invoked as a blocking call
4. Destructive operations (PR merge, branch delete, issue close) proceed without approval

### 1.2 Evidence

From the incident investigation (Work #271, Run ID: 4d528079):

| Event | Type | Description |
|-------|------|-------------|
| 003 | `decision_point` | "Release phase requires approval in guarded mode" |
| **MISSING** | `approval_granted` | **Should exist but does not** |
| 004 | `step_start` | "Merging PR #318" |

The workflow logged that approval was required but proceeded to merge anyway.

### 1.3 Impact

| Aspect | Assessment |
|--------|------------|
| **Severity** | High |
| **Affected** | All FABER workflows using guarded or assist autonomy |
| **Risk** | PRs merged without review, issues closed prematurely, branches deleted |

---

## 2. Scope

### 2.1 In Scope

- Fix approval gate to check at phase ENTRY, not just transition
- Add validation guards before destructive operations
- Add CRITICAL_RULE for destructive operation handling
- Add state validation for resume scenarios on completed workflows
- Update event emission to require blocking approval calls

### 2.2 Out of Scope

- Changes to autonomy levels themselves
- Changes to workflow configuration schema
- Adding new approval gates beyond existing `require_approval_for` config
- Retroactive fixes to already-merged PRs

### 2.3 Dependencies

| Dependency | Type | Description |
|------------|------|-------------|
| `plugins/faber/agents/faber-manager.md` | Primary | Main file to modify |
| `plugins/faber/skills/run-manager/scripts/emit-event.sh` | Integration | Event emission |
| AskUserQuestion tool | Runtime | Blocking approval prompts |

---

## 3. Technical Design

### 3.1 Fix 1: Approval Gate on Phase Entry (Primary Fix)

**Location**: `plugins/faber/agents/faber-manager.md`, Section 4.1 (Pre-Phase Actions)

**Current Behavior**: Approval is checked in Section 4.3 (Post-Phase Actions) before transitioning to the NEXT phase.

**New Behavior**: Approval is checked at the START of the CURRENT phase, regardless of whether this is a new run or resume.

**Implementation**:

Add to Section 4.1, immediately after "Pre-Phase Actions" header and before any other actions:

```markdown
**Approval Gate Check (MANDATORY - Before ANY Phase Work):**

CRITICAL: This check happens at the START of each phase, regardless of
whether this is a new run or a resume. This ensures approval gates cannot
be bypassed via resume scenarios.

IF autonomy.require_approval_for contains {current_phase} THEN
  # Check if approval was already granted in THIS run for THIS phase
  approval_event = find_event_in_run(
    run_id=run_id,
    type="approval_granted",
    phase=current_phase
  )

  IF approval_event is null THEN
    # No approval recorded - MUST prompt user
    # Emit decision_point event for audit trail
    Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
      --run-id "{run_id}" \
      --type "decision_point" \
      --phase "{current_phase}" \
      --message "Phase {current_phase} requires approval - awaiting user confirmation"

    # MANDATORY: Use AskUserQuestion and WAIT for response
    # DO NOT proceed until user explicitly approves
    USE AskUserQuestion:
      question: "The {current_phase} phase requires approval in {autonomy} mode. Continue?"
      header: "Approval Required"
      options:
        - label: "Approve and continue"
          description: "Grant approval and proceed with the {current_phase} phase"
        - label: "Pause workflow"
          description: "Pause here and resume later with: /fractary-faber:run --resume {run_id}"
        - label: "Abort workflow"
          description: "Stop the workflow entirely"
      multiSelect: false

    # Handle user response - ONLY proceed on explicit approval
    SWITCH user_selection:
      CASE "Approve and continue":
        # Record approval for audit trail
        Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
          --run-id "{run_id}" \
          --type "approval_granted" \
          --phase "{current_phase}" \
          --message "User approved proceeding with {current_phase} phase"
        # Continue to phase execution

      CASE "Pause workflow":
        # Update state to paused
        Invoke Skill: faber-state
        Operation: update-workflow
        Parameters: run_id={run_id}, status="paused", paused_at="{current_phase}"

        # Output pause message with resume command
        OUTPUT:
          ⏸️ PAUSED: FABER Workflow
          Run ID: {run_id}
          Paused at: {current_phase} phase (awaiting approval)
          Resume: /fractary-faber:run --work-id {work_id} --resume {run_id}

        STOP workflow (paused state)

      CASE "Abort workflow":
        # Update state to aborted
        Invoke Skill: faber-state
        Operation: mark-complete
        Parameters: run_id={run_id}, final_status="aborted", reason="User rejected approval for {current_phase}"

        ABORT workflow
```

**Key Changes**:
1. Approval check moved from Section 4.3 to Section 4.1
2. Check happens at phase ENTRY, not before NEXT phase transition
3. Check uses `find_event_in_run()` to verify approval exists in THIS run
4. AskUserQuestion is MANDATORY and BLOCKING when approval needed

### 3.2 Fix 2: Add CRITICAL_RULE 14 - Destructive Operation Approval

**Location**: CRITICAL_RULES section in `plugins/faber/agents/faber-manager.md`

**Add new rule after rule 13**:

```markdown
14. **Destructive Operation Approval**
    - PR merge, branch delete, and issue close are DESTRUCTIVE operations
    - These operations ALWAYS require explicit user approval via AskUserQuestion
    - The `decision_point` event is NOT sufficient - you MUST block and wait for user response
    - NEVER emit a `decision_point` event without immediately invoking `AskUserQuestion`
    - An `approval_granted` event MUST exist before any destructive operation executes
    - Even in autonomous mode, destructive operations require approval unless explicitly configured with `allow_destructive_auto: true` (see Section 3.6 for config schema)
    - If approval is missing, ABORT the workflow - do not proceed
```

### 3.6 Config Schema Addition: `allow_destructive_auto`

**Location**: `plugins/faber/config/workflow.schema.json` (autonomy definition)

Add new optional property to the autonomy configuration:

```json
{
  "autonomy": {
    "type": "object",
    "properties": {
      "level": {
        "type": "string",
        "enum": ["dry-run", "assist", "guarded", "autonomous"]
      },
      "require_approval_for": {
        "type": "array",
        "items": { "type": "string" }
      },
      "allow_destructive_auto": {
        "type": "boolean",
        "default": false,
        "description": "When true AND autonomy level is 'autonomous', allows destructive operations (PR merge, branch delete, issue close) without explicit approval. USE WITH EXTREME CAUTION. Default: false (always require approval for destructive ops)."
      }
    }
  }
}
```

**Usage in workflow config**:
```json
{
  "autonomy": {
    "level": "autonomous",
    "allow_destructive_auto": true
  }
}
```

**Enforcement logic** (in faber-manager Section 4.1):
```
IF autonomy.level == "autonomous" AND autonomy.allow_destructive_auto == true THEN
  # Skip approval prompt for destructive operations
  # Still emit decision_point event for audit trail
  LOG "⚠️ Destructive auto-approval enabled - proceeding without user confirmation"
ELSE
  # Normal approval flow - prompt user
```

**WARNING**: This option is dangerous and should only be used in fully automated CI/CD pipelines where human oversight exists at a different layer (e.g., required PR reviews, branch protection).

### 3.3 Fix 3: Validation Guard Before Destructive Operations (Guard 6)

**Location**: EXECUTION_GUARDS section in `plugins/faber/agents/faber-manager.md`

**Add new guard after Guard 5**:

```markdown
### Guard 6: Destructive Operation Approval Verification

**When**: Before executing any destructive operation (PR merge, branch delete, issue close)
**What to verify**:
- An `approval_granted` event exists for this phase in this run
- The **MOST RECENT** `approval_granted` was recorded AFTER the **MOST RECENT** `decision_point` for this phase
- This handles retry scenarios where a phase may be re-entered multiple times

**Implementation**:

```
# Agent Logic (execute before merge/delete/close operations):

1. Identify the current phase requiring approval (typically "release")

2. Search for approval event in current run:
   Bash: ls .fractary/plugins/faber/runs/{run_id}/events/*-approval_granted* 2>/dev/null

3. If no approval event found:
   ❌ ERROR: Cannot execute destructive operation without approval

   No approval_granted event found for phase '{phase}'.
   This is a safety violation - destructive operations require explicit approval.

   Expected: approval_granted event with phase="{phase}"
   Found: None

   This may indicate:
   - Approval gate was bypassed (BUG - should not happen)
   - Workflow was resumed without re-approval
   - Event files were deleted or corrupted

   Resolution:
   - Do NOT proceed with destructive operation
   - Report this as a workflow failure
   - User must restart workflow to grant approval properly

   [ABORT WORKFLOW - FATAL ERROR]

4. If approval event found, verify it's for this phase:
   Bash: jq -r '.phase' .fractary/plugins/faber/runs/{run_id}/events/*-approval_granted*.json

   IF approval_phase != current_phase THEN
     ❌ ERROR: Approval is for wrong phase
     [ABORT WORKFLOW]

5. Find the MOST RECENT approval_granted and decision_point for this phase:
   # Get most recent approval timestamp for this phase
   most_recent_approval = ls -t .fractary/plugins/faber/runs/{run_id}/events/*-approval_granted*.json | head -1
   approval_ts = jq -r '.timestamp' {most_recent_approval}
   approval_phase = jq -r '.phase' {most_recent_approval}

   # Get most recent decision_point timestamp for this phase
   most_recent_decision = ls -t .fractary/plugins/faber/runs/{run_id}/events/*-decision_point*.json | head -1
   decision_ts = jq -r '.timestamp' {most_recent_decision}
   decision_phase = jq -r '.phase' {most_recent_decision}

   # Verify approval is for the correct phase
   IF approval_phase != current_phase THEN
     ❌ ERROR: Most recent approval is for wrong phase ({approval_phase} != {current_phase})
     [ABORT WORKFLOW]

   # Verify most recent approval is AFTER most recent decision_point
   IF approval_ts < decision_ts THEN
     ❌ ERROR: Stale approval - most recent approval predates most recent decision point

     Most recent approval:       {approval_ts}
     Most recent decision_point: {decision_ts}

     This can happen in retry scenarios where a new decision_point was emitted
     but user has not yet re-approved. User must re-approve the operation.

     [ABORT WORKFLOW]

6. All checks passed - proceed with destructive operation
   LOG "✓ Approval verified for {phase} phase (most recent check) - proceeding with {operation}"
```

**Enforcement mechanism**: This guard is executed by the agent as inline logic before any merge/delete/close operation. It is NOT a separate script but agent-level validation that uses Bash tool for file checks.
```

### 3.7 Fix 4: State Validation on Resume of Completed Workflow

**Location**: `plugins/faber/agents/faber-manager.md`, Section Step 2 (Load State)

**Add validation after loading state for resume scenarios**:

```markdown
**For resume scenario (is_resume=true):**

# Load existing state for the run (using existing read-state operation)
Invoke Skill: faber-state
Operation: read-state
Parameters: run_id={run_id}

# VALIDATION: Check if workflow already completed
IF state.status == "completed" OR state.workflow_status == "completed" THEN
  # Workflow already finished - require explicit confirmation to re-run
  USE AskUserQuestion:
    question: "This workflow already completed successfully. Re-executing will run phases again and may cause duplicate PRs, commits, or other side effects. Are you sure you want to re-run?"
    header: "Already Complete"
    options:
      - label: "Yes, re-run anyway"
        description: "Execute workflow again (may create duplicates)"
      - label: "No, abort"
        description: "Do not re-execute completed workflow"
    multiSelect: false

  IF user_selection != "Yes, re-run anyway" THEN
    OUTPUT:
      ℹ️ Workflow already completed
      Run ID: {run_id}
      Status: Completed at {state.completed_at}

      No action taken. Workflow state preserved.

    STOP workflow (no action)

  # User confirmed re-run - emit event for audit trail
  Bash: plugins/faber/skills/run-manager/scripts/emit-event.sh \
    --run-id "{run_id}" \
    --type "workflow_rerun_confirmed" \
    --message "User confirmed re-execution of completed workflow"

  # Reset phase statuses using existing update-phase operation for each phase
  # This uses ONLY existing faber-state operations - no new operations needed
  FOR each phase IN [frame, architect, build, evaluate, release]:
    Invoke Skill: faber-state
    Operation: update-phase
    Parameters: run_id={run_id}, phase={phase}, status="pending"

  # Update workflow status to in_progress using existing operation
  Invoke Skill: faber-state
  Operation: update-workflow
  Parameters: run_id={run_id}, status="in_progress"
```

**Note**: This implementation uses ONLY existing faber-state operations:
- `read-state` - to check current state
- `update-phase` - to reset each phase to pending
- `update-workflow` - to set workflow back to in_progress

No new faber-state operations are required.

### 3.5 Fix 5: Remove Redundant Approval Check from Section 4.3

**Location**: `plugins/faber/agents/faber-manager.md`, Section 4.3 (Post-Phase Actions)

Since approval is now checked at phase entry (Section 4.1), the approval check in Section 4.3 should be removed or modified to avoid double-prompting:

**Current code to REMOVE or MODIFY**:

The existing approval check block in Section 4.3 that starts with:
```markdown
**Check autonomy gates (BEFORE entering next phase):**
```

**Action**:
- Option A: Remove entirely (approval now handled at entry)
- Option B: Keep as "informational" only - log that next phase will require approval but DO NOT prompt here

**Recommended**: Option B - Keep for visibility but remove the AskUserQuestion call:

```markdown
**Autonomy Gate Notification (informational only):**

# Determine the next phase in sequence
next_phase = get_next_phase(phase)

IF next_phase is not null AND autonomy.require_approval_for contains next_phase THEN
  # Log that next phase will require approval (but don't prompt here)
  LOG "ℹ️ Next phase ({next_phase}) requires approval - will prompt at phase entry"
  # The actual approval prompt happens in Section 4.1 when next_phase starts
```

---

## 4. Implementation Plan

### Phase 1: Core Fix (Section 4.1 Approval Gate)

**Files Modified**:
- `plugins/faber/agents/faber-manager.md`

**Changes**:
1. Add approval gate check to Section 4.1 (Pre-Phase Actions)
2. Ensure AskUserQuestion is blocking and mandatory
3. Verify approval event is recorded before proceeding

**Testing**:
- Resume workflow at release phase - should prompt for approval
- New workflow to release phase - should prompt at entry
- Verify approval_granted event exists after approval

### Phase 2: Critical Rule Addition

**Files Modified**:
- `plugins/faber/agents/faber-manager.md`

**Changes**:
1. Add CRITICAL_RULE 14 for destructive operations

**Testing**:
- Verify rule is visible in agent context
- Test that violations are caught by other guards

### Phase 3: Guard 6 Implementation

**Files Modified**:
- `plugins/faber/agents/faber-manager.md`

**Changes**:
1. Add Guard 6 to EXECUTION_GUARDS section
2. Implement approval verification logic

**Testing**:
- Attempt merge without approval_granted event - should fail
- Attempt merge with stale approval - should fail
- Normal merge with valid approval - should succeed

### Phase 4: Resume State Validation

**Files Modified**:
- `plugins/faber/agents/faber-manager.md`

**Changes**:
1. Add completed workflow check to Step 2
2. Add reset-for-rerun operation to faber-state skill

**Testing**:
- Resume completed workflow - should prompt for confirmation
- Decline re-run - should abort gracefully
- Confirm re-run - should reset and execute

### Phase 5: Section 4.3 Cleanup

**Files Modified**:
- `plugins/faber/agents/faber-manager.md`

**Changes**:
1. Remove or modify redundant approval check in Section 4.3
2. Keep informational logging about next phase requirements

**Testing**:
- Full workflow execution - should only prompt once per phase
- No double-prompting for same approval

---

## 5. Acceptance Criteria

| # | Criterion | Verification Method |
|---|-----------|---------------------|
| 1 | Approval gate is checked at phase ENTRY, not just phase transition | Code review + manual test |
| 2 | Resume scenarios cannot bypass approval gates | Manual test: resume at release phase |
| 3 | `decision_point` events are always followed by blocking `AskUserQuestion` calls | Code review + event log inspection |
| 4 | `approval_granted` event must exist before destructive operations | Guard 6 enforcement + event log |
| 5 | Completed workflows require confirmation to re-execute | Manual test: resume completed workflow |
| 6 | Tests verify approval gate cannot be bypassed via resume | Integration test |
| 7 | No double-prompting for the same approval in a single phase | Manual test |

---

## 6. Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Breaking existing workflows | Low | Medium | Approval logic is additive, not replacing |
| Double-prompting users | Medium | Low | Remove redundant check from Section 4.3 |
| Performance impact from event checks | Low | Low | File checks are fast, run once per phase |
| Incomplete fix (edge cases) | Medium | High | Comprehensive testing with resume scenarios |

---

## 7. Related Documentation

- **Issue**: [#322](https://github.com/fractary/claude-plugins/issues/322)
- **Incident**: Work #271, PR #318 merged without approval
- **Affected Run**: 4d528079-51c7-40a2-becd-958d86a9a7c9
- **Agent File**: `plugins/faber/agents/faber-manager.md`

---

## 8. Appendix: Event Log Evidence

### Second Run Events (4d528079) - Showing the Bug

```
001-workflow_resumed.json     - "Workflow resumed for release phase"
002-phase_start.json          - "Starting release phase"
003-decision_point.json       - "Release phase requires approval in guarded mode"
                              ** NO approval_granted event **
004-step_start.json           - "Merging PR #318"
005-step_complete.json        - "Merge complete"
006-phase_complete.json       - "Release phase complete"
007-workflow_complete.json    - "Workflow complete"
```

### Expected Event Sequence (After Fix)

```
001-workflow_resumed.json     - "Workflow resumed for release phase"
002-phase_start.json          - "Starting release phase"
003-decision_point.json       - "Release phase requires approval"
004-approval_granted.json     - "User approved proceeding with release phase"  ** NEW **
005-step_start.json           - "Merging PR"
006-step_complete.json        - "Merge complete"
007-phase_complete.json       - "Release phase complete"
008-workflow_complete.json    - "Workflow complete"
```

---

## 9. Changelog

### 2025-12-09 - Round 1 Refinement

**Questions Addressed**:

1. **faber-state operations**: User confirmed to use ONLY existing operations. Section 3.7 (Fix 4) rewritten to use `read-state`, `update-phase` loop, and `update-workflow` rather than proposing a new `reset-for-rerun` operation.

2. **allow_destructive_auto config**: User requested a formal config schema. Section 3.6 added defining the `allow_destructive_auto` boolean property with JSON schema, usage example, and enforcement logic. Critical Rule 14 updated to reference this config option.

3. **Multiple approvals in retry scenarios**: User selected "check most recent approval". Guard 6 (Section 3.3) updated to find the MOST RECENT `approval_granted` and `decision_point` events using `ls -t | head -1`, then verify `approval_ts > decision_ts` to ensure approval is fresh for the current decision point.

**Changes Made**:
- Added `Refined: 2025-12-09 (Round 1)` to frontmatter
- Added Section 3.6: Config Schema for `allow_destructive_auto`
- Updated Section 3.2 (Critical Rule 14) to reference Section 3.6 for config
- Rewrote Guard 6 (Section 3.3) with most-recent timestamp comparison logic
- Rewrote Section 3.7 (Fix 4) to use existing faber-state operations only
- Updated Phase 4 in Implementation Plan to reflect no new faber-state operations needed
