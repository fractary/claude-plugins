---
name: fractary-file:test-connection
description: Test connection to configured storage provider
model: claude-haiku-4-5
---

# Test File Plugin Connection

Test the current file plugin configuration by attempting a list operation.

<CONTEXT>
You are the test-connection command for the fractary-file plugin. Your role is to verify that the configured storage handler is properly set up and can communicate with the storage provider. You test authentication, permissions, and basic operations.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER expose credentials in test output
2. ALWAYS use read-only operations for testing (list, not write)
3. ALWAYS provide specific error messages with troubleshooting steps
4. NEVER modify or delete any files during testing
5. ALWAYS test with the currently active handler
</CRITICAL_RULES>

<INPUTS>
Command-line arguments (optional):
- `--handler <name>`: Test specific handler instead of active one
- `--verbose`: Show detailed connection information
- `--quick`: Skip extended checks, just test basic connectivity

Examples:
```bash
# Test current active handler
/fractary-file:test-connection

# Test specific handler
/fractary-file:test-connection --handler s3

# Verbose output
/fractary-file:test-connection --verbose

# Quick test only
/fractary-file:test-connection --quick
```
</INPUTS>

<WORKFLOW>

## Step 1: Load Configuration

Locate and load configuration:
```bash
source plugins/file/skills/common/functions.sh

# Find config file
if [ -f ".fractary/plugins/file/config.json" ]; then
    CONFIG_PATH=".fractary/plugins/file/config.json"
    CONFIG_SOURCE="Project"
elif [ -f "$HOME/.config/fractary/file/config.json" ]; then
    CONFIG_PATH="$HOME/.config/fractary/file/config.json"
    CONFIG_SOURCE="Global"
else
    echo "ℹ️  No configuration found, testing default (local handler)"
    CONFIG_PATH=""
    CONFIG_SOURCE="Default"
fi

# Load or use default
if [ -n "$CONFIG_PATH" ]; then
    CONFIG=$(cat "$CONFIG_PATH")
    ACTIVE_HANDLER=$(echo "$CONFIG" | jq -r '.active_handler')
else
    ACTIVE_HANDLER="local"
    CONFIG='{"schema_version":"1.0","active_handler":"local","handlers":{"local":{"base_path":".","create_directories":true}}}'
fi

# Override if --handler specified
if [ -n "$SPECIFIED_HANDLER" ]; then
    ACTIVE_HANDLER="$SPECIFIED_HANDLER"
fi
```

## Step 2: Display Test Banner

```
🔍 Testing Connection
═══════════════════════════════════════

Handler: {handler}
Config Source: {Project|Global|Default}
Test Time: {timestamp}
```

If verbose mode:
```
Configuration:
  File: {config_path}
  Handler: {handler}
  {handler-specific details with masked credentials}
```

## Step 3: Validate Configuration

```bash
# Check handler exists in config
if ! echo "$CONFIG" | jq -e ".handlers.$ACTIVE_HANDLER" > /dev/null 2>&1; then
    echo "❌ Error: Handler '$ACTIVE_HANDLER' is not configured"
    echo ""
    echo "Available handlers:"
    echo "$CONFIG" | jq -r '.handlers | keys[]' | sed 's/^/  • /'
    echo ""
    echo "To configure: /fractary-file:init --handler $ACTIVE_HANDLER"
    exit 1
fi

# Extract handler config
HANDLER_CONFIG=$(echo "$CONFIG" | jq ".handlers.$ACTIVE_HANDLER")
```

## Step 4: Pre-Flight Checks

Verify dependencies and requirements for the handler.

### Local Handler
```bash
echo "  • Checking base path..."
BASE_PATH=$(echo "$HANDLER_CONFIG" | jq -r '.base_path')

if [ ! -d "$BASE_PATH" ]; then
    echo "    ⚠️  Directory doesn't exist: $BASE_PATH"
    CREATE_DIRS=$(echo "$HANDLER_CONFIG" | jq -r '.create_directories // true')
    if [ "$CREATE_DIRS" = "true" ]; then
        echo "    ℹ️  Will create on first operation"
    else
        echo "    ❌ create_directories is false"
        exit 1
    fi
else
    echo "    ✓ Directory exists"
fi

echo "  • Checking write permissions..."
if [ -w "$BASE_PATH" ] || [ ! -e "$BASE_PATH" ]; then
    echo "    ✓ Writable"
else
    echo "    ❌ Not writable"
    exit 1
fi
```

