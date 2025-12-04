---
name: fractary-work:label-add
description: Add a label to an issue
model: claude-haiku-4-5
argument-hint: '<number> <label> [--color <hex>] [--description "<text>"]'
---

<CONTEXT>
You are the work:label-add command for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent to add a label to an issue.
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
   - Extract label name (required)
   - Parse optional arguments: --color, --description
   - Validate required arguments are present

2. **Capture working directory context**
   - Capture current directory: `WORK_CWD="${PWD}"`
   - This ensures operations execute in the correct repository

3. **Build structured request**
   - Package all parameters
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

**Label names cannot contain spaces:**
```bash
✅ /work:label-add 123 high-priority
✅ /work:label-add 123 urgent
✅ /work:label-add 123 bug --color ff0000

❌ /work:label-add 123 "high priority"  # Spaces not supported in label names
```

**Use hyphens or underscores instead:**
- `high-priority` ✅
- `high_priority` ✅
- `high priority` ❌

**Multi-word descriptions need quotes:**
```bash
✅ /work:label-add 123 urgent --description "Requires immediate attention"
❌ /work:label-add 123 urgent --description Requires immediate attention
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Arguments

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `label` (string): Label name to add (no spaces, use hyphens/underscores). Examples: "bug", "high-priority", "needs_review"

**Optional Arguments**:
- `--color` (string): Label color as hex code for label creation if label doesn't exist (e.g., "ff0000" for red, "00ff00" for green). No # prefix needed
- `--description` (string): Label description for label creation if label doesn't exist, use quotes if multi-word (e.g., "High priority items")

**Maps to**: add-label operation
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Add a single label
/work:label-add 123 bug

# Add label with color
/work:label-add 123 urgent --color ff0000

# Add label with description
/work:label-add 123 high-priority --description "Critical issues requiring immediate attention"

# Add label with both
/work:label-add 123 security --color ffa500 --description "Security-related issues"
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
```json
{
  "operation": "add-label",
  "parameters": {
    "issue_number": "123",
    "label": "urgent",
    "color": "ff0000",
    "description": "High priority items"
  }
}
```

The work-manager agent will:
1. Validate the request
2. Route to the appropriate skill (label-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:label-add <number> <label>
```

**Missing label name**:
```
Error: label name is required
Usage: /work:label-add <number> <label>
```

**Label contains spaces**:
```
Error: Label names cannot contain spaces: "high priority"
Use hyphens or underscores: high-priority, high_priority
```
</ERROR_HANDLING>

<NOTES>
## Common Labels

Standard labels include:
- **Type**: bug, feature, enhancement, documentation, chore
- **Priority**: critical, high-priority, low-priority
- **Status**: in-progress, in-review, blocked, ready
- **Area**: frontend, backend, api, ui, security, performance

## Platform Support

This command works with:
- GitHub Issues (labels have colors and descriptions)
- Jira Cloud (simple text tags)
- Linear (labels have colors, team-specific)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-label.md](../../../docs/commands/work-label.md)

Related commands:
- `/work:label-remove` - Remove label
- `/work:label-list` - List labels
- `/work:label-set` - Set all labels
- `/work:issue-create` - Create issue
- `/work:init` - Configure work plugin
</NOTES>
