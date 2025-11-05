# File Manager Routing Workflow

This workflow describes how the file-manager skill routes operations to appropriate handler skills.

## Step 1: Initialize

Source common functions for shared utilities:

```bash
# Get skill directory
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common functions
source "$SKILL_DIR/../common/functions.sh"
```

## Step 2: Parse Input

Extract operation request from input:

```bash
# Parse JSON input (can be from args or stdin)
if [[ $# -gt 0 ]]; then
    INPUT_JSON="$1"
else
    INPUT_JSON=$(cat)
fi

# Extract fields
OPERATION=$(echo "$INPUT_JSON" | jq -r '.operation')
HANDLER_OVERRIDE=$(echo "$INPUT_JSON" | jq -r '.handler // empty')
PARAMETERS=$(echo "$INPUT_JSON" | jq -r '.parameters')
PROVIDED_CONFIG=$(echo "$INPUT_JSON" | jq -r '.config // empty')
```

## Step 3: Load Configuration

Load configuration with fallback chain:

```bash
# Use provided config or load from filesystem
if [[ -n "$PROVIDED_CONFIG" ]] && [[ "$PROVIDED_CONFIG" != "null" ]]; then
    # Use config from request
    ACTIVE_HANDLER=$(echo "$PROVIDED_CONFIG" | jq -r '.active_handler // "local"')
    HANDLER_CONFIG=$(echo "$PROVIDED_CONFIG" | jq -r ".handlers.$ACTIVE_HANDLER")
    GLOBAL_SETTINGS=$(echo "$PROVIDED_CONFIG" | jq -r '.global_settings')
else
    # Load from filesystem
    CONFIG_FILE=".fractary/plugins/file/config.json"

    # Get active handler (with fallback to local)
    ACTIVE_HANDLER=$(get_active_handler "$CONFIG_FILE")

    # Override if provided in request
    if [[ -n "$HANDLER_OVERRIDE" ]]; then
        ACTIVE_HANDLER="$HANDLER_OVERRIDE"
    fi

    # Load handler config
    HANDLER_CONFIG=$(load_handler_config "$CONFIG_FILE" "$ACTIVE_HANDLER")

    # Load global settings
    GLOBAL_SETTINGS=$(load_global_settings "$CONFIG_FILE")
fi

# Log configuration source
echo "Using handler: $ACTIVE_HANDLER" >&2
```

## Step 4: Validate Configuration

Ensure handler is configured:

```bash
# Check if handler config is empty
if [[ -z "$HANDLER_CONFIG" ]] || [[ "$HANDLER_CONFIG" == "{}" ]] || [[ "$HANDLER_CONFIG" == "null" ]]; then
    # Special case: local handler works with defaults
    if [[ "$ACTIVE_HANDLER" == "local" ]]; then
        HANDLER_CONFIG='{"base_path":"./storage","create_directories":true,"permissions":"0755"}'
    else
        # Other handlers require configuration
        return_result false "Handler '$ACTIVE_HANDLER' is not configured. Run /fractary-file:init --handler $ACTIVE_HANDLER"
        exit 3
    fi
fi
```

## Step 5: Validate Operation

Check operation is valid and has required parameters:

