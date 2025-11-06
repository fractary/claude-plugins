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
- `--handlers <providers>`: Configure specific handler(s), comma-separated (local|r2|s3|gcs|gdrive)
  - Single: `--handlers local`
  - Multiple: `--handlers local,s3,r2`
- `--handler <provider>`: (Deprecated, use --handlers) Configure single handler
- `--non-interactive`: Skip prompts, use defaults or environment variables
- `--test`: Test connection after configuration (default: true)

Examples:
```bash
# Interactive setup (prompts for handler selection)
/fractary-file:init

# Setup S3 only
/fractary-file:init --handlers s3

# Setup multiple handlers (local and S3)
/fractary-file:init --handlers local,s3

# Setup all cloud handlers
/fractary-file:init --handlers r2,s3,gcs

# Non-interactive setup using environment variables
/fractary-file:init --handlers r2,s3 --non-interactive

# Setup without connection test
/fractary-file:init --handlers local --no-test
```
</INPUTS>

<WORKFLOW>

## Step 1: Welcome Message

Display welcome banner:
```
🗄️  Fractary File Plugin Configuration
───────────────────────────────────────────

This wizard will help you configure file storage for your project.

You can configure multiple storage providers and choose a default.
Different files can use different storage locations as needed.

Default: Local filesystem storage (zero configuration required)
Supported: Local, Cloudflare R2, AWS S3, Google Cloud Storage, Google Drive

Press Ctrl+C at any time to cancel.
───────────────────────────────────────────
```

## Step 2: Parse Arguments

Extract from user input:
- `handlers`: comma-separated list or null (prompts user)
  - Accept both `--handlers` (new) and `--handler` (backwards compatibility)
  - Convert single handler to list: "s3" → "s3"
- `interactive`: true or false (default: true)
- `test_connection`: true or false (default: true)

Validation:
- If `--handlers` or `--handler` specified, validate each handler is one of: local, r2, s3, gcs, gdrive
- If invalid handler found, show error listing valid options and exit
- If `--non-interactive` and no handlers specified, default to "local"
- Remove duplicates from handler list if any

## Step 3: Invoke Config Wizard Skill

Use the @agent-fractary-file:file-manager agent to invoke the config-wizard skill with:
```json
{
  "skill": "config-wizard",
  "parameters": {
    "handlers": "local,s3,r2|s3|null",
    "interactive": true|false,
    "test_connection": true|false
  }
}
```

Note: Pass handlers as comma-separated string, not as array.

## Step 4: Display Results

After skill completes, show final summary:
```
✅ Configuration complete!

Configured handlers: {handler1, handler2, ...}
Default handler: {active_handler}
Location: {config_path}
Status: {tested ? "Tested and working" : "Saved (not tested)"}

Next steps:
  • Test connection: /fractary-file:test-connection
  • Upload a file: Use @agent-fractary-file:file-manager
  • Override handler for specific operations with handler_override
  • Switch default: /fractary-file:switch-handler
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
