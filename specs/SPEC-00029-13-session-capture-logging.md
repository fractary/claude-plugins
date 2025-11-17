# SPEC-00029-13: Session Capture and Logging

**Issue**: #29
**Phase**: 4 (fractary-logs Plugin)
**Dependencies**: SPEC-00029-12
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement log-capturer skill to record Claude Code conversations and operational logs tied to work items. Captured sessions provide valuable context for future reference, debugging, and learning from past implementations.

## Session Capture Methods

### 1. Manual Capture
```bash
# Start capturing session for issue
/fractary-logs:capture 123

# Continue conversation...
# All messages captured

# Stop capture (optional, auto-stops on new issue)
/fractary-logs:stop
```

### 2. Auto-Capture (FABER Integration)
- Automatically start capture when FABER workflow begins
- Continue throughout all phases
- Auto-stop and archive when work completes

### 3. Explicit Log
```bash
# Log specific message/decision
/fractary-logs:log 123 "Decided to use PostgreSQL for better JSON support"
```

## Session Log Format

### Markdown Format (Default)

Structured markdown with conversation flow:

```markdown
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
phase: architect
tags: [authentication, oauth, security]
---

# Session Log: User Authentication Implementation

**Issue**: [#123](https://github.com/org/repo/issues/123)
**Date**: 2025-01-15
**Duration**: 2h 30m
**Phase**: Architect → Build

## Session Summary

Discussed and implemented OAuth2 authentication with JWT tokens. Supported Google and GitHub as OAuth providers. Made architectural decisions about token storage and refresh strategies.

## Key Decisions

1. **OAuth2 over Basic Auth**: Better security, easier third-party integration
2. **JWT Storage**: HttpOnly cookies to prevent XSS
3. **Token Refresh**: 15-minute access tokens, 7-day refresh tokens
4. **Provider Support**: Google, GitHub initially; extensible for more

## Conversation

### [09:00:15] User
> Can we implement OAuth2 for user authentication?

### [09:01:42] Claude
> Yes, I can help implement OAuth2 authentication. Let me break down the requirements and create a specification...
>
> First, I'll use the fractary-spec plugin to generate a detailed specification from the issue.

### [09:05:23] Claude
> I've generated the specification at `/specs/spec-123-user-auth.md`. Here's the approach:
>
> 1. Use OAuth2 authorization code flow
> 2. Support multiple providers (Google, GitHub)
> 3. JWT tokens for session management
> 4. Refresh token rotation

### [09:08:45] User
> How should we store the tokens securely?

### [09:10:12] Claude
> For secure token storage:
> - Access tokens: HttpOnly cookies (prevents XSS)
> - Refresh tokens: Encrypted database field
> - Never expose tokens to client-side JavaScript

[... conversation continues ...]

## Implementation Details

### Files Created
- `src/auth/oauth/provider.interface.ts`
- `src/auth/oauth/google-provider.ts`
- `src/auth/oauth/github-provider.ts`
- `src/auth/jwt/token-manager.ts`

### Files Modified
- `src/app.module.ts` - Added OAuth module
- `config/oauth.json` - Provider configuration

### Commands Executed
```bash
npm install @nestjs/passport passport-google-oauth20 passport-github2
npm install @nestjs/jwt jsonwebtoken
```

## Issues Encountered

### Issue 1: CORS Configuration
**Problem**: OAuth redirect failing due to CORS
**Solution**: Added origin whitelist in CORS config
**Time**: 15 minutes

### Issue 2: Token Refresh Race Condition
**Problem**: Multiple requests refreshing token simultaneously
**Solution**: Implemented token refresh lock mechanism
**Time**: 30 minutes

## Testing

- ✓ Google OAuth flow tested
- ✓ GitHub OAuth flow tested
- ✓ Token refresh mechanism tested
- ✓ Invalid token handling tested
- ⚠ Load testing pending

## References

- [OAuth2 RFC 6749](https://tools.ietf.org/html/rfc6749)
- [JWT RFC 7519](https://tools.ietf.org/html/rfc7519)
- [Specification: spec-123-user-auth.md](/specs/spec-123-user-auth.md)

## Next Steps

1. Implement rate limiting for token endpoints
2. Add OAuth provider for Microsoft
3. Write integration tests
4. Update documentation

## Session Metadata

**Total Messages**: 47
**Code Blocks**: 12
**Files Touched**: 8
**Decisions Made**: 4
**Issues Resolved**: 2
```

## Capture Implementation

### Start Capture

