# Capture Session Workflow

<WORKFLOW>

## Start Session Capture

### 1. Validate Input
- Verify issue_number is provided
- Check if session already active
- Verify log storage path exists

### 2. Generate Session ID
- Format: `session-{issue}-{date}-{time}`
- Example: `session-123-2025-01-15-0900`
- Ensure uniqueness

### 3. Create Session File
Execute `scripts/start-capture.sh` with:
- issue_number: The work item number
- Outputs: Session file path

The script creates a markdown file with:
```markdown
---
session_id: session-123-2025-01-15-0900
issue_number: 123
issue_title: (fetched from GitHub if available)
issue_url: https://github.com/org/repo/issues/123
started: 2025-01-15T09:00:00Z
participant: Claude Code
model: claude-sonnet-4-5-20250929
log_type: session
status: active
---

# Session Log: Issue #123

**Started**: 2025-01-15 09:00 UTC

## Conversation

```

### 4. Store Session Context
Save to `/tmp/fractary-logs-active-session`:
- session_id
- issue_number
- start_time
- log_file_path

### 5. Begin Recording
All subsequent conversation automatically captured via append operations.

## Append Message to Session

### 1. Verify Active Session
Check `/tmp/fractary-logs-active-session` exists

### 2. Format Message
- Add timestamp: `[HH:MM:SS]`
- Add role: User | Claude | System
- Apply redaction if enabled

### 3. Append to File
Execute `scripts/append-message.sh` with:
- role: user | claude | system
- message: The content to log

Output format:
```markdown
### [09:15:30] User
> Can we implement OAuth2 for user authentication?

### [09:16:45] Claude
> Yes, I can help implement OAuth2. Let me break down the requirements...
```

## Stop Session Capture

### 1. Verify Active Session
Check active session exists

### 2. Calculate Duration
- End time: current timestamp
- Duration: end - start

### 3. Update Session File
Execute `scripts/stop-capture.sh`

Updates frontmatter:
```markdown
---
session_id: session-123-2025-01-15-0900
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
status: completed
---
```

### 4. Generate Summary (Optional)
Append session summary:
```markdown
## Session Metadata

**Total Messages**: 47
**Duration**: 2h 30m
**Status**: Completed
```

### 5. Clear Active Context
Remove `/tmp/fractary-logs-active-session`

### 6. Link to Issue (Optional)
Execute `scripts/link-to-issue.sh` to comment on GitHub issue

## Sensitive Data Redaction

Apply redaction patterns before writing:

### API Keys
Pattern: `['\"]?[A-Za-z0-9_-]{32,}['\"]?`
Replace: `***REDACTED***`

### Tokens (JWT)
Pattern: `eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]*`
Replace: `***JWT***`

### Email Addresses
Pattern: `[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Z|a-z]{2,}`
Replace: `***EMAIL***`

### Passwords
Pattern: `password[:\s=]+['"]?[^'"\s]+['"]?`
Replace: `password: ***REDACTED***`

### Credit Cards
Pattern: `\b\d{4}[\s-]?\d{4}[\s-]?\d{4}[\s-]?\d{4}\b`
Replace: `***CARD***`

## Error Recovery

### Session File Corrupted
1. Backup corrupted file
2. Recreate from last known good state
3. Log the incident
4. Continue recording

### Storage Full
1. Attempt to free space (archive old logs)
2. If fails, buffer in temp
3. Alert user
4. Resume when space available

### Multiple Active Sessions
1. Detect conflict
2. Ask user which to keep active
3. Finalize others
4. Continue with selected session

</WORKFLOW>
