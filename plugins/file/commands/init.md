---
name: fractary-file:init
description: Initialize and configure the fractary-file plugin
model: claude-haiku-4-5
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
- `interactive`: true or false (default: true)
- `test_connection`: true or false (default: true)

### 2.1 Backwards Compatibility Handling

Handle both `--handler` (deprecated) and `--handlers` (current):

```bash
HANDLERS=""

# Check for both flags
if [ -n "$FLAG_HANDLERS" ]; then
    # New flag: --handlers local,s3,r2
    HANDLERS="$FLAG_HANDLERS"
elif [ -n "$FLAG_HANDLER" ]; then
    # Old flag: --handler s3 (convert to new format)
    HANDLERS="$FLAG_HANDLER"
    echo "⚠️  Note: --handler is deprecated. Use --handlers instead."
    echo "   Converted: --handler $FLAG_HANDLER → --handlers $HANDLERS"
fi
```

**Conversion Examples**:
- `--handler s3` → `--handlers s3` (single handler)
- Old behavior preserved, new format used internally

### 2.2 Handler List Validation

Validate and normalize handler list:

```bash
# Remove duplicates and validate
if [ -n "$HANDLERS" ]; then
    # Convert comma-separated string to array
    IFS=',' read -ra HANDLER_ARRAY <<< "$HANDLERS"

    # Remove duplicates
    UNIQUE_HANDLERS=($(echo "${HANDLER_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))

    # Validate each handler
    VALID_HANDLERS=("local" "r2" "s3" "gcs" "gdrive")
    for handler in "${UNIQUE_HANDLERS[@]}"; do
        if [[ ! " ${VALID_HANDLERS[@]} " =~ " ${handler} " ]]; then
            echo "❌ Error: Invalid handler '$handler'"
            echo ""
            echo "Valid handlers: ${VALID_HANDLERS[@]}"
            exit 1
        fi
    done

    # Rebuild cleaned handlers list
    HANDLERS=$(IFS=,; echo "${UNIQUE_HANDLERS[*]}")
fi

# Default handling
if [ "$INTERACTIVE" = "false" ] && [ -z "$HANDLERS" ]; then
    HANDLERS="local"
    echo "ℹ️  Non-interactive mode with no handler specified, defaulting to 'local'"
fi
```

**Edge Cases Handled**:
1. **Duplicates**: `--handlers local,s3,local` → `local,s3`
2. **Invalid handlers**: `--handlers s3,invalid` → Error with valid options
3. **Empty input**:
   - Interactive: Prompts user to select
   - Non-interactive: Defaults to `local`
4. **Whitespace**: Trimmed automatically
5. **Case sensitivity**: Validated as-is (must be lowercase)

### 2.3 Default Handler Selection

**CRITICAL**: When no `--handlers` argument is provided, intelligently detect which handlers to configure:

```bash
# Default handling
if [ -z "$HANDLERS" ]; then
    # Always include local
    HANDLERS="local"

    # In interactive mode or if AWS profiles exist, add S3
    if [ "$INTERACTIVE" = "true" ]; then
        # Interactive: always offer S3 configuration
        HANDLERS="local,s3"
        echo "ℹ️  No handler specified, defaulting to 'local,s3' (local for development, S3 for production)"
        echo "   Use --handlers to override this default"
    else
        # Non-interactive: only add S3 if AWS profiles/credentials exist
        if [ -f "$HOME/.aws/config" ] || [ -f "$HOME/.aws/credentials" ]; then
            HANDLERS="local,s3"
            echo "ℹ️  Non-interactive mode: detected AWS configuration, defaulting to 'local,s3'"
        else
            HANDLERS="local"
            echo "ℹ️  Non-interactive mode: no AWS configuration detected, defaulting to 'local' only"
            echo "   Use --handlers local,s3 to configure S3"
        fi
    fi
fi
```

**Rationale**:
- `local`: Always included, no credentials needed, ideal for development and testing
- `s3`: Added intelligently:
  - **Interactive mode**: Always offered (user can configure or skip)
  - **Non-interactive mode**: Only if AWS config exists (avoids forcing S3 setup when not available)

This ensures consistent behavior while respecting the environment:
- Interactive users get the full experience with guidance
- Non-interactive environments (CI/CD) only configure what's available
- Users can always override with explicit `--handlers` argument

