---
name: fractary-work:milestone-list
description: List milestones with optional filtering
argument-hint: [--state <state>] [--sort <sort>]
---

<CONTEXT>
You are the work:milestone-list command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to list milestones.
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
   - Parse optional arguments: --state, --sort
   - Set default values if not provided

2. **Build structured request**
   - Package all filter parameters

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

### Examples

```bash
✅ /work:milestone-list
✅ /work:milestone-list --state open
✅ /work:milestone-list --state all --sort completeness
✅ /work:milestone-list --sort due_date

❌ /work:milestone-list --state=open
```

**State values are exact keywords:**
- Use exactly: `open`, `closed`, `all`
- NOT: `active`, `completed`, `finished`

**Sort values are exact keywords:**
- Use exactly: `due_date`, `completeness`, `title`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Optional Arguments**:
- `--state` (enum): Filter by state. Must be one of: `open`, `closed`, `all` (default: open)
- `--sort` (enum): Sort order. Must be one of: `due_date` (by due date), `completeness` (by completion %), `title` (alphabetically) (default: due_date)

**Maps to**: list-milestones operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# List all open milestones (default)
/work:milestone-list

# List all milestones
/work:milestone-list --state all

# List closed milestones
/work:milestone-list --state closed

# List sorted by completeness
/work:milestone-list --sort completeness

# List sorted by title
/work:milestone-list --sort title

# Combine filters
/work:milestone-list --state open --sort due_date
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "list-milestones",
  "parameters": {
    "state": "open",
    "sort": "due_date"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (milestone-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results with milestone details
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Invalid state**:
```
Error: Invalid state: invalid
Valid states: open, closed, all
```

**Invalid sort**:
```
Error: Invalid sort: invalid
Valid sorts: due_date, completeness, title
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
- `/work:milestone-set` - Assign milestone to issue
- `/work:milestone-close` - Close milestone
- `/work:init` - Configure work plugin
</NOTES>