### R2/S3/GCS Handlers (Cloud Storage)
```bash
# Check required CLI tools
case "$ACTIVE_HANDLER" in
    r2)
        echo "  • Checking rclone..."
        if ! command -v rclone &> /dev/null; then
            echo "    ❌ rclone not installed"
            echo "    Install: https://rclone.org/install/"
            exit 1
        fi
        echo "    ✓ rclone found ($(rclone --version | head -1))"
        ;;
    s3)
        echo "  • Checking AWS CLI..."
        if ! command -v aws &> /dev/null; then
            echo "    ❌ aws cli not installed"
            echo "    Install: https://aws.amazon.com/cli/"
            exit 1
        fi
        echo "    ✓ aws cli found ($(aws --version))"
        ;;
    gcs)
        echo "  • Checking gcloud CLI..."
        if ! command -v gcloud &> /dev/null; then
            echo "    ❌ gcloud not installed"
            echo "    Install: https://cloud.google.com/sdk/docs/install"
            exit 1
        fi
        echo "    ✓ gcloud found ($(gcloud --version | head -1))"
        ;;
esac

# Check environment variables
echo "  • Checking credentials..."
EXPANDED_CONFIG=$(expand_env_vars "$HANDLER_CONFIG")

# Validate credentials are set (not empty after expansion)
case "$ACTIVE_HANDLER" in
    r2)
        ACCESS_KEY=$(echo "$EXPANDED_CONFIG" | jq -r '.access_key_id')
        SECRET_KEY=$(echo "$EXPANDED_CONFIG" | jq -r '.secret_access_key')
        if [ -z "$ACCESS_KEY" ] || [ -z "$SECRET_KEY" ]; then
            echo "    ❌ Credentials not set"
            echo "    Set: R2_ACCESS_KEY_ID and R2_SECRET_ACCESS_KEY"
            exit 1
        fi
        echo "    ✓ Credentials set"
        ;;
    s3)
        ACCESS_KEY=$(echo "$EXPANDED_CONFIG" | jq -r '.access_key_id // empty')
        SECRET_KEY=$(echo "$EXPANDED_CONFIG" | jq -r '.secret_access_key // empty')
        if [ -z "$ACCESS_KEY" ] && [ -z "$SECRET_KEY" ]; then
            echo "    ℹ️  Using IAM roles (no credentials)"
        else
            echo "    ✓ Credentials set"
        fi
        ;;
    gcs)
        SA_KEY=$(echo "$EXPANDED_CONFIG" | jq -r '.service_account_key // empty')
        if [ -z "$SA_KEY" ]; then
            echo "    ℹ️  Using Application Default Credentials"
        else
            if [ ! -f "$SA_KEY" ]; then
                echo "    ❌ Service account key file not found: $SA_KEY"
                exit 1
            fi
            echo "    ✓ Service account key found"
        fi
        ;;
esac

# Verify bucket/container exists
BUCKET=$(echo "$EXPANDED_CONFIG" | jq -r '.bucket_name')
echo "  • Checking bucket/container..."
echo "    Target: $BUCKET"
```

### Google Drive Handler
```bash
echo "  • Checking rclone..."
if ! command -v rclone &> /dev/null; then
    echo "    ❌ rclone not installed"
    exit 1
fi
echo "    ✓ rclone found"

echo "  • Checking rclone remote..."
REMOTE=$(echo "$HANDLER_CONFIG" | jq -r '.rclone_remote')
if ! rclone listremotes | grep -q "^${REMOTE}:$"; then
    echo "    ❌ rclone remote '$REMOTE' not configured"
    echo "    Configure: rclone config"
    echo "    See: plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md"
    exit 1
fi
echo "    ✓ Remote '$REMOTE' configured"
```

