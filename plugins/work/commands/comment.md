---
name: fractary-work:comment
description: Create and manage comments on work items
argument-hint: create <issue_number> <text> | list <issue_number> [--limit <n>]
---

# /work:comment - Comment Management Command

Create and manage comments on work items across GitHub Issues, Jira, and Linear.

## Usage

```bash
# Create a comment
/work:comment create <issue_number> <text>

# List comments on an issue
/work:comment list <issue_number> [--limit <n>]
```

## Examples

```bash
# Add a comment
/work:comment create 123 "Starting work on this issue"

# Add a longer comment
/work:comment create 123 "Investigated the bug - it's caused by a race condition in the auth middleware. Working on a fix."

# List comments
/work:comment list 123

# List recent comments only
/work:comment list 123 --limit 5
```

## Command Implementation

This command parses user input and invokes the work-manager agent with appropriate operations.

### Subcommand: create

**Purpose**: Add a comment to an issue

**Arguments**:
- `issue_number` (required): Issue number
- `text` (required): Comment text
- `--faber-context` (optional): FABER workflow context (internal use)

**Workflow**:
1. Parse issue number and comment text
2. Validate both are provided
3. Invoke agent: create-comment operation
4. Display success message with comment URL

**Example Flow**:
```
User: /work:comment create 123 "Working on this now"

1. Create comment:
   {
     "operation": "create-comment",
     "parameters": {
       "issue_number": "123",
       "comment": "Working on this now"
     }
   }

2. Display:
   ✅ Comment posted successfully

   Issue #123: Add CSV export feature
   Comment by: @username
   Posted: 2025-10-30 14:35

   "Working on this now"

   URL: https://github.com/owner/repo/issues/123#issuecomment-123456
```

### Subcommand: list

**Purpose**: List comments on an issue

**Arguments**:
- `issue_number` (required): Issue number
- `--limit` (optional): Maximum number of comments to show (default: 10)
- `--since` (optional): Show comments since date (YYYY-MM-DD)

**Workflow**:
1. Parse issue number and filters
2. Invoke agent: list-comments operation
3. Format and display comments

**Example Flow**:
```
User: /work:comment list 123

1. List comments:
   {
     "operation": "list-comments",
     "parameters": {
       "issue_number": "123",
       "limit": 10
     }
   }

2. Display:
   Comments on Issue #123 (3 total):
   ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

   @alice - 2025-10-28 10:15
   "I'll take a look at this today"

   @bob - 2025-10-29 14:30
   "Found the root cause - it's in the auth module"

   @alice - 2025-10-30 09:45
   "Fix is ready for review. PR #456 submitted."

   Add comment: /work:comment create 123 "your message"
```

## Comment Formatting

Comments support markdown formatting on most platforms:

```bash
# Bold and italic
/work:comment create 123 "**Important:** This is *critical*"

# Code blocks
/work:comment create 123 "Fixed by updating \`auth.js\`"

# Lists
/work:comment create 123 "TODO:
- Test login flow
- Test logout flow
- Update docs"

# Links
/work:comment create 123 "Related to #456 and fixed in PR #789"
```

## Error Handling

**Missing Issue Number**:
```
Error: issue_number is required
Usage: /work:comment create <issue_number> <text>
```

**Missing Comment Text**:
```
Error: comment text is required
Usage: /work:comment create <issue_number> <text>
```

**Invalid Issue Number**:
```
Error: Issue not found: #999
Verify the issue number and try again
```

**Empty Comment**:
```
Error: Comment text cannot be empty
Provide comment text after the issue number
```

**Authentication Failed**:
```
Error: Authentication failed
Check your token configuration: /work:init
```

**Permission Denied**:
```
Error: Permission denied for issue #123
You may not have permission to comment on this issue
```

## Integration

**Called By**: User via CLI, FABER workflows

**Calls**: work-manager agent with operations:
- create-comment
- list-comments

**Returns**: Human-readable output formatted for terminal display

