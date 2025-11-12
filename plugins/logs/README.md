# fractary-logs Plugin

> ✅ **STABLE RELEASE** - See [STATUS.md](STATUS.md) for details
>
> **What Works**: Session capture, cloud backup, AI summaries, search, analysis
> **New Features**: Automatic cloud backup after 7 days, AI-powered session summaries
> **Recommended**: Production-ready for log retention and knowledge management

Operational log management for Claude Code development sessions, including session capture, automatic cloud backup, AI-powered summaries, search, and analysis.

## Overview

The fractary-logs plugin provides comprehensive logging infrastructure for development workflows:

- **Session Capture**: Record Claude Code conversations in structured markdown ✅
- **Automatic Cloud Backup**: Auto-archive logs older than 7 days to prevent data loss ✅
- **AI-Powered Summaries**: Generate intelligent summaries with key decisions, learnings, and insights ✅
- **Hybrid Retention**: 7-day local storage, forever in cloud (S3, R2, GCS, etc.) ✅
- **Separate Storage Paths**: Logs in `/claude-logs/`, summaries in `/claude-summaries/` ✅
- **Search**: Fast local + cloud search with filters ✅
- **Analysis**: Error extraction, pattern detection, session summaries, time analysis ✅

## Architecture

```
fractary-logs
├── log-manager (agent)          # Orchestrates all log operations
├── log-capturer (skill)         # Capture sessions
├── log-archiver (skill)         # Archive with hybrid retention
├── log-summarizer (skill)       # Generate AI-powered summaries (NEW)
├── log-searcher (skill)         # Search local + cloud
└── log-analyzer (skill)         # Extract insights
```

## Key Features

### 🔄 Automatic Cloud Backup

**Never lose your Claude sessions again!** The plugin automatically backs up logs older than 7 days to your configured cloud storage (S3, R2, GCS, etc.).

**How it works:**
- **On initialization**: Checks for logs older than 7 days and backs them up
- **On session start**: Background check for old logs, auto-backup without blocking
- **Configurable threshold**: Adjust `auto_backup.backup_older_than_days` (default: 7)

**Why 7 days?**
Claude API logs are retained for only 7 days. This plugin ensures you have a permanent backup before Claude deletes them.

**Storage structure:**
```
archive/logs/
├── claude-logs/
│   └── 2025/
│       ├── session-123-2025-01-15.md.gz
│       └── session-124-2025-01-16.md.gz
└── claude-summaries/
    └── 2025/
        ├── session-123-2025-01-15-summary.md
        └── session-124-2025-01-16-summary.md
```

### 🤖 AI-Powered Session Summaries

**Quickly understand past sessions** without reading the full conversation. The plugin uses Claude to analyze sessions and generate intelligent summaries.

**What's included:**
- **Key Accomplishments**: What was actually completed
- **Technical Decisions**: What was decided and why
- **Learnings & Insights**: Gotchas, best practices, new techniques
- **Files Changed**: Categorized by type of change
- **Issues Encountered**: Problems and solutions
- **Follow-up Items**: TODOs and unresolved questions

**Example summary excerpt:**
```markdown
## Key Accomplishments
- Implemented OAuth2 authentication flow with JWT tokens
- Added user session management with Redis
- Created comprehensive test suite (95% coverage)

## Technical Decisions
### Session Storage
**Decision**: Use Redis for session storage
**Rationale**: Fast in-memory access, built-in TTL, horizontal scaling
**Alternatives Considered**: PostgreSQL (too slow), JWT-only (stateless but less secure)

## Learnings & Insights
- **Redis Connection Pooling**: Always configure maxClients for production
- **JWT Refresh Tokens**: Store in httpOnly cookies to prevent XSS
- **OAuth State Parameter**: Critical for CSRF protection, don't skip!
```

### 📂 Separate Storage Paths

Logs and summaries are stored in separate, configurable paths:
- **Logs**: `archive/logs/claude-logs/{year}/` (compressed)
- **Summaries**: `archive/logs/claude-summaries/{year}/` (markdown)

**Benefits:**
- Easier to browse summaries without downloading full logs
- Different retention policies possible
- Cleaner organization
- Faster summary access

## Quick Start

### 1. Initialize

```bash
/fractary-logs:init
```

Creates configuration and log directories.

### 2. Capture Session

```bash
/fractary-logs:capture 123
```

Starts recording conversation for issue #123.

### 3. Search Logs

