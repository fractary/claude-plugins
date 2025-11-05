# Archive Process Documentation

## Overview

The log-archiver skill implements a **hybrid retention strategy** for operational logs:

1. **Lifecycle-Based** (Primary): Archive when work completes
2. **Time-Based** (Safety Net): Archive old logs (30 days default)

## Hybrid Retention Strategy

### Local Storage (30 Days)
- Fast access for active/recent work
- Lower cost (local disk)
- Immediate availability
- Default retention: 30 days

### Cloud Storage (Forever)
- Long-term archival
- Searchable via index
- Permanent record
- Compressed for efficiency

## Archive Triggers

### Lifecycle-Based
Automatically archive when:
- **Issue Closed**: Work item marked as closed
- **PR Merged**: Pull request successfully merged
- **Manual**: User explicitly triggers archive

### Time-Based
Safety net for forgotten logs:
- Runs daily (configurable)
- Archives logs older than threshold (30 days default)
- Handles orphaned logs (no issue number)
- Prevents storage bloat

## Archive Process Steps

### 1. Collection
Finds all logs for an issue across directories:
```
/logs/
├── sessions/session-123-*
├── builds/123-*
├── deployments/123-*
└── debug/123-*
```

### 2. Compression
Large logs (> 1MB) compressed with gzip:
- Format: `.gz`
- Compression level: 9 (maximum)
- Typical reduction: 60-70% for text logs
- Decision: Compress only if size reduction achieved

### 3. Cloud Upload
Upload via fractary-file agent:
- Destination: `archive/logs/{year}/{month}/{issue}/`
- Preserves filenames
- Gets cloud URL for each file
- Calculates SHA-256 checksum

### 4. Index Update
Maintains searchable index at `/logs/.archive-index.json`:
```json
{
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "archived_at": "2025-01-15T14:00:00Z",
      "archive_reason": "issue_closed",
      "logs": [
        {
          "type": "session",
          "filename": "session-123-2025-01-15.md",
          "cloud_url": "s3://bucket/archive/logs/2025/01/123/...",
          "size_bytes": 45600,
          "compressed": true,
          "checksum": "sha256:abc123..."
        }
      ],
      "total_size_bytes": 173600,
      "total_logs": 3
    }
  ]
}
```

### 5. GitHub Comment
Posts comment to issue with:
- List of archived logs
- Cloud URLs (if public)
- File sizes and compression info
- Archive timestamp
- How to access logs

### 6. Local Cleanup
Removes archived files from local storage:
- Verifies entry in index first
- Optionally verifies cloud accessibility
- Keeps index file locally
- Tracks freed space

### 7. Git Commit
Commits updated index:
```
Archive logs for issue #123

- Archived 3 logs to cloud storage
- Updated archive index
- Freed 173 KB locally

Archive reason: issue_closed
Issue: #123
```

## Archive Index

### Purpose
- Fast search without downloading logs
- Metadata for cloud logs
- Verification of archive status
- Recovery information

### Schema
```json
{
  "schema_version": "1.0",
  "last_updated": "2025-01-15T14:00:00Z",
  "archives": [
    {
      "issue_number": "123",
      "issue_url": "https://github.com/org/repo/issues/123",
      "issue_title": "Implement user authentication",
      "archived_at": "2025-01-15T14:00:00Z",
      "archive_reason": "issue_closed",
      "logs": [
        {
          "type": "session|build|deployment|debug",
          "filename": "original-filename",
          "local_path": "original-path",
          "cloud_url": "s3://...",
          "size_bytes": 45600,
          "compressed": true,
          "created": "2025-01-15T09:00:00Z",
          "archived": "2025-01-15T14:00:00Z",
          "checksum": "sha256:abc123..."
        }
      ],
      "total_size_bytes": 173600,
      "total_logs": 3,
      "compression_ratio": 0.35
    }
  ],
  "cleanup_events": [
    {
      "date": "2025-02-15T10:00:00Z",
      "logs_cleaned": 5,
      "space_freed_bytes": 450000,
      "age_threshold_days": 30
    }
  ]
}
```

