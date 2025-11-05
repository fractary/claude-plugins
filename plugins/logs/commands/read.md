---
name: fractary-logs:read
description: Read specific log file (local or archived)
argument-hint: <issue_number> [--type <type>]
---

# Read Logs

Read specific log file (local or archived).

## Usage

```bash
/fractary-logs:read <issue_number> [--type <type>]
```

## Arguments

- `issue_number`: GitHub issue number (required)

## Options

- `--type <type>`: Specific log type (session|build|deployment|debug)

## What It Does

1. Checks if logs are local or archived
2. Reads from local storage or cloud
3. Displays log content

## Prompt

Use the @agent-fractary-logs:log-manager agent to read logs with the following request:

```json
{
  "operation": "read",
  "parameters": {
    "issue_number": "<issue_number>",
    "log_type": null
  }
}
```

Read logs for issue:
- Check archive index for location
- If local: Read directly
- If archived: Use fractary-file to read from cloud
- Format and display log content
- Show all logs for issue or specific type if specified
