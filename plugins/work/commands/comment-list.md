---
name: fractary-work:comment-list
description: List comments on an issue
argument-hint: <issue_number> [--limit <n>] [--since <date>]
---

<CONTEXT>
You are the work:comment-list command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to list comments on an issue.
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
   - Parse optional arguments: --limit, --since
   - Validate required arguments are present

2. **Build structured request**
   - Package all parameters

3. **Invoke agent**
   - Use the Task tool with subagent_type="fractary-work:work-manager"
   - Pass the structured JSON request in the prompt parameter

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

**Date values need quotes:**
```bash
✅ /work:comment-list 123 --since "2025-01-01"
✅ /work:comment-list 123 --limit 5

❌ /work:comment-list 123 --since 2025-01-01  # Date should be quoted
```

**Numeric values don't require quotes:**
```bash
✅ /work:comment-list 123
✅ /work:comment-list 123 --limit 20
```

**Date format:**
- Use YYYY-MM-DD format: "2025-01-01" ✅
- NOT: "01/01/2025" ❌ or "Jan 1 2025" ❌
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")

**Optional Arguments**:
- `--limit` (number): Maximum number of comments to return (default: 10). Example: `--limit 20` for 20 most recent comments
- `--since` (string): Show only comments since date in YYYY-MM-DD format (e.g., "2025-01-01"). Use quotes for the date

**Maps to**: list-comments operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# List comments (default limit: 10)
/work:comment-list 123

# List recent comments only
/work:comment-list 123 --limit 5

# List comments since a date
/work:comment-list 123 --since "2025-01-01"

# Combine filters
/work:comment-list 123 --limit 20 --since "2025-01-01"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "list-comments",
  "parameters": {
    "issue_number": "123",
    "limit": 10,
    "since": "2025-01-01"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (comment-lister)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results with comment details
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:comment-list <issue_number>
```

**Invalid issue number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Invalid limit**:
```
Error: limit must be a positive number
Usage: /work:comment-list <issue_number> --limit <n>
```

**Invalid date format**:
```
Error: Invalid date format: 2025/01/01
Use YYYY-MM-DD format (e.g., 2025-01-01)
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

For detailed documentation, see: [/docs/commands/work-comment.md](../../../docs/commands/work-comment.md)

Related commands:
- `/work:comment-create` - Add comment
- `/work:issue-fetch` - Fetch issue details
- `/work:init` - Configure work plugin
</NOTES>
