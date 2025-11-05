# Stop Session Capture

Stop the active session capture and finalize the log.

## Usage

```bash
/fractary-logs:stop
```

## What It Does

1. Stops recording conversation
2. Updates session metadata (end time, duration)
3. Generates session summary
4. Finalizes session file

## Prompt

Use the @agent-fractary-logs:log-manager agent to stop session capture with the following request:

```json
{
  "operation": "stop"
}
```

Stop active session capture:
- Update session file with completion info
- Calculate and record duration
- Generate session summary
- Clear active session context
- Return final session file path and statistics
