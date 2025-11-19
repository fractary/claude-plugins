# Configuration Validation Workflow

This workflow describes how to validate file plugin configuration before routing operations.

## Purpose

Ensure configuration is valid and complete before attempting file operations. Catch configuration errors early with helpful error messages.

## Validation Steps

### Step 1: Check Configuration Exists

```bash
# Try project config first
CONFIG_FILE=".fractary/plugins/file/config.json"

if [[ ! -f "$CONFIG_FILE" ]]; then
    # Try global config
    CONFIG_FILE="$HOME/.config/fractary/file/config.json"
fi

if [[ ! -f "$CONFIG_FILE" ]]; then
    # No configuration found - use defaults
    echo "Warning: No configuration file found, using defaults" >&2
    echo "  To configure: /fractary-file:init" >&2

    # Default to local handler
    USE_DEFAULTS=true
    ACTIVE_HANDLER="local"
fi
```

### Step 2: Validate JSON Syntax

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    # Check if file is valid JSON
    if ! jq empty "$CONFIG_FILE" 2>/dev/null; then
        echo "Error: Configuration file is not valid JSON: $CONFIG_FILE" >&2
        echo "  Check syntax with: jq . $CONFIG_FILE" >&2
        exit 3
    fi
fi
```

### Step 3: Validate Schema Version

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    SCHEMA_VERSION=$(jq -r '.schema_version // "unknown"' "$CONFIG_FILE")

    if [[ "$SCHEMA_VERSION" != "1.0" ]]; then
        echo "Warning: Unknown schema version: $SCHEMA_VERSION" >&2
        echo "  Expected: 1.0" >&2
        echo "  Configuration may not work as expected" >&2
    fi
fi
```

### Step 4: Validate Active Handler

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    ACTIVE_HANDLER=$(jq -r '.active_handler // "local"' "$CONFIG_FILE")

    # Check if handler is supported
    SUPPORTED_HANDLERS=("local" "r2" "s3" "gcs" "gdrive")
    if [[ ! " ${SUPPORTED_HANDLERS[@]} " =~ " ${ACTIVE_HANDLER} " ]]; then
        echo "Error: Unsupported handler: $ACTIVE_HANDLER" >&2
        echo "  Supported handlers: ${SUPPORTED_HANDLERS[*]}" >&2
        exit 3
    fi
fi
```

### Step 5: Validate Handler Configuration

Check that active handler has configuration:

```bash
if [[ "$USE_DEFAULTS" != "true" ]] && [[ "$ACTIVE_HANDLER" != "local" ]]; then
    # Check if handler has configuration section
    HANDLER_CONFIG=$(jq -r ".handlers.$ACTIVE_HANDLER // {}" "$CONFIG_FILE")

    if [[ -z "$HANDLER_CONFIG" ]] || [[ "$HANDLER_CONFIG" == "{}" ]]; then
        echo "Error: Handler '$ACTIVE_HANDLER' is not configured" >&2
        echo "  Run: /fractary-file:init --handler $ACTIVE_HANDLER" >&2
        exit 3
    fi
