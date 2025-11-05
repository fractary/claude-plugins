# Log Message

Log a specific message or decision to an issue's log.

## Usage

```bash
/fractary-logs:log <issue_number> "<message>"
```

## Arguments

- `issue_number`: GitHub issue number (required)
- `message`: Message to log (required)

## What It Does

1. Checks for active session or creates entry
2. Logs the message with timestamp
3. Links to issue

## Prompt

Use the @agent-fractary-logs:log-manager agent to log a message with the following request:

```json
{
  "operation": "log",
  "parameters": {
    "issue_number": "<issue_number>",
    "message": "<message>"
  }
}
```

Log explicit message:
- Append to active session or create new entry
- Include timestamp and context
- Link to issue