## Time-Based Cleanup

### Purpose
Safety net to catch:
- Abandoned work items
- Forgotten sessions
- Orphaned logs
- Incomplete workflows

### Process
1. Find logs older than threshold (30 days)
2. Group by issue number
3. Check if already archived
4. Archive unarchived logs
5. Clean up already-archived logs
6. Handle orphaned logs specially

### Orphaned Logs
Logs without issue numbers:
- Archive to: `archive/logs/{year}/{month}/orphaned/`
- Index entry: `"issue_number": "orphaned-2025-01"`
- Searchable like other logs

### Scheduling
Recommended: Daily at 2 AM
```bash
0 2 * * * /fractary-logs:cleanup --older-than 30
```

## Safety Mechanisms

### Never Delete Without Archive
- Always upload to cloud first
- Verify upload succeeded
- Only then delete local files
- Keep index even after cleanup

### Verification
- Check archive index before deletion
- Optionally verify cloud URL accessible
- Track all operations in index
- Recovery information preserved

### Partial Failures
- Upload some files, not all: Record successful, report failed
- Index update fails: Write recovery file, don't delete
- Cleanup fails: Archive succeeded, user can manually clean later

### Concurrent Operations
- Lock mechanism for simultaneous archives
- Skip issues with active archival
- Retry on next cleanup run

## Configuration

### Retention Policy
```json
{
  "retention": {
    "strategy": "hybrid",
    "local_days": 30,
    "cloud_days": "forever",
    "auto_archive_on_age": true
  }
}
```

### Compression Settings
```json
{
  "archive": {
    "compression": {
      "enabled": true,
      "format": "gzip",
      "threshold_mb": 1
    }
  }
}
```

### Archive Triggers
```json
{
  "archive": {
    "auto_archive_on": {
      "work_complete": true,
      "issue_close": true,
      "manual_trigger": true
    }
  }
}
```

### Post-Archive Actions
```json
{
  "archive": {
    "post_archive": {
      "update_archive_index": true,
      "comment_on_issue": true,
      "remove_from_local": true,
      "keep_index": true
    }
  }
}
```

## Usage Examples

### Manual Archive
```bash
/fractary-logs:archive 123
```

### Forced Re-Archive
```bash
/fractary-logs:archive 123 --force
```

### Time-Based Cleanup
```bash
/fractary-logs:cleanup --older-than 30
```

### Dry Run
```bash
/fractary-logs:cleanup --older-than 30 --dry-run
```

### Verify Archives
```bash
/fractary-logs:verify
```

## Troubleshooting

### Upload Failures
**Problem**: Cloud upload fails
**Solution**:
- Check fractary-file configuration
- Verify cloud credentials
- Check network connectivity
- Logs remain local until resolved

### Index Corruption
**Problem**: Archive index corrupted
**Solution**:
- Backup corrupted index
- Rebuild from cloud storage metadata
- Use recovery files if available

### Storage Full
**Problem**: Local or cloud storage full
**Solution**:
- Run cleanup for local: `/fractary-logs:cleanup`
- For cloud: Increase quota or change retention
- Check configuration for archive paths

### Missing Archives
**Problem**: Logs archived but not in index
**Solution**:
- Check for recovery files in `/tmp/archive-recovery-*.json`
- Manually rebuild index entry
- Re-archive with `--force` if needed

## Best Practices

### Regular Cleanup
Run cleanup regularly (daily recommended):
```bash
0 2 * * * /fractary-logs:cleanup --older-than 30
```

### Monitor Archive Size
Track cloud storage usage:
```bash
/fractary-logs:stats
```

### Verify Archives Periodically
Monthly verification:
```bash
/fractary-logs:verify --full
```

### Backup Archive Index
Index is critical for searchability:
```bash
cp /logs/.archive-index.json /logs/.archive-index.backup.json
```

### Review Orphaned Logs
Periodically review orphaned logs:
```bash
/fractary-logs:search --orphaned
```
