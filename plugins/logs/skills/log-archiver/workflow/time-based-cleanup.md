# Time-Based Cleanup Workflow

<WORKFLOW>

## Purpose

Time-based cleanup is a safety net to archive orphaned or forgotten logs that weren't archived via lifecycle events. Default threshold: 30 days.

## 1. Find Old Logs

Find all logs older than threshold:
```bash
find /logs -type f -mtime +$AGE_DAYS ! -name ".archive-index.json"
```

Result: List of file paths older than threshold

If no old logs:
- Report "No logs older than $AGE_DAYS days"
- Exit successfully

## 2. Group Logs by Issue

For each old log file:
1. Extract issue number from filename:
   - Pattern 1: `session-{issue}-...`
   - Pattern 2: `{issue}-...`
   - Pattern 3: No issue number → "orphaned"

2. Group into buckets:
   ```json
   {
     "123": ["/logs/sessions/session-123-..."],
     "124": ["/logs/builds/124-build.log"],
     "orphaned": ["/logs/debug/error-trace.log"]
   }
   ```

## 3. Check Archive Status

For each issue group, consult archive index:
```bash
jq -e --arg issue "$ISSUE" \
  '.archives[] | select(.issue_number == $issue)' \
  /logs/.archive-index.json
```

Categorize:
- **Already archived**: Skip, safe to delete locally
- **Not archived**: Need to archive before cleanup
- **Partial archive**: Check if specific log already in cloud

## 4. Archive Unarchived Logs

For each issue with unarchived logs:
1. Use archive-issue-logs workflow
2. Trigger reason: "age_threshold"
3. Mark age in metadata

For orphaned logs (no issue number):
1. Group by month: `{year}-{month}`
2. Upload to: `archive/logs/{year}/{month}/orphaned/`
3. Create special index entry:
   ```json
   {
     "issue_number": "orphaned-2025-01",
     "archived_at": "2025-02-15T10:00:00Z",
     "archive_reason": "age_threshold",
     "logs": [
       {
         "type": "debug",
         "filename": "error-trace.log",
         "cloud_url": "s3://bucket/archive/logs/2025/01/orphaned/error-trace.log",
         "size_bytes": 12800,
         "compressed": false
       }
     ]
   }
   ```

## 5. Clean Already-Archived Logs

For logs already archived (verified in index):
1. Double-check cloud file exists (optional safety check)
2. Delete local file:
   ```bash
   rm "$LOG_FILE"
   ```
3. Track freed space

## 6. Update Archive Index

If new archives created:
- Index already updated by archive-issue-logs workflow

If only cleanup (no new archives):
- Add cleanup event to index metadata:
  ```json
  {
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

## 7. Return Summary

Output:
```
✓ Time-based cleanup complete
  Threshold: 30 days
  Found: 5 old logs
  Already archived: 3 logs
  Newly archived: 2 logs (1 issue, 1 orphaned)
  Local cleaned: 5 files, 450 KB freed

Cleanup summary:
- Issue #89: 1 log archived
- Orphaned logs: 1 log archived
- Previously archived: 3 logs cleaned
```

## Dry Run Mode

When `--dry-run` flag provided:
1. Perform all discovery steps
2. Report what would be done
3. Do not upload, delete, or modify anything

Output:
```
Dry run: Time-based cleanup

Would process 5 logs:
- Issue #89: 1 log needs archiving
- Orphaned: 1 log needs archiving
- Already archived: 3 logs would be cleaned

Would free: 450 KB
```

## Scheduling

Can be run as cron job:
```bash
# Daily at 2 AM
0 2 * * * /fractary-logs:cleanup --older-than 30
```

Or triggered manually:
```bash
/fractary-logs:cleanup --older-than 30
```

## Safety Checks

### Before Deleting
1. Verify archive index entry exists
2. Optionally verify cloud URL accessible
3. Never delete archive index itself

### Concurrent Archival
If archival in progress for an issue:
- Skip that issue
- Report "Archival in progress, skipping"
- Continue with other issues

### Locked Files
If file in use:
- Skip that file
- Report "File locked, skipping"
- Retry on next cleanup run

## Error Handling

### Archive Failures
If new archival fails:
- Keep logs locally
- Report failure
- Continue with other logs
- Retry on next cleanup

### Deletion Failures
If cannot delete file:
- Archive succeeded (if applicable)
- Report undeletable files
- User can manually clean later
- Mark cleanup as "partial"

### Index Corruption
If index unreadable:
- STOP cleanup immediately
- Do not delete anything
- Report corruption
- User must rebuild index first

</WORKFLOW>
