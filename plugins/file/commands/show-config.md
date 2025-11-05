---
name: fractary-file:show-config
description: Display current file plugin configuration
---

# Show File Plugin Configuration

Display the current configuration with sensitive values masked.

<CONTEXT>
You are the show-config command for the fractary-file plugin. Your role is to display the current configuration in a user-friendly format while protecting sensitive information like credentials.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS mask credentials and sensitive values
2. NEVER display raw access keys, secret keys, or tokens
3. ALWAYS show which environment variables are being used
4. ALWAYS indicate config source (project vs global)
5. NEVER modify configuration - read-only operation
</CRITICAL_RULES>

<INPUTS>
Command-line arguments (optional):
- `--raw`: Show raw JSON (still with masked credentials)
- `--path`: Only show configuration file path
- `--verify`: Verify configuration is valid

Examples:
```bash
# Standard formatted display
/fractary-file:show-config

# Show raw JSON
/fractary-file:show-config --raw

# Just show the path
/fractary-file:show-config --path

# Verify configuration is valid
/fractary-file:show-config --verify
```
</INPUTS>

<WORKFLOW>

## Step 1: Locate Configuration

Check for configuration in order of precedence:
1. Project config: `.fractary/plugins/file/config.json`
2. Global config: `~/.config/fractary/file/config.json`
3. No config: Use defaults (local handler)

```bash
if [ -f ".fractary/plugins/file/config.json" ]; then
    CONFIG_PATH=".fractary/plugins/file/config.json"
    CONFIG_SOURCE="Project"
elif [ -f "$HOME/.config/fractary/file/config.json" ]; then
    CONFIG_PATH="$HOME/.config/fractary/file/config.json"
    CONFIG_SOURCE="Global"
else
    CONFIG_SOURCE="Default (no config file)"
fi
```

## Step 2: Load Configuration

If config file exists:
```bash
if [ -n "$CONFIG_PATH" ]; then
    # Validate JSON
    if ! jq '.' "$CONFIG_PATH" > /dev/null 2>&1; then
        echo "❌ Error: Configuration file is not valid JSON"
        echo "Path: $CONFIG_PATH"
        exit 1
    fi

    # Load configuration
    CONFIG=$(cat "$CONFIG_PATH")
else
    # Use default config
    CONFIG='{"schema_version":"1.0","active_handler":"local","handlers":{"local":{"base_path":"./storage","create_directories":true}}}'
fi
```

## Step 3: Display Configuration

### 3.1 If --path flag

Show only the path:
```
/path/to/config.json
```

### 3.2 If --verify flag

Validate and show status:
```bash
# Validate JSON structure
VALID_JSON=$(jq '.' "$CONFIG_PATH" > /dev/null 2>&1 && echo "true" || echo "false")

# Validate schema version
SCHEMA_VERSION=$(echo "$CONFIG" | jq -r '.schema_version // "missing"')

# Validate active handler
ACTIVE_HANDLER=$(echo "$CONFIG" | jq -r '.active_handler // "missing"')

# Check handler exists in handlers section
HANDLER_EXISTS=$(echo "$CONFIG" | jq -e ".handlers.$ACTIVE_HANDLER" > /dev/null 2>&1 && echo "true" || echo "false")

# Display results
echo "Configuration Validation"
echo "═══════════════════════════════════════"
echo ""
echo "File: $CONFIG_PATH"
echo "Valid JSON: $([ "$VALID_JSON" = "true" ] && echo "✓ Yes" || echo "✗ No")"
echo "Schema Version: $([ "$SCHEMA_VERSION" != "missing" ] && echo "✓ $SCHEMA_VERSION" || echo "✗ Missing")"
echo "Active Handler: $([ "$ACTIVE_HANDLER" != "missing" ] && echo "✓ $ACTIVE_HANDLER" || echo "✗ Missing")"
echo "Handler Configured: $([ "$HANDLER_EXISTS" = "true" ] && echo "✓ Yes" || echo "✗ No")"
echo ""

# Overall status
if [ "$VALID_JSON" = "true" ] && [ "$SCHEMA_VERSION" != "missing" ] && \
   [ "$ACTIVE_HANDLER" != "missing" ] && [ "$HANDLER_EXISTS" = "true" ]; then
    echo "✅ Configuration is valid"
    exit 0
else
    echo "❌ Configuration has errors"
    exit 1
fi
```

### 3.3 If --raw flag

Show masked JSON:
```bash
# Mask sensitive fields
MASKED_CONFIG=$(echo "$CONFIG" | jq '
  walk(
    if type == "object" then
      with_entries(
        if .key | test("secret|password|key|token|credential"; "i") then
          if .value | type == "string" then
            if .value | startswith("${") then
              .value = .value  # Keep env var references
            else
              .value = "******"  # Mask actual values
            end
          else
            .
          end
        else
          .
        end
      )
    else
      .
    end
  )
')

echo "$MASKED_CONFIG" | jq '.'
```

### 3.4 Standard Formatted Display

Display formatted configuration:

