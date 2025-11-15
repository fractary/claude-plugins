---
name: fractary-work:state-reopen
description: Reopen a closed issue
argument-hint: '<number> [--comment "<text>"]'
---

<CONTEXT>
You are the work:state-reopen command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to reopen a closed issue.
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
   - Parse optional arguments: --comment
   - Validate required arguments are present

2. **Build structured request**
   - Package all parameters

3. **ACTUALLY INVOKE the Task tool**
   - Use the Task tool with subagent_type="fractary-work:work-manager"
   - Pass the structured JSON request in the prompt parameter
   - Do NOT just describe what should be done - actually call the Task tool

4. **Return response**
   - The work-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_SYNTAX>
## Command Argument Syntax

This command follows the **space-separated** argument syntax (consistent with work/repo plugin family):
- **Format**: `--flag value` (NOT `--flag=value`)
- **Multi-word values**: MUST be enclosed in quotes
- **Example**: `--comment "Bug still present in production"` ✅
- **Wrong**: `--comment Bug still present in production` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:state-reopen 123 --comment "Bug still present in production"
✅ /work:state-reopen 123 --comment "Need to retest with new data"

❌ /work:state-reopen 123 --comment Bug still present
```

**Single-word values don't require quotes:**
```bash
✅ /work:state-reopen 123
✅ /work:state-reopen 123 --comment Regression
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")

**Optional Arguments**:
- `--comment` (string): Comment explaining why reopening, use quotes if multi-word (e.g., "Bug still present in v2.0")

**Maps to**: reopen-issue operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Reopen issue
/work:state-reopen 123

# Reopen with explanation
/work:state-reopen 123 --comment "Bug still occurring in production"

# Reopen with detailed comment
/work:state-reopen 123 --comment "Need to retest - found edge case in v2.0"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "reopen-issue",
  "parameters": {
    "issue_number": "123",
    "comment": "Bug still present in v2.0"
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
Usage: /work:state-reopen <number>
```

**Already open**:
```
Warning: Issue #123 is already open
No action taken
```

**Invalid issue number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```
</ERROR_HANDLING>

<NOTES>
## Platform Support

This command works with:
- GitHub Issues (OPEN/CLOSED states + labels for intermediate states)
- Jira Cloud (Maps to workflow states)
- Linear (Maps to Linear workflow states)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-state.md](../../../docs/commands/work-state.md)

Related commands:
- `/work:state-close` - Close issue
- `/work:state-transition` - Transition to workflow state
- `/work:comment-create` - Add comment
- `/work:init` - Configure work plugin
</NOTES>
