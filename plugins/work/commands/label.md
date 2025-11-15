---
name: fractary-work:label
description: "[DEPRECATED] Add, remove, and manage labels on work items - Use /work:label-add, /work:label-remove, /work:label-list, or /work:label-set instead"
argument-hint: add <number> <label> | remove <number> <label> | list <number> | set <number> <label1> <label2> ...
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/work:label-add` - Add a label to an issue
- `/work:label-remove` - Remove a label from an issue
- `/work:label-list` - List all labels on an issue
- `/work:label-set` - Set exact labels on issue (replaces all)

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/work:label add 123 bug` → `/work:label-add 123 bug`
- `/work:label remove 123 wontfix` → `/work:label-remove 123 wontfix`
- `/work:label list 123` → `/work:label-list 123`
- `/work:label set 123 bug urgent` → `/work:label-set 123 bug urgent`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the work:label command router for the fractary-work plugin.
Your role is to parse user input and invoke the work-manager agent with the appropriate request.

**DEPRECATION WARNING:** Before proceeding, inform the user that this command is deprecated and they should use the new single-purpose commands instead.
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
   - Extract subcommand (add, remove, list, set)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters

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
- **Example**: `--description "High priority items"` ✅
- **Wrong**: `--description High priority items` ❌

### Quote Usage

**Label names cannot contain spaces:**
```bash
✅ /work:label add 123 high-priority
✅ /work:label add 123 urgent
✅ /work:label set 123 bug high-priority reviewed

❌ /work:label add 123 "high priority"  # Spaces not supported in label names
```

**Use hyphens or underscores instead:**
- `high-priority` ✅
- `high_priority` ✅
- `high priority` ❌

**Multi-word descriptions need quotes:**
```bash
✅ /work:label add 123 urgent --description "Requires immediate attention"
❌ /work:label add 123 urgent --description Requires immediate attention
```

**The set subcommand takes multiple space-separated labels:**
```bash
✅ /work:label set 123 bug high-priority security
✅ /work:label set 123 feature enhancement
```
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### add <number> <label> [--color <hex>] [--description <text>]
**Purpose**: Add a label to an issue

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `label` (string): Label name to add (no spaces, use hyphens/underscores). Examples: "bug", "high-priority", "needs_review"

**Optional Arguments**:
- `--color` (string): Label color as hex code for label creation if label doesn't exist (e.g., "ff0000" for red, "00ff00" for green). No # prefix needed
- `--description` (string): Label description for label creation if label doesn't exist, use quotes if multi-word (e.g., "High priority items")

**Maps to**: add-label

**Example**:
```
/work:label add 123 urgent
→ Invoke agent with {"operation": "add-label", "parameters": {"issue_number": "123", "label": "urgent"}}
```

### remove <number> <label>
**Purpose**: Remove a label from an issue

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `label` (string): Label name to remove (exact match required). Examples: "wontfix", "duplicate"

**Maps to**: remove-label

**Example**:
```
/work:label remove 123 wontfix
→ Invoke agent with {"operation": "remove-label", "parameters": {"issue_number": "123", "label": "wontfix"}}
```

### list <number>
**Purpose**: List all labels on an issue

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")

**Maps to**: list-labels

**Example**:
```
/work:label list 123
→ Invoke agent with {"operation": "list-labels", "parameters": {"issue_number": "123"}}
```

### set <number> <label1> <label2> ...
**Purpose**: Set exact labels on an issue (replaces all existing labels)

**Required Arguments**:
- `number` (number): Issue number (e.g., 123, not "#123")
- `labels` (string...): Space-separated list of label names (no spaces in individual labels). Example: `bug high-priority reviewed`

**Maps to**: set-labels

**Example**:
```
/work:label set 123 bug high-priority reviewed
→ Invoke agent with {"operation": "set-labels", "parameters": {"issue_number": "123", "labels": ["bug", "high-priority", "reviewed"]}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Add a single label
/work:label add 123 bug

# Add multiple labels (one at a time)
/work:label add 123 urgent
/work:label add 123 security

# Remove a label
/work:label remove 123 wontfix

# List all labels on an issue
/work:label list 123

# Set exact labels (replaces all existing)
/work:label set 123 bug high-priority security
```
</EXAMPLES>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the work-manager agent with a structured request.

Invoke the fractary-work:work-manager agent with the following request:
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
1. Validate the request
2. Route to the appropriate skill (label-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results

## Supported Operations

- `add-label` - Add label to issue
- `remove-label` - Remove label from issue
- `list-labels` - List labels on issue
- `set-labels` - Set exact labels (replace all)
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing issue number**:
```
Error: issue_number is required
Usage: /work:label add <number> <label>
```

**Missing label name**:
```
Error: label name is required
Usage: /work:label add <number> <label>
```

**Label not found**:
```
Error: Label 'nonexistent' not found on issue #123
Current labels: bug, feature
```
</ERROR_HANDLING>

<NOTES>
## Common Labels

Standard labels include:
- **Type**: bug, feature, enhancement, documentation, chore
- **Priority**: critical, high-priority, low-priority
- **Status**: in-progress, in-review, blocked, ready
- **Area**: frontend, backend, api, ui, security, performance

## FABER Labels

FABER workflows use special labels:
- `faber-in-progress` - Issue in FABER workflow
- `faber-in-review` - Awaiting review
- `faber-completed` - Successfully completed
- `faber-error` - Workflow encountered error

## Platform Support

This command works with:
- GitHub Issues (labels have colors and descriptions)
- Jira Cloud (simple text tags)
- Linear (labels have colors, team-specific)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/work-label.md](../../../docs/commands/work-label.md)

Related commands:
- `/work:issue` - Manage issues
- `/work:state` - Manage issue states
- `/work:milestone` - Manage milestones
- `/work:init` - Configure work plugin
</NOTES>
