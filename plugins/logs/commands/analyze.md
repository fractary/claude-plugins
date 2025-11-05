# Analyze Logs

Analyze logs for patterns, errors, summaries, or time analysis.

## Usage

```bash
/fractary-logs:analyze <type> [options]
```

## Analysis Types

- `errors`: Extract all errors
- `patterns`: Find recurring patterns
- `session`: Summarize specific session
- `time`: Analyze time spent

## Options

- `--issue <number>`: Analyze specific issue
- `--since <date>`: Start date (YYYY-MM-DD)
- `--until <date>`: End date (YYYY-MM-DD)
- `--verbose`: Show detailed breakdown

## Examples

```bash
/fractary-logs:analyze errors --issue 123
/fractary-logs:analyze patterns --since 2025-01-01
/fractary-logs:analyze session 123
/fractary-logs:analyze time --since 2025-01-01
```

## Prompt

Use the @agent-fractary-logs:log-manager agent to analyze logs with the following request:

```json
{
  "operation": "analyze",
  "parameters": {
    "analysis_type": "errors|patterns|session|time",
    "issue_number": null,
    "since_date": null,
    "until_date": null
  },
  "options": {
    "verbose": false
  }
}
```

Analyze logs:
- **errors**: Extract all error messages with context
- **patterns**: Find recurring issues and frequencies
- **session**: Generate session summary
- **time**: Analyze time spent on work
- Return formatted analysis results
