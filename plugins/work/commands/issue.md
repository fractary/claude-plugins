---
name: fractary-work:issue
description: Create, fetch, update, search, and manage work items
argument-hint: create <title> [--type <type>] [--body <text>] | fetch <number> | list [--state <state>] [--label <label>] | update <number> [--title <title>] [--body <text>] | assign <number> <user> | search <query>
---

# /work:issue - Issue Management Command

Create, fetch, update, search, and manage work items across GitHub Issues, Jira, and Linear.

## Usage

```bash
# Create a new issue
/work:issue create <title> [--type <type>] [--body <text>]

# Fetch issue details
/work:issue fetch <number>

# List issues
/work:issue list [--state <state>] [--label <label>]

# Update an issue
/work:issue update <number> [--title <title>] [--body <text>]

# Assign an issue
/work:issue assign <number> <user>

# Search issues
/work:issue search <query>
```

## Examples

```bash
# Create feature issue
/work:issue create "Add CSV export feature" --type feature

# Create bug with description
/work:issue create "Fix login timeout" --type bug --body "Users are being logged out after 5 minutes instead of 30"

# Fetch issue details
/work:issue fetch 123

# List open issues
/work:issue list
/work:issue list --state open

# List issues by label
/work:issue list --label bug

# Update issue title
/work:issue update 123 --title "Fix authentication timeout bug"

# Update issue body
/work:issue update 123 --body "Updated description with more details"

# Assign issue to yourself
/work:issue assign 123 @me

# Assign to specific user
/work:issue assign 123 @username

# Search for issues
/work:issue search "authentication"
```

## Command Implementation

This command parses user input and invokes the work-manager agent with appropriate operations.

### Subcommand: create

**Purpose**: Create a new work item

**Arguments**:
- `title` (required): Issue title
- `--type` (optional): Issue type (feature|bug|chore|patch, default: feature)
- `--body` (optional): Issue description
- `--label` (optional): Additional labels (can be repeated)
- `--milestone` (optional): Milestone name or number
- `--assignee` (optional): User to assign (use @me for yourself)

**Workflow**:
1. Parse arguments and extract title
2. Validate title is non-empty
3. Invoke agent: create-issue operation
4. Display created issue number and URL

**Example Flow**:
```
User: /work:issue create "Add CSV export" --type feature --body "Allow users to export data to CSV format"

1. Create issue:
   {
     "operation": "create-issue",
     "parameters": {
       "title": "Add CSV export",
       "type": "feature",
       "body": "Allow users to export data to CSV format"
     }
   }

2. Display:
   ✅ Issue created successfully

   Issue #123: Add CSV export
   Type: feature
   State: open
   URL: https://github.com/owner/repo/issues/123

   Next steps:
   - View issue: /work:issue fetch 123
   - Start work: /work:state transition 123 in_progress
```

### Subcommand: fetch

**Purpose**: Fetch and display issue details

**Arguments**:
- `number` (required): Issue number

**Workflow**:
1. Parse issue number
2. Validate number is valid integer
3. Invoke agent: fetch-issue operation
4. Format and display issue details

**Example Flow**:
```
User: /work:issue fetch 123

1. Fetch issue:
   {
     "operation": "fetch-issue",
     "parameters": {
       "issue_number": "123"
     }
   }

2. Display:
   Issue #123: Add CSV export feature
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   State: open
   Type: feature
   Assignee: @username
   Labels: feature, enhancement
   Milestone: v1.0

   Description:
   Allow users to export their data to CSV format with
   configurable columns and filtering options.

   Comments: 3
   Created: 2025-10-15
   Updated: 2025-10-20

   URL: https://github.com/owner/repo/issues/123
```

### Subcommand: list

**Purpose**: List issues with optional filtering

**Arguments**:
- `--state` (optional): Filter by state (open|closed|all, default: open)
- `--label` (optional): Filter by label
- `--assignee` (optional): Filter by assignee (@me for yourself)
- `--milestone` (optional): Filter by milestone
- `--limit` (optional): Maximum number of issues (default: 30)

**Workflow**:
1. Parse filter arguments
2. Invoke agent: list-issues operation
3. Format and display results in table format

**Example Flow**:
```
User: /work:issue list --state open --label bug

1. List issues:
   {
     "operation": "list-issues",
     "parameters": {
       "state": "open",
       "labels": ["bug"]
     }
   }

2. Display:
   Open Issues (3 found):
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   #456  Fix login timeout              @alice    bug
   #457  Fix CSV export encoding        @bob      bug, export
   #458  Fix mobile UI layout           @carol    bug, ui

   Use /work:issue fetch <number> for details
```

### Subcommand: update

**Purpose**: Update issue title or description

**Arguments**:
- `number` (required): Issue number
- `--title` (optional): New title
- `--body` (optional): New description

**Workflow**:
1. Parse issue number and update fields
2. Validate at least one field is provided
3. Invoke agent: update-issue operation
4. Display success message

**Example Flow**:
```
User: /work:issue update 123 --title "Add CSV export with filtering"

1. Update issue:
   {
     "operation": "update-issue",
     "parameters": {
       "issue_number": "123",
       "title": "Add CSV export with filtering"
     }
   }

2. Display:
   ✅ Issue updated successfully

   Issue #123: Add CSV export with filtering
   Updated: title

   View issue: /work:issue fetch 123
```

