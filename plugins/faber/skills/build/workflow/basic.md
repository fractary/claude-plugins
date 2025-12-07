# Build Phase: Basic Workflow

This workflow implements the Build phase with **autonomous execution** and **phase-based implementation**. The key innovation is the "plan first, then execute completely" approach.

## Prerequisites

- Spec file exists (from Architect phase)
- Spec contains phase-structured implementation plan
- Current phase identified

## Workflow Steps

### Step 0: Create Implementation Plan (CRITICAL)

**This step is MANDATORY before any code changes.**

Before writing ANY code, engage extended thinking to create a comprehensive implementation plan:

```
<extended_thinking>
I am implementing phase {current_phase} of the specification.

Let me analyze this phase thoroughly:

1. PHASE OVERVIEW
   - Phase name: {phase_name}
   - Phase objective: {objective}
   - Tasks in this phase: {tasks}

2. FILE ANALYSIS
   For each task, what files need to be:
   - Created: [list new files]
   - Modified: [list existing files to change]
   - Deleted: [list files to remove]

3. IMPLEMENTATION ORDER
   The logical order to implement these tasks:
   1. First: {task} because {reason}
   2. Then: {task} because {depends on previous}
   3. ...

4. POTENTIAL CHALLENGES
   - Challenge 1: {description} → Solution: {approach}
   - Challenge 2: {description} → Solution: {approach}

5. COMMIT STRATEGY
   I will create commits at these boundaries:
   - After {task group 1}: commit message "{type}: {description}"
   - After {task group 2}: commit message "{type}: {description}"

6. TESTING APPROACH
   How I will verify each task works:
   - Task 1: {verification method}
   - Task 2: {verification method}

My complete plan is documented above. Now I will execute it WITHOUT stopping.
</extended_thinking>
```

**Output the plan visibly** so it's part of the session record.

### Step 1: Post Build Start Notification

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "🔨 **Build Phase Started**

**Work ID**: \`${WORK_ID}\`
**Type**: ${WORK_TYPE}
**Spec Phase**: ${CURRENT_PHASE}
$([ "$RETRY_COUNT" -gt 0 ] && echo "**Retry**: Attempt $((RETRY_COUNT + 1))")

Implementing phase from specification..." '[]'
```

### Step 2: Load and Analyze Specification

```bash
# Read spec file
SPEC_FILE=$(echo "$ARCHITECT_CONTEXT" | jq -r '.spec_file')
SPEC_CONTENT=$(cat "$SPEC_FILE")

# Identify current phase
CURRENT_PHASE=$(echo "$CONTEXT" | jq -r '.current_phase // "phase-1"')

# Extract phase details from spec
# Look for section: ### Phase N: {name}
# Extract: Status, Objective, Tasks

# If session_summary present (resuming), review it
SESSION_SUMMARY=$(echo "$CONTEXT" | jq -r '.session_summary // null')
if [ "$SESSION_SUMMARY" != "null" ]; then
    echo "📋 Resuming from previous session:"
    echo "  - Phase completed: $(echo "$SESSION_SUMMARY" | jq -r '.phase_completed')"
    echo "  - Accomplishments: $(echo "$SESSION_SUMMARY" | jq -r '.accomplished | length') items"
fi

# If retry, consider previous failures
if [ "$RETRY_COUNT" -gt 0 ]; then
    echo "🔄 Retry Context: $RETRY_CONTEXT"
    echo "Previous attempt failed - addressing issues..."
fi
```

### Step 2.5: Validate and Sanitize Inputs

**Before using any workflow parameters, validate and sanitize them:**

```bash
# Input validation helper function
sanitize_input() {
    local input="$1"
    local max_length="${2:-200}"
    # Remove control characters, limit length, escape special chars
    echo "$input" | tr -d '\n\r\0' | cut -c1-"$max_length" | sed 's/[`$"\\]/\\&/g'
}

validate_phase_name() {
    local phase="$1"
    # Phase names should match pattern: phase-N or "Phase N: Name"
    if [[ ! "$phase" =~ ^(phase-[0-9]+|Phase\ [0-9]+:.*)$ ]]; then
        echo "WARNING: Unexpected phase format: $phase"
    fi
}

# Validate required inputs
if [ -z "$SPEC_FILE" ] || [ ! -f "$SPEC_FILE" ]; then
    echo "ERROR: Spec file not found: $SPEC_FILE"
    exit 1
fi

if [ -z "$CURRENT_PHASE" ]; then
    echo "ERROR: Current phase not specified"
    exit 1
fi

# Sanitize all user-derived inputs
SAFE_PHASE_NAME=$(sanitize_input "$PHASE_NAME" 100)
SAFE_TASK_DESCRIPTION=$(sanitize_input "$TASK_DESCRIPTION" 200)
SAFE_WORK_ITEM_TITLE=$(sanitize_input "$WORK_ITEM_TITLE" 100)

# Validate phase name format
validate_phase_name "$CURRENT_PHASE"

