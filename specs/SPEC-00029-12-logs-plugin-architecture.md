# SPEC-00029-12: Logs Plugin Architecture

**Issue**: #29
**Phase**: 4 (fractary-logs Plugin)
**Dependencies**: SPEC-00029-01, SPEC-00029-02, SPEC-00029-03 (fractary-file)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Create the fractary-logs plugin for operational log management including session capture, archival, search, and analysis. Logs use hybrid retention: local storage for recent/active logs (30 days default) with automatic archival to cloud storage for long-term retention.

## Key Principles

1. **Operational Focus**: Logs are operational records, not documentation
2. **Hybrid Retention**: Local (30 days) + Cloud (forever)
3. **Lifecycle + Time**: Archive on completion OR age threshold
4. **Session Capture**: Record Claude conversations for future reference
5. **Issue-Centric**: Logs tied to issue numbers
6. **Searchable**: Query across local and cloud logs

## Plugin Structure

```
plugins/logs/
├── .claude-plugin/
│   └── plugin.json                  # Dependencies: fractary-file
├── agents/
│   └── log-manager.md              # Log orchestrator
├── commands/
│   ├── init.md                     # /fractary-logs:init
│   ├── capture.md                  # /fractary-logs:capture <issue>
│   ├── archive.md                  # /fractary-logs:archive <issue>
│   ├── search.md                   # /fractary-logs:search <query>
│   └── read.md                     # /fractary-logs:read <issue>
├── skills/
│   ├── log-capturer/               # Capture sessions
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── session-logging-guide.md
│   │   ├── scripts/
│   │   │   ├── start-capture.sh
│   │   │   ├── stop-capture.sh
│   │   │   ├── format-session.sh
│   │   │   └── link-to-issue.sh
│   │   └── workflow/
│   │       └── capture-session.md
│   ├── log-archiver/               # Archive to cloud
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── archive-process.md
│   │   ├── scripts/
│   │   │   ├── collect-logs.sh
│   │   │   ├── compress-logs.sh
│   │   │   ├── upload-to-cloud.sh
│   │   │   ├── update-index.sh
│   │   │   └── cleanup-local.sh
│   │   └── workflow/
│   │       ├── archive-issue-logs.md
│   │       └── time-based-cleanup.md
│   ├── log-searcher/               # Search logs
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── search-syntax.md
│   │   └── scripts/
│   │       ├── search-local.sh
│   │       ├── search-cloud.sh
│   │       └── aggregate-results.sh
│   └── log-analyzer/               # Analyze patterns
│       ├── SKILL.md
│       ├── docs/
│       │   └── analysis-types.md
│       └── scripts/
│           ├── extract-errors.sh
│           ├── find-patterns.sh
│           └── generate-summary.sh
├── config/
│   └── config.example.json
└── README.md
```

## Configuration Schema

```json
{
  "schema_version": "1.0",
  "storage": {
    "local_path": "/logs",
    "cloud_archive_path": "archive/logs/{year}/{month}/{issue_number}",
    "archive_index_file": ".archive-index.json"
  },
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever",
    "auto_archive_on_age": true
  },
  "archive": {
    "auto_archive_on": {
      "work_complete": true,
      "issue_close": true,
      "manual_trigger": true
    },
    "compression": {
      "enabled": true,
      "format": "gzip",
      "threshold_mb": 1
    },
    "post_archive": {
      "update_archive_index": true,
      "comment_on_issue": true,
      "remove_from_local": true,
      "keep_index": true
    }
  },
  "session_logging": {
    "enabled": true,
    "auto_capture": false,
    "format": "markdown",
    "include_timestamps": true,
    "redact_sensitive": true,
    "auto_name_by_issue": true
  },
  "search": {
    "index_local": true,
    "search_cloud": true,
    "max_results": 100
  }
}
```

## Log Types

### 1. Session Logs
Claude Code conversation transcripts:
```
logs/
└── sessions/
    ├── session-123-2025-01-15.md
    └── session-124-2025-01-16.md
```

### 2. Build Logs
Compilation, test execution:
```
logs/
└── builds/
    ├── 123-build-2025-01-15.log
    └── 123-test-2025-01-15.log
```

### 3. Deployment Logs
Infrastructure operations:
```
logs/
└── deployments/
    └── 123-deploy-2025-01-15.log
```

### 4. Debug Logs
Troubleshooting, error traces:
```
logs/
└── debug/
    └── 123-debug-2025-01-15.log
```

