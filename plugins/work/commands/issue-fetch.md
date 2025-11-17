---
name: fractary-work:issue-fetch
description: Fetch and display issue details
argument-hint: <number>
---

<CONTEXT>
You are the work:issue-fetch command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to fetch issue details.
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

**WHEN COMMANDS FAIL:**
- NEVER bypass the command architecture with manual bash/gh/jq commands
- NEVER use gh/jq CLI directly as a workaround
- ALWAYS report the failure to the user with error details
- ALWAYS wait for explicit user instruction on how to proceed
- DO NOT be "helpful" by finding alternative approaches
- The user decides: debug the skill, try different approach, or abort

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract issue number (required)
   - Validate required arguments are present

2. **Capture working directory context**
   - Capture current directory: `WORK_CWD="${PWD}"`
   - This ensures operations execute in the correct repository
   - Critical fix for agent execution context bug

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
- **Format**: `/work:issue-fetch <number>`
- **number**: Issue number (e.g., 123, not "#123")

### Examples

```bash
✅ /work:issue-fetch 123
✅ /work:issue-fetch 42

❌ /work:issue-fetch #123  # Don't include # symbol
❌ /work:issue-fetch       # Issue number required
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `number`: Issue number

**Maps to**: fetch-issue operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Fetch issue details
/work:issue-fetch 123

# Fetch different issue
/work:issue-fetch 456
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

**CRITICAL**: Capture the current working directory and pass it to the agent to ensure operations execute in the correct repository.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "fetch-issue",
  "parameters": {
    "issue_number": "123",
    "working_directory": "${PWD}"
  }
}
```

The work-manager agent will:
1. Set `CLAUDE_WORK_CWD` environment variable from `working_directory`
2. Validate the request
3. Route to the appropriate skill (issue-fetcher)
4. Execute the platform-specific operation (GitHub/Jira/Linear)
5. Return structured results including title, description, state, labels, assignees, and comments

**Why working_directory is required**:
When agents execute via Task tool, they run from the plugin directory, not the user's project directory. Passing `working_directory` ensures scripts load the correct configuration and operate on the correct repository. See: `/.tmp/FRACTARY_WORK_PLUGIN_BUG_REPORT.md`
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue number is required
Usage: /work:issue-fetch <number>
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
- GitHub Issues
- Jira Cloud
- Linear

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-issue.md](../../../docs/commands/work-issue.md)

Related commands:
- `/work:issue-create` - Create new issue
- `/work:issue-list` - List issues
- `/work:issue-update` - Update issue
- `/work:comment-list` - List comments
- `/work:init` - Configure work plugin
</NOTES>