**Breaking Change Notice**:
- **Previous behavior**: Prompted user to select handlers interactively
- **New behavior**: Defaults to `local,s3` (interactive) or `local` (non-interactive without AWS)
- **Migration**: Users who prefer different defaults can use `--handlers` flag

### 2.4 Type Transformation Flow

The handlers parameter goes through several transformations:

```
CLI Flag → String → Array → String → Array (in config-wizard)
```

**Detailed Flow**:

1. **CLI Input** (User):
   ```bash
   /fractary-file:init --handlers local,s3,r2
   ```

2. **Parsed as String** (init command, Step 2.1):
   ```bash
   HANDLERS="local,s3,r2"
   ```

3. **Converted to Array for Validation** (init command, Step 2.2):
   ```bash
   IFS=',' read -ra HANDLER_ARRAY <<< "$HANDLERS"
   # HANDLER_ARRAY=("local" "s3" "r2")
   ```

4. **Validated and De-duplicated** (init command, Step 2.2):
   ```bash
   UNIQUE_HANDLERS=($(echo "${HANDLER_ARRAY[@]}" | tr ' ' '\n' | sort -u | tr '\n' ' '))
   ```

5. **Converted Back to String** (init command, Step 2.2):
   ```bash
   HANDLERS=$(IFS=,; echo "${UNIQUE_HANDLERS[*]}")
   # HANDLERS="local,r2,s3" (sorted, de-duped)
   ```

6. **Passed to Skill as String** (init command, Step 3):
   ```json
   {
     "skill": "config-wizard",
     "parameters": {
       "handlers": "local,r2,s3"
     }
   }
   ```

7. **Converted to Array in Skill** (config-wizard, Phase 2.1):
   ```bash
   IFS=',' read -ra HANDLER_LIST <<< "$HANDLERS"
   # HANDLER_LIST=("local" "r2" "s3")
   ```

8. **Iterated Over** (config-wizard, Phase 3.0.1):
   ```bash
   for HANDLER in "${HANDLER_LIST[@]}"; do
       # Configure each handler
   done
   ```

**Why String → Array → String → Array?**
- CLI flags are strings
- Validation requires array operations (dedup, check membership)
- Agent invocation uses JSON (strings)
- Skill iteration requires array looping

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

<MANDATORY_IMPLEMENTATION>
**YOU MUST EXECUTE THESE STEPS - DO NOT SKIP ANY STEP:**

**Step 1: Check if config already exists**
```bash
if [ -f ".fractary/plugins/file/config.json" ]; then
    echo "⚠️ Configuration already exists at .fractary/plugins/file/config.json"
    # If --force flag was NOT provided, ask user before overwriting
fi
```

**Step 2: Create the configuration directory**
This is the CRITICAL step - you MUST run these commands:
```bash
# Create directory
mkdir -p .fractary/plugins/file
```

**Step 3: Create the configuration file with local handler (default)**
```bash
# Create config file with local handler as default
cat > .fractary/plugins/file/config.json << 'EOF'
{
  "schema_version": "1.0",
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": ".",
      "create_directories": true,
      "permissions": "0755"
    }
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true,
    "parallel_uploads": 4
  }
}
EOF

# Set permissions
chmod 600 .fractary/plugins/file/config.json
```

**Step 4: Verify the file was created**
```bash
if [ -f ".fractary/plugins/file/config.json" ]; then
    echo "✅ Configuration created: .fractary/plugins/file/config.json"
    cat .fractary/plugins/file/config.json
else
    echo "❌ Failed to create configuration file"
fi
```

**Step 5: Show success message and next steps**
Display:
```
✅ Fractary File Plugin initialized!

Configuration: .fractary/plugins/file/config.json
Default handler: local

Next steps:
1. Test connection: /fractary-file:test-connection
2. Add cloud handlers (S3, R2, etc.): Edit the config file
3. Upload a file: Use @agent-fractary-file:file-manager
```

**Adding Additional Handlers:**
To add S3, R2, or other handlers, edit `.fractary/plugins/file/config.json` and add handler sections from the example config at `plugins/file/config/config.example.json`.

</MANDATORY_IMPLEMENTATION>
