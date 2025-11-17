# Partial Upload Recovery

## Overview

The log-archiver skill implements robust partial upload recovery to handle cloud upload failures gracefully. When some files succeed and others fail during archival, the system tracks individual file upload status and allows retry without re-uploading successfully transferred files.

## Upload Status Tracking

### Per-File Status

Each log file in the archive index has these additional fields:

```json
{
  "local_path": "/logs/sessions/session-123.md.gz",
  "remote_path": "archive/logs/2025/01/123/session-123.md.gz",
  "upload_status": "uploaded",     // "pending" | "uploaded" | "failed"
  "upload_timestamp": "2025-01-15T14:30:00Z",
  "cloud_url": "r2://fractary-logs/..."  // Only set when uploaded
}
```

### Archive-Level Flags

The archive entry tracks overall status:

```json
{
  "issue_number": "123",
  "partial_archive": false,        // true if any file is failed/pending
  "upload_complete": true,         // true if all files are uploaded
  "logs": [ /* file entries */ ]
}
```

## Workflow

### Initial Archive Attempt

1. Agent collects logs and prepares metadata
2. Agent attempts to upload each file via file-manager
3. **For each file**:
   - Success: `update-file-status.sh <issue> <path> "uploaded" "<cloud_url>"`
   - Failure: `update-file-status.sh <issue> <path> "failed"`
4. Index automatically recalculates `partial_archive` and `upload_complete`
5. Agent reports partial archive to user if any files failed

### Retry Failed Uploads

User executes: `/fractary-logs:archive 123 --retry`

1. Agent calls `retry-failed-uploads.sh 123`
2. Script returns JSON with files to retry:
   ```json
   {
     "issue_number": "123",
     "retry_count": 1,
     "files_to_retry": [
       {
         "local_path": "/logs/builds/123-build.log.gz",
         "remote_path": "archive/logs/2025/01/123/123-build.log.gz",
         "file_exists": true,
         "metadata": { /* full metadata */ }
       }
     ]
   }
   ```
3. Agent uploads only the failed files
4. Agent updates status for each retry
5. When all files uploaded: `partial_archive` → false, `upload_complete` → true

## Scripts

### update-file-status.sh

**Purpose**: Update upload status for a specific file

**Usage**:
```bash
./scripts/update-file-status.sh <issue> <filepath> <status> [cloud_url]
```

**Parameters**:
- `issue`: Issue number (numeric)
- `filepath`: Local file path (must match index entry)
- `status`: "pending" | "uploaded" | "failed"
- `cloud_url`: Optional cloud URL (required when status = "uploaded")

**Example**:
```bash
# Mark file as uploaded
./scripts/update-file-status.sh 123 "/logs/sessions/session-123.md.gz" "uploaded" "r2://..."

# Mark file as failed
./scripts/update-file-status.sh 123 "/logs/builds/123-build.log.gz" "failed"
```

**Features**:
- File locking (flock) for concurrency safety
- Atomic updates (temp file + mv)
- Automatic recalculation of partial_archive/upload_complete flags
- Input validation (numeric issue, valid status, no path traversal)

### retry-failed-uploads.sh

**Purpose**: Identify files that need retry from a partial archive

**Usage**:
```bash
./scripts/retry-failed-uploads.sh <issue>
```

**Returns**: JSON object with retry information

**Example**:
```bash
./scripts/retry-failed-uploads.sh 123
```

**Output**:
```json
{
  "issue_number": "123",
  "retry_count": 2,
  "files_to_retry": [
    {
      "local_path": "/logs/sessions/session-123.md.gz",
      "remote_path": "archive/logs/2025/01/123/session-123.md.gz",
      "type": "session",
      "file_exists": true,
      "metadata": { /* complete file metadata */ }
    }
  ]
}
```

**Features**:
- Queries index for files with status "failed" or "pending"
- Checks if local files still exist
- Returns complete metadata for agent re-upload
- Validates partial_archive flag
- Exits cleanly if archive is already complete

## Error Scenarios

### Some Files Uploaded, Others Failed

**What Happens**:
1. Successful uploads are recorded in index with status "uploaded"
2. Failed uploads are recorded with status "failed"
3. `partial_archive: true`, `upload_complete: false`
4. Local files are NOT deleted
5. User is notified of partial archive

**Recovery**:
```bash
/fractary-logs:archive 123 --retry
```

### Local File Missing During Retry

**What Happens**:
1. `retry-failed-uploads.sh` reports `file_exists: false`
2. Agent cannot upload missing file
3. Agent asks user to locate file or skip

**Options**:
- Locate original file and copy back
- Skip file (mark as permanently failed)
- Re-generate file if possible

### All Uploads Failed

**What Happens**:
1. All files marked as "failed"
2. `partial_archive: true`, `upload_complete: false`
3. No files deleted locally
4. Full retry possible

**Recovery**:
Same as partial failure - use `--retry` flag

### Network Issues During Retry

**What Happens**:
1. Some retry attempts may succeed
2. Others may fail again
3. Index reflects latest attempt status
4. Can retry again

**Best Practice**:
Multiple retry attempts are safe - already-uploaded files are not re-uploaded.

## Best Practices

### For Plugin Developers

1. **Always update file status** after each upload attempt:
   ```bash
   # Success
   ./update-file-status.sh "$ISSUE" "$FILE" "uploaded" "$URL"

   # Failure
   ./update-file-status.sh "$ISSUE" "$FILE" "failed"
   ```

2. **Don't delete local files** until `upload_complete: true`

3. **Check file existence** before uploading during retry

4. **Log failures** for debugging

### For Users

1. **Check partial archive status**:
   ```bash
   /fractary-logs:read 123  # View archive index entry
   ```

2. **Retry promptly** - local files may be cleaned up after 30 days

3. **Multiple retries are safe** - no duplicate uploads

4. **Check network connectivity** before retry

## Security Considerations

1. **File locking**: Prevents race conditions during concurrent updates
2. **Input validation**: All parameters validated before use
3. **Path traversal protection**: File paths checked for `..`
4. **Atomic operations**: Temp file + mv for consistency
5. **No /tmp usage**: Uses secure temp directories or index for state

## Testing

### Simulate Partial Upload

```bash
# Archive logs
/fractary-logs:archive 123

# Manually mark a file as failed (testing only)
./update-file-status.sh 123 "/logs/sessions/session-123.md.gz" "failed"

# Check retry list
./retry-failed-uploads.sh 123

# Retry
/fractary-logs:archive 123 --retry
```

### Verify Index State

```bash
# View archive entry
jq '.archives[] | select(.issue_number == "123")' /logs/.archive-index.json

# Check specific file status
jq '.archives[] | select(.issue_number == "123") | .logs[] | select(.local_path == "/logs/sessions/session-123.md.gz")' /logs/.archive-index.json
```

## See Also

- [Archive Process](archive-process.md)
- [Archive Issue Logs Workflow](../workflow/archive-issue-logs.md)
- [SPEC-00029-14: Log Archive Workflow](../../../../specs/SPEC-00029-14-log-archive-workflow.md)
