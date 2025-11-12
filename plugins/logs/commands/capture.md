---
name: fractary-logs:capture
description: Start capturing Claude Code conversation session for an issue
argument-hint: <issue_number>
---

# Start Session Capture

Start capturing Claude Code conversation session for an issue.

## Usage

```bash
/fractary-logs:capture <issue_number>
```

## Arguments

- `issue_number`: GitHub issue number to link session to (required)

## What It Does

1. Creates session log file
2. Links to GitHub issue
3. Begins recording conversation
4. All subsequent messages automatically captured
5. Continues until stopped or new issue started

## Prompt

Use the @agent-fractary-logs:log-manager agent to start session capture with the following request:

```json
{
  "operation": "capture",
  "parameters": {
    "issue_number": "<issue_number>"
  }
}
```

Start capturing session:
- **Check for old logs and trigger auto-backup** (if `auto_backup.trigger_on_session_start` enabled):
  - Non-blocking check for logs older than `auto_backup.backup_older_than_days` (default 7 days)
  - If found, report count and queue for background archival
  - Archive to cloud with AI-generated summaries
  - Does not block session start
- Create session file: `/logs/sessions/session-<issue>-<date>.md`
- Initialize with frontmatter (issue info, timestamps, participant)
- Begin recording conversation flow
- Return session ID and file path
- Report auto-backup status if applicable
