---
name: fractary-work:milestone-close
description: Close a completed milestone
argument-hint: <milestone_id> [--comment <text>]
---

<CONTEXT>
You are the work:milestone-close command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to close a milestone.
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
   - Extract milestone_id (required)
   - Parse optional arguments: --comment
   - Validate required arguments are present

2. **Build structured request**
   - Package milestone and comment parameters

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

**Always use quotes for multi-word values:**
```bash
✅ /work:milestone-close "v1.0 Release"
✅ /work:milestone-close "v1.0 Release" --comment "All issues completed successfully"

❌ /work:milestone-close v1.0 Release
❌ /work:milestone-close "v1.0 Release" --comment All issues completed
```

**Single-word values or numbers don't require quotes:**
```bash
✅ /work:milestone-close v1.0
✅ /work:milestone-close 1  # Milestone number
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `milestone_id` (string or number): Milestone ID or title, use quotes if multi-word (e.g., "v1.0 Release" or "1" for milestone #1)

**Optional Arguments**:
- `--comment` (string): Comment to add when closing, use quotes if multi-word (e.g., "All issues completed successfully")

**Maps to**: close-milestone operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Close milestone
/work:milestone-close "v1.0 Release"

# Close with comment
/work:milestone-close "v1.0 Release" --comment "All issues completed successfully"

# Close by milestone number
/work:milestone-close 1

# Close with single-word title
/work:milestone-close v1.0
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "close-milestone",
  "parameters": {
    "milestone": "v1.0 Release",
    "comment": "All issues completed successfully"
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

**Missing milestone**:
```
Error: milestone is required
Usage: /work:milestone-close <milestone_id> [--comment <text>]
```

**Milestone not found**:
```
Error: Milestone not found: "v3.0 Release"
List milestones: /work:milestone-list --state all
```

**Already closed**:
```
Warning: Milestone "v1.0 Release" is already closed
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

## FABER Integration

FABER workflows can automatically close milestones when all associated issues are completed.

## See Also

For detailed documentation, see: [/docs/commands/work-milestone.md](../../../docs/commands/work-milestone.md)

Related commands:
- `/work:milestone-create` - Create milestone
- `/work:milestone-list` - List milestones
- `/work:milestone-set` - Assign milestone to issue
- `/work:milestone-remove` - Remove milestone from issue
- `/work:init` - Configure work plugin
</NOTES>