```bash
# Validate operation
VALID_OPERATIONS=("upload" "download" "delete" "list" "get-url" "read")
if [[ ! " ${VALID_OPERATIONS[@]} " =~ " ${OPERATION} " ]]; then
    return_result false "Invalid operation: $OPERATION. Valid: ${VALID_OPERATIONS[*]}"
    exit 2
fi

# Extract parameters
LOCAL_PATH=$(echo "$PARAMETERS" | jq -r '.local_path // empty')
REMOTE_PATH=$(echo "$PARAMETERS" | jq -r '.remote_path // empty')
PUBLIC=$(echo "$PARAMETERS" | jq -r '.public // false')
MAX_RESULTS=$(echo "$PARAMETERS" | jq -r '.max_results // 100')
MAX_BYTES=$(echo "$PARAMETERS" | jq -r '.max_bytes // 10485760')
EXPIRES_IN=$(echo "$PARAMETERS" | jq -r '.expires_in // 3600')

# Validate operation-specific parameters
case "$OPERATION" in
    upload)
        [[ -z "$LOCAL_PATH" ]] && return_result false "Missing parameter: local_path" && exit 2
        [[ -z "$REMOTE_PATH" ]] && return_result false "Missing parameter: remote_path" && exit 2
        [[ ! -f "$LOCAL_PATH" ]] && return_result false "File not found: $LOCAL_PATH" && exit 10
        ;;
    download)
        [[ -z "$REMOTE_PATH" ]] && return_result false "Missing parameter: remote_path" && exit 2
        [[ -z "$LOCAL_PATH" ]] && return_result false "Missing parameter: local_path" && exit 2
        ;;
    delete)
        [[ -z "$REMOTE_PATH" ]] && return_result false "Missing parameter: remote_path" && exit 2
        ;;
    list)
        # Optional parameters have defaults
        ;;
    get-url)
        [[ -z "$REMOTE_PATH" ]] && return_result false "Missing parameter: remote_path" && exit 2
        ;;
    read)
        [[ -z "$REMOTE_PATH" ]] && return_result false "Missing parameter: remote_path" && exit 2
        ;;
esac
```

## Step 6: Validate Paths

Check for path traversal attempts:

```bash
# Validate remote_path if present
if [[ -n "$REMOTE_PATH" ]]; then
    validate_path "$REMOTE_PATH"
    if [[ $? -ne 0 ]]; then
        log_operation "$ACTIVE_HANDLER" "$OPERATION" "$REMOTE_PATH" "path_traversal_blocked"
        return_result false "Invalid path: $REMOTE_PATH (path traversal attempt blocked)"
        exit 1
    fi
fi
```

## Step 7: Expand Environment Variables

Expand ${VAR_NAME} in configuration values:

```bash
# Expand environment variables in handler config
# This is handler-specific - different handlers have different credential fields

case "$ACTIVE_HANDLER" in
    local)
        # Local handler: just base_path
        BASE_PATH=$(echo "$HANDLER_CONFIG" | jq -r '.base_path // "./storage"')
        BASE_PATH=$(expand_env_vars "$BASE_PATH")
        CREATE_DIRS=$(echo "$HANDLER_CONFIG" | jq -r '.create_directories // true')
        ;;

    r2)
        # R2 handler: credentials + bucket info
        ACCOUNT_ID=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.account_id')")
        BUCKET_NAME=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.bucket_name')")
        ACCESS_KEY=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.access_key_id')")
        SECRET_KEY=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.secret_access_key')")
        PUBLIC_URL=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.public_url // empty')")

        # Validate required fields are not empty after expansion
        [[ -z "$ACCOUNT_ID" ]] && return_result false "R2 account_id not configured" && exit 3
        [[ -z "$BUCKET_NAME" ]] && return_result false "R2 bucket_name not configured" && exit 3
        [[ -z "$ACCESS_KEY" ]] && return_result false "R2 access_key_id not configured or env var not set" && exit 3
        [[ -z "$SECRET_KEY" ]] && return_result false "R2 secret_access_key not configured or env var not set" && exit 3
        ;;

    s3)
        # S3 handler: similar to R2
        REGION=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.region // "us-east-1"')")
        BUCKET_NAME=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.bucket_name')")
        ACCESS_KEY=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.access_key_id // empty')")
        SECRET_KEY=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.secret_access_key // empty')")
        ENDPOINT=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.endpoint // empty')")

        [[ -z "$BUCKET_NAME" ]] && return_result false "S3 bucket_name not configured" && exit 3
        # Note: access_key can be empty if using IAM roles
        ;;

    gcs)
        # GCS handler
        PROJECT_ID=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.project_id')")
        BUCKET_NAME=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.bucket_name')")
        SA_KEY=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.service_account_key // empty')")
        REGION=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.region // "us-central1"')")

        [[ -z "$PROJECT_ID" ]] && return_result false "GCS project_id not configured" && exit 3
        [[ -z "$BUCKET_NAME" ]] && return_result false "GCS bucket_name not configured" && exit 3
        # Note: SA key can be empty if using Application Default Credentials
        ;;

    gdrive)
        # Google Drive handler
        CLIENT_ID=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.client_id')")
        CLIENT_SECRET=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.client_secret')")
        FOLDER_ID=$(expand_env_vars "$(echo "$HANDLER_CONFIG" | jq -r '.folder_id // "root"')")

        [[ -z "$CLIENT_ID" ]] && return_result false "Google Drive client_id not configured" && exit 3
        [[ -z "$CLIENT_SECRET" ]] && return_result false "Google Drive client_secret not configured" && exit 3
        ;;
esac
```

