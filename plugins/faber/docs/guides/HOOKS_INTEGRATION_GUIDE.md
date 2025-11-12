# Hooks Integration Guide for FABER Workflow Manager

This guide demonstrates how to integrate the unified hook system into the FABER workflow manager (`workflow-manager.md`).

## Overview

Hooks are executed at two points for each phase:
- **Pre-phase hooks**: Before skill invocation (context injection, setup scripts)
- **Post-phase hooks**: After skill completes (validation, notifications)

## Integration Pattern

For each phase in the workflow manager, insert hook execution before and after the phase skill:

```
Phase Start
  ↓
Update session (started)
  ↓
Execute PRE-PHASE HOOKS ← NEW
  ├─ Context hooks → Inject into skill context
  ├─ Prompt hooks → Inject into skill context
  ├─ Script hooks → Execute shell scripts
  └─ Skill hooks → Invoke Claude Code skills
  ↓
Build phase context (including injected context) ← MODIFIED
  ↓
Invoke phase skill
  ↓
Execute POST-PHASE HOOKS ← NEW
  ├─ Script hooks → Execute shell scripts
  └─ Skill hooks → Invoke Claude Code skills
  ↓
Load phase results
  ↓
Update session (completed)
  ↓
Phase Complete
```

## Step-by-Step Integration

### 1. Add Hook Configuration Loading

In the **Initialization** section, after loading the main configuration:

```markdown
### 2. Load Configuration

```bash
# ... existing config loading ...

# Load hooks configuration
HOOKS_CONFIG=$(echo "$CONFIG_JSON" | jq -r '.hooks // {}')

# Check if any hooks are configured
HAS_HOOKS=$(echo "$HOOKS_CONFIG" | jq -r 'if . == {} then "false" else "true" end')

if [ "$HAS_HOOKS" = "true" ]; then
    echo "🪝 Hooks configured"
fi
```
```

### 2. Add Hook Executor Helper Function

Add this helper function after initialization:

```markdown
## Hook Execution Helper

Add this function to execute hooks at phase boundaries:

```bash
# Execute hooks for a phase
# Args: $1=phase, $2=hook_type (pre|post), $3=phase_context_json
execute_phase_hooks() {
    local PHASE="$1"
    local HOOK_TYPE="$2"
    local PHASE_CONTEXT="$3"

    # Check if hooks configured for this phase/timing
    local HOOKS_FOR_PHASE=$(echo "$HOOKS_CONFIG" | jq -r ".${PHASE}.${HOOK_TYPE} // []")
    local HOOK_COUNT=$(echo "$HOOKS_FOR_PHASE" | jq 'length')

    if [ "$HOOK_COUNT" -eq 0 ]; then
        # No hooks configured
        return 0
    fi

    echo "🪝 Executing ${HOOK_TYPE}-phase hooks for $PHASE ($HOOK_COUNT hooks)"
    echo ""

    # Build hook executor request
    local HOOK_REQUEST="{
        \"hookType\": \"$HOOK_TYPE\",
        \"phase\": \"$PHASE\",
        \"environment\": \"${FABER_ENVIRONMENT:-dev}\",
        \"workflowContext\": $PHASE_CONTEXT,
        \"hooks\": $HOOKS_FOR_PHASE
    }"

    # Write request to temp file
    local HOOK_REQUEST_FILE=$(mktemp)
    echo "$HOOK_REQUEST" > "$HOOK_REQUEST_FILE"

    # Invoke hook executor skill
    Use the @skill-fractary-faber:hook-executor skill with the following request:
    $(cat "$HOOK_REQUEST_FILE")

    local HOOK_EXIT=$?
    rm -f "$HOOK_REQUEST_FILE"

    if [ $HOOK_EXIT -ne 0 ]; then
        echo ""
        echo "❌ Hook execution failed for $PHASE ($HOOK_TYPE)"
        return 1
    fi

    echo ""
    echo "✅ Hooks complete for $PHASE ($HOOK_TYPE)"
    echo ""

    return 0
}

# Extract context injection from hook executor result
# Args: $1=hook_executor_result_json
extract_context_injection() {
    echo "$1" | jq -r '.contextInjection // ""'
}
```
```

### 3. Modify Each Phase to Include Hooks

For **each phase** (Frame, Architect, Build, Evaluate, Release), modify the execution flow:

#### Before (Original Pattern):

