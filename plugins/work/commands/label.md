---
name: fractary-work:label
description: Add, remove, and manage labels on work items
argument-hint: add <number> <label> | remove <number> <label> | list <number> | set <number> <label1> <label2> ...
---

# /work:label - Label Management Command

Add, remove, and manage labels on work items across GitHub Issues, Jira, and Linear.

## Usage

```bash
# Add a label
/work:label add <number> <label>

# Remove a label
/work:label remove <number> <label>

# List labels on an issue
/work:label list <number>

# Set labels (replace all)
/work:label set <number> <label1> <label2> ...
```

## Examples

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

## Command Implementation

This command parses user input and invokes the work-manager agent with appropriate operations.

### Subcommand: add

**Purpose**: Add a label to an issue

**Arguments**:
- `number` (required): Issue number
- `label` (required): Label name to add
- `--color` (optional): Label color (hex code, for label creation)
- `--description` (optional): Label description (for label creation)

**Workflow**:
1. Parse issue number and label name
2. Validate both are provided
3. Invoke agent: add-label operation
4. Display success message

**Example Flow**:
```
User: /work:label add 123 urgent

1. Add label:
   {
     "operation": "add-label",
     "parameters": {
       "issue_number": "123",
       "label": "urgent"
     }
   }

2. Display:
   ✅ Label added successfully

   Issue #123: Fix authentication bug
   Added label: urgent
   Current labels: bug, urgent, security

   View issue: /work:issue fetch 123
```

### Subcommand: remove

**Purpose**: Remove a label from an issue

**Arguments**:
- `number` (required): Issue number
- `label` (required): Label name to remove

**Workflow**:
1. Parse issue number and label name
2. Validate label exists on issue
3. Invoke agent: remove-label operation
4. Display success message

**Example Flow**:
```
User: /work:label remove 123 wontfix

1. Remove label:
   {
     "operation": "remove-label",
     "parameters": {
       "issue_number": "123",
       "label": "wontfix"
     }
   }

2. Display:
   ✅ Label removed successfully

   Issue #123: Fix authentication bug
   Removed label: wontfix
   Current labels: bug, urgent

   View issue: /work:issue fetch 123
```

### Subcommand: list

**Purpose**: List all labels on an issue

**Arguments**:
- `number` (required): Issue number

**Workflow**:
1. Parse issue number
2. Invoke agent: list-labels operation
3. Format and display labels

**Example Flow**:
```
User: /work:label list 123

1. List labels:
   {
     "operation": "list-labels",
     "parameters": {
       "issue_number": "123"
     }
   }

2. Display:
   Labels on Issue #123:
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   bug              (defects and errors)
   high-priority    (needs immediate attention)
   security         (security-related issues)
   in-progress      (currently being worked on)

   Total: 4 labels

   Add label: /work:label add 123 <label>
   Remove label: /work:label remove 123 <label>
```

### Subcommand: set

**Purpose**: Set exact labels on an issue (replaces all existing labels)

**Arguments**:
- `number` (required): Issue number
- `labels` (required): Space-separated list of labels

**Workflow**:
1. Parse issue number and label list
2. Invoke agent: set-labels operation
3. Display success message with label diff

**Example Flow**:
```
User: /work:label set 123 bug high-priority reviewed

1. Set labels:
   {
     "operation": "set-labels",
     "parameters": {
       "issue_number": "123",
       "labels": ["bug", "high-priority", "reviewed"]
     }
   }

2. Display:
   ✅ Labels updated successfully

   Issue #123: Fix authentication bug
   Previous labels: bug, urgent, security, in-progress
   New labels: bug, high-priority, reviewed

   Changes:
   + high-priority, reviewed
   - urgent, security, in-progress

   View issue: /work:issue fetch 123
```

## Common Labels

### Standard Labels

Most projects use these standard labels:

**Type Labels**:
- `bug` - Bug fixes and defects
- `feature` - New features
- `enhancement` - Improvements to existing features
- `documentation` - Documentation updates
- `chore` - Maintenance and tooling

**Priority Labels**:
- `critical` - Critical priority
- `high-priority` - High priority
- `low-priority` - Low priority

**Status Labels**:
- `in-progress` - Currently being worked on
- `in-review` - Under review
- `blocked` - Blocked by external dependency
- `ready` - Ready to start

**Area Labels**:
- `frontend` - Frontend code
- `backend` - Backend code
- `api` - API changes
- `ui` - User interface
- `security` - Security-related
- `performance` - Performance improvements

### FABER Labels

FABER workflows use special labels for tracking:

- `faber-in-progress` - Issue in FABER workflow
- `faber-in-review` - Awaiting review
- `faber-completed` - Successfully completed
- `faber-error` - Workflow encountered error

These are managed automatically by FABER but can be manually added if needed.

## Error Handling

**Missing Issue Number**:
```
Error: issue_number is required
Usage: /work:label add <number> <label>
```

