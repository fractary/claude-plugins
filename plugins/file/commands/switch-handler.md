---
name: fractary-file:switch-handler
description: Switch active storage handler
argument-hint: <handler> [--no-test] [--force]
---

# Switch Storage Handler

Switch the active storage handler to a different configured provider.

<CONTEXT>
You are the switch-handler command for the fractary-file plugin. Your role is to change the active handler in the configuration file to a different storage provider that's already configured.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS verify target handler is configured before switching
2. ALWAYS back up current configuration before modifying
3. ALWAYS validate configuration after switching
4. NEVER modify handler configurations, only active_handler field
5. ALWAYS test connection after switch (unless --no-test specified)
6. NEVER switch to unconfigured handler without user confirmation
</CRITICAL_RULES>

<INPUTS>
Required argument:
- `<handler>`: Handler name to switch to (local|r2|s3|gcs|gdrive)

Optional flags:
- `--no-test`: Skip connection test after switching
- `--force`: Switch even if handler appears unconfigured (not recommended)

Examples:
```bash
# Switch to S3 handler
/fractary-file:switch-handler s3

# Switch to local without testing
/fractary-file:switch-handler local --no-test

# Force switch to handler (skip validation)
/fractary-file:switch-handler gcs --force
```
</INPUTS>

<WORKFLOW>

## Step 1: Parse Arguments

Validate command syntax:
```bash
if [ $# -eq 0 ]; then
    echo "❌ Error: Handler name required"
    echo ""
    echo "Usage: /fractary-file:switch-handler <handler> [--no-test] [--force]"
    echo ""
    echo "Available handlers: local, r2, s3, gcs, gdrive"
    echo ""
    echo "Examples:"
    echo "  /fractary-file:switch-handler s3"
    echo "  /fractary-file:switch-handler local --no-test"
    exit 1
fi

TARGET_HANDLER="$1"
shift

# Parse flags
NO_TEST=false
FORCE=false
while [ $# -gt 0 ]; do
    case "$1" in
        --no-test) NO_TEST=true ;;
        --force) FORCE=true ;;
        *) echo "⚠️  Unknown flag: $1" ;;
    esac
    shift
done
```

Validate handler name:
```bash
case "$TARGET_HANDLER" in
    local|r2|s3|gcs|gdrive)
        # Valid handler
        ;;
    *)
        echo "❌ Error: Invalid handler '$TARGET_HANDLER'"
        echo ""
        echo "Valid handlers: local, r2, s3, gcs, gdrive"
        exit 1
        ;;
esac
```

## Step 2: Locate Configuration

Find configuration file:
```bash
if [ -f ".fractary/plugins/file/config.json" ]; then
    CONFIG_PATH=".fractary/plugins/file/config.json"
    CONFIG_SOURCE="Project"
elif [ -f "$HOME/.config/fractary/file/config.json" ]; then
    CONFIG_PATH="$HOME/.config/fractary/file/config.json"
    CONFIG_SOURCE="Global"
else
    echo "❌ Error: No configuration file found"
    echo ""
    echo "Create configuration first:"
    echo "  /fractary-file:init"
    exit 1
fi
```

## Step 3: Load Current Configuration

```bash
# Validate JSON
if ! jq '.' "$CONFIG_PATH" > /dev/null 2>&1; then
    echo "❌ Error: Configuration file is not valid JSON"
    echo "Path: $CONFIG_PATH"
    exit 1
fi

# Load config
CONFIG=$(cat "$CONFIG_PATH")
CURRENT_HANDLER=$(echo "$CONFIG" | jq -r '.active_handler')

echo "Switching Active Handler"
echo "═══════════════════════════════════════"
echo ""
echo "Config: $CONFIG_PATH ($CONFIG_SOURCE)"
echo "Current handler: $CURRENT_HANDLER"
echo "Target handler: $TARGET_HANDLER"
echo ""
```

## Step 4: Check if Already Active

```bash
if [ "$CURRENT_HANDLER" = "$TARGET_HANDLER" ]; then
    echo "ℹ️  Handler '$TARGET_HANDLER' is already active"
    echo ""
    echo "Current configuration is already using this handler."
    exit 0
fi
```

## Step 5: Verify Target Handler Configured

Unless --force flag is set:

