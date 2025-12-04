---
name: fractary-logs:search
description: Search across local and archived logs with filters
model: claude-haiku-4-5
argument-hint: '"<query>" [--issue <number>] [--type <type>] [--since <date>] [--until <date>] [--regex] [--local-only] [--cloud-only] [--max-results <n>] [--context <n>]'
---

# Search Logs

Search across local and archived logs.

## Usage

```bash
/fractary-logs:search "<query>" [options]
```

## Arguments

- `query`: Text or regex to search (required)

## Options

- `--issue <number>`: Search only logs for specific issue
- `--type <type>`: Filter by log type (session|build|deployment|debug)
- `--since <date>`: Start date (YYYY-MM-DD)
- `--until <date>`: End date (YYYY-MM-DD)
- `--regex`: Treat query as regular expression
- `--local-only`: Search only local logs
- `--cloud-only`: Search only archived logs
- `--max-results <n>`: Limit results (default: 100)
- `--context <n>`: Lines of context (default: 3)

## Examples

```bash
/fractary-logs:search "OAuth implementation"
/fractary-logs:search "error" --issue 123 --type build
/fractary-logs:search --regex "error:\s+\w+" --since 2025-01-01
```

## Prompt

Use the @agent-fractary-logs:log-manager agent to search logs with the following request:

```json
{
  "operation": "search",
  "parameters": {
    "query": "<query>"
  },
  "filters": {
    "issue_number": null,
    "log_type": null,
    "since_date": null,
    "until_date": null
  },
  "options": {
    "regex": false,
    "local_only": false,
    "cloud_only": false,
    "max_results": 100,
    "context_lines": 3
  }
}
```

Search logs:
- Search local logs (fast)
- Search cloud logs via index if enabled
- Aggregate and rank results
- Return formatted matches with context