### Subcommand: assign

**Purpose**: Assign issue to a user

**Arguments**:
- `number` (required): Issue number
- `user` (required): Username (use @me for yourself, @username for specific user)

**Workflow**:
1. Parse issue number and username
2. Resolve @me to current user
3. Invoke agent: assign-issue operation
4. Display success message

**Example Flow**:
```
User: /work:issue assign 123 @me

1. Assign issue:
   {
     "operation": "assign-issue",
     "parameters": {
       "issue_number": "123",
       "assignee": "current_user"
     }
   }

2. Display:
   ✅ Issue assigned successfully

   Issue #123 assigned to: @username

   View issue: /work:issue fetch 123
```

### Subcommand: search

**Purpose**: Search issues by keyword

**Arguments**:
- `query` (required): Search query
- `--state` (optional): Filter by state (open|closed|all, default: all)
- `--limit` (optional): Maximum results (default: 20)

**Workflow**:
1. Parse search query and filters
2. Invoke agent: search-issues operation
3. Format and display results

**Example Flow**:
```
User: /work:issue search "authentication"

1. Search issues:
   {
     "operation": "search-issues",
     "parameters": {
       "query": "authentication",
       "state": "all"
     }
   }

2. Display:
   Search Results (5 found):
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   #123  Add authentication system      closed    feature
   #456  Fix authentication timeout     open      bug
   #789  Improve auth performance       open      enhancement

   Use /work:issue fetch <number> for details
```

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

## Error Handling

**Missing Required Argument**:
```
Error: title is required
Usage: /work:issue create <title> [--type <type>]
```

**Invalid Issue Number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Invalid Issue Type**:
```
Error: Invalid issue type: invalid
Valid types: feature, bug, chore, patch
```

**No Update Fields**:
```
Error: At least one update field required
Usage: /work:issue update <number> [--title <title>] [--body <text>]
```

**Invalid User**:
```
Error: User not found: @invalid
Use @me for yourself or @username for specific user
```

**Authentication Failed**:
```
Error: Authentication failed
Check your token configuration: /work:init
```

**Permission Denied**:
```
Error: Permission denied for issue #123
You may not have access to this repository/project
```

## Integration

**Called By**: User via CLI

**Calls**: work-manager agent with operations:
- create-issue
- fetch-issue
- list-issues
- update-issue
- assign-issue
- search-issues

**Returns**: Human-readable output formatted for terminal display

## Platform-Specific Behavior

### GitHub Issues

- Issue numbers are repository-specific
- Labels are used for classification
- States: open, closed
- Assignees support multiple users
- Mentions use @username format

### Jira

- Issue keys use project prefix (e.g., PROJ-123)
- Issue types map to Jira issue types
- States depend on workflow configuration
- Custom fields may be available
- Assignees use email or account ID

### Linear

- Issue identifiers use team prefix (e.g., ENG-123)
- Labels and issue types both supported
- States follow Linear workflow
- Priority levels available
- Team-specific configuration

## FABER Integration

When used within FABER workflows, the command automatically:
- Links issues to current work context
- Applies FABER labels for workflow tracking
- Updates issue state based on workflow phase
- Posts comments on state transitions

**FABER Workflow States**:
- Frame → fetch and classify issue
- Architect → update with design specs
- Build → add implementation comments
- Evaluate → update with test results
- Release → close issue on merge

## Advanced Usage

**Create with Multiple Labels**:
```bash
/work:issue create "Security audit" --type chore --label security --label audit --label high-priority
```

**Create and Assign**:
```bash
/work:issue create "Fix bug" --type bug --assignee @me
```

**List with Multiple Filters**:
```bash
/work:issue list --state open --label bug --assignee @me
```

**Update Multiple Fields**:
```bash
/work:issue update 123 --title "New title" --body "Updated description with more details"
```

**Search with State Filter**:
```bash
/work:issue search "performance" --state open
```

## Best Practices

1. **Use descriptive titles**: Clear, concise issue titles improve discoverability
2. **Choose correct type**: Helps with classification and workflow routing
3. **Provide context in body**: Include reproduction steps for bugs, requirements for features
4. **Assign appropriately**: Assign issues when starting work
5. **Keep issues focused**: One issue per feature/bug for better tracking
6. **Use labels effectively**: Add relevant labels for better organization
7. **Link related issues**: Reference related issues in descriptions

## Notes

- Issue numbers are platform-specific (GitHub: #123, Jira: PROJ-123, Linear: TEAM-123)
- All operations respect platform authentication and permissions
- Configuration is loaded from `.fractary/plugins/work/config.json`
- Issue types are universal across platforms (mapped automatically)
- States may vary by platform but follow universal patterns
- Search capabilities depend on platform API support
- Some advanced features may be platform-specific

## See Also

- [/work:comment](comment.md) - Manage issue comments
- [/work:state](state.md) - Manage issue states
- [/work:label](label.md) - Manage issue labels
- [/work:milestone](milestone.md) - Manage milestones
- [/work:init](init.md) - Configure work plugin
- [Work Plugin README](../README.md) - Complete documentation
