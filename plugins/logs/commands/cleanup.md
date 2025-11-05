---
name: fractary-logs:cleanup
description: Archive and clean up old logs based on age threshold
argument-hint: "[--older-than <days>] [--dry-run]"
---

# Cleanup Old Logs

Archive and clean up old logs (time-based safety net).

## Usage

```bash
/fractary-logs:cleanup [--older-than <days>] [--dry-run]
```

## Options

- `--older-than <days>`: Age threshold in days (default: 30)
- `--dry-run`: Show what would be done without doing it

## What It Does

1. Finds logs older than threshold
2. Groups by issue number
3. Archives unarchived logs
4. Cleans already-archived logs
5. Handles orphaned logs

## Prompt

Use the @agent-fractary-logs:log-manager agent to clean up old logs with the following request:

```json
{
  "operation": "cleanup",
  "parameters": {
    "age_days": 30
  },
  "options": {
    "dry_run": false
  }
}
```

Time-based cleanup:
- Find logs older than threshold
- Check archive status
- Archive unarchived logs
- Clean already-archived logs
- Archive orphaned logs to `archive/logs/{year}/{month}/orphaned/`
- Report cleanup summary
