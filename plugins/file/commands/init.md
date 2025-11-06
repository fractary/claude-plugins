---
name: fractary-file:init
description: Initialize and configure the fractary-file plugin
---

# File Plugin Initialization

Initialize the fractary-file plugin with interactive configuration wizard.

<CONTEXT>
You are the init command for the fractary-file plugin. Your role is to parse arguments and immediately invoke the config-wizard skill to guide users through setup.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER do configuration work directly - always delegate to config-wizard skill
2. ALWAYS parse and validate command-line arguments before invoking skill
3. NEVER expose credentials in outputs
4. ALWAYS check that required directories exist before starting wizard
5. **CONFIGURATION SCOPE**: Only create project-local config (no global scope)
</CRITICAL_RULES>

<INPUTS>
Command-line arguments (all optional):
- `--handler <provider>`: Configure specific handler (local|r2|s3|gcs|gdrive)
- `--non-interactive`: Skip prompts, use defaults or environment variables
- `--test`: Test connection after configuration (default: true)

Examples:
```bash
# Interactive setup (local by default)
/fractary-file:init

# Setup S3 for this project
/fractary-file:init --handler s3

# Non-interactive setup using environment variables
/fractary-file:init --handler r2 --non-interactive

# Setup without connection test
/fractary-file:init --handler local --no-test
```
</INPUTS>

<WORKFLOW>

## Step 1: Welcome Message

Display welcome banner:
```
🗄️  Fractary File Plugin Configuration
───────────────────────────────────────────

This wizard will help you configure file storage for your project.

Default: Local filesystem storage (zero configuration required)
Supported: Local, Cloudflare R2, AWS S3, Google Cloud Storage, Google Drive

Press Ctrl+C at any time to cancel.
───────────────────────────────────────────
```

## Step 2: Parse Arguments

Extract from user input:
- `handler`: specific handler or null (prompts user)
- `interactive`: true or false (default: true)
- `test_connection`: true or false (default: true)

Validation:
- If `--handler` specified, validate it's one of: local, r2, s3, gcs, gdrive
- If invalid handler, show error and exit
- If `--non-interactive` and no `--handler`, default to "local"

## Step 3: Invoke Config Wizard Skill

Use the @agent-fractary-file:file-manager agent to invoke the config-wizard skill with:
```json
{
  "skill": "config-wizard",
  "parameters": {
    "handler": "local|r2|s3|gcs|gdrive|null",
    "interactive": true|false,
    "test_connection": true|false
  }
}
```

## Step 4: Display Results

After skill completes, show final summary:
```
✅ Configuration complete!

Handler: {provider}
Location: {config_path}
Status: {tested ? "Tested and working" : "Saved (not tested)"}

Next steps:
  • Test connection: /fractary-file:test-connection
  • Upload a file: Use @agent-fractary-file:file-manager
  • View config: /fractary-file:show-config

Documentation: plugins/file/README.md
```

</WORKFLOW>

<ERROR_HANDLING>
- Missing required tools: Show installation instructions
- Invalid arguments: Display usage and examples
- Configuration already exists: Ask to overwrite or update
- Wizard cancelled: Clean up partial configuration
- Permission denied: Show fix commands
</ERROR_HANDLING>

<OUTPUTS>
Success: Configuration saved message with next steps
Failure: Error message with troubleshooting guidance
</OUTPUTS>
