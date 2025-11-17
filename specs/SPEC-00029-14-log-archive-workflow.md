# SPEC-00029-14: Log Archive Workflow

**Issue**: #29
**Phase**: 4 (fractary-logs Plugin)
**Dependencies**: SPEC-00029-12, SPEC-00029-13
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement log-archiver skill with hybrid retention strategy: lifecycle-based archival (issue complete) + time-based safety net (30 days). Compress large logs, upload to cloud, maintain searchable index, and clean local storage.

## Hybrid Retention Strategy

### Lifecycle-Based (Primary)
Archive when work completes:
- Issue closed
- PR merged
- Manual: `/fractary-logs:archive <issue>`

### Time-Based (Safety Net)
Archive orphaned/old logs:
- Logs older than 30 days automatically archived
- Runs daily cleanup check
- Catches logs from abandoned/incomplete work

## Archive Workflow

```
Archive Request (Issue #123 or Age > 30 days)
    ↓
Collect logs for issue
    ├─ /logs/sessions/session-123-*.md
    ├─ /logs/builds/123-*.log
    ├─ /logs/deployments/123-*.log
    └─ /logs/debug/123-*.log
    ↓
Compress large logs (> 1MB)
    ├─ session-123-2025-01-15.md → session-123-2025-01-15.md.gz
    └─ 123-build.log → 123-build.log.gz
    ↓
Upload to cloud (via fractary-file)
    ├─ Upload to: archive/logs/2025/01/123/
    └─ Get URLs for each file
    ↓
Update archive index
    ├─ Load /logs/.archive-index.json
    ├─ Add entry with metadata
    └─ Save index
    ↓
Comment on GitHub issue
    ↓
Remove from local
    ├─ Delete log files
    └─ Keep index for searchability
    ↓
Git commit (index update)
```

## Compression

**When to compress**:
- Files > 1MB
- Text-based logs (high compression ratio)

**Format**: gzip (.gz)

**scripts/compress-logs.sh**:
```bash
#!/bin/bash
set -euo pipefail

LOG_FILE="$1"
THRESHOLD_MB=1

SIZE_MB=$(du -m "$LOG_FILE" | cut -f1)

if (( SIZE_MB > THRESHOLD_MB )); then
    gzip -9 "$LOG_FILE"
    echo "${LOG_FILE}.gz"
else
    echo "$LOG_FILE"
fi
```

## Multi-Log Collection

**scripts/collect-logs.sh**:
```bash
#!/bin/bash
set -euo pipefail

ISSUE_NUMBER="$1"
LOG_DIR="/logs"

# Find all logs for issue
SESSIONS=$(find "$LOG_DIR/sessions" -name "*${ISSUE_NUMBER}*" 2>/dev/null || true)
BUILDS=$(find "$LOG_DIR/builds" -name "${ISSUE_NUMBER}-*" 2>/dev/null || true)
DEPLOYMENTS=$(find "$LOG_DIR/deployments" -name "${ISSUE_NUMBER}-*" 2>/dev/null || true)
DEBUG=$(find "$LOG_DIR/debug" -name "${ISSUE_NUMBER}-*" 2>/dev/null || true)

# Combine all logs
ALL_LOGS="$SESSIONS $BUILDS $DEPLOYMENTS $DEBUG"

if [[ -z "$ALL_LOGS" ]]; then
    echo "No logs found for issue $ISSUE_NUMBER"
    exit 1
fi

# Return as JSON array
echo "$ALL_LOGS" | jq -R -s -c 'split("\n") | map(select(length > 0))'
```

## Cloud Upload

**scripts/upload-to-cloud.sh**:
```bash
#!/bin/bash
set -euo pipefail

ISSUE_NUMBER="$1"
LOG_FILE="$2"
YEAR=$(date +%Y)
MONTH=$(date +%m)

# Cloud path
CLOUD_PATH="archive/logs/${YEAR}/${MONTH}/${ISSUE_NUMBER}/$(basename "$LOG_FILE")"

# Upload via fractary-file
# Use file-manager agent
echo "Uploading $LOG_FILE to $CLOUD_PATH..."

# Get cloud URL after upload
CLOUD_URL=$(fractary-file upload "$LOG_FILE" "$CLOUD_PATH" --get-url)

echo "$CLOUD_URL"
```

## Archive Index Update

**Update /logs/.archive-index.json**:

