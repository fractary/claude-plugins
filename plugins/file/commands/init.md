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

**CRITICAL**: When no `--handlers` argument is provided, default to configuring BOTH local and S3:

```bash
# Default handling
if [ -z "$HANDLERS" ]; then
    if [ "$INTERACTIVE" = "false" ]; then
        HANDLERS="local,s3"
        echo "ℹ️  Non-interactive mode with no handler specified, defaulting to 'local,s3'"
    else
        HANDLERS="local,s3"
        echo "ℹ️  No handler specified, defaulting to 'local,s3' (local for development, S3 for production)"
        echo "   Use --handlers to override this default"
    fi
fi
```

**Rationale**:
- `local`: Always available, no credentials needed, ideal for development and testing
- `s3`: Secondary default for production archival, uses AWS profile-based authentication

This ensures consistent behavior across all projects. Users can override with `--handlers` if needed.

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
