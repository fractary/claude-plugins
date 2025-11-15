---
name: fractary-work:state-transition
description: Transition issue to a specific workflow state
argument-hint: '<number> <state> [--comment "<text>"]'
---

<CONTEXT>
You are the work:state-transition command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to transition an issue to a specific workflow state.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the fractary-work:work-manager agent (or @agent-fractary-work:work-manager)
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the work-manager agent handles skill invocation)
- Execute platform-specific logic (that's the agent's job)

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract issue number (required)
   - Extract state (required)
   - Parse optional arguments: --comment
   - Validate required arguments are present

2. **Build structured request**
   - Package all parameters

3. **ACTUALLY INVOKE the Task tool**
   - Use the Task tool with subagent_type="fractary-work:work-manager"
   - Pass the structured JSON request in the prompt parameter
   - Do NOT just describe what should be done - actually call the Task tool

   **IF THE TASK TOOL INVOCATION FAILS:**
   - STOP IMMEDIATELY - do not attempt any workarounds
   - Report the exact error message to the user
   - DO NOT use bash/gh/jq CLI commands as a fallback
   - DO NOT invoke skills directly
   - DO NOT try alternative approaches
   - Wait for user to provide explicit instruction

4. **Return response**
   - The work-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes

### Quote Usage

**State values are exact keywords (no quotes needed):**
```bash
✅ /work:state-transition 123 in_progress
✅ /work:state-transition 123 in_review
✅ /work:state-transition 123 done

❌ /work:state-transition 123 "in progress"  # Use underscores, not spaces
❌ /work:state-transition 123 in-progress    # Use underscores, not hyphens
```

**Always use quotes for multi-word comments:**
```bash
✅ /work:state-transition 123 in_progress --comment "Starting work on this"
✅ /work:state-transition 123 in_review --comment "Ready for review"

❌ /work:state-transition 123 in_progress --comment Starting work on this
```

**Single-word comments don't require quotes:**
```bash
✅ /work:state-transition 123 done --comment Completed
```

**State values use underscores:**
- Use exactly: `open`, `in_progress`, `in_review`, `done`, `closed`
- NOT: `in-progress`, `inProgress`, `in progress`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `state` (enum): Target workflow state. Must be one of: `open`, `in_progress`, `in_review`, `done`, `closed` (note: use underscores)

**Optional Arguments**:
- `--comment` (string): Comment to post with transition, use quotes if multi-word (e.g., "Moving to in_progress")

**Maps to**: transition-state operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Transition to in_progress
/work:state-transition 123 in_progress

# Transition with comment
/work:state-transition 123 in_progress --comment "Starting work on this"

# Transition to in_review
/work:state-transition 123 in_review --comment "Ready for code review"

# Transition to done
/work:state-transition 123 done --comment "Implementation complete"

# Transition to closed
/work:state-transition 123 closed
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "transition-state",
  "parameters": {
    "issue_number": "123",
    "state": "in_progress",
    "comment": "Starting work on this"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (state-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:state-transition <number> <state>
```

**Missing state**:
```
Error: state is required
Usage: /work:state-transition <number> <state>
```

**Invalid state**:
```
Error: Invalid state: invalid_state
Valid states: open, in_progress, in_review, done, closed
```

**Already in target state**:
```
Warning: Issue #123 is already in state: in_progress
No action taken
```
</ERROR_HANDLING>

<NOTES>
## Universal States

The work plugin uses universal states that map to platform-specific states:
- **open**: Issue created but not started
- **in_progress**: Actively being worked on
- **in_review**: Under review
- **done**: Completed
- **closed**: Explicitly closed

## Platform Support

This command works with:
- GitHub Issues (OPEN/CLOSED states + labels for intermediate states)
- Jira Cloud (Maps to workflow states)
- Linear (Maps to Linear workflow states)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## FABER Integration

FABER workflows automatically manage state transitions through the workflow phases (Frame → Architect → Build → Evaluate → Release).

## See Also

For detailed documentation, see: [/docs/commands/work-state.md](../../../docs/commands/work-state.md)

Related commands:
- `/work:state-close` - Close issue
- `/work:state-reopen` - Reopen issue
- `/work:comment-create` - Add comment
- `/work:init` - Configure work plugin
</NOTES>
