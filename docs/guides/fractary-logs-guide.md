# Fractary Logs Plugin - User Guide

Complete guide to operational log management with the fractary-logs plugin.

> ⚠️ **NOTE**: Plugin is in ALPHA/PREVIEW status. Session capture, local storage, and search work. Cloud upload integration pending. See `plugins/logs/STATUS.md` for details.

## Overview

The fractary-logs plugin provides operational log management for development workflows with **hybrid retention**: recent logs local (fast), old logs cloud (permanent).

### Key Concepts

**Session Capture**: Record Claude Code conversations in structured markdown with timestamps, decisions, and file references.

**Hybrid Retention**: Keep recent logs local (30 days default) for fast access, archive old logs to cloud for permanent searchable storage.

**Lifecycle Archival**: Archive logs when work completes (issue closes), not just on time basis.

**Log Types**:
- **Session logs**: Claude conversations
- **Build logs**: Compilation, test execution
- **Deployment logs**: Production deployments
- **Debug logs**: Troubleshooting sessions

### Why Hybrid Retention?

**Problem**: Logs grow indefinitely, cluttering workspace and git history.

**Solution**:
- Keep recent logs local (fast, no cloud calls)
- Archive old logs to cloud (permanent, searchable)
- Automatic transition on age or lifecycle

**Benefits**:
- Clean workspace
- Fast local access for recent work
- Permanent historical record
- Searchable across local + cloud
- Cost-effective (compress old logs)

## Quick Start

### 1. Initialize

```bash
/fractary-logs:init
```

Creates:
- `.fractary/plugins/logs/config.json` - Configuration
- `/logs` directory - Local log storage
- `.fractary/plugins/logs/archive-index.json` - Archive index

### 2. Capture Session

```bash
/fractary-logs:capture 123
```

Starts recording conversation for issue #123 to `/logs/sessions/session-123-{timestamp}.md`.

**Captured automatically**:
- All messages (user and Claude)
- Timestamps
- Key decisions marked
- Files touched tracked
- Commands executed

### 3. Work on Issue

Continue conversation. Session auto-records to log file in real-time.

### 4. Stop Capture (Optional)

```bash
/fractary-logs:stop
```

Stops active capture. Auto-stops when archiving.

### 5. Archive When Complete

```bash
/fractary-logs:archive 123
```

**What happens**:
1. Collects all logs for issue (sessions, builds, deploys)
2. Compresses logs (gzip, 60-70% reduction)
3. Uploads to cloud (via fractary-file)
4. Updates archive index
5. Removes logs older than retention period (30 days)
6. Logs remain locally if within retention period

### 6. Search Logs Later

```bash
/fractary-logs:search "OAuth implementation"
```

Searches both local and cloud-archived logs, returning matches with context.

### 7. Read Archived Logs

```bash
/fractary-logs:read 123
```

Streams archived session log from cloud without downloading.

## Session Logging

### Session Format

```markdown
---
session_id: session-123-2025-01-15-0900
issue_number: 123
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
files_modified: 12
key_decisions: 3
---

# Session Log: OAuth Integration

**Issue**: #123 - Implement OAuth 2.0 Authentication
**Duration**: 2.5 hours
**Outcome**: Implementation complete, tests passing

## Conversation

### [09:00] User
Can we implement OAuth 2.0 for GitHub login?

### [09:02] Claude
Yes! Let me create a plan:
1. Set up OAuth app in GitHub
2. Implement callback endpoint
3. Store tokens securely
4. Add middleware

### [09:15] User
Sounds good. Let's start with the callback.

### [09:16] Claude
I'll create the endpoint...

[Implementation discussion continues...]

## Key Decisions

🔑 **[09:30] Token Storage**
Decision: Store refresh tokens in Redis, access tokens in memory
Rationale: Balance security (no DB persistence) and performance
Alternative considered: DB storage (rejected due to security)

🔑 **[10:15] Session Duration**
Decision: 7-day sessions with auto-renewal
Rationale: Balance UX and security
Alternative considered: 30 days (rejected as too long)

## Files Modified

- src/auth/oauth.ts (created)
- src/auth/middleware.ts (modified)
- tests/auth/oauth.test.ts (created)
- docs/api/auth.md (updated)

## Summary

✓ OAuth flow implemented
✓ Tests passing (18/18)
✓ Documentation updated
✓ Ready for review
```

