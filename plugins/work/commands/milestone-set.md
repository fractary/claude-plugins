---
name: fractary-work:milestone-set
description: Set milestone on an issue
argument-hint: <issue_number> <milestone>
---

<CONTEXT>
You are the work:milestone-set command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to assign a milestone to an issue.
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
   - Extract milestone (required)
   - Validate required arguments are present

2. **Build structured request**
   - Package issue_number and milestone parameters

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

This command takes two positional arguments:
- **Format**: `/work:milestone-set <issue_number> <milestone>`
- **issue_number**: Issue number (e.g., 123, not "#123")
- **milestone**: Milestone title or number

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:milestone-set 123 "v1.0 Release"
✅ /work:milestone-set 123 "Sprint 5"

❌ /work:milestone-set 123 v1.0 Release
```

**Single-word values or numbers don't require quotes:**
```bash
✅ /work:milestone-set 123 v1.0
✅ /work:milestone-set 123 1  # Milestone number
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")
- `milestone` (string or number): Milestone title or number, use quotes if multi-word (e.g., "v1.0 Release" or just "1" for milestone #1)

**Maps to**: set-milestone operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Set milestone on issue
/work:milestone-set 123 "v1.0 Release"

# Set milestone by number
/work:milestone-set 123 1

# Set milestone with single-word title
/work:milestone-set 456 v2.0
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "set-milestone",
  "parameters": {
    "issue_number": "123",
    "milestone": "v1.0 Release"
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
Usage: /work:milestone-set <issue_number> <milestone>
```

**Missing milestone**:
```
Error: milestone is required
Usage: /work:milestone-set <issue_number> <milestone>
```

**Milestone not found**:
```
Error: Milestone not found: "v3.0 Release"
List milestones: /work:milestone-list --state all
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
- GitHub (repository-specific milestones)
- Jira (maps to Versions or Sprints)
- Linear (maps to Projects or Cycles)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## FABER Integration

FABER workflows can automatically assign issues to release milestones during the Release phase.

## See Also

For detailed documentation, see: [/docs/commands/work-milestone.md](../../../docs/commands/work-milestone.md)

Related commands:
- `/work:milestone-create` - Create milestone
- `/work:milestone-list` - List milestones
- `/work:milestone-remove` - Remove milestone from issue
- `/work:milestone-close` - Close milestone
- `/work:init` - Configure work plugin
</NOTES>
