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
2. Copies **only** `config.json` from plugin example (no other files)
3. Creates log storage directories
4. Initializes archive index
5. Verifies fractary-file integration

**⚠️ IMPORTANT:** Only `config.json` is copied to `.fractary/plugins/logs/`. Do not manually copy scripts, schemas, or documentation files from the plugin source.

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
- Create `.fractary/plugins/logs/config.json` from example (schema v2.0)
- **Configuration includes path-based retention policies** with sensible defaults:
  - Sessions: 7 days local, forever cloud (high priority)
  - Builds: 3 days local, 30 days cloud (medium priority)
  - Deployments: 30 days local, forever cloud (critical priority)
  - Tests: 3 days local, 7 days cloud (low priority)
  - Debug: 7 days local, 30 days cloud (medium priority)
  - Audit: 90 days local, forever cloud (critical priority)
  - Operational: 14 days local, 90 days cloud (medium priority)
  - Workflow: 7 days local, forever cloud (high priority)
  - Changelog: 7 days local, forever cloud (high priority)
- **Validate configuration against JSON schema** (config.schema.json):
  - Checks required fields, types, and constraints
  - Validates enum values and numeric ranges
  - Ensures path formats are correct
  - Warns if validation tools not available (optional)
- Create log directories (`/logs/sessions`, `/logs/builds`, `/logs/deployments`, `/logs/debug`, etc.)
- Initialize archive index at `/logs/.archive-index.json`
- Verify fractary-file plugin is available and configured
- **Check for old logs and trigger auto-backup** (if `auto_backup.trigger_on_init` enabled):
  - Find logs older than path-specific `archive_triggers.age_days` (e.g., 7 days for sessions)
  - Archive to cloud with AI-generated summaries (if enabled)
  - Update archive index
  - Clean local storage (respects `cleanup_after_archive` per path)
- Report configuration status and auto-backup results