```bash
if [ "$FORCE" = "false" ]; then
    # Check if handler exists in handlers section
    if ! echo "$CONFIG" | jq -e ".handlers.$TARGET_HANDLER" > /dev/null 2>&1; then
        echo "⚠️  Warning: Handler '$TARGET_HANDLER' is not configured"
        echo ""
        echo "Configuration does not have settings for '$TARGET_HANDLER' handler."
        echo ""
        echo "Configured handlers:"
        echo "$CONFIG" | jq -r '.handlers | keys[]' | sed 's/^/  • /'
        echo ""
        read -p "Configure '$TARGET_HANDLER' now? [Y/n]: " CONFIGURE

        if [ "$CONFIGURE" != "n" ]; then
            # Invoke init command for this handler
            echo ""
            echo "Launching configuration wizard..."
            /fractary-file:init --handler "$TARGET_HANDLER"

            # Reload config after init
            CONFIG=$(cat "$CONFIG_PATH")
        else
            echo ""
            echo "Switch cancelled."
            echo ""
            echo "To configure: /fractary-file:init --handler $TARGET_HANDLER"
            exit 1
        fi
    else
        echo "✓ Target handler is configured"
    fi
else
    echo "⚠️  Force mode: skipping validation"
fi
```

## Step 6: Backup Configuration

Create backup before modifying:
```bash
BACKUP_PATH="${CONFIG_PATH}.backup.$(date +%s)"
cp "$CONFIG_PATH" "$BACKUP_PATH"
echo "✓ Backup created: $BACKUP_PATH"
```

## Step 7: Update Configuration

Modify active_handler field:
```bash
UPDATED_CONFIG=$(echo "$CONFIG" | jq ".active_handler = \"$TARGET_HANDLER\"")

# Validate updated config is valid JSON
if ! echo "$UPDATED_CONFIG" | jq '.' > /dev/null 2>&1; then
    echo "❌ Error: Failed to update configuration (invalid JSON)"
    echo "Original configuration preserved."
    rm -f "$BACKUP_PATH"
    exit 1
fi

# Write updated config
echo "$UPDATED_CONFIG" | jq '.' > "$CONFIG_PATH"

# Verify file permissions (should be 0600)
chmod 0600 "$CONFIG_PATH"

echo "✓ Configuration updated"
```

## Step 8: Verify Update

```bash
# Read back and verify
VERIFY_CONFIG=$(cat "$CONFIG_PATH")
VERIFY_HANDLER=$(echo "$VERIFY_CONFIG" | jq -r '.active_handler')

if [ "$VERIFY_HANDLER" != "$TARGET_HANDLER" ]; then
    echo "❌ Error: Configuration update verification failed"
    echo ""
    echo "Restoring from backup..."
    cp "$BACKUP_PATH" "$CONFIG_PATH"
    echo "✓ Original configuration restored"
    exit 1
fi

echo "✓ Update verified"
echo ""
```

## Step 9: Test Connection

Unless --no-test flag is set:

```bash
if [ "$NO_TEST" = "false" ]; then
    echo "Testing Connection:"
    echo "───────────────────────────────────────"

    # Invoke test-connection command
    /fractary-file:test-connection

    TEST_RESULT=$?

    echo ""

    if [ $TEST_RESULT -eq 0 ]; then
        echo "✓ Connection test passed"
    else
        echo "⚠️  Connection test failed"
        echo ""
        read -p "Revert to previous handler ($CURRENT_HANDLER)? [y/N]: " REVERT

        if [ "$REVERT" = "y" ]; then
            # Restore from backup
            cp "$BACKUP_PATH" "$CONFIG_PATH"
            echo "✓ Reverted to '$CURRENT_HANDLER' handler"
            rm -f "$BACKUP_PATH"
            exit 1
        else
            echo "Kept new handler '$TARGET_HANDLER'"
            echo "Fix the configuration and test again:"
            echo "  /fractary-file:test-connection"
        fi
    fi
else
    echo "⚠️  Connection test skipped (--no-test specified)"
    echo ""
    echo "Test manually with:"
    echo "  /fractary-file:test-connection"
fi
```

## Step 10: Cleanup and Summary

```bash
# Remove backup if everything succeeded
rm -f "$BACKUP_PATH"

echo ""
echo "═══════════════════════════════════════"
echo "✅ Handler switched successfully!"
echo "═══════════════════════════════════════"
echo ""
echo "Active handler: $TARGET_HANDLER"
echo "Configuration: $CONFIG_PATH"
echo ""
echo "Commands:"
echo "  • View config: /fractary-file:show-config"
echo "  • Test again: /fractary-file:test-connection"
echo "  • Upload file: Use @agent-fractary-file:file-manager"
echo ""
echo "Documentation: plugins/file/README.md"
```

</WORKFLOW>