```bash
echo "══════════════════════════════════════"
echo "📋 Phase 1/5: Frame"
echo "══════════════════════════════════════"

# Update session - Frame started
"$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "started"

# Build context for Frame
FRAME_CONTEXT="{
    \"work_id\": \"$WORK_ID\",
    \"source_type\": \"$SOURCE_TYPE\",
    \"source_id\": \"$SOURCE_ID\",
    \"work_domain\": \"$WORK_DOMAIN\",
    \"autonomy\": \"$AUTONOMY\"
}"

# Invoke Frame skill
echo "Invoking Frame skill..."
Use the @skill-$FRAME_SKILL skill with the following request:
{
    "operation": "execute_frame",
    "work_id": "$WORK_ID",
    "context": $FRAME_CONTEXT
}

FRAME_EXIT=$?
if [ $FRAME_EXIT -ne 0 ]; then
    echo "❌ Frame phase failed"
    exit 1
fi

# Update session - Frame completed
"$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "completed"
```

#### After (With Hooks):

```bash
echo "══════════════════════════════════════"
echo "📋 Phase 1/5: Frame"
echo "══════════════════════════════════════"

# Update session - Frame started
"$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "started"

# Build base context for Frame
FRAME_CONTEXT="{
    \"work_id\": \"$WORK_ID\",
    \"source_type\": \"$SOURCE_TYPE\",
    \"source_id\": \"$SOURCE_ID\",
    \"work_domain\": \"$WORK_DOMAIN\",
    \"autonomy\": \"$AUTONOMY\"
}"

# ========== PRE-PHASE HOOKS ==========
execute_phase_hooks "frame" "pre" "$FRAME_CONTEXT"
HOOK_EXIT=$?
if [ $HOOK_EXIT -ne 0 ]; then
    echo "❌ Pre-frame hooks failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "failed" '{"error": "Pre-frame hooks failed"}'
    exit 1
fi

# Get context injection from hooks (if any)
HOOK_RESULT=$("$CORE_SKILL/hook-result-get.sh" "$WORK_ID" "frame" "pre")
CONTEXT_INJECTION=$(extract_context_injection "$HOOK_RESULT")

# Invoke Frame skill (with injected context if present)
echo "Invoking Frame skill..."
if [ -n "$CONTEXT_INJECTION" ]; then
    echo "(With injected context from hooks)"
fi

Use the @skill-$FRAME_SKILL skill with the following request:
{
    "operation": "execute_frame",
    "work_id": "$WORK_ID",
    "context": $FRAME_CONTEXT,
    "injected_context": "$CONTEXT_INJECTION"
}

FRAME_EXIT=$?
if [ $FRAME_EXIT -ne 0 ]; then
    echo "❌ Frame phase failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "failed"
    exit 1
fi

# ========== POST-PHASE HOOKS ==========
execute_phase_hooks "frame" "post" "$FRAME_CONTEXT"
HOOK_EXIT=$?
if [ $HOOK_EXIT -ne 0 ]; then
    echo "❌ Post-frame hooks failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "failed" '{"error": "Post-frame hooks failed"}'
    exit 1
fi

# Update session - Frame completed
"$CORE_SKILL/session-update.sh" "$WORK_ID" "frame" "completed"
```

### 4. Modify Phase Skills to Accept Injected Context

Each phase skill needs to be aware of injected context. Modify skill prompts:

#### Frame Skill (Example)

Add to the `<CONTEXT>` section:

```markdown
<CONTEXT>
You are the Frame phase skill for FABER workflows.

... existing context ...

## Injected Context

If `injected_context` is provided in your request, this contains project-specific
context from configured hooks (e.g., work classification rules, environment setup
guidance, project standards). Apply this context when executing the Frame phase.

**Example injected context**:
```
═══════════════════════════════════════════════════════════
📋 PROJECT CONTEXT: work-classification
Priority: medium

Use the project's established work classification system when
categorizing issues. Refer to the rules below.

## Referenced Documentation

### Work Classification Rules
**Source**: `docs/process/WORK_CLASSIFICATION.md`

[... project-specific classification rules ...]

═══════════════════════════════════════════════════════════
```
</CONTEXT>
```

Add to the `<INPUTS>` section:

```markdown
<INPUTS>
... existing inputs ...

**Optional Fields**:
- `injected_context` (string): Project-specific context injected from hooks
  (contains formatted context blocks from context/prompt hooks)
</INPUTS>
```

Add to the `<WORKFLOW>` section at the beginning:

```markdown
<WORKFLOW>

## Step 0: Process Injected Context (if present)

If `injected_context` is provided:
1. Read the injected context carefully
2. Apply any project-specific guidance, standards, or constraints
3. Incorporate this context into your decision-making throughout the phase

The injected context may include:
- Project-specific classification rules
- Environment setup requirements
- Standards and patterns to follow
- Critical reminders or warnings

Treat injected context as **authoritative project requirements** that override
general defaults.

## Step 1: ... (continue with existing workflow)
```

## Complete Example: Architect Phase with Hooks

Here's a complete example showing the Architect phase with full hook integration:

