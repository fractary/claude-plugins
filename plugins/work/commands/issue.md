---
name: fractary-work:issue
description: "[DEPRECATED] Create, fetch, update, search, and manage work items - Use /work:issue-create, /work:issue-fetch, /work:issue-list, /work:issue-update, /work:issue-assign, or /work:issue-search instead"
model: claude-haiku-4-5
argument-hint: create <title> [--type <type>] [--body <text>] | fetch <number> | list [--state <state>] [--label <label>] | update <number> [--title <title>] [--body <text>] | assign <number> <user> | search <query>
---

<DEPRECATION_NOTICE>
⚠️ **THIS COMMAND IS DEPRECATED**

This multi-function command has been split into focused single-purpose commands for better usability:

- `/work:issue-create` - Create a new work item
- `/work:issue-fetch` - Fetch and display issue details
- `/work:issue-list` - List issues with filtering
- `/work:issue-update` - Update issue title or description
- `/work:issue-assign` - Assign issue to a user
- `/work:issue-search` - Search issues by keyword

**Why this change?**
- Simpler command structure (no subcommands)
- Shorter argument hints that fit on screen
- Better discoverability through tab completion
- Consistent with Unix philosophy: do one thing well

**Migration:**
- `/work:issue create "title"` → `/work:issue-create "title"`
- `/work:issue fetch 123` → `/work:issue-fetch 123`
- `/work:issue list --state open` → `/work:issue-list --state open`
- `/work:issue update 123 --title "new"` → `/work:issue-update 123 --title "new"`
- `/work:issue assign 123 @me` → `/work:issue-assign 123 @me`
- `/work:issue search "query"` → `/work:issue-search "query"`

This command will be removed in the next major version. Please update your workflows to use the new single-purpose commands.
</DEPRECATION_NOTICE>

<CONTEXT>
You are the work:issue command router for the fractary-work plugin.
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
   - Extract subcommand (create, fetch, list, update, assign, search)
   - Parse required and optional arguments
   - Validate required arguments are present

2. **Build structured request**
   - Map subcommand to operation name
   - Package parameters
   - **For create subcommand**: Convert `--type` to label format
     - If `--type feature` provided, add "type: feature" to labels
     - If `--type bug` provided, add "type: bug" to labels
     - If `--type chore` provided, add "type: chore" to labels
     - If `--type patch` provided, add "type: patch" to labels
     - Merge with any additional `--label` flags into comma-separated string
     - Remove the "type" parameter - only pass "labels" to agent

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
- **Example**: `--body "This is a description"` ✅
- **Wrong**: `--body This is a description` ❌

### Quote Usage

**Always use quotes for multi-word values:**
```bash
✅ /work:issue create "Title with spaces" --body "Description with spaces"
✅ /work:issue update 123 --title "New title here"
✅ /work:issue create "Bug fix" --type bug --label high-priority

❌ /work:issue create Title with spaces --body Description with spaces
❌ /work:issue update 123 --title New title here
```

**Single-word values don't require quotes:**
```bash
✅ /work:issue create "Title" --type feature
✅ /work:issue list --state open
✅ /work:issue fetch 123
```

**Labels cannot contain spaces:**
```bash
✅ /work:issue create "Title" --label urgent --label high-priority
❌ /work:issue create "Title" --label "high priority"  # Spaces not supported in label values
```

Use hyphens or underscores instead: `high-priority`, `high_priority`
</ARGUMENT_SYNTAX>

<ARGUMENT_PARSING>
## Subcommands

### create <title> [--type <type>] [--body <text>] [--label <label>] [--milestone <milestone>] [--assignee <user>]
**Purpose**: Create a new work item

**Required Arguments**:
- `title`: Issue title

**Optional Arguments**:
- `--type`: Issue type (feature|bug|chore|patch, default: feature) - Automatically converted to "type: <value>" label
- `--body`: Issue description
- `--label`: Additional labels (can be repeated, space-separated values not allowed)
- `--milestone`: Milestone name or number
- `--assignee`: User to assign (use @me for yourself)

**Maps to**: create-issue

**Type Conversion**: The `--type` flag is automatically converted to a label in the format "type: <value>". For example, `--type feature` becomes the label `"type: feature"`. This label is then merged with any additional `--label` flags.

**Example**:
```
/work:issue create "Add CSV export" --type feature --body "Allow users to export data"
→ Invoke agent with {"operation": "create-issue", "parameters": {"title": "Add CSV export", "description": "Allow users to export data", "labels": "type: feature"}}
```

**Example with additional labels**:
```
/work:issue create "Fix login bug" --type bug --label urgent --label security
→ Invoke agent with {"operation": "create-issue", "parameters": {"title": "Fix login bug", "labels": "type: bug,urgent,security"}}
```

### fetch <number>
**Purpose**: Fetch and display issue details

**Required Arguments**:
- `number`: Issue number

**Maps to**: fetch-issue

**Example**:
```
/work:issue fetch 123
→ Invoke agent with {"operation": "fetch-issue", "parameters": {"issue_number": "123"}}
```