```bash
/fractary-logs:search "OAuth implementation"
```

Search across all logs (local and archived).

### 4. Archive Logs

```bash
/fractary-logs:archive 123
```

Archive logs for completed issue to cloud.

## Commands

### Session Management

- `/fractary-logs:capture <issue>` - Start capturing session
- `/fractary-logs:stop` - Stop active capture
- `/fractary-logs:log <issue> "<message>"` - Log specific message

### Archival

- `/fractary-logs:archive <issue>` - Archive logs for issue
- `/fractary-logs:cleanup [--older-than 30]` - Time-based cleanup

### Search & Analysis

- `/fractary-logs:search "<query>" [options]` - Search logs
- `/fractary-logs:analyze <type> [options]` - Analyze logs
  - `errors` - Extract all errors
  - `patterns` - Find recurring issues
  - `session` - Summarize session
  - `time` - Analyze time spent
- `/fractary-logs:read <issue>` - Read logs for issue

### Configuration

- `/fractary-logs:init` - Initialize configuration

## Features

### Session Capture

Record Claude Code conversations:
- Structured markdown format
- Automatic timestamps
- Issue linking
- Sensitive data redaction
- Key decisions highlighted
- Files touched tracked

Example session log:
```markdown
---
session_id: session-123-2025-01-15-0900
issue_number: 123
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
---

# Session Log: User Authentication

## Conversation

### [09:15] User
Can we implement OAuth2?

### [09:16] Claude
Yes, let me break down the requirements...
```

### Hybrid Retention

**Local Storage (Fast)**:
- Recent/active logs (30 days default)
- Immediate access
- No cloud calls
- Lower cost

**Cloud Storage (Forever)**:
- Long-term archival
- Compressed (60-70% reduction)
- Searchable via index
- Permanent record

**Automatic Transition**:
- Lifecycle-based: Archive when issue closes
- Time-based: Archive logs older than 30 days
- Safety net: Never lose logs

### Search

**Hybrid Search**:
```bash
/fractary-logs:search "OAuth" --issue 123
```

Searches both local and cloud, aggregates results.

**Filters**:
- `--issue <number>` - Specific issue
- `--type <type>` - Log type (session|build|deployment|debug)
- `--since <date>` - Start date
- `--until <date>` - End date
- `--regex` - Regular expression
- `--local-only` - Local only (fast)
- `--cloud-only` - Cloud only (comprehensive)

### Analysis

**Error Extraction**:
```bash
/fractary-logs:analyze errors --issue 123
```

Find all errors with context, file locations, solutions.

**Pattern Detection**:
```bash
/fractary-logs:analyze patterns --since 2025-01-01
```

Identify recurring issues across multiple logs.

**Session Summary**:
```bash
/fractary-logs:analyze session 123
```

Generate concise summary: duration, decisions, files, issues.

**Time Analysis**:
```bash
/fractary-logs:analyze time --since 2025-01-01
```

Understand time spent by issue, type, day of week.

## Configuration

Located at `.fractary/plugins/logs/config.json`.

Copy from example:
```bash
cp plugins/logs/config/config.example.json .fractary/plugins/logs/config.json
```

### Key Settings

**Storage**:
```json
{
  "storage": {
    "local_path": "/logs",
    "cloud_archive_path": "archive/logs/{year}/{month}/{issue_number}",
    "provider": "s3",
    "bucket": "fractary-logs"
  }
}
```

**Retention & Auto-Backup**:
```json
{
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever",
    "auto_archive_on_age": true,
    "auto_archive_threshold_days": 7
  },
  "auto_backup": {
    "enabled": true,
    "trigger_on_init": true,
    "trigger_on_session_start": true,
    "backup_older_than_days": 7,
    "generate_summaries": true
  }
}
```

**AI Summaries**:
```json
{
  "summarization": {
    "enabled": true,
    "auto_generate_on_archive": true,
    "model": "claude-sonnet-4-5-20250929",
    "store_with_logs": false,
    "separate_paths": true,
    "format": "markdown"
  }
}
```

**Storage Paths**:
```json
{
  "storage": {
    "cloud_logs_path": "archive/logs/claude-logs/{year}",
    "cloud_summaries_path": "archive/logs/claude-summaries/{year}"
  }
}
```

**Session Logging**:
```json
{
  "session_logging": {
    "enabled": true,
    "format": "markdown",
    "redact_sensitive": true,
    "auto_name_by_issue": true
  }
}
```

