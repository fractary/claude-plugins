# Phase Checkpoint Workflow

This workflow is triggered when a spec phase is completed during Build. It ensures progress is persisted through spec updates, commits, issue comments, and session summaries.

## Overview

**When to Trigger**: After all tasks in the current spec phase are complete.

**Purpose**:
1. Persist progress externally (spec file, git, issue)
2. Create session summary for potential cross-session continuity
3. Signal faber-manager that phase is complete

## Checkpoint Actions

### Action 1: Update Spec with Phase Completion

Use the spec-updater skill to mark the phase as complete.

```markdown
Invoke Skill: fractary-spec:spec-updater
Operation: batch-update
Parameters:
{
  "spec_path": "{SPEC_FILE}",
  "phase_id": "{CURRENT_PHASE}",
  "updates": {
    "status": "complete",
    "check_all_tasks": true,
    "notes": ["{implementation_notes}"]
  }
}
```

**What this does:**
- Changes phase status from "🔄 In Progress" to "✅ Complete"
- Checks off all tasks in the phase (`- [ ]` → `- [x]`)
- Adds any implementation notes

**Verify:**
- Spec file was updated
- Phase shows as complete
- Tasks are checked off

### Action 2: Create Final Commit (if needed)

If there are any uncommitted changes, create a final phase commit.

```bash
# Check for uncommitted changes
UNCOMMITTED=$(git status --porcelain)

if [ -n "$UNCOMMITTED" ]; then
    # Stage all changes
    git add -A

    # Create commit message
    COMMIT_MSG="feat(${WORK_ID}): Complete ${PHASE_NAME}"
fi
```

Use repo-manager to create the commit:

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "feat({work_id}): Complete {phase_name}",
    "type": "feat",
    "work_id": "{work_id}",
    "description": "Phase checkpoint - all tasks in {phase_name} completed"
  }
}
```

**Skip if**: No uncommitted changes exist.

### Action 3: Post Progress Comment to Issue

Post a progress update to the issue using the comment template.

```markdown
Invoke Skill: fractary-work:comment-creator
Operation: create-comment
Parameters:
{
  "issue_id": "{WORK_ID}",
  "message": "{formatted_progress_comment}"
}
```

**Progress comment should include:**
- Phase completed (name and number)
- Files changed since last checkpoint
- Tasks completed (count)
- Overall progress (phases done / total phases, percentage)
- Next phase description (if any)

Use `templates/progress-comment.md.template` to format the comment.

### Action 4: Generate Session Summary

Create a session summary for potential cross-session continuity.

```json
{
  "session_id": "session-{timestamp}",
  "phase_completed": "{CURRENT_PHASE}",
  "timestamp": "{ISO_TIMESTAMP}",
  "summary": {
    "accomplished": [
      "{accomplishment_1}",
      "{accomplishment_2}"
    ],
    "decisions": [
      "{decision_1}",
      "{decision_2}"
    ],
    "files_changed": [
      "{file_1}",
      "{file_2}"
    ],
    "commits": ["{commit_sha_1}", "{commit_sha_2}"],
    "remaining_phases": ["{next_phase}", "..."],
    "context_notes": "{any_important_context_for_next_session}"
  }
}
```

**Generating the summary:**

1. **accomplished**: List main things completed in this phase
   - Review the tasks that were checked off
   - Summarize key files created/modified

2. **decisions**: List technical decisions made
   - Any non-obvious choices
   - Trade-offs considered
   - Patterns adopted

3. **files_changed**: List from git diff or tracking
   - All files created/modified in this phase

4. **commits**: List commit SHAs from this phase

5. **remaining_phases**: Parse from spec
   - All phases not yet complete

6. **context_notes**: Any critical context
   - Blockers encountered
   - Dependencies identified
   - Things the next session should know

**Store summary:**

The session summary is included in the build results returned to faber-manager. It will be saved to:
`.fractary/plugins/faber/runs/{run_id}/session-summaries/session-{timestamp}.json`

### Action 5: Return Checkpoint Results

Return checkpoint results to the build workflow:

```json
{
  "checkpoint_complete": true,
  "actions": {
    "spec_updated": true,
    "commit_created": true,
    "comment_posted": true,
    "comment_url": "https://github.com/org/repo/issues/123#comment-456",
    "session_summary_created": true
  },
  "phase_status": "complete",
  "next_phase": "{next_phase_id}",
  "recommend_session_end": true
}
```

## Error Handling

| Error | Severity | Action |
|-------|----------|--------|
| Spec update failed | WARNING | Log warning, continue with other actions |
| Commit failed | WARNING | Log warning, continue (changes may be uncommitted) |
| Comment post failed | WARNING | Log warning, continue (non-critical) |
| Summary generation failed | WARNING | Log warning, continue |

**Checkpoint should NOT fail the build** - these are persistence actions. If they fail, log warnings but allow build to complete.

## Example Execution

```
═══════════════════════════════════════════════════════════
  PHASE CHECKPOINT
═══════════════════════════════════════════════════════════
  Phase: phase-1 (Core Infrastructure)
  Work ID: #262
───────────────────────────────────────────────────────────

✓ Action 1: Spec updated
  - Status: ✅ Complete
  - Tasks checked: 4/4

✓ Action 2: Commit created
  - SHA: abc123
  - Message: feat(262): Complete Core Infrastructure

✓ Action 3: Progress comment posted
  - URL: https://github.com/fractary/claude-plugins/issues/262#comment-789

✓ Action 4: Session summary generated
  - Accomplished: 4 items
  - Files changed: 5
  - Remaining phases: 2

═══════════════════════════════════════════════════════════
  CHECKPOINT COMPLETE
  Next phase: phase-2 (Checkpoint Integration)
  Recommend: End session for clean handoff
═══════════════════════════════════════════════════════════
```

## Integration Points

**Called By:**
- Build skill workflow (`workflow/basic.md` Step 6)

**Invokes:**
- `fractary-spec:spec-updater` - Update spec file
- `fractary-repo:repo-manager` - Create commit
- `fractary-work:comment-creator` - Post issue comment

**Returns To:**
- Build skill, which includes checkpoint results in its response to faber-manager

## Notes

- Checkpoint is designed to be resilient - failures don't break the build
- Session summary enables cross-session context loading via context-reconstitution.md
- Progress comment provides human-visible audit trail
- All four actions should complete in under 30 seconds total
