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

## What It Does

1. Collects all logs for issue (sessions, builds, deployments, debug)
2. Compresses large logs (> 1MB)
3. Uploads to cloud storage via fractary-file
4. Updates archive index
5. Comments on GitHub issue
6. Removes local copies

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
    "force": false
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