### Automatic Capture Features

**Timestamp precision**: Every message tagged with HH:MM
**Key decisions**: Automatically marked with 🔑 when Claude makes architectural choice
**Files touched**: Tracked automatically via tool use
**Commands executed**: Bash commands logged
**Error context**: Errors with full stack traces

### Manual Logging

Add entries without full capture:

```bash
/fractary-logs:log 123 "Deployed to staging - 5 minutes downtime during migration"
```

Appends to session log or creates new entry.

## Log Types

### Session Logs

**Location**: `/logs/sessions/`

**Content**: Claude conversations

**Format**: Markdown with YAML front matter

**Retention**: 30 days local, then cloud

**Example**: `session-123-2025-01-15-0900.md`

---

### Build Logs

**Location**: `/logs/builds/`

**Content**: Compilation, test output, CI/CD

**Format**: Plain text

**Example**: `123-build-2025-01-15.log`

**Capture**:
```bash
npm run build > /logs/builds/123-build-$(date +%Y-%m-%d).log 2>&1
```

---

### Deployment Logs

**Location**: `/logs/deployments/`

**Content**: Deployment steps, infrastructure changes

**Format**: Plain text or structured

**Example**: `123-deploy-production-2025-01-15.log`

**Capture**:
```bash
/fractary-logs:log 123 "Starting production deployment..."
./deploy.sh >> /logs/deployments/123-deploy-production.log 2>&1
/fractary-logs:log 123 "Deployment complete"
```

---

### Debug Logs

**Location**: `/logs/debug/`

**Content**: Debugging sessions, investigation notes

**Format**: Markdown or plain text

**Example**: `123-debug-memory-leak.md`

## Search

### Basic Search

```bash
/fractary-logs:search "OAuth"
```

Searches:
- All log types
- Local + cloud
- Returns matches with context

**Output**:
```
Found 3 matches:

[Local] /logs/sessions/session-123-2025-01-15.md
  Line 45: Implementing OAuth 2.0 flow...
  Line 67: OAuth callback endpoint created

[Cloud] archive/logs/2024/12/session-100.md
  Line 23: Previous OAuth work for reference

Search complete: 3 results (2 local, 1 cloud)
```

### Filtered Search

**By issue**:
```bash
/fractary-logs:search "error" --issue 123
```

**By log type**:
```bash
/fractary-logs:search "deployment failed" --type deployment
```

**By date range**:
```bash
/fractary-logs:search "timeout" --since 2024-01-01 --until 2024-12-31
```

**Local only** (fast):
```bash
/fractary-logs:search "quick search" --local-only
```

**Cloud only** (historical):
```bash
/fractary-logs:search "old issue" --cloud-only
```

**Regex**:
```bash
/fractary-logs:search "error|exception|failed" --regex
```

### Search Tips

- Use quotes for phrases: `"OAuth implementation"`
- Combine filters: `--issue 123 --type session`
- Use --local-only for recent work (much faster)
- Use --regex for pattern matching
- Omit filters for comprehensive search

## Analysis

### Error Extraction

```bash
/fractary-logs:analyze errors --issue 123
```

Finds all errors in issue #123 logs with:
- Error message
- Stack trace
- File location
- Timestamp
- Context (surrounding log lines)
- Solution (if found in subsequent lines)

**Output**:
```
=== Error Analysis ===

Error 1: TypeError: Cannot read property 'token' of undefined
  File: src/auth/oauth.ts:45
  Time: 2025-01-15 10:23:15
  Context: OAuth callback handler
  Solution: Added null check (10:25)

Error 2: Test failed: OAuth flow returns 500
  File: tests/auth/oauth.test.ts
  Time: 2025-01-15 10:45:30
  Context: Integration test
  Solution: Fixed token validation (10:52)

Total: 2 errors found, 2 resolved
```

---

### Pattern Detection

```bash
/fractary-logs:analyze patterns --since 2024-01-01
```

Identifies recurring issues across multiple sessions:
- Common error patterns
- Frequent manual interventions
- Repeated questions
- Candidate for automation

**Output**:
```
=== Pattern Analysis ===

Pattern 1: Database connection timeout (8 occurrences)
  Issues: #100, #105, #123, #134, #156, #167, #189, #201
  Suggestion: Implement connection pooling

Pattern 2: Missing environment variable (6 occurrences)
  Issues: #110, #125, #140, #155, #170, #185
  Suggestion: Add env validation on startup

Patterns found: 5
Automation opportunities: 3
```