## Step 5: Connection Test

Perform actual connection test using the handler.

Display:
```
Testing Connection:
───────────────────────────────────────
```

### Execute Test via File Manager

Use the file-manager agent to perform a list operation:

```
Use the @agent-fractary-file:file-manager agent to list files:
{
  "operation": "list",
  "parameters": {
    "path": "",
    "limit": 1
  }
}
```

Parse the response:
```bash
if echo "$RESULT" | jq -e '.success == true' > /dev/null; then
    echo "  ✓ Connection successful"
    echo "  ✓ Authentication working"
    echo "  ✓ Storage accessible"

    # Check if files were returned
    FILE_COUNT=$(echo "$RESULT" | jq '.files | length')
    if [ "$FILE_COUNT" -gt 0 ]; then
        echo "  ✓ Files found ($FILE_COUNT)"

        if [ "$VERBOSE" = "true" ]; then
            echo ""
            echo "Sample file:"
            echo "$RESULT" | jq -r '.files[0] | "  Name: \(.name)\n  Size: \(.size) bytes\n  Modified: \(.modified)"'
        fi
    else
        echo "  ℹ️  Storage is empty (this is okay)"
    fi

    TEST_SUCCESS=true
else
    ERROR=$(echo "$RESULT" | jq -r '.error // "Unknown error"')
    echo "  ✗ Connection failed"
    echo ""
    echo "Error: $ERROR"
    TEST_SUCCESS=false
fi
```

## Step 6: Extended Checks (if not --quick)

If test succeeded and not in quick mode, perform additional checks:

```
Extended Checks:
───────────────────────────────────────
```

### Test Write Permissions (Optional)
```bash
echo "  • Testing write permissions..."

# Create a tiny test file
TEST_FILE="/tmp/fractary_test_$$"
echo "test" > "$TEST_FILE"

# Attempt upload
UPLOAD_RESULT=$(Use @agent-fractary-file:file-manager to upload {
  "operation": "upload",
  "parameters": {
    "local_path": "$TEST_FILE",
    "remote_path": ".fractary_connection_test"
  }
})

if echo "$UPLOAD_RESULT" | jq -e '.success == true' > /dev/null; then
    echo "    ✓ Write permissions OK"

    # Clean up test file
    DELETE_RESULT=$(Use @agent-fractary-file:file-manager to delete {
      "operation": "delete",
      "parameters": {
        "remote_path": ".fractary_connection_test"
      }
    })

    if echo "$DELETE_RESULT" | jq -e '.success == true' > /dev/null; then
        echo "    ✓ Delete permissions OK"
    fi
else
    echo "    ⚠️  Write test failed (might be read-only access)"
fi

rm -f "$TEST_FILE"
```

### Test Performance (Optional)
```bash
if [ "$VERBOSE" = "true" ]; then
    echo "  • Measuring latency..."
    START_TIME=$(date +%s%N)

    # Simple list operation
    LIST_RESULT=$(Use @agent-fractary-file:file-manager to list {
      "operation": "list",
      "parameters": {"path": "", "limit": 1}
    })

    END_TIME=$(date +%s%N)
    LATENCY=$(( ($END_TIME - $START_TIME) / 1000000 ))

    echo "    Latency: ${LATENCY}ms"

    if [ $LATENCY -lt 500 ]; then
        echo "    ✓ Excellent"
    elif [ $LATENCY -lt 2000 ]; then
        echo "    ✓ Good"
    else
        echo "    ⚠️  Slow (might be network or provider)"
    fi
fi
```

## Step 7: Final Summary

Display final test results:

### On Success
```
═══════════════════════════════════════
✅ Connection Test Passed!
═══════════════════════════════════════

All checks completed successfully.
The file plugin is ready to use.

Next steps:
  • Upload a file:
    Use @agent-fractary-file:file-manager to upload:
    {
      "operation": "upload",
      "parameters": {
        "local_path": "./myfile.txt",
        "remote_path": "folder/myfile.txt"
      }
    }

  • View configuration:
    /fractary-file:show-config

Documentation: plugins/file/README.md
```