### list [--state <state>] [--label <label>] [--assignee <user>] [--milestone <milestone>] [--limit <n>]
**Purpose**: List issues with optional filtering

**Optional Arguments**:
- `--state`: Filter by state (open|closed|all, default: open)
- `--label`: Filter by label
- `--assignee`: Filter by assignee (@me for yourself)
- `--milestone`: Filter by milestone
- `--limit`: Maximum number of issues (default: 30)

**Maps to**: list-issues

**Example**:
```
/work:issue list --state open --label bug
→ Invoke agent with {"operation": "list-issues", "parameters": {"state": "open", "labels": ["bug"]}}
```

### update <number> [--title <title>] [--body <text>]
**Purpose**: Update issue title or description

**Required Arguments**:
- `number`: Issue number

**Optional Arguments**:
- `--title`: New title
- `--body`: New description

**Maps to**: update-issue

**Example**:
```
/work:issue update 123 --title "New title"
→ Invoke agent with {"operation": "update-issue", "parameters": {"issue_number": "123", "title": "New title"}}
```

### assign <number> <user>
**Purpose**: Assign issue to a user

**Required Arguments**:
- `number`: Issue number
- `user`: Username (use @me for yourself, @username for specific user)

**Maps to**: assign-issue

**Example**:
```
/work:issue assign 123 @me
→ Invoke agent with {"operation": "assign-issue", "parameters": {"issue_number": "123", "assignee": "current_user"}}
```

### search <query> [--state <state>] [--limit <n>]
**Purpose**: Search issues by keyword

**Required Arguments**:
- `query`: Search query

**Optional Arguments**:
- `--state`: Filter by state (open|closed|all, default: all)
- `--limit`: Maximum results (default: 20)

**Maps to**: search-issues

**Example**:
```
/work:issue search "authentication"
→ Invoke agent with {"operation": "search-issues", "parameters": {"query": "authentication", "state": "all"}}
```
</ARGUMENT_PARSING>

<EXAMPLES>
## Usage Examples

```bash
# Create a new feature issue
/work:issue create "Add CSV export feature" --type feature

# Create a bug with description
/work:issue create "Fix login timeout" --type bug --body "Users logged out after 5 minutes"

# Fetch issue details
/work:issue fetch 123

# List open issues
/work:issue list
/work:issue list --state open

# List issues by label
/work:issue list --label bug

# Update issue title
/work:issue update 123 --title "Fix authentication timeout bug"

# Assign issue to yourself
/work:issue assign 123 @me

# Search for issues
/work:issue search "authentication"
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
2. Route to the appropriate skill (issue-creator, issue-fetcher, issue-updater, etc.)
3. Execute the platform-specific operation (GitHub/Jira/Linear)
4. Return structured results

## Supported Operations

- `create-issue` - Create new work item
- `fetch-issue` - Fetch issue details
- `list-issues` - List issues with filtering
- `update-issue` - Update issue title or description
- `assign-issue` - Assign issue to user
- `search-issues` - Search issues by keyword

## Type Conversion

**IMPORTANT**: The `--type` flag must be converted to a label before sending to the agent.

When the user provides `--type <value>`, convert it to `"type: <value>"` label format and merge with any additional `--label` flags:

- `--type feature` → `"type: feature"` label
- `--type bug` → `"type: bug"` label
- `--type chore` → `"type: chore"` label
- `--type patch` → `"type: patch"` label

Example: `/work:issue create "Title" --type bug --label urgent` becomes:
```json
{
  "operation": "create-issue",
  "parameters": {
    "title": "Title",
    "labels": "type: bug,urgent"
  }
}
```
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Missing required argument**:
```
Error: title is required
Usage: /work:issue create <title> [--type <type>]
```

**Invalid subcommand**:
```
Error: Unknown subcommand: invalid
Available: create, fetch, list, update, assign, search
```

**Missing issue number**:
```
Error: issue number is required
Usage: /work:issue fetch <number>
```
</ERROR_HANDLING>

<NOTES>
## Issue Types

The work plugin supports these universal issue types:
- **feature**: New functionality or enhancement
- **bug**: Bug fix or defect
- **chore**: Maintenance tasks, refactoring, dependencies
- **patch**: Urgent fixes, hotfixes, security patches

These map to platform-specific types automatically:
- **GitHub**: Uses labels (type: feature, type: bug, etc.)
- **Jira**: Uses issue types (Story, Bug, Task)
- **Linear**: Uses issue types and labels

## Platform Support

This command works with:
- GitHub Issues
- Jira Cloud
- Linear

Platform is configured via `/work:init` and stored in `.fractary/plugins/work/config.json`.

## See Also

For detailed documentation, see: [/docs/commands/issue.md](../../../docs/commands/work-issue.md)

Related commands:
- `/work:comment` - Manage issue comments
- `/work:state` - Manage issue states
- `/work:label` - Manage issue labels
- `/work:milestone` - Manage milestones
- `/work:init` - Configure work plugin
</NOTES>
