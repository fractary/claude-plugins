---
name: fractary-work:state
description: Manage issue lifecycle states (close, reopen, update state)
argument-hint: close <number> [--comment <text>] | reopen <number> [--comment <text>] | transition <number> <state>
---

# /work:state - State Management Command

Manage issue lifecycle states: close issues, reopen issues, and transition between workflow states.

## Usage

```bash
# Close an issue
/work:state close <number> [--comment <text>]

# Reopen an issue
/work:state reopen <number> [--comment <text>]

# Transition to a specific state
/work:state transition <number> <state>
```

## Examples

```bash
# Close issue
/work:state close 123

# Close with comment
/work:state close 123 --comment "Fixed in PR #456"

# Reopen issue
/work:state reopen 123

# Reopen with explanation
/work:state reopen 123 --comment "Bug still occurring in production"

# Transition to specific state
/work:state transition 123 in_progress
/work:state transition 123 in_review
/work:state transition 123 done
```

## Command Implementation

This command parses user input and invokes the work-manager agent with appropriate operations.

### Subcommand: close

**Purpose**: Close an issue and optionally post a comment

**Arguments**:
- `number` (required): Issue number
- `--comment` (optional): Comment to post when closing
- `--reason` (optional): Reason for closing (completed|duplicate|wontfix)

**Workflow**:
1. Parse issue number and optional comment
2. Validate issue number
3. Invoke agent: close-issue operation
4. Display success message

**Example Flow**:
```
User: /work:state close 123 --comment "Fixed in PR #456"

1. Close issue:
   {
     "operation": "close-issue",
     "parameters": {
       "issue_number": "123",
       "comment": "Fixed in PR #456",
       "reason": "completed"
     }
   }

2. Display:
   ✅ Issue closed successfully

   Issue #123: Add CSV export feature
   State: closed
   Comment posted: "Fixed in PR #456"

   View issue: /work:issue fetch 123
```

### Subcommand: reopen

**Purpose**: Reopen a closed issue

**Arguments**:
- `number` (required): Issue number
- `--comment` (optional): Comment explaining why reopening

**Workflow**:
1. Parse issue number and optional comment
2. Validate issue is currently closed
3. Invoke agent: reopen-issue operation
4. Display success message

**Example Flow**:
```
User: /work:state reopen 123 --comment "Bug still present in v2.0"

1. Reopen issue:
   {
     "operation": "reopen-issue",
     "parameters": {
       "issue_number": "123",
       "comment": "Bug still present in v2.0"
     }
   }

2. Display:
   ✅ Issue reopened successfully

   Issue #123: Fix authentication timeout
   State: open
   Comment posted: "Bug still present in v2.0"

   View issue: /work:issue fetch 123
```

### Subcommand: transition

**Purpose**: Transition issue to a specific workflow state

**Arguments**:
- `number` (required): Issue number
- `state` (required): Target state (open|in_progress|in_review|done|closed)
- `--comment` (optional): Comment to post with transition

**Workflow**:
1. Parse issue number and target state
2. Validate state is valid for platform
3. Invoke agent: transition-state operation
4. Display success message

**Example Flow**:
```
User: /work:state transition 123 in_progress

1. Transition state:
   {
     "operation": "transition-state",
     "parameters": {
       "issue_number": "123",
       "state": "in_progress"
     }
   }

2. Display:
   ✅ State transitioned successfully

   Issue #123: Add CSV export feature
   Previous state: open
   New state: in_progress

   View issue: /work:issue fetch 123
```

## Universal States

The work plugin uses universal states that map to platform-specific states:

- **open**: Issue is created but not started (GitHub: OPEN, Jira: To Do, Linear: Todo)
- **in_progress**: Actively being worked on (GitHub: OPEN + label, Jira: In Progress, Linear: In Progress)
- **in_review**: Under review (GitHub: OPEN + label, Jira: In Review, Linear: In Review)
- **done**: Completed (GitHub: CLOSED, Jira: Done, Linear: Done)
- **closed**: Explicitly closed (GitHub: CLOSED, Jira: Closed, Linear: Canceled)

### Platform Mappings

**GitHub**:
- Uses OPEN/CLOSED states
- Intermediate states via labels (faber-in-progress, faber-in-review)
- Transitions update labels automatically

**Jira**:
- Maps to workflow states (configurable)
- Transitions use Jira workflow transitions
- Custom workflows supported via configuration

**Linear**:
- Maps to Linear workflow states
- Transitions respect team workflow configuration
- Additional states may be available per team