**Missing Label Name**:
```
Error: label name is required
Usage: /work:label add <number> <label>
```

**Invalid Issue Number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Label Already Exists**:
```
Warning: Label 'bug' already exists on issue #123
No action taken
```

**Label Not Found**:
```
Error: Label 'nonexistent' not found on issue #123
Current labels: bug, feature
```

**Invalid Label Name**:
```
Error: Invalid label name: "invalid label!"
Label names cannot contain special characters
```

**Permission Denied**:
```
Error: Permission denied for issue #123
You may not have permission to modify labels
```

## Integration

**Called By**: User via CLI, FABER workflows

**Calls**: work-manager agent with operations:
- add-label
- remove-label
- list-labels
- set-labels

**Returns**: Human-readable output formatted for terminal display

## Platform-Specific Behavior

### GitHub Issues

- Labels have colors and descriptions
- Labels are repository-wide
- New labels created automatically if missing
- Case-sensitive label matching
- Supports emoji in label names

### Jira

- Labels are simple text tags
- No colors or descriptions
- Labels are project-wide or global
- Case-insensitive label matching
- Space-separated label list

### Linear

- Labels have colors
- Team-specific and workspace-level labels
- Labels can be organized hierarchically
- Supports issue type labels

## FABER Integration

FABER workflows automatically manage labels:

**Frame Phase**:
- Adds work type label (feature, bug, chore, patch)
- Adds `faber-in-progress` label

**Architect Phase**:
- Maintains `faber-in-progress`
- May add architecture-related labels

**Build Phase**:
- Maintains `faber-in-progress`
- May add implementation labels

**Evaluate Phase**:
- Adds `faber-in-review`
- Removes `faber-in-progress`

**Release Phase**:
- Adds `faber-completed`
- Removes `faber-in-review`
- Adds version/release labels

**On Error**:
- Adds `faber-error`
- Maintains phase labels for context

## Advanced Usage

**Add Multiple Labels Sequentially**:
```bash
/work:label add 123 bug
/work:label add 123 high-priority
/work:label add 123 security
```

**Replace Labels Atomically**:
```bash
# Before: bug, urgent, in-progress
/work:label set 123 bug high-priority reviewed
# After: bug, high-priority, reviewed
```

**Create Colored Label (GitHub)**:
```bash
/work:label add 123 urgent --color ff0000 --description "Needs immediate attention"
```

**Label Organization**:
```bash
# Remove old organizational labels
/work:label remove 123 sprint-1
/work:label remove 123 Q1

# Add current labels
/work:label add 123 sprint-2
/work:label add 123 Q2
```

**Bulk Label Management**:
```bash
# Set consistent labels across related issues
/work:label set 123 bug auth high-priority
/work:label set 124 bug auth high-priority
/work:label set 125 bug auth high-priority
```

## Best Practices

1. **Use consistent naming**: Establish label conventions (lowercase, hyphens)
2. **Choose clear names**: Labels should be self-explanatory
3. **Limit label count**: Too many labels reduce effectiveness
4. **Use type labels**: Always classify issue type
5. **Use priority labels**: Indicate urgency when relevant
6. **Use area labels**: Help with filtering and assignments
7. **Remove obsolete labels**: Keep labels current with work status
8. **Document labels**: Maintain label definitions for team

## Label Naming Conventions

**Recommended Patterns**:
- `type: <name>` - Issue type (type: bug, type: feature)
- `priority: <level>` - Priority level (priority: high, priority: low)
- `area: <component>` - Code area (area: api, area: ui)
- `status: <state>` - Status (status: blocked, status: ready)

**Examples**:
```bash
/work:label add 123 "type: bug"
/work:label add 123 "priority: high"
/work:label add 123 "area: authentication"
/work:label add 123 "status: in-progress"
```

## Common Workflows

### Triage New Issue
```bash
# Classify and prioritize
/work:label add 456 bug
/work:label add 456 high-priority
/work:label add 456 api
/work:issue assign 456 @teamlead
```

### Mark as Blocked
```bash
# Indicate blocker
/work:label add 789 blocked
/work:comment create 789 "Blocked: waiting on infrastructure team"
```

### Update Priority
```bash
# Change priority
/work:label remove 123 low-priority
/work:label add 123 high-priority
/work:comment create 123 "Escalating priority due to customer impact"
```

### Organize Sprint
```bash
# Add sprint label
/work:label add 123 sprint-5
/work:label add 123 Q4-2025
```

## Notes

- Labels are case-sensitive on most platforms
- Label colors and descriptions are platform-specific
- FABER manages workflow labels automatically
- Labels support filtering in issue lists
- Some platforms limit label count per issue
- Label names may have character restrictions
- Repository admins can define standard labels
- Labels enable automated workflows and routing

## See Also

- [/work:issue](issue.md) - Manage issues
- [/work:state](state.md) - Manage issue states
- [/work:milestone](milestone.md) - Manage milestones
- [Work Plugin README](../README.md) - Complete documentation