<COMPLETION_CRITERIA>
- Configuration file updated successfully
- active_handler field changed to target handler
- Configuration validated as valid JSON
- Backup created before modification
- Connection tested (unless --no-test)
- User notified of successful switch
</COMPLETION_CRITERIA>

<OUTPUTS>

**Success:**
```
✅ Handler switched successfully!
Active handler: {target_handler}
Connection tested: {yes|no|failed}
```

**Failure:**
```
❌ Switch failed: {error}
Original configuration preserved
```

</OUTPUTS>

<ERROR_HANDLING>

**No Configuration File:**
```
❌ Error: No configuration file found

You need to create a configuration first:
  /fractary-file:init

This will create a configuration file that you can then switch between handlers.
```

**Invalid Handler Name:**
```
❌ Error: Invalid handler 'xyz'

Valid handlers:
  • local - Local filesystem storage
  • r2 - Cloudflare R2
  • s3 - AWS S3
  • gcs - Google Cloud Storage
  • gdrive - Google Drive

Usage:
  /fractary-file:switch-handler <handler>
```

**Handler Not Configured:**
```
⚠️  Warning: Handler 'gcs' is not configured

The configuration file doesn't have settings for Google Cloud Storage.

Options:
  1. Configure now: /fractary-file:init --handler gcs
  2. Force switch anyway (not recommended): --force
  3. View configured handlers: /fractary-file:show-config

Currently configured handlers:
  • local
  • s3

To switch to a configured handler:
  /fractary-file:switch-handler s3
```

**Configuration File Corrupt:**
```
❌ Error: Configuration file is not valid JSON

File: {path}

Fix:
  1. Restore from backup if available: {path}.backup.*
  2. Validate JSON: jq '.' {path}
  3. Recreate: /fractary-file:init
```

**Connection Test Failed After Switch:**
```
⚠️  Handler switched but connection test failed

Active handler: {new_handler}
Error: {test_error}

Options:
  1. Revert to previous handler ({old_handler})
  2. Fix configuration and test again
  3. Keep new handler and troubleshoot

What would you like to do? [1/2/3]:
```

**Permission Denied:**
```
❌ Error: Permission denied writing to configuration file

File: {path}

Fix:
  chmod 0600 {path}
  chown $USER:$USER {path}
```

**Backup Failed:**
```
⚠️  Warning: Could not create backup

The switch will proceed, but you won't have a backup of your current configuration.

Proceed anyway? [y/N]:
```

</ERROR_HANDLING>

<EXAMPLES>

## Example 1: Simple Switch

```bash
$ /fractary-file:switch-handler s3

Switching Active Handler
═══════════════════════════════════════

Config: .fractary/plugins/file/config.json (Project)
Current handler: local
Target handler: s3

✓ Target handler is configured
✓ Backup created: .fractary/plugins/file/config.json.backup.1705000000
✓ Configuration updated
✓ Update verified

Testing Connection:
───────────────────────────────────────
🔍 Testing Connection
  • Checking AWS CLI... ✓
  • Checking credentials... ✓
  • Checking bucket... ✓
  ✓ Connection successful

✓ Connection test passed

═══════════════════════════════════════
✅ Handler switched successfully!
═══════════════════════════════════════

Active handler: s3
Configuration: .fractary/plugins/file/config.json
```

## Example 2: Switch to Unconfigured Handler

```bash
$ /fractary-file:switch-handler gcs

Switching Active Handler
═══════════════════════════════════════

Config: .fractary/plugins/file/config.json (Project)
Current handler: local
Target handler: gcs

⚠️  Warning: Handler 'gcs' is not configured

Configured handlers:
  • local
  • s3

Configure 'gcs' now? [Y/n]: y

Launching configuration wizard...
🗄️  File Plugin Configuration
[... wizard runs ...]

✅ Configuration complete!

✓ Backup created: .fractary/plugins/file/config.json.backup.1705000001
✓ Configuration updated
✓ Update verified

Testing Connection:
[... connection test ...]

✅ Handler switched successfully!
```

## Example 3: Switch Without Testing

```bash
$ /fractary-file:switch-handler local --no-test

Switching Active Handler
═══════════════════════════════════════

Config: .fractary/plugins/file/config.json (Project)
Current handler: s3
Target handler: local

✓ Target handler is configured
✓ Backup created: .fractary/plugins/file/config.json.backup.1705000002
✓ Configuration updated
✓ Update verified

⚠️  Connection test skipped (--no-test specified)

Test manually with:
  /fractary-file:test-connection

═══════════════════════════════════════
✅ Handler switched successfully!
═══════════════════════════════════════

Active handler: local
Configuration: .fractary/plugins/file/config.json
```

</EXAMPLES>