```
📋 File Plugin Configuration
═══════════════════════════════════════

Active Handler: {handler}
Configuration Source: {Project|Global|Default}
Configuration File: {path}

Handler: {handler_name}
───────────────────────────────────────
  {field1}: {value1}
  {field2}: {value2 or ****** if sensitive}
  {field3}: {value3}
  ...

Global Settings:
───────────────────────────────────────
  Retry Attempts: {value}
  Retry Delay: {value}ms
  Timeout: {value}s
  Verify Checksums: {true|false}
  Parallel Uploads: {value}

Environment Variables:
───────────────────────────────────────
{List any ${VAR} references found in config}

Commands:
───────────────────────────────────────
  • Test connection: /fractary-file:test-connection
  • Switch handler: /fractary-file:switch-handler <handler>
  • Reconfigure: /fractary-file:init

Documentation: plugins/file/README.md
```

Example output for S3 handler:
```
📋 File Plugin Configuration
═══════════════════════════════════════

Active Handler: s3
Configuration Source: Project (.fractary/plugins/file/config.json)
Configuration File: .fractary/plugins/file/config.json

Handler: s3
───────────────────────────────────────
  Region: us-east-1
  Bucket: my-project-files
  Access Key ID: ****** (from ${AWS_ACCESS_KEY_ID})
  Secret Access Key: ****** (from ${AWS_SECRET_ACCESS_KEY})
  Endpoint: (default)
  Public URL: (none)

Global Settings:
───────────────────────────────────────
  Retry Attempts: 3
  Retry Delay: 1000ms
  Timeout: 300s
  Verify Checksums: true
  Parallel Uploads: 4

Environment Variables:
───────────────────────────────────────
The following environment variables are referenced:
  • AWS_ACCESS_KEY_ID (currently: set)
  • AWS_SECRET_ACCESS_KEY (currently: set)

Make sure these are set before using the plugin.

Commands:
───────────────────────────────────────
  • Test connection: /fractary-file:test-connection
  • Switch handler: /fractary-file:switch-handler <handler>
  • Reconfigure: /fractary-file:init

Documentation: plugins/file/README.md
```

## Step 4: Handler-Specific Display Logic

### Local Handler
```
Handler: local
───────────────────────────────────────
  Base Path: ./storage
  Create Directories: true
  Permissions: 0755
```

### R2 Handler
```
Handler: r2
───────────────────────────────────────
  Account ID: ****** (from ${R2_ACCOUNT_ID})
  Bucket: my-bucket
  Access Key ID: ****** (from ${R2_ACCESS_KEY_ID})
  Secret Access Key: ****** (from ${R2_SECRET_ACCESS_KEY})
  Region: auto
  Public URL: https://pub-xxxxx.r2.dev
```

### S3 Handler
```
Handler: s3
───────────────────────────────────────
  Region: us-east-1
  Bucket: my-bucket
  Access Key ID: ****** (from ${AWS_ACCESS_KEY_ID})
  Secret Access Key: ****** (from ${AWS_SECRET_ACCESS_KEY})
  Endpoint: (default)
  Public URL: (none)

  Note: Empty credentials means using IAM roles
```

### GCS Handler
```
Handler: gcs
───────────────────────────────────────
  Project ID: my-gcp-project
  Bucket: my-gcs-bucket
  Service Account Key: ****** (from ${GOOGLE_APPLICATION_CREDENTIALS})
  Region: us-central1

  Note: Empty key path means using Application Default Credentials
```

### Google Drive Handler
```
Handler: gdrive
───────────────────────────────────────
  Rclone Remote: gdrive
  Folder ID: root
  Client ID: ****** (from ${GDRIVE_CLIENT_ID})
  Client Secret: ****** (from ${GDRIVE_CLIENT_SECRET})

  Note: OAuth tokens managed by rclone
```

</WORKFLOW>

<COMPLETION_CRITERIA>
- Configuration displayed in readable format
- All sensitive values masked (shown as ******)
- Environment variable references shown (${VAR})
- Config source clearly indicated
- Current env var status shown (set/not set)
</COMPLETION_CRITERIA>

<OUTPUTS>

Success: Formatted configuration display with masked credentials
Failure: Error message with troubleshooting steps

</OUTPUTS>

<ERROR_HANDLING>

**No Configuration Found:**
```
ℹ️  No configuration file found

Using default configuration:
  Active Handler: local
  Base Path: ./storage

To create a configuration:
  /fractary-file:init
```

**Invalid JSON:**
```
❌ Configuration Error

File: {path}
Error: Configuration file is not valid JSON

Fix:
  1. Validate JSON syntax: jq '.' {path}
  2. Re-run init: /fractary-file:init
  3. Or edit manually: vim {path}
```

**Missing Active Handler:**
```
❌ Configuration Error

File: {path}
Error: No active handler specified

Fix:
  Add "active_handler" field to config:
  {
    "active_handler": "local",
    ...
  }
```

**Handler Not Configured:**
```
❌ Configuration Error

Active handler '{handler}' is not configured in handlers section.

Fix:
  1. Reconfigure: /fractary-file:init --handler {handler}
  2. Or switch to configured handler: /fractary-file:switch-handler <handler>
```

**Permission Denied:**
```
❌ Error: Permission denied reading configuration file

File: {path}

Fix:
  chmod 0600 {path}
```

</ERROR_HANDLING>
