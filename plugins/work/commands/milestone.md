---
name: fractary-work:milestone
description: "[DEPRECATED] Create, list, and manage milestones for release planning - Use /work:milestone-create, /work:milestone-list, /work:milestone-set, /work:milestone-remove, or /work:milestone-close instead"
model: claude-haiku-4-5
argument-hint: create <title> [--due <date>] [--description <text>] | list [--state <state>] | set <issue_number> <milestone> | remove <issue_number> | close <milestone_id>
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/work:milestone-create` - Create a new milestone
- `/work:milestone-list` - List milestones with filtering
- `/work:milestone-set` - Set milestone on an issue
- `/work:milestone-remove` - Remove milestone from an issue
- `/work:milestone-close` - Close a completed milestone

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/work:milestone create "v1.0"` → `/work:milestone-create "v1.0"`
- `/work:milestone list` → `/work:milestone-list`
- `/work:milestone set 123 "v1.0"` → `/work:milestone-set 123 "v1.0"`
- `/work:milestone remove 123` → `/work:milestone-remove 123`
- `/work:milestone close "v1.0"` → `/work:milestone-close "v1.0"`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the work:milestone command router for the fractary-work plugin.
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
   - Extract subcommand (create, list, set, remove, close)
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
- **Example**: `--description "Major release with new features"` ✅
- **Wrong**: `--description Major release with new features` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:milestone create "v2.0 Release" --due 2025-12-31
✅ /work:milestone create "Sprint 5" --description "November sprint goals"
✅ /work:milestone set 123 "v1.0 Release"

❌ /work:milestone create v2.0 Release --due 2025-12-31
❌ /work:milestone set 123 v1.0 Release
```

**Single-word values don't require quotes:**
```bash
✅ /work:milestone create v1.0 --due 2025-12-31
✅ /work:milestone list --state open
```

**Date format:**
- Use YYYY-MM-DD format: "2025-12-31" ✅
- NOT: "12/31/2025" ❌ or "Dec 31 2025" ❌

**State values are exact keywords:**
- Use exactly: `open`, `closed`, `all`
- NOT: `active`, `completed`, `finished`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### create <title> [--due <date>] [--description <text>] [--state <state>]
**Purpose**: Create a new milestone

**Required Arguments**:
- `title` (string): Milestone title, use quotes if multi-word (e.g., "v2.0 Release", "Sprint 5")

**Optional Arguments**:
- `--due` (string): Due date in YYYY-MM-DD format (e.g., "2025-12-31"). Use quotes for the date
- `--description` (string): Milestone description, use quotes if multi-word (e.g., "Major release with breaking changes")
- `--state` (enum): Initial state. Must be one of: `open`, `closed` (default: open)

**Maps to**: create-milestone

**Example**:
```
/work:milestone create "v2.0 Release" --due 2025-12-31 --description "Major release"
→ Invoke agent with {"operation": "create-milestone", "parameters": {"title": "v2.0 Release", "due_date": "2025-12-31", "description": "Major release"}}
```

### list [--state <state>] [--sort <sort>]
**Purpose**: List milestones with optional filtering

**Optional Arguments**:
- `--state` (enum): Filter by state. Must be one of: `open`, `closed`, `all` (default: open)
- `--sort` (enum): Sort order. Must be one of: `due_date` (by due date), `completeness` (by completion %), `title` (alphabetically) (default: due_date)

**Maps to**: list-milestones

**Example**:
```
/work:milestone list
→ Invoke agent with {"operation": "list-milestones", "parameters": {"state": "open"}}
```

### set <issue_number> <milestone>
**Purpose**: Set milestone on an issue

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")
- `milestone` (string or number): Milestone title or number, use quotes if multi-word (e.g., "v1.0 Release" or just "1" for milestone #1)

**Maps to**: set-milestone

**Example**:
```
/work:milestone set 123 "v1.0 Release"
→ Invoke agent with {"operation": "set-milestone", "parameters": {"issue_number": "123", "milestone": "v1.0 Release"}}
```

### remove <issue_number>
**Purpose**: Remove milestone from an issue

**Required Arguments**:
- `issue_number` (number): Issue number (e.g., 123, not "#123")

**Maps to**: remove-milestone

**Example**:
```
/work:milestone remove 123
→ Invoke agent with {"operation": "remove-milestone", "parameters": {"issue_number": "123"}}
```

### close <milestone_id> [--comment <text>]
**Purpose**: Close a completed milestone

**Required Arguments**:
- `milestone_id` (string or number): Milestone ID or title, use quotes if multi-word (e.g., "v1.0 Release" or "1" for milestone #1)

**Optional Arguments**:
- `--comment` (string): Comment to add when closing, use quotes if multi-word (e.g., "All issues completed successfully")

**Maps to**: close-milestone

**Example**:
```
/work:milestone close "v1.0 Release"
→ Invoke agent with {"operation": "close-milestone", "parameters": {"milestone": "v1.0 Release"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create a milestone
/work:milestone create "v1.0 Release" --due 2025-12-31

# Create with description
/work:milestone create "Sprint 5" --due 2025-11-15 --description "November sprint goals"

# List all milestones
/work:milestone list

# List open milestones only
/work:milestone list --state open

# Set milestone on issue
/work:milestone set 123 "v1.0 Release"

# Remove milestone from issue
/work:milestone remove 123

# Close completed milestone
/work:milestone close "v1.0 Release"
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
2. Route to the appropriate skill (milestone-manager)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results

## Supported Operations

- `create-milestone` - Create new milestone
- `list-milestones` - List milestones with filtering
- `set-milestone` - Set milestone on issue
- `remove-milestone` - Remove milestone from issue
- `close-milestone` - Close completed milestone
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing title**:
```
Error: milestone title is required
Usage: /work:milestone create <title>
```

**Invalid date format**:
```
Error: Invalid date format: 2025/12/31
Use YYYY-MM-DD format (e.g., 2025-12-31)
```

**Milestone not found**:
```
Error: Milestone not found: "v3.0 Release"
List milestones: /work:milestone list --state all
```
</ERROR_HANDLING>

<NOTES>
## Use Cases

Milestones are ideal for:
- **Release Planning**: Track releases (v1.0, v2.0)
- **Sprint Management**: Manage sprints (Sprint 5, Sprint 6)
- **Feature Tracking**: Group related features

## Naming Conventions

**Semantic Versioning**: v1.0.0, v1.1.0, v1.0.1
**Time-Based**: Sprint 5, Q4 2025, November 2025
**Feature-Based**: Authentication Overhaul, Mobile App Launch

## Platform Support

This command works with:
- GitHub (repository-specific milestones)
- Jira (maps to Versions or Sprints)
- Linear (maps to Projects or Cycles)

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## FABER Integration

FABER workflows can automatically assign issues to release milestones and update milestone progress during the Release phase.

## See Also

For detailed documentation, see: [/docs/commands/work-milestone.md](../../../docs/commands/work-milestone.md)

Related commands:
- `/work:issue` - Manage issues
- `/work:label` - Manage labels
- `/work:state` - Manage issue states
- `/work:init` - Configure work plugin
</NOTES>