## Close Reasons

Some platforms support close reasons:

- **completed**: Work finished successfully (default)
- **duplicate**: Duplicate of another issue
- **wontfix**: Issue won't be addressed
- **invalid**: Issue is not valid

```bash
# Close as completed (default)
/work:state close 123

# Close as duplicate
/work:state close 123 --reason duplicate --comment "Duplicate of #456"

# Close as won't fix
/work:state close 123 --reason wontfix --comment "Not in scope for current release"
```

## Error Handling

**Missing Issue Number**:
```
Error: issue_number is required
Usage: /work:state close <number>
```

**Invalid Issue Number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Invalid State**:
```
Error: Invalid state: invalid_state
Valid states: open, in_progress, in_review, done, closed
```

**Already in Target State**:
```
Warning: Issue #123 is already closed
No action taken
```

**Invalid Transition**:
```
Error: Cannot transition from closed to in_progress
Reopen the issue first: /work:state reopen 123
```

**Permission Denied**:
```
Error: Permission denied for issue #123
You may not have permission to change this issue's state
```

## Integration

**Called By**: User via CLI, FABER workflows

**Calls**: work-manager agent with operations:
- close-issue
- reopen-issue
- transition-state

**Returns**: Human-readable output formatted for terminal display

## FABER Integration

When used within FABER workflows, state transitions happen automatically:

**Frame Phase**:
- Fetches issue (no state change)
- Classifies work type

**Architect Phase**:
- Transitions to: in_progress
- Posts comment with architecture plan

**Build Phase**:
- Maintains: in_progress
- Posts updates on implementation progress

**Evaluate Phase**:
- Transitions to: in_review
- Posts test results and validation

**Release Phase**:
- Transitions to: done
- Posts PR link and deployment info
- Closes issue on PR merge

**FABER State Comment Example**:
```
🏗️ FABER Phase: Architect → Build

Transitioning to: in_progress

Architecture completed:
- Database schema designed
- API endpoints specified
- Component structure defined

Next: Implementation
```

## Advanced Usage

**Close Multiple Issues**:
```bash
# Close related issues together
/work:state close 123 --comment "Fixed along with #124 and #125"
/work:state close 124
/work:state close 125
```

**Workflow Progression**:
```bash
# Progress through workflow
/work:state transition 123 in_progress   # Start work
# ... do work ...
/work:state transition 123 in_review     # Submit for review
# ... review happens ...
/work:state transition 123 done          # Mark complete
/work:state close 123                    # Close issue
```

**Reopen with Priority**:
```bash
/work:state reopen 123 --comment "Critical bug discovered in production. Needs immediate attention."
/work:label add 123 urgent
/work:issue assign 123 @oncall
```

**Close as Duplicate**:
```bash
/work:state close 456 --reason duplicate --comment "This is a duplicate of #123. Please track progress there."
```

## Best Practices

1. **Always add comments**: Explain why state is changing
2. **Use correct state**: Choose appropriate intermediate states
3. **Close properly**: Include fix reference or reason
4. **Reopen with context**: Explain what changed or what was missed
5. **Follow workflow**: Respect team's workflow progression
6. **Link related work**: Reference PRs, commits, or related issues
7. **Update regularly**: Keep issue state current with actual work

## Common Workflows

### Starting Work
```bash
# Assign to self and mark in progress
/work:issue assign 123 @me
/work:state transition 123 in_progress
/work:comment create 123 "Starting implementation"
```

### Submitting for Review
```bash
# Transition and link PR
/work:state transition 123 in_review
/work:comment create 123 "PR #456 submitted for review"
```

### Completing Work
```bash
# Mark done and close
/work:state transition 123 done
/work:state close 123 --comment "Completed and merged in PR #456"
```

### Handling Blockers
```bash
# Comment and potentially transition back
/work:comment create 123 "⚠️ Blocked: waiting on API team"
# Keep in current state or transition back if needed
/work:state transition 123 open
```

## Notes

- State transitions may trigger platform-specific automations
- Some platforms have additional custom states
- State history is tracked automatically
- Closed issues can always be reopened
- FABER workflows manage states automatically
- Labels may be used for intermediate states on some platforms
- Workflow states are configurable per platform in config.json
- Transitions respect platform workflow rules

## See Also

- [/work:issue](issue.md) - Manage issues
- [/work:comment](comment.md) - Manage comments
- [/work:label](label.md) - Manage labels
- [Work Plugin README](../README.md) - Complete documentation
