---
name: fractary-logs:archive
description: Archive all logs for a completed issue to cloud storage
argument-hint: <issue_number> [--force] [--retry]
---

# Archive Logs

Archive all logs for a completed issue to cloud storage.

## Usage

```bash
/fractary-logs:archive <issue_number> [--force]
```

## Arguments

- `issue_number`: GitHub issue number (required)

## Options

- `--force`: Skip checks and force re-archive
- `--retry`: Retry failed uploads from a partial archive

## What It Does

1. Collects all logs for issue (sessions, builds, deployments, debug)
2. Compresses large logs (> 1MB)
3. Uploads to cloud storage via fractary-file
4. Tracks upload status per file (pending/uploaded/failed)
5. Updates archive index with partial/complete status
6. Comments on GitHub issue
7. Removes local copies

**With --retry flag**:
- Identifies files with failed/pending uploads from previous attempt
- Re-attempts uploads for failed files only
- Updates archive status to complete when all uploads succeed
- Preserves already-uploaded files (no re-upload)

## Prompt

Use the @agent-fractary-logs:log-manager agent to archive logs with the following request:

```json
{
  "operation": "archive",
  "parameters": {
    "issue_number": "<issue_number>",
    "trigger": "manual"
  },
  "options": {
    "force": false,
    "retry": false
  }
}
```

Archive logs for issue:
- Collect all logs for the issue
- Compress if > 1MB
- Upload to cloud: `archive/logs/{year}/{month}/{issue}/`
- Update archive index
- Comment on GitHub issue with archive URLs
- Clean local storage
- Commit index update
