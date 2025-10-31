---
name: fractary-work:state
description: Manage issue lifecycle states (close, reopen, update state)
argument-hint: close <number> [--comment <text>] | reopen <number> [--comment <text>] | transition <number> <state>
---

<CONTEXT>
You are the work:state command router for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent with the appropriate request.
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

3. **Invoke agent**
   - Invoke fractary-work:work-manager agent with the request

4. **Return response**
   - The work-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Subcommands

### close <number> [--comment <text>] [--reason <reason>]
**Purpose**: Close an issue and optionally post a comment

**Required Arguments**:
- `number`: Issue number

**Optional Arguments**:
- `--comment`: Comment to post when closing
- `--reason`: Reason for closing (completed|duplicate|wontfix)

**Maps to**: close-issue

**Example**:
```
/work:state close 123 --comment "Fixed in PR #456"
→ Invoke agent with {"operation": "close-issue", "parameters": {"issue_number": "123", "comment": "Fixed in PR #456", "reason": "completed"}}
```

### reopen <number> [--comment <text>]
**Purpose**: Reopen a closed issue

**Required Arguments**:
- `number`: Issue number

**Optional Arguments**:
- `--comment`: Comment explaining why reopening

**Maps to**: reopen-issue

**Example**:
```
/work:state reopen 123 --comment "Bug still present in v2.0"
→ Invoke agent with {"operation": "reopen-issue", "parameters": {"issue_number": "123", "comment": "Bug still present in v2.0"}}
```

### transition <number> <state> [--comment <text>]
**Purpose**: Transition issue to a specific workflow state

**Required Arguments**:
- `number`: Issue number
- `state`: Target state (open|in_progress|in_review|done|closed)

**Optional Arguments**:
- `--comment`: Comment to post with transition

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

After parsing arguments, invoke the work-manager agent using declarative syntax:

**Agent**: fractary-work:work-manager (or @agent-fractary-work:work-manager)

**Request structure**:
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
1. Receive the request
2. Route to appropriate skill based on operation
3. Execute platform-specific logic (GitHub/Jira/Linear)
4. Return structured response

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
