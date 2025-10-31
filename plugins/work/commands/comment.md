---
name: fractary-work:comment
description: Create and manage comments on work items
argument-hint: create <issue_number> <text> | list <issue_number> [--limit <n>]
---

<CONTEXT>
You are the work:comment command router for the fractary-work plugin.
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
   - Extract subcommand (create, list)
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

### create <issue_number> <text> [--faber-context <context>]
**Purpose**: Add a comment to an issue

**Required Arguments**:
- `issue_number`: Issue number
- `text`: Comment text

**Optional Arguments**:
- `--faber-context`: FABER workflow context (internal use)

**Maps to**: create-comment

**Example**:
```
/work:comment create 123 "Working on this now"
→ Invoke agent with {"operation": "create-comment", "parameters": {"issue_number": "123", "comment": "Working on this now"}}
```

### list <issue_number> [--limit <n>] [--since <date>]
**Purpose**: List comments on an issue

**Required Arguments**:
- `issue_number`: Issue number

**Optional Arguments**:
- `--limit`: Maximum number of comments (default: 10)
- `--since`: Show comments since date (YYYY-MM-DD)

**Maps to**: list-comments

**Example**:
```
/work:comment list 123
→ Invoke agent with {"operation": "list-comments", "parameters": {"issue_number": "123", "limit": 10}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Add a comment
/work:comment create 123 "Starting work on this issue"

# Add a longer comment
/work:comment create 123 "Investigated the bug - it's caused by a race condition"

# List comments
/work:comment list 123

# List recent comments only
/work:comment list 123 --limit 5
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

- `create-comment` - Add comment to issue
- `list-comments` - List comments on issue
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:comment create <issue_number> <text>
```

**Missing comment text**:
```
Error: comment text is required
Usage: /work:comment create <issue_number> <text>
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
- `/work:issue` - Manage issues
- `/work:state` - Manage issue states
- `/work:init` - Configure work plugin
</NOTES>