fi
```

### Step 6: Validate Handler-Specific Fields

Each handler has required fields:

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    case "$ACTIVE_HANDLER" in
        local)
            # Local handler works with defaults
            BASE_PATH=$(jq -r ".handlers.local.base_path // \".\"" "$CONFIG_FILE")

            # Validate base_path is accessible
            if [[ ! -d "$BASE_PATH" ]] && [[ $(jq -r ".handlers.local.create_directories // true" "$CONFIG_FILE") == "false" ]]; then
                echo "Error: Base path does not exist and create_directories is false: $BASE_PATH" >&2
                exit 3
            fi
            ;;

        r2)
            # R2 handler requires specific fields
            REQUIRED_FIELDS=("account_id" "bucket_name" "access_key_id" "secret_access_key")

            for field in "${REQUIRED_FIELDS[@]}"; do
                VALUE=$(jq -r ".handlers.r2.$field // empty" "$CONFIG_FILE")

                if [[ -z "$VALUE" ]]; then
                    echo "Error: R2 handler missing required field: $field" >&2
                    echo "  Configure with: /fractary-file:init --handler r2" >&2
                    exit 3
                fi

                # Check if value looks like env var reference
                if [[ "$VALUE" =~ ^\$\{.*\}$ ]]; then
                    # Extract var name
                    VAR_NAME=$(echo "$VALUE" | sed 's/\${//; s/}//')

                    # Check if env var exists
                    if [[ -z "${!VAR_NAME}" ]]; then
                        echo "Error: R2 $field references undefined environment variable: $VAR_NAME" >&2
                        echo "  Set with: export $VAR_NAME=\"your-value\"" >&2
                        exit 3
                    fi
                fi
            done
            ;;

        s3)
            # S3 handler requires bucket and region
            BUCKET=$(jq -r ".handlers.s3.bucket_name // empty" "$CONFIG_FILE")
            if [[ -z "$BUCKET" ]]; then
                echo "Error: S3 handler missing required field: bucket_name" >&2
                exit 3
            fi

            # Credentials are optional if using IAM roles
            ACCESS_KEY=$(jq -r ".handlers.s3.access_key_id // empty" "$CONFIG_FILE")
            if [[ -z "$ACCESS_KEY" ]]; then
                echo "Info: No S3 access_key_id configured, assuming IAM role usage" >&2
            fi
            ;;

        gcs)
            # GCS handler requires project and bucket
            REQUIRED_FIELDS=("project_id" "bucket_name")

            for field in "${REQUIRED_FIELDS[@]}"; do
                VALUE=$(jq -r ".handlers.gcs.$field // empty" "$CONFIG_FILE")

                if [[ -z "$VALUE" ]]; then
                    echo "Error: GCS handler missing required field: $field" >&2
                    exit 3
                fi
            done

            # Service account key is optional if using ADC
            SA_KEY=$(jq -r ".handlers.gcs.service_account_key // empty" "$CONFIG_FILE")
            if [[ -z "$SA_KEY" ]]; then
                echo "Info: No GCS service_account_key configured, assuming Application Default Credentials" >&2
            fi
            ;;

        gdrive)
            # Google Drive requires OAuth credentials
            REQUIRED_FIELDS=("client_id" "client_secret")

            for field in "${REQUIRED_FIELDS[@]}"; do
                VALUE=$(jq -r ".handlers.gdrive.$field // empty" "$CONFIG_FILE")

                if [[ -z "$VALUE" ]]; then
                    echo "Error: Google Drive handler missing required field: $field" >&2
                    echo "  See docs: plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md" >&2
                    exit 3
                fi
            done
            ;;
    esac
fi
```

### Step 7: Validate Global Settings

Check global settings if present:

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    # Validate retry_attempts
    RETRY_ATTEMPTS=$(jq -r '.global_settings.retry_attempts // 3' "$CONFIG_FILE")
    if ! [[ "$RETRY_ATTEMPTS" =~ ^[0-9]+$ ]] || [[ "$RETRY_ATTEMPTS" -lt 1 ]] || [[ "$RETRY_ATTEMPTS" -gt 10 ]]; then
        echo "Warning: Invalid retry_attempts ($RETRY_ATTEMPTS), using default (3)" >&2
        RETRY_ATTEMPTS=3
    fi

    # Validate timeout_seconds
    TIMEOUT=$(jq -r '.global_settings.timeout_seconds // 300' "$CONFIG_FILE")
    if ! [[ "$TIMEOUT" =~ ^[0-9]+$ ]] || [[ "$TIMEOUT" -lt 10 ]] || [[ "$TIMEOUT" -gt 3600 ]]; then
        echo "Warning: Invalid timeout_seconds ($TIMEOUT), using default (300)" >&2
        TIMEOUT=300
    fi
fi
```

### Step 8: Check File Permissions

Validate config file has secure permissions:

```bash
if [[ "$USE_DEFAULTS" != "true" ]]; then
    enforce_config_permissions "$CONFIG_FILE"
    if [[ $? -ne 0 ]]; then
        echo "Warning: Failed to set secure permissions on config file" >&2
    fi
fi
```

## Validation Result

After validation:

```bash
# Export validated configuration for use
export FILE_PLUGIN_ACTIVE_HANDLER="$ACTIVE_HANDLER"
export FILE_PLUGIN_CONFIG_FILE="$CONFIG_FILE"
export FILE_PLUGIN_RETRY_ATTEMPTS="$RETRY_ATTEMPTS"
export FILE_PLUGIN_TIMEOUT="$TIMEOUT"

echo "Configuration validated successfully" >&2
echo "  Handler: $ACTIVE_HANDLER" >&2
echo "  Config:  $CONFIG_FILE" >&2
```

## Common Configuration Errors

### Missing Environment Variables

**Error**: `R2 access_key_id references undefined environment variable: R2_ACCESS_KEY_ID`

**Fix**:
```bash
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
```

### Invalid JSON

**Error**: `Configuration file is not valid JSON`

**Fix**:
```bash
# Check syntax
jq . .fractary/plugins/file/config.json

# Common issues:
# - Missing commas between fields
# - Trailing commas
# - Unquoted strings
# - Missing closing brackets
```

### Handler Not Configured

**Error**: `Handler 'r2' is not configured`

**Fix**:
```bash
# Run init command to configure
/fractary-file:init --handler r2
```

### Permission Issues

**Error**: `Config file permissions too open (644)`

**Fix**:
```bash
chmod 0600 .fractary/plugins/file/config.json
```
