---
name: fractary-work:milestone
description: Create, list, and manage milestones for release planning
argument-hint: create <title> [--due <date>] [--description <text>] | list [--state <state>] | set <issue_number> <milestone> | remove <issue_number>
---

# /work:milestone - Milestone Management Command

Create, list, and manage milestones for release planning and sprint management across GitHub, Jira, and Linear.

## Usage

```bash
# Create a milestone
/work:milestone create <title> [--due <date>] [--description <text>]

# List milestones
/work:milestone list [--state <state>]

# Set milestone on an issue
/work:milestone set <issue_number> <milestone>

# Remove milestone from an issue
/work:milestone remove <issue_number>

# Close a milestone
/work:milestone close <milestone_id>
```

## Examples

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
/work:milestone close 5
```

## Command Implementation

This command parses user input and invokes the work-manager agent with appropriate operations.

### Subcommand: create

**Purpose**: Create a new milestone

**Arguments**:
- `title` (required): Milestone title
- `--due` (optional): Due date (YYYY-MM-DD format)
- `--description` (optional): Milestone description
- `--state` (optional): Initial state (open|closed, default: open)

**Workflow**:
1. Parse milestone title and options
2. Validate title is non-empty
3. Parse and validate due date if provided
4. Invoke agent: create-milestone operation
5. Display created milestone details

**Example Flow**:
```
User: /work:milestone create "v2.0 Release" --due 2025-12-31 --description "Major release with new features"

1. Create milestone:
   {
     "operation": "create-milestone",
     "parameters": {
       "title": "v2.0 Release",
       "due_date": "2025-12-31",
       "description": "Major release with new features"
     }
   }

2. Display:
   ✅ Milestone created successfully

   Milestone: v2.0 Release
   Due date: December 31, 2025
   State: open
   Issues: 0 / 0 (0% complete)

   Description:
   Major release with new features

   URL: https://github.com/owner/repo/milestone/5

   Add issues: /work:milestone set <issue_number> "v2.0 Release"
```

### Subcommand: list

**Purpose**: List milestones with optional filtering

**Arguments**:
- `--state` (optional): Filter by state (open|closed|all, default: open)
- `--sort` (optional): Sort order (due_date|completeness|title, default: due_date)

**Workflow**:
1. Parse filter options
2. Invoke agent: list-milestones operation
3. Format and display milestone table

**Example Flow**:
```
User: /work:milestone list

1. List milestones:
   {
     "operation": "list-milestones",
     "parameters": {
       "state": "open"
     }
   }

2. Display:
   Open Milestones (3 found):
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   v1.0 Release        Due: 2025-11-30    12/15 (80%)
   Sprint 5            Due: 2025-11-15     3/5  (60%)
   v2.0 Release        Due: 2025-12-31     0/0  (0%)

   Set milestone: /work:milestone set <issue> <milestone>
   View details: /work:milestone show <milestone>
```

### Subcommand: set

**Purpose**: Set milestone on an issue

**Arguments**:
- `issue_number` (required): Issue number
- `milestone` (required): Milestone title or number

**Workflow**:
1. Parse issue number and milestone identifier
2. Resolve milestone title to milestone ID
3. Invoke agent: set-milestone operation
4. Display success message

**Example Flow**:
```
User: /work:milestone set 123 "v1.0 Release"

1. Set milestone:
   {
     "operation": "set-milestone",
     "parameters": {
       "issue_number": "123",
       "milestone": "v1.0 Release"
     }
   }

2. Display:
   ✅ Milestone set successfully

   Issue #123: Add CSV export feature
   Milestone: v1.0 Release (Due: 2025-11-30)
   Progress: 13/15 issues (87%)

   View issue: /work:issue fetch 123
   View milestone: /work:milestone show "v1.0 Release"
```

### Subcommand: remove

**Purpose**: Remove milestone from an issue

**Arguments**:
- `issue_number` (required): Issue number

**Workflow**:
1. Parse issue number
2. Invoke agent: remove-milestone operation
3. Display success message

**Example Flow**:
```
User: /work:milestone remove 123

1. Remove milestone:
   {
     "operation": "remove-milestone",
     "parameters": {
       "issue_number": "123"
     }
   }

2. Display:
   ✅ Milestone removed successfully

   Issue #123: Add CSV export feature
   Previous milestone: v1.0 Release
   Current milestone: (none)

   View issue: /work:issue fetch 123
```

### Subcommand: close

**Purpose**: Close a completed milestone

**Arguments**:
- `milestone_id` (required): Milestone ID or title
- `--comment` (optional): Comment to add when closing

**Workflow**:
1. Parse milestone identifier
2. Validate milestone exists
3. Invoke agent: close-milestone operation
4. Display closure summary

**Example Flow**:
```
User: /work:milestone close "v1.0 Release"

1. Close milestone:
   {
     "operation": "close-milestone",
     "parameters": {
       "milestone": "v1.0 Release"
     }
   }

2. Display:
   ✅ Milestone closed successfully

   Milestone: v1.0 Release
   Due date: 2025-11-30
   Completed: 2025-11-28 (2 days early)
   Final stats: 15/15 issues (100%)

   All issues in this milestone are now complete!
```

## Use Cases

### Release Planning

Milestones are ideal for tracking releases:

```bash
# Create release milestone
/work:milestone create "v1.0 Release" --due 2025-12-31 --description "First major release"

# Add issues to release
/work:milestone set 123 "v1.0 Release"
/work:milestone set 124 "v1.0 Release"
/work:milestone set 125 "v1.0 Release"

# Track progress
/work:milestone list

# Close when done
/work:milestone close "v1.0 Release"
```

### Sprint Management

Track sprint work with milestones:

```bash
# Create sprint
/work:milestone create "Sprint 5" --due 2025-11-15 --description "Two-week sprint: Nov 1-15"