---

### Session Summary

```bash
/fractary-logs:analyze session 123
```

Generates concise summary of session:
- Duration
- Key decisions made
- Files modified
- Issues encountered and resolved
- Outcome

**Output**:
```
=== Session Summary: #123 ===

Duration: 2.5 hours
Key Decisions: 3 architectural choices
Files Modified: 12 files across 3 directories
Issues Encountered: 2 errors (both resolved)
Outcome: Implementation complete, tests passing

Top Activities:
1. OAuth implementation (60%)
2. Testing (25%)
3. Documentation (15%)

Next Steps: Ready for code review
```

---

### Time Analysis

```bash
/fractary-logs:analyze time --since 2024-01-01
```

Understand time spent:
- By issue
- By log type
- By day of week
- By time of day

**Output**:
```
=== Time Analysis ===

Total Development Time: 240 hours

By Issue Type:
  Features: 150 hours (62%)
  Bugs: 60 hours (25%)
  Infrastructure: 30 hours (13%)

By Day of Week:
  Monday: 52 hours
  Tuesday: 48 hours
  Wednesday: 50 hours
  Thursday: 45 hours
  Friday: 45 hours

Most Productive: Tuesday 10am-12pm
```

## Archival

### Automatic Archival

Configure in `.fractary/plugins/logs/config.json`:

```json
{
  "archive": {
    "auto_archive_on": {
      "issue_close": true,
      "age_days": 30
    }
  }
}
```

**Lifecycle-based**: Archive when issue closes (recommended)
**Time-based**: Archive logs older than 30 days (safety net)

### Manual Archival

```bash
/fractary-logs:archive 123
```

Archives all logs for issue #123:
1. Collects session, build, deployment, debug logs
2. Compresses each log (gzip)
3. Uploads to cloud via fractary-file
4. Updates archive index (local + cloud backup)
5. Removes from local if outside retention period

### Cleanup

```bash
/fractary-logs:cleanup --older-than 30
```

Archives and removes logs older than 30 days.

**Best practice**: Run daily via cron:
```bash
0 2 * * * /fractary-logs:cleanup --older-than 30
```

### Archive Format

**Cloud location**:
```
archive/logs/{year}/{month}/{issue_number}/
  session-{timestamp}.md.gz
  build-{timestamp}.log.gz
  deploy-{timestamp}.log.gz
```

**Compression**: 60-70% size reduction via gzip

**Index** (two-tier):
- Local: `.fractary/plugins/logs/archive-index.json`
- Cloud: `archive/logs/.archive-index.json`

## Configuration

Edit `.fractary/plugins/logs/config.json`:

```json
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/logs",
    "cloud_archive_path": "archive/logs/{year}/{month}/{issue_number}"
  },
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever",
    "auto_archive_on_age": true
  },
  "session_logging": {
    "enabled": true,
    "format": "markdown",
    "redact_sensitive": true,
    "auto_name_by_issue": true,
    "capture": {
      "timestamps": true,
      "key_decisions": true,
      "files_modified": true,
      "commands_executed": true
    }
  },
  "archive": {
    "compression": "gzip",
    "auto_archive_on": {
      "issue_close": true,
      "age_days": 30
    }
  },
  "search": {
    "include_cloud": true,
    "max_results": 100,
    "context_lines": 3
  }
}
```

### Configuration Options

**Storage**: Local and cloud paths
**Retention**: How long to keep logs locally vs cloud
**Session Logging**: What to capture in sessions
**Archive**: Compression and triggers
**Search**: Search behavior

## Integration

### With fractary-file

Logs plugin uses file plugin for cloud storage. Ensure fractary-file configured:

```bash
# Initialize file plugin with desired handler
/fractary-file:init --handler r2

# Test connection
Use @agent-fractary-file:file-manager to test upload
```

Without fractary-file:
- Archival operations will fail
- Use local-only mode
- Set retention strategy to "local"

---

### With fractary-work

Optional GitHub integration:
- Comment on issues when session starts
- Comment when logs archived with links
- Link logs to work items

---

### With FABER

Auto-capture during FABER workflow:

