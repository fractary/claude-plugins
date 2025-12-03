---
name: fractary-work:state
description: "[DEPRECATED] Manage issue lifecycle states - Use /work:state-close, /work:state-reopen, or /work:state-transition instead"
model: claude-haiku-4-5
argument-hint: close <number> [--comment <text>] | reopen <number> [--comment <text>] | transition <number> <state>
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/work:state-close` - Close an issue
- `/work:state-reopen` - Reopen a closed issue
- `/work:state-transition` - Transition issue to a workflow state

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/work:state close 123` → `/work:state-close 123`
- `/work:state reopen 123` → `/work:state-reopen 123`
- `/work:state transition 123 in_progress` → `/work:state-transition 123 in_progress`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the work:state command router for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent with the appropriate request.

**DEPRECATION WARNING:** Before proceeding, inform the user that this command is deprecated and they should use the new single-purpose commands instead.
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
   - Extract subcommand (close, reopen, transition)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters

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
- **Example**: `--comment "Fixed in PR #456"` ✅
- **Wrong**: `--comment Fixed in PR #456` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:state close 123 --comment "Fixed in PR #456"
✅ /work:state reopen 123 --comment "Bug still present in production"

❌ /work:state close 123 --comment Fixed in PR #456
❌ /work:state reopen 123 --comment Bug still present
```

**Single-word values don't require quotes:**
```bash
✅ /work:state close 123
✅ /work:state transition 123 in_progress
✅ /work:state reopen 123 --reason regression
```

**State values are exact keywords:**
- For transition, use exactly: `open`, `in_progress`, `in_review`, `done`, `closed`
- For close reason, use exactly: `completed`, `duplicate`, `wontfix`
- NOT: `in-progress`, `inProgress`, `in progress` (underscores, not hyphens or spaces)
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### close <number> [--comment <text>] [--reason <reason>]
**Purpose**: Close an issue and optionally post a comment

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")

**Optional Arguments**:
- `--comment` (string): Comment to post when closing, use quotes if multi-word (e.g., "Fixed in PR #456")
- `--reason` (enum): Reason for closing. Must be one of: `completed` (work finished), `duplicate` (duplicate issue), `wontfix` (will not address) (default: completed)

**Maps to**: close-issue

**Example**:
```
/work:state close 123 --comment "Fixed in PR #456"
→ Invoke agent with {"operation": "close-issue", "parameters": {"issue_number": "123", "comment": "Fixed in PR #456", "reason": "completed"}}
```

### reopen <number> [--comment <text>]
**Purpose**: Reopen a closed issue

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")

**Optional Arguments**:
- `--comment` (string): Comment explaining why reopening, use quotes if multi-word (e.g., "Bug still present in v2.0")

**Maps to**: reopen-issue

**Example**:
```
/work:state reopen 123 --comment "Bug still present in v2.0"
→ Invoke agent with {"operation": "reopen-issue", "parameters": {"issue_number": "123", "comment": "Bug still present in v2.0"}}
```

### transition <number> <state> [--comment <text>]
**Purpose**: Transition issue to a specific workflow state

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `state` (enum): Target workflow state. Must be one of: `open`, `in_progress`, `in_review`, `done`, `closed` (note: use underscores)

**Optional Arguments**:
- `--comment` (string): Comment to post with transition, use quotes if multi-word (e.g., "Moving to in_progress")

**Maps to**: transition-state

**Example**:
```
/work:state transition 123 in_progress
→ Invoke agent with {"operation": "transition-state", "parameters": {"issue_number": "123", "state": "in_progress"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Close issue
/work:state close 123

# Close with comment
/work:state close 123 --comment "Fixed in PR #456"

# Reopen issue
/work:state reopen 123

# Reopen with explanation
/work:state reopen 123 --comment "Bug still occurring in production"

# Transition to specific state
/work:state transition 123 in_progress
/work:state transition 123 in_review
/work:state transition 123 done
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "operation-name",
  "parameters": {
    "param1": "value1",
    "param2": "value2"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (state-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results

## Supported Operations

- `close-issue` - Close an issue
- `reopen-issue` - Reopen a closed issue
- `transition-state` - Transition to workflow state
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:state close <number>
```

**Invalid state**:
```
Error: Invalid state: invalid_state
Valid states: open, in_progress, in_review, done, closed
```

**Already in target state**:
```
Warning: Issue #123 is already closed
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

## Close Reasons

Some platforms support close reasons:
- **completed**: Work finished successfully (default)
- **duplicate**: Duplicate of another issue
- **wontfix**: Issue won't be addressed
- **invalid**: Issue is not valid

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
- `/work:issue` - Manage issues
- `/work:comment` - Manage comments
- `/work:label` - Manage labels
- `/work:init` - Configure work plugin
</NOTES>