# Add sprint work
/work:milestone set 200 "Sprint 5"
/work:milestone set 201 "Sprint 5"
/work:milestone set 202 "Sprint 5"

# Review progress
/work:milestone list --state open

# Close sprint
/work:milestone close "Sprint 5"
```

### Feature Tracking

Group related features:

```bash
# Create feature milestone
/work:milestone create "Authentication System" --description "Complete auth overhaul"

# Add all auth issues
/work:milestone set 300 "Authentication System"
/work:milestone set 301 "Authentication System"
/work:milestone set 302 "Authentication System"
```

## Error Handling

**Missing Title**:
```
Error: milestone title is required
Usage: /work:milestone create <title>
```

**Invalid Date Format**:
```
Error: Invalid date format: 2025/12/31
Use YYYY-MM-DD format (e.g., 2025-12-31)
```

**Milestone Not Found**:
```
Error: Milestone not found: "v3.0 Release"
List milestones: /work:milestone list --state all
```

**Issue Not Found**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Milestone Already Exists**:
```
Error: Milestone already exists: "v1.0 Release"
Choose a different title or use existing milestone
```

**Permission Denied**:
```
Error: Permission denied
You may not have permission to create/modify milestones
```

## Integration

**Called By**: User via CLI, FABER workflows

**Calls**: work-manager agent with operations:
- create-milestone
- list-milestones
- set-milestone
- remove-milestone
- close-milestone

**Returns**: Human-readable output formatted for terminal display

## Platform-Specific Behavior

### GitHub

- Milestones are repository-specific
- Due dates optional
- Track open/closed issue counts automatically
- Completion percentage calculated automatically
- Can be sorted by due date, completeness, or name

### Jira

- Milestones map to "Versions" or "Sprints"
- Versions used for release planning
- Sprints used for agile workflows
- Due dates and start dates supported
- Release notes can be attached

### Linear

- Milestones map to "Projects" or "Cycles"
- Projects for long-term goals
- Cycles for sprint-like iterations
- Start and end dates both tracked
- Progress visualization available

## FABER Integration

FABER workflows can automatically manage milestones:

**Release Phase**:
- Assigns issues to release milestone
- Updates milestone progress
- Closes milestone when all issues complete

**Example FABER Milestone Usage**:
```bash
# FABER automatically:
# 1. Detects release milestone from config
# 2. Assigns completed work to milestone
# 3. Updates milestone progress
# 4. Closes milestone when release complete
```

## Advanced Usage

**Create Milestone Series**:
```bash
# Create quarterly milestones
/work:milestone create "Q1 2025" --due 2025-03-31
/work:milestone create "Q2 2025" --due 2025-06-30
/work:milestone create "Q3 2025" --due 2025-09-30
/work:milestone create "Q4 2025" --due 2025-12-31
```

**Bulk Milestone Assignment**:
```bash
# Assign multiple issues to sprint
/work:milestone set 100 "Sprint 5"
/work:milestone set 101 "Sprint 5"
/work:milestone set 102 "Sprint 5"
/work:milestone set 103 "Sprint 5"
```

**Track Multiple Releases**:
```bash
# List all releases
/work:milestone list --state all

# Show progress on current release
/work:milestone list --state open
```

**Milestone Cleanup**:
```bash
# Remove issues from old milestone
/work:milestone remove 200
/work:milestone remove 201

# Reassign to new milestone
/work:milestone set 200 "v2.0 Release"
/work:milestone set 201 "v2.0 Release"
```

## Best Practices

1. **Use clear naming**: Include version or sprint number
2. **Set due dates**: Helps with planning and tracking
3. **Add descriptions**: Explain milestone goals and scope
4. **Group related work**: Keep milestone focused and coherent
5. **Close completed milestones**: Keep active list manageable
6. **Track progress regularly**: Review milestone completion
7. **Plan ahead**: Create future milestones early
8. **Don't overload**: Keep milestone scope reasonable

## Milestone Naming Conventions

**Semantic Versioning**:
- `v1.0.0` - Major release
- `v1.1.0` - Minor release
- `v1.0.1` - Patch release

**Time-Based**:
- `Sprint 5` - Sprint number
- `Q4 2025` - Quarterly milestone
- `November 2025` - Monthly milestone

**Feature-Based**:
- `Authentication Overhaul`
- `Mobile App Launch`
- `API v2 Migration`

## Common Workflows

### Plan New Release
```bash
# Create milestone
/work:milestone create "v2.0" --due 2026-01-31 --description "Major feature release"

# Add planned features
/work:issue create "New dashboard" --type feature
/work:milestone set <new_issue> "v2.0"

# Track progress
/work:milestone list
```

### Sprint Planning
```bash
# Create sprint
/work:milestone create "Sprint 6" --due 2025-11-30

# Move issues from backlog
/work:milestone set 300 "Sprint 6"
/work:milestone set 301 "Sprint 6"

# Review sprint scope
/work:milestone list --state open
```

### Close Completed Milestone
```bash
# Verify all issues closed
/work:milestone list --state open

# Close milestone
/work:milestone close "v1.0"

# Create next milestone
/work:milestone create "v1.1" --due 2026-02-28
```

## Notes

- Milestones group related issues for tracking
- Completion percentage calculated from open/closed issues
- Due dates are optional but recommended
- Closed milestones remain visible for reference
- Some platforms support start dates in addition to due dates
- Milestone progress visible in issue lists
- FABER can automate milestone management
- API rate limits may apply to bulk operations

## See Also

- [/work:issue](issue.md) - Manage issues
- [/work:label](label.md) - Manage labels
- [/work:state](state.md) - Manage issue states
- [Work Plugin README](../README.md) - Complete documentation
