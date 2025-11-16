---
name: fractary-work:comment-create
description: Add a comment to an issue
argument-hint: '<issue_number> "<text>" [--faber-context <context>]'
---

<CONTEXT>
You are the work:comment-create command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to create a comment on an issue.
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
   - Extract comment text (required)
   - Parse optional arguments: --faber-context
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
- **Example**: `--comment "Working on this issue"` ✅
- **Wrong**: `--comment Working on this issue` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:comment-create 123 "Working on this now"
✅ /work:comment-create 123 "Investigated the bug - found the root cause"

❌ /work:comment-create 123 Working on this now
❌ /work:comment-create 123 Investigated the bug
```

**Single-word values don't require quotes:**
```bash
✅ /work:comment-create 123 LGTM
✅ /work:comment-create 123 Done
```

**Comment text guidelines:**
- Multi-word comments MUST use quotes
- Single word comments (e.g., "LGTM", "Done") don't need quotes
- Comments can include markdown formatting
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")
- `text` (string): Comment text, use quotes if multi-word (e.g., "Working on this now"). Supports markdown formatting

**Optional Arguments**:
- `--faber-context` (string): FABER workflow context metadata (internal use, typically set automatically by FABER workflows)

**Maps to**: create-comment operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Add a comment
/work:comment-create 123 "Starting work on this issue"

# Add a longer comment
/work:comment-create 123 "Investigated the bug - it's caused by a race condition"

# Add a single-word comment
/work:comment-create 123 LGTM

# Add a comment with markdown
/work:comment-create 123 "## Progress Update\n\n- Fixed authentication\n- Added tests\n- Updated docs"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "create-comment",
  "parameters": {
    "issue_number": "123",
    "comment": "Working on this now"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (comment-creator)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:comment-create <issue_number> <text>
```

**Missing comment text**:
```
Error: comment text is required
Usage: /work:comment-create <issue_number> <text>
```

**Invalid issue number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```
</ERROR_HANDLING>

<NOTES>
## Comment Formatting

Comments support markdown formatting on most platforms (GitHub Flavored Markdown, Jira wiki markup, Linear markdown).

## Platform Support

This command works with:
- GitHub Issues
- Jira Cloud
- Linear

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## FABER Integration

When used within FABER workflows, comments automatically include phase information, workflow progress updates, links to commits and PRs, and test results.

## See Also

For detailed documentation, see: [/docs/commands/work-comment.md](../../../docs/commands/work-comment.md)

Related commands:
- `/work:comment-list` - List comments
- `/work:issue-fetch` - Fetch issue details
- `/work:state-close` - Close issue with comment
- `/work:init` - Configure work plugin
</NOTES>