## Integration

### fractary-file

**Required dependency** for cloud storage operations.

The logs plugin integrates via **agent-to-agent invocation**:
- log-manager agent invokes file-manager agent from fractary-file
- file-manager handles all cloud operations (upload, read, delete)
- Supports multiple providers: R2, S3, GCS, Google Drive, Local

**Setup**:
1. Initialize fractary-file: `/fractary-file:init`
2. Configure storage provider (R2, S3, etc.)
3. Test connection: `/fractary-file:test-connection`

**How it works**:
- When archiving logs, log-manager prepares metadata
- log-manager invokes file-manager to upload each file
- file-manager returns cloud URLs
- log-manager updates archive index with URLs
- Archived logs remain searchable via index

**Without fractary-file**:
- Archival operations will fail
- Use local-only mode (no cloud archival)
- Set `retention.strategy` to `"local"` in config

### fractary-work

Optional GitHub integration:
- Comment on issues when logs captured
- Comment on issues when logs archived
- Link sessions to work items

### FABER Workflows

Auto-capture during FABER:
- Starts when workflow begins
- Continues through all phases
- Archives when work completes

## Directory Structure

```
/logs/
├── .archive-index.json       # Archive metadata (searchable)
├── sessions/                 # Session logs
│   ├── session-123-2025-01-15.md
│   └── session-124-2025-01-16.md
├── builds/                   # Build logs
│   └── 123-build.log
├── deployments/              # Deployment logs
│   └── 123-deploy.log
└── debug/                    # Debug logs
    └── 123-debug.log
```

## Best Practices

### Session Capture

**Do capture**:
- Feature implementations
- Bug investigations
- Architecture discussions
- Complex refactorings

**Don't capture**:
- Trivial changes
- Simple file edits
- Quick questions

### Archival

**Lifecycle-based** (Automatic):
- Let plugin archive when issues close
- Reliable and timely
- No manual intervention

**Time-based** (Safety net):
- Run daily: `0 2 * * * /fractary-logs:cleanup`
- Catches abandoned work
- Prevents storage bloat

### Search

**Fast searches**:
- Use `--local-only` for recent work
- Specify `--issue` when known
- Use `--type` to narrow scope

**Comprehensive searches**:
- Use hybrid search (default)
- Use `--cloud-only` for historical
- Remove filters for broad search

### Analysis

**Regular analysis**:
- Weekly: Error extraction for current work
- Monthly: Pattern detection across all work
- Quarterly: Time analysis for planning

**Share insights**:
- Team retrospectives
- Documentation updates
- Knowledge base
- Best practices

## Advanced Usage

### Custom Analysis

Combine search and read for custom analysis:
```bash
/fractary-logs:search "interesting pattern" --since 2024-01-01
/fractary-logs:read <issue>
# Manual analysis or pipe to custom scripts
```

### Archive Index

Direct access to archive index:
```bash
cat /logs/.archive-index.json | jq '.archives[] | select(.issue_number == "123")'
```

### Bulk Operations

Archive multiple issues:
```bash
for issue in 123 124 125; do
  /fractary-logs:archive $issue
done
```

## Troubleshooting

### "No active session"

You tried to stop or append without starting capture.

**Solution**: `/fractary-logs:capture <issue>` first

### "Archive index not found"

Index file missing or corrupted.

**Solution**: `/fractary-logs:init` to reinitialize

### "Upload failed"

fractary-file integration issue.

**Solution**:
- Check fractary-file configuration
- Verify cloud credentials
- Logs remain local until resolved

### Search not finding archived logs

Archive index out of sync.

**Solution**: Rebuild index or re-archive with `--force`

## Development

### Adding New Log Types

1. Create directory: `/logs/<new-type>/`
2. Update collection scripts to include new type
3. Update search to recognize new type
4. Add to configuration schema

### Custom Scripts

All scripts in `skills/*/scripts/` can be extended or replaced:
- Bash scripts for deterministic operations
- Follow existing patterns
- Update skill documentation

## Documentation

- [Session Logging Guide](skills/log-capturer/docs/session-logging-guide.md)
- [Archive Process](skills/log-archiver/docs/archive-process.md)
- [Search Syntax](skills/log-searcher/docs/search-syntax.md)
- [Analysis Types](skills/log-analyzer/docs/analysis-types.md)

## License

Part of the Fractary Claude Code Plugins ecosystem.