## Step 8: Prepare Handler Parameters

Build parameter set for handler based on operation:

```bash
# Build handler-specific request
# NOTE: In the actual skill invocation, we pass all these parameters to the handler skill
# The handler skill then invokes its scripts with all parameters

case "$ACTIVE_HANDLER" in
    local)
        # For local handler, invoke scripts directly with parameters
        HANDLER_SKILL="$SKILL_DIR/handler-storage-local"
        SCRIPT_PATH="$HANDLER_SKILL/scripts/${OPERATION}.sh"

        case "$OPERATION" in
            upload)
                "$SCRIPT_PATH" "$BASE_PATH" "$LOCAL_PATH" "$REMOTE_PATH" "$CREATE_DIRS"
                ;;
            download)
                "$SCRIPT_PATH" "$BASE_PATH" "$REMOTE_PATH" "$LOCAL_PATH" "$CREATE_DIRS"
                ;;
            delete)
                "$SCRIPT_PATH" "$BASE_PATH" "$REMOTE_PATH"
                ;;
            list)
                PREFIX=$(echo "$PARAMETERS" | jq -r '.prefix // empty')
                "$SCRIPT_PATH" "$BASE_PATH" "$PREFIX" "$MAX_RESULTS"
                ;;
            get-url)
                "$SCRIPT_PATH" "$BASE_PATH" "$REMOTE_PATH"
                ;;
            read)
                "$SCRIPT_PATH" "$BASE_PATH" "$REMOTE_PATH" "$MAX_BYTES"
                ;;
        esac
        ;;

    r2)
        # For R2 handler, invoke scripts with all parameters
        HANDLER_SKILL="$SKILL_DIR/handler-storage-r2"
        SCRIPT_PATH="$HANDLER_SKILL/scripts/${OPERATION}.sh"

        case "$OPERATION" in
            upload)
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$LOCAL_PATH" "$REMOTE_PATH" "$PUBLIC" "$PUBLIC_URL"
                ;;
            download)
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$REMOTE_PATH" "$LOCAL_PATH"
                ;;
            delete)
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$REMOTE_PATH"
                ;;
            list)
                PREFIX=$(echo "$PARAMETERS" | jq -r '.prefix // empty')
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$PREFIX" "$MAX_RESULTS"
                ;;
            get-url)
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$REMOTE_PATH" "$EXPIRES_IN" "$PUBLIC_URL"
                ;;
            read)
                "$SCRIPT_PATH" "$ACCOUNT_ID" "$BUCKET_NAME" "$ACCESS_KEY" "$SECRET_KEY" "$REMOTE_PATH" "$MAX_BYTES"
                ;;
        esac
        ;;

    # Similar patterns for s3, gcs, gdrive handlers
    *)
        return_result false "Handler not yet implemented: $ACTIVE_HANDLER"
        exit 1
        ;;
esac

# Capture result
HANDLER_EXIT_CODE=$?
```

## Step 9: Process Results

Handler script returns JSON on stdout:

```bash
if [[ $HANDLER_EXIT_CODE -eq 0 ]]; then
    # Success - handler already returned JSON
    # We could add metadata here if needed
    log_operation "$ACTIVE_HANDLER" "$OPERATION" "$REMOTE_PATH" "success"
    exit 0
else
    # Error - log and return error
    log_operation "$ACTIVE_HANDLER" "$OPERATION" "$REMOTE_PATH" "error_$HANDLER_EXIT_CODE"

    # Handler script should have printed error message
    # We just need to exit with same code
    exit $HANDLER_EXIT_CODE
fi
```

## Error Exit Codes

- 0: Success
- 1: General error
- 2: Invalid parameters
- 3: Configuration error
- 10: File not found
- 11: Authentication error
- 12: Network error
- 13: Permission denied
