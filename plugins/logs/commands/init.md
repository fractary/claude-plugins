---
name: fractary-logs:init
description: Initialize fractary-logs plugin configuration and storage directories
argument-hint: "[--force]"
---

# Initialize fractary-logs Configuration

Initialize the fractary-logs plugin configuration.

## Usage

```bash
/fractary-logs:init [--force]
```

## Options

- `--force`: Overwrite existing configuration

## What It Does

1. Creates configuration directory: `.fractary/plugins/logs/`
2. Copies example configuration if none exists
3. Creates log storage directories
4. Initializes archive index
5. Verifies fractary-file integration

## Prompt

Use the @agent-fractary-logs:log-manager agent to initialize the plugin configuration with the following request:

```json
{
  "operation": "init",
  "options": {
    "force": false
  }
}
```

Initialize plugin configuration:
- Create `.fractary/plugins/logs/config.json` from example
- **Validate configuration against JSON schema** (config.schema.json):
  - Checks required fields, types, and constraints
  - Validates enum values and numeric ranges
  - Ensures path formats are correct
  - Warns if validation tools not available (optional)
- Create log directories (`/logs/sessions`, `/logs/builds`, `/logs/deployments`, `/logs/debug`)
- Initialize archive index at `/logs/.archive-index.json`
- Verify fractary-file plugin is available and configured
- **Check for old logs and trigger auto-backup** (if `auto_backup.trigger_on_init` enabled):
  - Find logs older than `auto_backup.backup_older_than_days` (default 7 days)
  - Archive to cloud with AI-generated summaries (if enabled)
  - Update archive index
  - Clean local storage
- Report configuration status and auto-backup results