```toml
[plugins]
logs = "fractary-logs"

[workflow.frame]
start_session_capture = true

[workflow.release]
archive_logs = true
```

**Workflow**:
1. Frame phase: Start session capture
2. All phases: Conversation logged automatically
3. Release phase: Archive logs automatically

No manual commands needed!

## Best Practices

### 1. Capture Important Work

**Do capture**:
- Feature implementations
- Bug investigations
- Complex refactorings
- Architecture discussions

**Don't capture**:
- Trivial edits
- Quick questions
- Simple file changes

### 2. Use Lifecycle-Based Archival

Let plugin archive when issues close. More reliable than time-based.

### 3. Search Local First

Use `--local-only` for recent work. Much faster than cloud search.

### 4. Regular Analysis

- **Weekly**: Error extraction for active work
- **Monthly**: Pattern detection for all work
- **Quarterly**: Time analysis for planning

### 5. Compress Before Upload

Plugin auto-compresses with gzip (60-70% reduction). No manual action needed.

### 6. Monitor Storage Costs

Cloud storage is cheap but check costs:
```bash
# List all archived logs
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {"prefix": "archive/logs/"}
}
```

### 7. Secure Sensitive Data

Plugin redacts common sensitive patterns:
- API keys
- Passwords
- Tokens
- Email addresses

Verify redaction:
```bash
grep -r "password=" /logs/
```

Should return no matches.

### 8. Share Insights

Use analysis results:
- Team retrospectives
- Documentation updates
- Process improvements
- Automation opportunities

## Troubleshooting

### No active session error

**Cause**: Trying to stop/log without starting capture

**Solution**: `/fractary-logs:capture <issue>` first

### Archive index not found

**Cause**: Index file missing or corrupted

**Solution**: `/fractary-logs:init` to reinitialize (syncs from cloud if available)

### Upload failed

**Cause**: fractary-file misconfigured

**Solution**:
- Check file plugin: `cat .fractary/plugins/file/config.json`
- Test upload directly with file plugin
- Verify cloud credentials
- Logs remain local until resolved

### Search not finding archived logs

**Cause**: Archive index out of sync

**Solution**: Sync from cloud:
```bash
/fractary-logs:init
```

### Permission denied

**Cause**: /logs directory not writable

**Solution**: `chmod -R u+w /logs`

### Logs too large

**Cause**: Very long sessions

**Solution**:
- Stop and restart capture periodically
- Archive more frequently
- Increase compression (already gzip, consider xz)

## Recovery from Data Loss

If you lose local environment:

```bash
# 1. Clone repo
git clone https://github.com/org/repo

# 2. Initialize logs plugin
/fractary-logs:init

# Output:
# Syncing archive index from cloud...
# ✓ Recovered 200 archived log sessions from cloud!

# 3. All archived logs accessible
/fractary-logs:search "specific topic"
/fractary-logs:read 123
```

Archive index backed up to cloud, enabling full recovery.

## Advanced Usage

### Custom Analysis Scripts

Pipe search results to custom scripts:

```bash
/fractary-logs:search "pattern" | your-analysis-script.sh
```

### Direct Index Access

Query archive index:

```bash
cat .fractary/plugins/logs/archive-index.json | \
  jq '.archives[] | select(.issue_number == "123")'
```

### Bulk Operations

Archive multiple issues:

```bash
for issue in $(gh issue list --state closed --json number --jq '.[].number'); do
  /fractary-logs:archive $issue
done
```

### Integration with Monitoring

Send analysis results to monitoring:

```bash
/fractary-logs:analyze errors --since today | \
  send-to-monitoring.sh
```

## Further Reading

- Plugin README: `plugins/logs/README.md`
- Configuration example: `plugins/logs/config/config.example.json`
- Session logging guide: `plugins/logs/skills/log-capturer/docs/session-logging-guide.md`
- Archive process: `plugins/logs/skills/log-archiver/docs/archive-process.md`
- Search syntax: `plugins/logs/skills/log-searcher/docs/search-syntax.md`
- Analysis types: `plugins/logs/skills/log-analyzer/docs/analysis-types.md`
- Specs: `specs/SPEC-00029-12.md` through `SPEC-00029-16.md`

---

**Version**: 1.0 (2025-01-15)
**Status**: ALPHA/PREVIEW - Session capture, local storage, search work. Cloud upload pending.