**scripts/start-capture.sh**:
```bash
#!/bin/bash
set -euo pipefail

ISSUE_NUMBER="$1"
SESSION_ID="session-${ISSUE_NUMBER}-$(date +%Y-%m-%d-%H%M)"
LOG_DIR="/logs/sessions"
LOG_FILE="$LOG_DIR/$SESSION_ID.md"

mkdir -p "$LOG_DIR"

# Create session file with front matter
cat > "$LOG_FILE" <<EOF
---
session_id: $SESSION_ID
issue_number: $ISSUE_NUMBER
started: $(date -u +%Y-%m-%dT%H:%M:%SZ)
participant: Claude Code
log_type: session
status: active
---

# Session Log: Issue #$ISSUE_NUMBER

**Started**: $(date -u +%Y-%m-%d %H:%M UTC)

## Conversation

EOF

# Save session context
echo "$SESSION_ID" > /tmp/fractary-logs-active-session

echo "Session capture started: $LOG_FILE"
```

### Append to Session

**scripts/append-message.sh**:
```bash
#!/bin/bash
set -euo pipefail

ROLE="$1"  # user|claude
MESSAGE="$2"
TIMESTAMP=$(date -u +%H:%M:%S)

SESSION_ID=$(cat /tmp/fractary-logs-active-session 2>/dev/null || echo "")
if [[ -z "$SESSION_ID" ]]; then
    echo "No active session"
    exit 1
fi

LOG_FILE="/logs/sessions/$SESSION_ID.md"

cat >> "$LOG_FILE" <<EOF

### [$TIMESTAMP] $(echo "$ROLE" | awk '{print toupper(substr($0,1,1)) tolower(substr($0,2))}')
> $MESSAGE

EOF
```

### Stop Capture

**scripts/stop-capture.sh**:
```bash
#!/bin/bash
set -euo pipefail

SESSION_ID=$(cat /tmp/fractary-logs-active-session 2>/dev/null || echo "")
if [[ -z "$SESSION_ID" ]]; then
    echo "No active session"
    exit 0
fi

LOG_FILE="/logs/sessions/$SESSION_ID.md"

# Update end time in front matter
END_TIME=$(date -u +%Y-%m-%dT%H:%M:%SZ)
sed -i "s/^status: active$/status: completed\nended: $END_TIME/" "$LOG_FILE"

# Calculate duration
# Add session summary section

rm /tmp/fractary-logs-active-session

echo "Session capture completed: $LOG_FILE"
```

## Sensitive Data Redaction

Automatically redact:
- API keys, tokens, passwords
- Email addresses (configurable)
- IP addresses (configurable)
- Credit card numbers
- Social security numbers

**Redaction patterns**:
```bash
# API keys
s/['\"]?[A-Za-z0-9_-]{32,}['\"]?/***REDACTED***/g

# Email
s/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[A-Z|a-z]{2,}/***EMAIL***/g

# Tokens
s/eyJ[A-Za-z0-9-_]+\.[A-Za-z0-9-_]+\.[A-Za-z0-9-_]*/***JWT***/g
```

## Commands

### /fractary-logs:capture

```markdown
Start capturing session for issue

Usage:
  /fractary-logs:capture <issue_number>

Example:
  /fractary-logs:capture 123

  Session capture started for issue #123
  All subsequent conversation will be logged.
```

### /fractary-logs:log

```markdown
Log specific message or decision

Usage:
  /fractary-logs:log <issue_number> "<message>"

Example:
  /fractary-logs:log 123 "Decided to use Redis for caching"
```

### /fractary-logs:stop

```markdown
Stop active session capture

Usage:
  /fractary-logs:stop

Example:
  /fractary-logs:stop

  Session completed: /logs/sessions/session-123-2025-01-15.md
```

## GitHub Integration

Comment on issue when session captured:

```markdown
💬 Session Logged

Claude Code session captured:
- [Session 2025-01-15](/logs/sessions/session-123-2025-01-15.md)
- Duration: 2h 30m
- Phase: Architect → Build

This session will be archived with other logs when work completes.
```

## Success Criteria

- [ ] Manual capture working (/fractary-logs:capture)
- [ ] Auto-capture in FABER workflows
- [ ] Markdown format with conversation flow
- [ ] Sensitive data redacted
- [ ] Key decisions highlighted
- [ ] Files touched tracked
- [ ] Issues encountered logged
- [ ] GitHub integration (comment on issue)

## Timeline

**Estimated**: 3-4 days

## Next Steps

- **SPEC-00029-14**: Log archive workflow
