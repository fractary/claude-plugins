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

## 4. Prepare Files for Cloud Upload

For each log file, prepare metadata for upload:

1. Generate cloud path:
   ```
   archive/logs/{year}/{month}/{issue}/filename.ext
   ```
2. Calculate checksum (SHA-256):
   ```bash
   sha256sum "$LOG_FILE" | cut -d' ' -f1
   ```
3. Prepare upload metadata:
   ```json
   {
     "local_path": "/logs/sessions/session-123-2025-01-15.md.gz",
     "remote_path": "archive/logs/2025/01/123/session-123-2025-01-15.md.gz",
     "type": "session",
     "filename": "session-123-2025-01-15.md",
     "size_bytes": 45600,
     "compressed": true,
     "checksum": "sha256:abc123...",
     "created": "2025-01-15T09:00:00Z"
   }
   ```

**Return to agent**: Array of files with upload metadata

## 5. Agent Uploads to Cloud (via file-manager)

**IMPORTANT**: This step is performed by the log-manager AGENT, not the skill.

The log-archiver skill returns control to the log-manager agent with the list of files to upload.

The log-manager agent then:

1. For each file in the upload list:
   - Invoke @agent-fractary-file:file-manager with upload operation:
     ```json
     {
       "operation": "upload",
       "parameters": {
         "local_path": "/logs/sessions/session-123-2025-01-15.md.gz",
         "remote_path": "archive/logs/2025/01/123/session-123-2025-01-15.md.gz",
         "public": false
       }
     }
     ```
   - Wait for upload completion
   - Receive cloud URL from response
   - Add cloud URL to metadata

2. Verify all uploads succeeded

3. Build complete archive metadata with URLs:
   ```json
   {
     "type": "session",
     "filename": "session-123-2025-01-15.md",
     "local_path": "/logs/sessions/session-123-2025-01-15.md",
     "cloud_url": "r2://fractary-logs/archive/logs/2025/01/123/...",
     "public_url": "https://storage.example.com/...",
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

## 6. Update Archive Index

**Performed by log-manager agent** after successful uploads.

The agent invokes the log-archiver skill again (or uses a script) to update the index:

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

## 7. Comment on GitHub Issue

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

## 8. Clean Local Storage

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

## 9. Git Commit

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

## 10. Return Summary

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

### Retry Strategy

**Automatic Retries** for transient failures:
- **Network errors**: Retry up to 3 times with exponential backoff (2s, 4s, 8s)
- **Rate limits**: Retry with backoff (10s, 30s, 60s)
- **Timeouts**: Retry up to 2 times with increased timeout

**No Retry** for permanent failures:
- Authentication errors (invalid credentials)
- Permission errors (access denied)
- File not found errors

**Retry Limits**:
- Maximum 3 retries per file per archive operation
- Maximum 10 minutes total retry time per file
- Exponential backoff between retries

### Partial Upload Tracking

Each file in the archive index tracks its upload status:
- `upload_status`: "pending" | "uploaded" | "failed" | "retrying"
- `upload_timestamp`: When status was last updated
- `upload_attempt`: Number of upload attempts
- `last_error`: Error message from last failure
- `cloud_url`: Set when upload succeeds

The archive entry has flags:
- `partial_archive`: true if any file is failed/pending/retrying
- `upload_complete`: true if all files are uploaded
- `retry_count`: Total number of retries performed

### Cleanup Procedures

**On Upload Failure**:
1. Keep compressed files locally (don't delete)
2. Mark file status as "failed" in index
3. Log error details for troubleshooting
4. Clean up temporary files (*.tmp, *.part)

**On Partial Success**:
1. Keep all local files until all uploads succeed
2. Clean up successfully uploaded compressed files
3. Preserve failed files for manual intervention

**Orphaned File Cleanup**:
- Compressed files (*.gz) older than 7 days with no index entry
- Temporary files (*.tmp) older than 24 hours
- Lock files (*.lock) older than 1 hour with no active process

### Partial Upload Workflow

If some files uploaded, others failed:

1. **Track each file status**:
   ```bash
   scripts/update-file-status.sh <issue> <filepath> "uploaded" "<cloud_url>"
   scripts/update-file-status.sh <issue> <filepath> "failed"
   ```

2. **Index automatically marked as partial**:
   - `partial_archive: true`
   - `upload_complete: false`

3. **Return partial archive info to user**:
   ```
   ⚠️  Partial archive completed for issue #123
     Uploaded: 2 of 3 files
     Failed: 1 file

   Failed files:
     - /logs/builds/123-build.log.gz

   Retry with: /fractary-logs:archive 123 --retry
   ```

4. **Local files preserved** until all uploads succeed

### Retry Failed Uploads

Execute `scripts/retry-failed-uploads.sh <issue>`

1. Query index for files with status "failed" or "pending"
2. Check if local files still exist
3. Return list of files to retry
4. Agent re-invokes file-manager for each file
5. Update status as uploads succeed/fail
6. When all succeed: `partial_archive` → false, `upload_complete` → true

Example:
```bash
# Check for failed uploads
./scripts/retry-failed-uploads.sh 123
# Returns JSON with files to retry

# Agent uploads each file and updates status
./scripts/update-file-status.sh 123 "/logs/builds/123-build.log.gz" "uploaded" "r2://..."

# Archive now complete
```

### Index Update Failed

If uploads succeeded but index update failed:

1. Files are in cloud (durable)
2. Local files remain (can rebuild index)
3. Alert user to manual recovery
4. User can re-run archive with --force to rebuild index

**Transaction-Like Index Updates**:
1. Create backup: `cp .archive-index.json .archive-index.json.backup`
2. Write new index to temporary file: `.archive-index.json.tmp`
3. Validate JSON structure of temporary file
4. Atomic rename: `mv .archive-index.json.tmp .archive-index.json`
5. Remove backup on success
6. On failure: Restore from backup

**Rollback Procedure**:
If index update fails after successful uploads:
```bash
# Restore previous index
cp .archive-index.json.backup .archive-index.json

# Mark archive as partial in restored index
./scripts/mark-partial-archive.sh <issue> "Index update failed"

# Files are in cloud but not indexed
# User can manually re-run: /fractary-logs:archive <issue> --reindex-only
```

Do NOT write to /tmp - index is the source of truth.

### Cleanup Failed

If cannot delete local files after successful upload:

1. Archive succeeded (cloud is source of truth)
2. `upload_complete: true` in index
3. Log which files couldn't be deleted
4. Files can be manually cleaned later
5. Mark archival as successful

</WORKFLOW>
