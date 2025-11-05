# Archive Issue Logs Workflow

<WORKFLOW>

## 1. Validate Archive Request

### Check if Already Archived
Query archive index:
```bash
jq -e --arg issue "$ISSUE_NUMBER" \
  '.archives[] | select(.issue_number == $issue)' \
  /logs/.archive-index.json
```

If found:
- Check archive_reason and archived_at
- Ask user if force re-archive needed
- If not force: Skip archival, return existing archive info

### Verify Issue Status
For lifecycle-based archival:
- issue_closed: Verify issue is actually closed
- pr_merged: Verify PR is merged
- manual: No verification needed

## 2. Collect All Logs for Issue

Execute `scripts/collect-logs.sh <issue_number>`

Searches in:
- `/logs/sessions/` for `*{issue}*` or `session-{issue}-*`
- `/logs/builds/` for `{issue}-*`
- `/logs/deployments/` for `{issue}-*`
- `/logs/debug/` for `{issue}-*`

Returns JSON array:
```json
[
  "/logs/sessions/session-123-2025-01-15.md",
  "/logs/sessions/session-123-2025-01-16.md",
  "/logs/builds/123-build.log"
]
```

If no logs found:
- Report "No logs found for issue"
- Create archive index entry with empty logs array
- Exit successfully

## 3. Compress Large Logs

For each log file:
1. Check size: `du -m "$LOG_FILE"`
2. If size > threshold (default 1 MB):
   - Execute `scripts/compress-logs.sh "$LOG_FILE"`
   - Returns compressed file path
3. If size <= threshold:
   - Use original file

Result: Array of files ready for upload (mix of .gz and originals)

## 4. Upload to Cloud Storage

For each log file:
1. Generate cloud path:
   ```
   archive/logs/{year}/{month}/{issue}/filename.ext
   ```
2. Execute `scripts/upload-to-cloud.sh <issue> <file>`
   - Uses fractary-file agent to upload
   - Returns cloud URL
3. Calculate checksum (SHA-256)
4. Record metadata:
   ```json
   {
     "type": "session|build|deployment|debug",
     "filename": "session-123-2025-01-15.md",
     "local_path": "/logs/sessions/session-123-2025-01-15.md",
     "cloud_url": "s3://bucket/archive/logs/2025/01/123/...",
     "size_bytes": 45600,
     "compressed": true,
     "checksum": "sha256:abc123...",
     "created": "2025-01-15T09:00:00Z",
     "archived": "2025-01-15T14:00:00Z"
   }
   ```

If upload fails for any file:
- STOP archival process
- Do not delete local files
- Return error to user
- Keep already-uploaded files (no rollback)

## 5. Update Archive Index

Execute `scripts/update-index.sh <issue> <metadata_json>`

Adds entry to `/logs/.archive-index.json`:
```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "issue_title": "Implement user authentication",
  "archived_at": "2025-01-15T14:00:00Z",
  "archive_reason": "issue_closed",
  "logs": [
    { /* log metadata */ },
    { /* log metadata */ }
  ],
  "total_size_bytes": 173600,
  "total_logs": 3,
  "compression_ratio": 0.35
}
```

Sort archives by issue_number (descending).
Update last_updated timestamp.

## 6. Comment on GitHub Issue

If gh CLI available and configured:

Generate comment:
```markdown
📦 **Logs Archived**

Session logs and operational logs have been archived to cloud storage.

**Sessions**:
- [Session 2025-01-15](https://storage.example.com/.../session-2025-01-15.md.gz) (45.6 KB, 2h 30m)
- [Session 2025-01-16](https://storage.example.com/.../session-2025-01-16.md) (32.1 KB, 1h 15m)

**Build Logs**:
- [Build Log](https://storage.example.com/.../build.log.gz) (45.0 KB)

**Total**: 3 logs, 122.7 KB compressed

Archived: 2025-01-15 14:00 UTC

These logs are permanently stored and searchable via:
- `/fractary-logs:read 123`
- `/fractary-logs:search "<query>"`
```

Post comment:
```bash
gh issue comment $ISSUE_NUMBER --body "$COMMENT"
```

## 7. Clean Local Storage

Execute `scripts/cleanup-local.sh <issue_number>`

For each archived log:
1. Verify entry in archive index
2. Verify cloud URL accessible (optional)
3. Delete local file:
   ```bash
   rm "$LOG_FILE"
   ```
4. Track freed space

Keep the archive index file locally!

## 8. Git Commit

Commit the updated index:
```bash
git add /logs/.archive-index.json
git commit -m "Archive logs for issue #$ISSUE_NUMBER

- Archived $LOG_COUNT logs to cloud storage
- Updated archive index
- Freed $FREED_SPACE locally

Archive reason: $TRIGGER
Issue: #$ISSUE_NUMBER"
```

## 9. Return Summary

Output:
```
✓ Logs archived for issue #123
  Collected: 3 logs
  Compressed: 1 log (128 KB → 45 KB, 65% reduction)
  Uploaded: 3 logs to archive/logs/2025/01/123/
  Index updated: /logs/.archive-index.json
  GitHub commented: issue #123
  Local cleaned: 173 KB freed

Archive complete!
```

## Error Recovery

### Partial Upload
If some files uploaded, others failed:
1. Record successful uploads in index
2. Mark as "partial_archive"
3. Return list of failed files
4. User can retry failed files

### Index Update Failed
If uploads succeeded but index update failed:
1. Write metadata to recovery file: `/tmp/archive-recovery-{issue}.json`
2. Alert user to manual index rebuild
3. Do not delete local files

### Cleanup Failed
If cannot delete local files:
1. Archive succeeded, logs in cloud
2. Log which files couldn't be deleted
3. User can manually clean later
4. Mark as successful (cloud is source of truth)

</WORKFLOW>