```bash
echo "══════════════════════════════════════"
echo "📐 Phase 2/5: Architect"
echo "══════════════════════════════════════"

# Update session - Architect started
"$CORE_SKILL/session-update.sh" "$WORK_ID" "architect" "started"

# Load Frame results if resuming
if [ "$START_FROM_PHASE" != "frame" ] && [ -z "$WORK_TYPE" ]; then
    SESSION_JSON=$("$CORE_SKILL/session-status.sh" "$WORK_ID")
    WORK_TYPE=$(echo "$SESSION_JSON" | jq -r '.stages.frame.data.work_type // "feature"')
    WORK_ITEM_TITLE=$(echo "$SESSION_JSON" | jq -r '.stages.frame.data.title // ""')
    WORK_ITEM_DESCRIPTION=$(echo "$SESSION_JSON" | jq -r '.stages.frame.data.description // ""')
    BRANCH_NAME=$(echo "$SESSION_JSON" | jq -r '.stages.frame.data.branch_name // ""')
fi

# Build context for Architect (includes Frame results)
ARCHITECT_CONTEXT="{
    \"work_id\": \"$WORK_ID\",
    \"source_type\": \"$SOURCE_TYPE\",
    \"source_id\": \"$SOURCE_ID\",
    \"work_domain\": \"$WORK_DOMAIN\",
    \"work_type\": \"$WORK_TYPE\",
    \"autonomy\": \"$AUTONOMY\",
    \"frame\": {
        \"work_item_title\": \"$WORK_ITEM_TITLE\",
        \"work_item_description\": \"$WORK_ITEM_DESCRIPTION\",
        \"branch_name\": \"$BRANCH_NAME\"
    }
}"

# ========== PRE-ARCHITECT HOOKS ==========
# These typically inject:
# - Architecture standards and patterns
# - Technology stack constraints
# - API design guidelines
# - Database patterns
echo ""
execute_phase_hooks "architect" "pre" "$ARCHITECT_CONTEXT"
HOOK_EXIT=$?
if [ $HOOK_EXIT -ne 0 ]; then
    echo ""
    echo "❌ Pre-architect hooks failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "architect" "failed" '{"error": "Pre-architect hooks failed"}'
    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "architect" "Hook execution failed" '["retry", "cancel"]'
    exit 1
fi

# Get context injection from hooks
HOOK_RESULT=$("$CORE_SKILL/hook-result-get.sh" "$WORK_ID" "architect" "pre")
CONTEXT_INJECTION=$(extract_context_injection "$HOOK_RESULT")

# Store hook result for reference
echo "$HOOK_RESULT" > ".faber/sessions/$WORK_ID-architect-pre-hooks.json"

# Invoke Architect skill with Frame context and injected context
echo "Invoking Architect skill with Frame context..."
if [ -n "$CONTEXT_INJECTION" ]; then
    echo "📋 Injecting project-specific context from hooks"
    # Log which hooks injected context
    echo "$HOOK_RESULT" | jq -r '.executed[] | select(.type == "context" or .type == "prompt") | "  - \(.name) (\(.type))"'
fi
echo ""

Use the @skill-$ARCHITECT_SKILL skill with the following request:
{
    "operation": "execute_architect",
    "work_id": "$WORK_ID",
    "work_type": "$WORK_TYPE",
    "work_domain": "$WORK_DOMAIN",
    "context": $ARCHITECT_CONTEXT,
    "injected_context": "$CONTEXT_INJECTION"
}

ARCHITECT_EXIT=$?
if [ $ARCHITECT_EXIT -ne 0 ]; then
    echo ""
    echo "❌ Architect phase failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "architect" "failed" '{"error": "Architect skill returned non-zero exit code"}'
    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "architect" "Architect phase failed. Please check specification generation." '["retry", "cancel"]'
    exit 1
fi

# ========== POST-ARCHITECT HOOKS ==========
# These typically:
# - Validate architecture spec against standards
# - Run architecture review checks
# - Generate derived artifacts
echo ""
execute_phase_hooks "architect" "post" "$ARCHITECT_CONTEXT"
HOOK_EXIT=$?
if [ $HOOK_EXIT -ne 0 ]; then
    echo ""
    echo "❌ Post-architect hooks failed"
    "$CORE_SKILL/session-update.sh" "$WORK_ID" "architect" "failed" '{"error": "Post-architect hooks failed"}'
    "$CORE_SKILL/status-card-post.sh" "$WORK_ID" "$SOURCE_ID" "architect" "Post-architect validation failed" '["retry", "cancel"]'
    exit 1
fi

# Load Architect results into context
SESSION_JSON=$("$CORE_SKILL/session-status.sh" "$WORK_ID")
SPEC_FILE=$(echo "$SESSION_JSON" | jq -r '.stages.architect.data.spec_file // ""')
SPEC_COMMIT=$(echo "$SESSION_JSON" | jq -r '.stages.architect.data.commit_sha // ""')
KEY_DECISIONS=$(echo "$SESSION_JSON" | jq -r '.stages.architect.data.key_decisions // []')

# Update session - Architect completed
"$CORE_SKILL/session-update.sh" "$WORK_ID" "architect" "completed"

echo ""
echo "✅ Architect phase complete"
echo "   Specification: $SPEC_FILE"
echo "   Commit: $SPEC_COMMIT"
echo ""

# Check if stopping here
if [ "$STOP_AT_PHASE" = "architect" ]; then
    echo "⏸️  Stopping after Architect phase (as requested)"
    exit 0
fi
```