## Platform-Specific Behavior

### GitHub Issues

- Comments support full GitHub Flavored Markdown
- @mentions notify users
- Issue and PR references auto-link (#123, owner/repo#456)
- Reactions available (👍, ❤️, etc.) via web UI
- Comments can be edited/deleted via web UI

### Jira

- Comments support Jira wiki markup or markdown (depending on configuration)
- @mentions use Jira user format
- Issue references auto-link (PROJ-123)
- Comments can be internal (restricted visibility)
- Edit history tracked automatically

### Linear

- Comments support Linear markdown
- @mentions notify team members
- Issue references auto-link (TEAM-123)
- Comments appear in Linear activity feed
- Inline reactions supported

## FABER Integration

When used within FABER workflows, comments automatically include:
- Phase information (Frame, Architect, Build, Evaluate, Release)
- Workflow progress updates
- Links to commits and PRs
- Test results and validation status

**Example FABER Comment**:
```
🏗️ FABER Phase: Build

Implementation completed for CSV export feature.

Changes:
- Added export service (src/services/export.js)
- Created API endpoint (/api/export)
- Added unit tests (95% coverage)

Commit: abc123
Status: Ready for review

Next: Moving to Evaluate phase
```

These comments are posted automatically by FABER workflows when:
- Phase transitions occur
- Important milestones are reached
- Errors or blockers are encountered
- Workflow completes successfully

## Advanced Usage

**Multi-line Comments**:
```bash
/work:comment create 123 "Investigation results:

Root cause: Race condition in auth middleware
Impact: Login failures during high load
Solution: Add mutex lock in validateToken()

PR coming soon."
```

**Reference Other Issues**:
```bash
/work:comment create 123 "This is related to #456 and blocks #789"
```

**Mention Users**:
```bash
/work:comment create 123 "@alice can you review? @bob FYI"
```

**Code Snippets**:
```bash
/work:comment create 123 "The fix:
\`\`\`javascript
async function validateToken(token) {
  await mutex.acquire();
  try {
    return await verify(token);
  } finally {
    mutex.release();
  }
}
\`\`\`"
```

## Best Practices

1. **Be specific**: Provide clear, actionable information in comments
2. **Use formatting**: Leverage markdown for readability
3. **Reference related work**: Link to issues, PRs, and commits
4. **Tag relevant people**: @mention users who need to see the comment
5. **Update on progress**: Keep stakeholders informed with regular updates
6. **Include context**: Add debugging info, test results, or reproduction steps
7. **Be professional**: Comments are part of project history

## Common Use Cases

### Progress Update
```bash
/work:comment create 123 "**Progress Update**
- ✅ Implemented core logic
- ✅ Added unit tests
- 🔄 Working on integration tests
- ⏳ Documentation pending

ETA: End of day"
```

### Bug Investigation
```bash
/work:comment create 456 "**Investigation Results**

Reproduced the issue in staging. Occurs when:
1. User has multiple sessions
2. Token refresh happens simultaneously
3. Race condition in token validation

Root cause: Missing lock in \`auth.validateToken()\`
Fix in progress."
```

### Review Request
```bash
/work:comment create 789 "PR #234 is ready for review

Changes:
- Refactored user service
- Added caching layer
- Updated API docs

Tests passing, coverage at 92%
@reviewerteam please review"
```

### Blocked Status
```bash
/work:comment create 321 "⚠️ **Blocked**

Waiting on infrastructure team to provision database.
Ticket: OPS-456

Cannot proceed until this is resolved."
```

## Notes

- Comments are immutable once posted (platform-dependent editing)
- All comments are visible to users with access to the issue
- Markdown support varies by platform
- Some platforms support internal/private comments
- Comment notifications depend on platform settings
- FABER workflows post automated comments for tracking
- Long comments may be truncated in list view

## See Also

- [/work:issue](issue.md) - Manage issues
- [/work:state](state.md) - Manage issue states
- [Work Plugin README](../README.md) - Complete documentation