### On Failure
```
═══════════════════════════════════════
❌ Connection Test Failed
═══════════════════════════════════════

Error: {specific error message}

Troubleshooting:
{handler-specific troubleshooting steps}

Commands:
  • View config: /fractary-file:show-config
  • Reconfigure: /fractary-file:init
  • Documentation: plugins/file/README.md
```

</WORKFLOW>

<COMPLETION_CRITERIA>
- Pre-flight checks completed
- Connection test executed
- Results clearly displayed
- Specific errors shown with troubleshooting
- Success/failure status clear
</COMPLETION_CRITERIA>

<OUTPUTS>

**Success:**
```
✅ Connection test passed
All operations working correctly
```

**Failure:**
```
❌ Connection test failed: {error}
Troubleshooting steps provided
```

</OUTPUTS>

<ERROR_HANDLING>

## Handler-Specific Troubleshooting

### Local Handler Errors

**Directory doesn't exist:**
```
Error: Base directory not found

Fix:
  1. Check base_path in config: /fractary-file:show-config
  2. Create directory: mkdir -p {base_path}
  3. Or enable auto-creation: set create_directories: true in config
```

**Permission denied:**
```
Error: Permission denied writing to {path}

Fix:
  sudo chown -R $USER:$USER {base_path}
  chmod 0755 {base_path}
```

### R2 Handler Errors

**Invalid credentials:**
```
Error: Authentication failed

Fix:
  1. Verify credentials at: https://dash.cloudflare.com
  2. Check environment variables:
     echo $R2_ACCESS_KEY_ID
     echo $R2_SECRET_ACCESS_KEY
  3. Reconfigure: /fractary-file:init --handler r2
```

**Bucket not found:**
```
Error: Bucket '{bucket}' not found

Fix:
  1. Verify bucket exists in R2 dashboard
  2. Check bucket name spelling in config
  3. Verify account_id is correct
```

### S3 Handler Errors

**Credentials invalid:**
```
Error: The AWS Access Key Id you provided does not exist

Fix:
  1. If using IAM roles: verify EC2 instance profile or ECS task role
  2. If using access keys:
     • Verify keys in AWS Console
     • Check environment variables: echo $AWS_ACCESS_KEY_ID
  3. Reconfigure: /fractary-file:init --handler s3
```

**Bucket not found or wrong region:**
```
Error: The specified bucket does not exist

Fix:
  1. Verify bucket exists in AWS Console
  2. Check bucket region matches config
  3. For S3-compatible services, verify endpoint URL
```

### GCS Handler Errors

**ADC not configured:**
```
Error: Application Default Credentials not found

Fix:
  1. Set up ADC: gcloud auth application-default login
  2. Or use service account key:
     export GOOGLE_APPLICATION_CREDENTIALS="/path/to/key.json"
  3. Reconfigure: /fractary-file:init --handler gcs
```

**Permission denied:**
```
Error: Permission denied

Fix:
  1. Verify service account has "Storage Admin" role
  2. Check IAM permissions in GCP Console
  3. Verify project ID is correct
```

### Google Drive Errors

**Remote not configured:**
```
Error: rclone remote not found

Fix:
  1. Configure rclone: rclone config
  2. Follow OAuth setup guide:
     plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md
  3. Test rclone: rclone lsd {remote}:
```

**OAuth token expired:**
```
Error: Token expired

Fix:
  rclone will automatically refresh the token.
  If this fails, reconfigure: rclone config reconnect {remote}:
```

## General Troubleshooting

**Network connectivity:**
```
Error: Network timeout / Connection refused

Fix:
  1. Check internet connection
  2. Verify firewall rules
  3. Check proxy settings
  4. Try again with --verbose for more details
```

**Missing CLI tool:**
```
Error: Command not found: {tool}

Fix:
  {tool-specific installation instructions}
```

</ERROR_HANDLING>
