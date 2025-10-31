---
name: fractary-work:milestone
description: Create, list, and manage milestones for release planning
argument-hint: create <title> [--due <date>] [--description <text>] | list [--state <state>] | set <issue_number> <milestone> | remove <issue_number>
---

<CONTEXT>
You are the work:milestone command router for the fractary-work plugin.
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
   - Extract subcommand (create, list, set, remove, close)
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

### create <title> [--due <date>] [--description <text>] [--state <state>]
**Purpose**: Create a new milestone

**Required Arguments**:
- `title`: Milestone title

**Optional Arguments**:
- `--due`: Due date (YYYY-MM-DD format)
- `--description`: Milestone description
- `--state`: Initial state (open|closed, default: open)

**Maps to**: create-milestone

**Example**:
```
/work:milestone create "v2.0 Release" --due 2025-12-31 --description "Major release"
→ Invoke agent with {"operation": "create-milestone", "parameters": {"title": "v2.0 Release", "due_date": "2025-12-31", "description": "Major release"}}
```

### list [--state <state>] [--sort <sort>]
**Purpose**: List milestones with optional filtering

**Optional Arguments**:
- `--state`: Filter by state (open|closed|all, default: open)
- `--sort`: Sort order (due_date|completeness|title, default: due_date)

**Maps to**: list-milestones

**Example**:
```
/work:milestone list
→ Invoke agent with {"operation": "list-milestones", "parameters": {"state": "open"}}
```

### set <issue_number> <milestone>
**Purpose**: Set milestone on an issue

**Required Arguments**:
- `issue_number`: Issue number
- `milestone`: Milestone title or number

**Maps to**: set-milestone

**Example**:
```
/work:milestone set 123 "v1.0 Release"
→ Invoke agent with {"operation": "set-milestone", "parameters": {"issue_number": "123", "milestone": "v1.0 Release"}}
```

### remove <issue_number>
**Purpose**: Remove milestone from an issue

**Required Arguments**:
- `issue_number`: Issue number

**Maps to**: remove-milestone

**Example**:
```
/work:milestone remove 123
→ Invoke agent with {"operation": "remove-milestone", "parameters": {"issue_number": "123"}}
```

### close <milestone_id> [--comment <text>]
**Purpose**: Close a completed milestone

**Required Arguments**:
- `milestone_id`: Milestone ID or title

**Optional Arguments**:
- `--comment`: Comment to add when closing

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