# Log sanitized inputs for debugging
echo "📋 Validated inputs:"
echo "  - Phase: $SAFE_PHASE_NAME"
echo "  - Work ID: $WORK_ID"
echo "  - Spec: $SPEC_FILE"
```

**Security Notes:**
- All user-derived inputs are sanitized before use in commands or commits
- Phase names are validated against expected patterns
- Input lengths are limited to prevent buffer issues
- Special characters are escaped to prevent injection

### Step 3: Execute Implementation Plan

**CRITICAL: Execute the plan created in Step 0 WITHOUT stopping.**

For each task in the current phase:

1. **Implement the task**
   - Create/modify files as planned
   - Follow coding standards and best practices
   - Add appropriate error handling
   - Include inline documentation

2. **Update task in spec** (as you complete each task)
   - Change `- [ ]` to `- [x]` for completed tasks
   - This provides visible progress tracking

3. **Commit at logical boundaries**
   - Don't wait until the end - commit after completing logical units
   - Use semantic commit messages: `{type}({scope}): {description}`

**Implementation Guidance:**
- Follow the order defined in your plan
- If you hit a blocker, work around it or document it - don't stop
- If uncertain about an approach, make a decision and document it
- Trust your plan - you already thought through the challenges

### Step 4: Create Commits at Boundaries

Use repo-manager to commit implementation at logical boundaries:

```bash
# Sanitize work item title for commit message (prevent injection)
SAFE_TITLE=$(echo "$WORK_ITEM_TITLE" | tr -d '\n\r' | cut -c1-100 | sed 's/[`$"\\]/\\&/g')
COMMIT_MESSAGE="${WORK_TYPE}(${WORK_ID}): ${TASK_DESCRIPTION}"
```

**Security Note**: Sanitize user inputs before using in commit messages.

```markdown
Use the @agent-fractary-repo:repo-manager agent with the following request:
{
  "operation": "create-commit",
  "parameters": {
    "message": "{COMMIT_MESSAGE}",
    "type": "{work_type_prefix}",
    "work_id": "{work_id}",
    "files": ["{changed_files}"]
  }
}
```

### Step 5: Capture Build Logs (Optional)

**If configured**, capture build and compilation logs:

```bash
CAPTURE_BUILD_LOGS=$(echo "$CONFIG_JSON" | jq -r '.workflow.build.capture_build_logs // true')
```

If build commands were run:

```markdown
Use the @agent-fractary-logs:log-manager agent with the following request:
{
  "operation": "capture-build",
  "parameters": {
    "issue_number": "{source_id}",
    "log_content": "{build_output}",
    "log_level": "info",
    "build_type": "compilation"
  }
}
```

### Step 6: Trigger Phase Checkpoint

When ALL tasks in the current phase are complete, trigger the checkpoint workflow.

See `workflow/phase-checkpoint.md` for detailed checkpoint steps.

**Checkpoint Actions:**
1. Update spec with phase status = ✅ Complete
2. Create final commit if any uncommitted changes
3. Post progress comment to issue
4. Generate session summary

### Step 7: Update Workflow State

```bash
BUILD_DATA=$(cat <<EOF
{
  "commits": $(echo "$COMMITS" | jq -s .),
  "files_changed": $(echo "$CHANGED_FILES" | jq -R . | jq -s .),
  "retry_count": $RETRY_COUNT,
  "spec_phase": "$CURRENT_PHASE",
  "tasks_completed": $TASKS_COMPLETED,
  "next_phase": "$NEXT_PHASE"
}
EOF
)

"$CORE_SKILL/state-update-phase.sh" "build" "completed" "$BUILD_DATA"
```

### Step 8: Post Build Complete

```bash
"$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "build" "✅ **Build Phase Complete**

**Spec Phase**: ${CURRENT_PHASE} ✅
**Tasks Completed**: ${TASKS_COMPLETED}
**Commits**: ${#COMMITS[@]}
**Files Changed**: ${#CHANGED_FILES[@]}

$([ -n "$NEXT_PHASE" ] && echo "**Next Phase**: ${NEXT_PHASE}" || echo "**Status**: All phases complete")

Implementation complete. Ready for next step..." '[]'
```

### Step 9: Return Results

```bash
cat <<EOF
{
  "status": "success",
  "phase": "build",
  "spec_phase": "$CURRENT_PHASE",
  "commits": $(echo "$COMMITS" | jq -s .),
  "files_changed": $(echo "$CHANGED_FILES" | jq -R . | jq -s .),
  "tasks_completed": $TASKS_COMPLETED,
  "retry_count": $RETRY_COUNT,
  "next_phase": "$NEXT_PHASE",
  "recommend_session_end": $([ -n "$NEXT_PHASE" ] && echo "true" || echo "false"),
  "session_summary": {
    "phase_completed": "$CURRENT_PHASE",
    "accomplished": $(echo "$ACCOMPLISHMENTS" | jq -R . | jq -s .),
    "decisions": $(echo "$DECISIONS" | jq -R . | jq -s .),
    "files_changed": $(echo "$CHANGED_FILES" | jq -R . | jq -s .),
    "remaining_phases": $(echo "$REMAINING_PHASES" | jq -R . | jq -s .)
  }
}
EOF
```

## Success Criteria

- ✅ Implementation plan created BEFORE any code
- ✅ All tasks in current phase completed
- ✅ Spec updated with task checkmarks
- ✅ Phase status marked as complete
- ✅ Commits created at logical boundaries
- ✅ Progress comment posted to issue
- ✅ Session summary generated
- ✅ Build results returned to faber-manager

## Retry Handling

When invoked as a retry (retry_count > 0):
1. Review retry_context for failure reasons
2. Update your plan to address specific issues
3. Re-implement or fix problematic areas
4. Ensure the approach addresses the root cause

## Anti-Patterns to Avoid

| Don't Do This | Do This Instead |
|---------------|-----------------|
| "Let's pause here and continue later" | Complete the current phase |
| "Should I proceed with the next task?" | Execute your plan autonomously |
| "This is getting complex, let's break it down" | It's already broken into phases |
| "I'll start with X and see how it goes" | Follow your documented plan |
| Stop when context feels low | Trust auto-compaction, keep going |

## Notes

- This workflow supports the **one-phase-per-session** model
- The implementation plan in Step 0 is your contract - follow it
- Commits should happen during execution, not just at the end
- The checkpoint at the end ensures progress is persisted
- faber-manager handles session lifecycle, not this skill
