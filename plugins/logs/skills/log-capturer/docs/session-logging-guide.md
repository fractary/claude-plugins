# Session Logging Guide

## Overview

The log-capturer skill records Claude Code conversation sessions in structured markdown format, providing a permanent record of development discussions, decisions, and implementations.

## Session Structure

### Frontmatter Metadata

Every session file begins with YAML frontmatter containing:

```yaml
---
session_id: session-123-2025-01-15-0900
issue_number: 123
issue_title: Implement user authentication
issue_url: https://github.com/org/repo/issues/123
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
participant: Claude Code
model: claude-sonnet-4-5-20250929
log_type: session
status: completed
tags: [authentication, oauth, security]
---
```

### Conversation Format

Messages are formatted with timestamps and roles:

```markdown
### [09:15:30] User
Can we implement OAuth2 for user authentication?

### [09:16:45] Claude
Yes, I can help implement OAuth2. Let me break down the requirements...
```

### Session Summary

At session end, a summary is appended:

```markdown
## Session Summary

**Total Messages**: 47
**Duration**: 150m
**Ended**: 2025-01-15 11:30 UTC
**Status**: Completed
```

## Usage Patterns

### Manual Capture

Start and stop capture manually:

```bash
# Start capture
/fractary-logs:capture 123

# Work on issue...
# All conversation automatically recorded

# Stop capture
/fractary-logs:stop
```

### Auto-Capture in FABER

Sessions automatically captured during FABER workflows:
- Starts when workflow begins
- Continues through all phases
- Stops and archives when work completes

### Explicit Logging

Log specific decisions or notes:

```bash
/fractary-logs:log 123 "Decided to use PostgreSQL for better JSON support"
```

## Sensitive Data Redaction

Automatic redaction of:

### API Keys
Pattern: Long alphanumeric strings (32+ chars)
Example: `sk_live_abc123...` → `**REDACTED**`

### JWT Tokens
Pattern: Three base64 segments separated by dots
Example: `eyJ0eX...` → `**JWT**`

### Passwords
Pattern: Password fields in any format
Example: `password: "secret123"` → `password: **REDACTED**`

### Credit Cards
Pattern: 16-digit card numbers
Example: `4532-1234-5678-9012` → `**CARD**`

### Email Addresses (Optional)
Can be enabled in configuration if needed.

## Best Practices

### When to Capture

✅ **Capture sessions for**:
- Feature implementations
- Bug investigations
- Architecture discussions
- Complex refactorings
- Learning new patterns

❌ **Skip capture for**:
- Trivial changes
- Simple file edits
- Quick questions
- Routine maintenance

### Structuring Sessions

**Keep sessions focused**:
- One issue per session
- Start new session for new issue
- Stop session when switching context

**Include context**:
- Link to specifications
- Reference related issues
- Note key decisions
- Document trade-offs

**Track files**:
- List files created
- List files modified
- Note configuration changes

### Session Naming

Session IDs automatically generated:
```
session-{issue}-{date}-{time}
session-123-2025-01-15-0900
```

## File Locations

Sessions stored by default:
```
/logs/sessions/session-{issue}-{date}.md
```

Configurable via `.fractary/plugins/logs/config.json`:
```json
{
  "storage": {
    "local_path": "/logs"
  }
}
```

## Integration with GitHub

Optional GitHub integration:
- Comment on issue when session logged
- Include session ID and duration
- Link to log file location
- Note archive status

Example comment:
```markdown
💬 Session Logged

Claude Code session captured:
- Session: session-123-2025-01-15-0900
- Started: 2025-01-15 09:00 UTC
- Duration: 2h 30m

Log location: `/logs/sessions/session-123-2025-01-15.md`

This session will be archived when work completes.
```

## Retrieval

Read sessions via:

```bash
# Read by issue number
/fractary-logs:read 123

# Search sessions
/fractary-logs:search "OAuth implementation"

# Analyze session
/fractary-logs:analyze session 123
```

Sessions remain locally accessible for 30 days (default), then automatically archived to cloud storage while remaining searchable.

## Troubleshooting

### "No active session"

You tried to append or stop without starting capture.

**Solution**: Start capture first with `/fractary-logs:capture <issue>`

### "Session already exists"

A session file with same timestamp already exists.

**Solution**: Wait a minute or manually remove old session file

### "Cannot write to log directory"

Permission or storage space issue.

**Solution**:
- Check log directory permissions
- Check available disk space
- Verify configuration path

### Redaction too aggressive

Legitimate content being redacted.

**Solution**: Adjust redaction patterns in configuration or disable:
```json
{
  "session_logging": {
    "redact_sensitive": false
  }
}
```

## Examples

### Feature Implementation Session

```markdown
---
session_id: session-123-2025-01-15-0900
issue_number: 123
issue_title: Add OAuth2 authentication
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
---

# Session Log: Add OAuth2 authentication

## Key Decisions

- Using OAuth2 authorization code flow
- Support Google and GitHub providers
- JWT tokens with 15-minute expiry
- Refresh tokens with 7-day expiry

## Files Created

- src/auth/oauth/provider.interface.ts
- src/auth/oauth/google-provider.ts
- src/auth/oauth/github-provider.ts

## Issues Encountered

- CORS error during redirect (resolved: whitelist config)
- Token refresh race condition (resolved: mutex lock)

## Next Steps

- Add Microsoft OAuth provider
- Implement rate limiting
- Write integration tests
```

### Bug Investigation Session

```markdown
---
session_id: session-456-2025-01-16-1400
issue_number: 456
issue_title: Database connection timeout
started: 2025-01-16T14:00:00Z
ended: 2025-01-16T15:30:00Z
duration_minutes: 90
---

# Session Log: Database connection timeout

## Investigation

Traced timeout to connection pool exhaustion under high load.

## Root Cause

Connection pool size: 10
Peak concurrent requests: 50+
Connections not released properly in error paths

## Solution

- Increased pool size to 50
- Added connection cleanup in finally blocks
- Implemented connection timeout monitoring

## Files Modified

- src/database/connection-manager.ts
- config/database.json
```