## Session Capture Format

**session-123-2025-01-15.md**:
```markdown
---
session_id: session-123-2025-01-15
issue_number: 123
issue_url: https://github.com/org/repo/issues/123
started: 2025-01-15T09:00:00Z
ended: 2025-01-15T11:30:00Z
duration_minutes: 150
participant: Claude Code
log_type: session
---

# Session Log: Issue #123 - User Authentication

**Issue**: [#123](https://github.com/org/repo/issues/123)
**Started**: 2025-01-15 09:00 UTC
**Duration**: 2h 30m

## Summary

Discussion of user authentication requirements and implementation approach.

## Conversation

### [09:00] User
Can we implement OAuth2 for user authentication?

### [09:02] Claude
Yes, I can help implement OAuth2. Let me break down the requirements...

[... full conversation transcript ...]

## Key Decisions

- Using OAuth2 with JWT tokens
- Support Google and GitHub providers
- Session duration: 24 hours

## Files Modified

- src/auth/oauth.ts
- src/auth/jwt.ts
- config/oauth.json

## Next Steps

- Implement Google OAuth flow
- Add JWT validation middleware
- Write integration tests
```

## Archive Index Format

```json
{
  "schema_version": "1.0",
  "last_updated": "2025-01-15T14:30:00Z",
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "archived_at": "2025-01-15T14:00:00Z",
      "logs": [
        {
          "type": "session",
          "filename": "session-123-2025-01-15.md",
          "cloud_url": "s3://bucket/archive/logs/2025/01/123/session-2025-01-15.md.gz",
          "size_bytes": 45600,
          "compressed": true,
          "checksum": "sha256:abc..."
        },
        {
          "type": "build",
          "filename": "123-build-2025-01-15.log",
          "cloud_url": "s3://bucket/archive/logs/2025/01/123/build.log.gz",
          "size_bytes": 128000,
          "compressed": true,
          "checksum": "sha256:def..."
        }
      ],
      "archive_reason": "issue_closed"
    }
  ]
}
```

## Agent Specification

**agents/log-manager.md**:

```markdown
<CONTEXT>
You are the log-manager agent for the fractary-logs plugin. You orchestrate operational log management including session capture, hybrid retention (local + cloud), archival, search, and analysis.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS tie logs to issue numbers
2. ALWAYS use hybrid retention (local 30 days, cloud forever)
3. ALWAYS compress logs before cloud upload (if > 1MB)
4. ALWAYS maintain archive index for searchability
5. ALWAYS redact sensitive information from logs
6. NEVER delete logs without archiving first
</CRITICAL_RULES>

<WORKFLOW>

## Capture Session
1. Start session logging for issue
2. Record conversation in markdown format
3. Include timestamps and key decisions
4. Save to /logs/sessions/
5. Link to issue

## Archive Logs
1. Collect all logs for issue (sessions, builds, deployments)
2. Compress if > 1MB
3. Upload to cloud via fractary-file
4. Update archive index
5. Comment on GitHub issue
6. Remove from local (keep index)

## Time-Based Cleanup
1. Find logs older than 30 days
2. Archive to cloud if not already archived
3. Remove from local
4. Update index

## Search Logs
1. Parse search query
2. Search local logs (fast)
3. Search cloud logs (slower, via index)
4. Aggregate and rank results
5. Return matches with context

</WORKFLOW>

<SKILLS>
- log-capturer: Capture sessions and logs
- log-archiver: Archive to cloud with hybrid retention
- log-searcher: Search across local and cloud
- log-analyzer: Extract patterns and insights
</SKILLS>
```

## Integration Points

- **fractary-file**: Upload/read logs from cloud
- **fractary-work**: Comment on issues with log locations
- **faber**: Capture sessions during FABER workflows
- **fractary-spec**: Archive logs when specs archived

## Success Criteria

- [ ] Plugin structure created
- [ ] Session capture working
- [ ] Hybrid retention (local 30 days, cloud forever)
- [ ] Time-based cleanup
- [ ] Lifecycle-based archival
- [ ] Search across local and cloud
- [ ] Compression for large logs
- [ ] Archive index maintained

## Timeline

**Estimated**: 1 week for core architecture

## Next Steps

- **SPEC-00029-13**: Session capture implementation
- **SPEC-00029-14**: Archive workflow
- **SPEC-00029-15**: Search and analysis