```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "issue_title": "Implement user authentication",
  "archived_at": "2025-01-15T14:30:00Z",
  "archive_reason": "issue_closed",
  "logs": [
    {
      "type": "session",
      "filename": "session-123-2025-01-15.md",
      "local_path": "/logs/sessions/session-123-2025-01-15.md",
      "cloud_url": "s3://bucket/archive/logs/2025/01/123/session-2025-01-15.md.gz",
      "public_url": "https://storage.example.com/logs/2025/01/123/session-2025-01-15.md.gz",
      "size_bytes": 45600,
      "compressed": true,
      "created": "2025-01-15T09:00:00Z",
      "duration_minutes": 150,
      "checksum": "sha256:abc123..."
    },
    {
      "type": "build",
      "filename": "123-build.log",
      "cloud_url": "s3://bucket/archive/logs/2025/01/123/build.log.gz",
      "size_bytes": 128000,
      "compressed": true,
      "checksum": "sha256:def456..."
    }
  ],
  "total_size_bytes": 173600,
  "total_logs": 2
}
```

## Time-Based Cleanup

**workflow/time-based-cleanup.md**:

```markdown
<WORKFLOW>

## Daily Cleanup Check

Run daily to archive old logs:

1. Find logs older than 30 days
2. Group by issue number (if possible)
3. For each group:
   - Check if already archived (consult index)
   - If not archived: Archive to cloud
   - Remove from local
4. Handle orphaned logs (no issue number):
   - Archive to archive/logs/{year}/{month}/orphaned/
   - Remove from local

## Execution

Trigger: Daily cron or on-demand
Command: /fractary-logs:cleanup --older-than 30

</WORKFLOW>
```

**scripts/cleanup-old-logs.sh**:
```bash
#!/bin/bash
set -euo pipefail

DAYS=${1:-30}
LOG_DIR="/logs"

# Find logs older than N days
OLD_LOGS=$(find "$LOG_DIR" -type f -mtime +$DAYS)

if [[ -z "$OLD_LOGS" ]]; then
    echo "No logs older than $DAYS days"
    exit 0
fi

echo "Found $(echo "$OLD_LOGS" | wc -l) logs older than $DAYS days"

# Group by issue number and archive
for LOG in $OLD_LOGS; do
    # Extract issue number from filename
    ISSUE=$(basename "$LOG" | grep -oP '^\d+|(?<=session-)\d+' || echo "orphaned")

    # Archive
    /fractary-logs:archive "$ISSUE" --file "$LOG"
done
```

## GitHub Comments

### Archive Comment on Issue

```markdown
📦 Logs Archived

Session logs and operational logs have been archived:

**Sessions**:
- [Session 2025-01-15](https://storage.example.com/logs/2025/01/123/session-2025-01-15.md.gz) (45.6 KB, 2h 30m)

**Build Logs**:
- [Build Log](https://storage.example.com/logs/2025/01/123/build.log.gz) (128 KB)

**Total**: 2 logs, 173.6 KB compressed

Archived: 2025-01-15 14:30 UTC

These logs are permanently stored and searchable via `/fractary-logs:search` or `/fractary-logs:read 123`.
```

## Commands

### /fractary-logs:archive

```markdown
Archive logs for completed issue

Usage:
  /fractary-logs:archive <issue_number> [--force]

Options:
  --force: Skip checks, archive immediately

Example:
  /fractary-logs:archive 123

  Archiving logs for issue #123...
  ✓ Collected 2 logs
  ✓ Compressed 1 large log
  ✓ Uploaded to cloud
  ✓ Updated index
  ✓ Commented on issue
  ✓ Cleaned local storage

  Archive complete!
```

### /fractary-logs:cleanup

```markdown
Clean up old logs (archive and remove locally)

Usage:
  /fractary-logs:cleanup [--older-than <days>] [--dry-run]

Options:
  --older-than: Age threshold in days (default: 30)
  --dry-run: Show what would be archived without doing it

Example:
  /fractary-logs:cleanup --older-than 30

  Found 5 logs older than 30 days
  Archiving...
  ✓ 5 logs archived
  ✓ Local storage cleaned
```

## Git Operations

```bash
# After archival
git rm /logs/sessions/session-123-*.md
git rm /logs/builds/123-*.log
git add /logs/.archive-index.json
git commit -m "Archive logs for issue #123

- Archived 2 logs to cloud storage
- Updated archive index
- Issue: #123"
```

## Success Criteria

- [ ] Lifecycle-based archival (issue close, PR merge)
- [ ] Time-based safety net (30 days)
- [ ] Compression for large logs
- [ ] Multi-log collection per issue
- [ ] Cloud upload via fractary-file
- [ ] Archive index maintained
- [ ] GitHub comments with archive URLs
- [ ] Local cleanup after archival
- [ ] Daily cleanup job for old logs

## Timeline

**Estimated**: 3-4 days

## Next Steps

- **SPEC-00029-15**: Log search and analysis
