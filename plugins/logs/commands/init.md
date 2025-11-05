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
- Create log directories (`/logs/sessions`, `/logs/builds`, `/logs/deployments`, `/logs/debug`)
- Initialize archive index at `/logs/.archive-index.json`
- Verify fractary-file plugin is available and configured
- Report configuration status
