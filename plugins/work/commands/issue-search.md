---
name: fractary-work:issue-search
description: Search issues by keyword
model: claude-haiku-4-5
argument-hint: <query> [--state <state>] [--limit <n>]
---

<CONTEXT>
You are the work:issue-search command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to search issues.
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
   - Extract search query (required)
   - Parse optional arguments: --state, --limit
   - Validate required arguments are present

2. **Capture working directory context**
   - Capture current directory: `WORK_CWD="${PWD}"`
   - This ensures operations execute in the correct repository

3. **Build structured request**
   - Package query and filter parameters
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
- **Example**: `--query "authentication bug"` ✅
- **Wrong**: `--query authentication bug` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:issue-search "authentication bug"
✅ /work:issue-search "login timeout" --state open

❌ /work:issue-search authentication bug
❌ /work:issue-search login timeout --state open
```

**Single-word values don't require quotes:**
```bash
✅ /work:issue-search authentication
✅ /work:issue-search bug --state all
✅ /work:issue-search login --limit 10
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `query`: Search query (use quotes if multi-word)

**Optional Arguments**:
- `--state`: Filter by state (open|closed|all, default: all)
- `--limit`: Maximum results (default: 20)

**Maps to**: search-issues operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Search all issues
/work:issue-search "authentication"

# Search with multi-word query
/work:issue-search "login timeout bug"

# Search only open issues
/work:issue-search "authentication" --state open

# Search with result limit
/work:issue-search "bug" --limit 10

# Combine filters
/work:issue-search "performance" --state closed --limit 5
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "search-issues",
  "parameters": {
    "query": "authentication",
    "state": "all",
    "limit": 20
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (issue-searcher)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results with matching issues
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing query**:
```
Error: search query is required
Usage: /work:issue-search <query> [--state <state>]
```

**Invalid state**:
```
Error: Invalid state: invalid
Valid states: open, closed, all
```

**Invalid limit**:
```
Error: limit must be a positive number
Usage: /work:issue-search <query> --limit <n>
```
</ERROR_HANDLING>

<NOTES>
## Search Capabilities

Different platforms support different search capabilities:
- **GitHub**: Full-text search in title, body, and comments
- **Jira**: JQL-powered search with advanced filters
- **Linear**: Text search in title and description

## Platform Support

This command works with:
- GitHub Issues
- Jira Cloud
- Linear

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-issue.md](../../../docs/commands/work-issue.md)

Related commands:
- `/work:issue-list` - List issues with filters
- `/work:issue-fetch` - Fetch issue details
- `/work:init` - Configure work plugin
</NOTES>
