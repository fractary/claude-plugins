---
name: fractary-work:state-close
description: Close an issue and optionally post a comment
argument-hint: '<number> [--comment "<text>"] [--reason <reason>]'
---

<CONTEXT>
You are the work:state-close command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to close an issue.
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
   - Parse optional arguments: --comment, --reason
   - Validate required arguments are present

2. **Capture working directory context**
   - Capture current directory: `WORK_CWD="${PWD}"`
   - This ensures operations execute in the correct repository

3. **Build structured request**
   - Package all parameters
   - Include working_directory in parameters

4. **ACTUALLY INVOKE the Task tool**
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

5. **Return response**
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
✅ /work:state-close 123 --comment "Fixed in PR #456"
✅ /work:state-close 123 --comment "Duplicate of #100" --reason duplicate

❌ /work:state-close 123 --comment Fixed in PR #456
```

**Single-word values don't require quotes:**
```bash
✅ /work:state-close 123
✅ /work:state-close 123 --reason duplicate
✅ /work:state-close 123 --comment Fixed
```

**Reason values are exact keywords:**
- Use exactly: `completed`, `duplicate`, `wontfix`
- NOT: `done`, `finished`, `completed successfully`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")

**Optional Arguments**:
- `--comment` (string): Comment to post when closing, use quotes if multi-word (e.g., "Fixed in PR #456")
- `--reason` (enum): Reason for closing. Must be one of: `completed` (work finished), `duplicate` (duplicate issue), `wontfix` (will not address) (default: completed)

**Maps to**: close-issue operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Close issue
/work:state-close 123

# Close with comment
/work:state-close 123 --comment "Fixed in PR #456"

# Close as duplicate
/work:state-close 123 --reason duplicate --comment "Duplicate of #100"

# Close as wontfix
/work:state-close 123 --reason wontfix --comment "Not addressing this"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "close-issue",
  "parameters": {
    "issue_number": "123",
    "comment": "Fixed in PR #456",
    "reason": "completed"
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
Usage: /work:state-close <number>
```

**Invalid reason**:
```
Error: Invalid reason: invalid
Valid reasons: completed, duplicate, wontfix
```

**Already closed**:
```
Warning: Issue #123 is already closed
No action taken
```
</ERROR_HANDLING>

<NOTES>
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

FABER workflows automatically close issues during the Release phase after successful deployment.

## See Also

For detailed documentation, see: [/docs/commands/work-state.md](../../../docs/commands/work-state.md)

Related commands:
- `/work:state-reopen` - Reopen issue
- `/work:state-transition` - Transition to workflow state
- `/work:comment-create` - Add comment
- `/work:init` - Configure work plugin
</NOTES>