## Implementation Checklist

When integrating hooks into the FABER workflow manager:

### Configuration

- [ ] Load hooks configuration from `.faber.config.toml`
- [ ] Parse hooks for each phase (frame, architect, build, evaluate, release)
- [ ] Parse hooks for each timing (pre, post)
- [ ] Validate hook configuration format
- [ ] Set environment variable `FABER_ENVIRONMENT` for environment filtering

### Helper Functions

- [ ] Implement `execute_phase_hooks()` function
- [ ] Implement `extract_context_injection()` function
- [ ] Create script to store/retrieve hook results (for context injection)
- [ ] Add error handling for hook failures

### Phase Modifications

For **each phase** (Frame, Architect, Build, Evaluate, Release):

- [ ] Add pre-phase hook execution before skill invocation
- [ ] Pass phase context to hook executor
- [ ] Capture context injection from hooks
- [ ] Pass injected context to phase skill
- [ ] Add post-phase hook execution after skill completion
- [ ] Handle hook failures (stop workflow if required hook fails)
- [ ] Log hook execution in session state
- [ ] Update status cards to indicate hook failures

### Phase Skill Modifications

For **each phase skill** (frame, architect, build, evaluate, release):

- [ ] Add `injected_context` parameter to `<INPUTS>` section
- [ ] Document injected context in `<CONTEXT>` section
- [ ] Add "Step 0: Process Injected Context" to `<WORKFLOW>` section
- [ ] Instruct skill to apply injected context throughout execution
- [ ] Add examples showing typical injected context for that phase

### Error Handling

- [ ] Handle hook executor failures
- [ ] Differentiate between `failureMode: stop` and `failureMode: warn`
- [ ] Update session state when hooks fail
- [ ] Post status cards when hooks fail
- [ ] Log hook failures for debugging

### Testing

- [ ] Test with no hooks configured (backward compatibility)
- [ ] Test with context hooks (verify context injection)
- [ ] Test with prompt hooks (verify prompt injection)
- [ ] Test with script hooks (verify script execution)
- [ ] Test with skill hooks (verify skill invocation)
- [ ] Test with environment filtering (verify hooks only run for specified environments)
- [ ] Test with required hooks that fail (verify workflow stops)
- [ ] Test with optional hooks that fail (verify workflow continues with warning)
- [ ] Test with multiple hooks per phase (verify execution order)
- [ ] Test context injection limit (verify weight-based pruning)

## Migration Path

Projects can adopt hooks incrementally:

### Phase 1: Add Hook Support (Backward Compatible)

1. Update workflow-manager.md with hook integration code
2. Keep all existing functionality working
3. Hooks are opt-in (only execute if configured)
4. No changes required to existing projects

### Phase 2: Document Hook System

1. Update FABER documentation with hook examples
2. Create example configurations for common use cases
3. Document hook types and configuration format
4. Provide migration guide for projects using wrapper commands

### Phase 3: Deprecate Wrapper Commands

1. Projects migrate from wrapper commands to hooks configuration
2. Demonstrate context injection replacing inline context
3. Show how hooks eliminate need for custom commands
4. Provide automated migration tooling

## Benefits Summary

### For Workflow Execution

- **Context Injection**: Project-specific standards/patterns available at the right phase
- **Environment-Specific Behavior**: Different hooks for dev/staging/prod
- **Validation Gates**: Ensure quality standards with post-phase hooks
- **Setup Automation**: Pre-phase hooks prepare environment
- **Extensibility**: Projects customize without forking plugins

### For Plugin Development

- **Separation of Concerns**: Core workflow logic separate from project-specific customization
- **Maintainability**: Projects update docs, not code
- **Testability**: Hook configuration can be tested independently
- **Reusability**: Same plugin works across projects with different requirements

### For Users

- **No Wrapper Commands**: Use standard `/faber run` command
- **Configuration Over Code**: Change behavior via `.faber.config.toml`
- **Discoverable**: Hooks are explicit in configuration
- **Safe**: Hooks respect required/optional and failureMode settings
