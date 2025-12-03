---
name: fractary-work:milestone-remove
description: Remove milestone from an issue
model: claude-haiku-4-5
argument-hint: <issue_number>
---

<CONTEXT>
You are the work:milestone-remove command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to remove a milestone from an issue.
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
   - Validate required arguments are present

2. **Capture working directory context**
   - Capture current directory: `WORK_CWD="${PWD}"`
   - This ensures operations execute in the correct repository

3. **Build structured request**
   - Package issue_number parameter
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

This command takes a simple positional argument:
- **Format**: `/work:milestone-remove <issue_number>`
- **issue_number**: Issue number (e.g., 123, not "#123")

### Examples

```bash
✅ /work:milestone-remove 123
✅ /work:milestone-remove 42

❌ /work:milestone-remove #123  # Don't include # symbol
❌ /work:milestone-remove       # Issue number required
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")

**Maps to**: remove-milestone operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Remove milestone from issue
/work:milestone-remove 123

# Remove milestone from different issue
/work:milestone-remove 456
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "remove-milestone",
  "parameters": {
    "issue_number": "123"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (milestone-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:milestone-remove <issue_number>
```

**Invalid issue number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**No milestone set**:
```
Warning: Issue #123 has no milestone set
No action taken
```
</ERROR_HANDLING>

<NOTES>
## Platform Support

This command works with:
- GitHub (repository-specific milestones)
- Jira (maps to Versions or Sprints)
- Linear (maps to Projects or Cycles)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-milestone.md](../../../docs/commands/work-milestone.md)

Related commands:
- `/work:milestone-create` - Create milestone
- `/work:milestone-list` - List milestones
- `/work:milestone-set` - Assign milestone to issue
- `/work:milestone-close` - Close milestone
- `/work:init` - Configure work plugin
</NOTES>
