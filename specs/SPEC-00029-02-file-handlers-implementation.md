# SPEC-00029-02: File Handlers Implementation

**Issue**: #29
**Phase**: 1 (fractary-file Enhancement)
**Dependencies**: SPEC-00029-01 (File Plugin Architecture)
**Status**: Draft
**Created**: 2025-01-15

## Overview

Implement all 5 storage handlers (Local, R2, S3, GCS, Google Drive) with complete support for 6 operations (upload, download, delete, list, get-url, read). This spec covers the detailed implementation of each handler, including provider-specific authentication, error handling, and operation scripts.

## Requirements

### Functional Requirements

1. **Local Handler** (Default)
   - Use standard file system operations (cp, rm, ls, cat)
   - Support directory creation
   - Generate file:// URLs
   - No external dependencies

2. **R2 Handler** (Migration from existing)
   - Use rclone or AWS S3 API compatible tools
   - Support Cloudflare R2 specific features
   - Generate public and presigned URLs
   - Maintain existing functionality

3. **S3 Handler**
   - Use AWS CLI (aws s3)
   - Support all AWS regions
   - Generate presigned URLs with configurable expiration
   - Support S3-compatible services (MinIO, etc.)

4. **GCS Handler**
   - Use gcloud storage or gsutil
   - Support service account authentication
   - Generate signed URLs
   - Support GCS-specific features (lifecycle, versioning)

5. **Google Drive Handler**
   - Use rclone with gdrive backend
   - Support OAuth2 authentication
   - Generate shareable links
   - Support folder-based organization

6. **Read Operation** (All Handlers)
   - Stream file contents without local download
   - Support large files efficiently
   - Return contents to stdout
   - Enable Claude to reference archived content transparently

### Non-Functional Requirements

1. **Performance**
   - Upload/download speeds limited only by network
   - Streaming for files > 100MB
   - Minimal memory footprint

2. **Reliability**
   - Retry transient failures automatically
   - Validate checksums after upload/download
   - Atomic operations where supported

3. **Security**
   - Credentials from environment variables or config
   - Never log credentials
   - Support IAM roles (S3, GCS)
   - OAuth2 for Google Drive

4. **Error Handling**
   - Clear error messages
   - Provider-specific error context
   - Distinguish transient vs permanent failures

## Architecture

### Handler Skill Structure

Each handler follows this structure:

```
handler-storage-{provider}/
├── SKILL.md
├── docs/
│   ├── setup-guide.md
│   ├── authentication.md
│   └── troubleshooting.md
└── scripts/
    ├── upload.sh
    ├── download.sh
    ├── delete.sh
    ├── list.sh
    ├── get-url.sh
    └── read.sh
```

### Standard Script Interface

All scripts follow this interface:

```bash
#!/bin/bash
set -euo pipefail

# Common functions
source "$(dirname "$0")/../../common/functions.sh"

# Load configuration
CONFIG_FILE="${CONFIG_FILE:-.fractary/plugins/file/config.json}"
HANDLER_CONFIG=$(load_handler_config "$CONFIG_FILE" "{provider}")

# Parse arguments
# Execute operation
# Handle errors
# Return structured output (JSON)
```

### Common Functions Library

Create `skills/common/functions.sh`:

```bash
#!/bin/bash

# Load handler-specific configuration
load_handler_config() {
    local config_file="$1"
    local handler="$2"

    if [[ ! -f "$config_file" ]]; then
        # Check global config
        config_file="$HOME/.config/fractary/file/config.json"
    fi

    if [[ -f "$config_file" ]]; then
        jq -r ".handlers.$handler" "$config_file"
    else
        echo "{}"
    fi
}

# Expand environment variables in config values
expand_env_vars() {
    local value="$1"
    # Replace ${VAR_NAME} with actual value
    echo "$value" | envsubst
}

# Calculate checksum
calculate_checksum() {
    local file="$1"
    sha256sum "$file" | awk '{print $1}'
}

# Retry operation
retry_operation() {
    local max_attempts="${1:-3}"
    local delay="${2:-1}"
    local command="${3}"

    local attempt=1
    while (( attempt <= max_attempts )); do
        if eval "$command"; then
            return 0
        fi

        if (( attempt < max_attempts )); then
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    return 1
}

# Return JSON result
return_result() {
    local success="$1"
    local message="$2"
    shift 2
    local extra="$*"

    jq -n \
        --arg success "$success" \
        --arg message "$message" \
        --argjson extra "${extra:-{}}" \
        '{success: ($success == "true"), message: $message} + $extra'
}
```

## Implementation Details

### 1. Local Handler

**handler-storage-local/scripts/upload.sh:**
```bash
#!/bin/bash
set -euo pipefail

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Load config
CONFIG=$(load_handler_config "" "local")
BASE_PATH=$(echo "$CONFIG" | jq -r '.base_path // "./storage"')

# Create target directory
TARGET="$BASE_PATH/$REMOTE_PATH"
mkdir -p "$(dirname "$TARGET")"

# Copy file
cp "$LOCAL_PATH" "$TARGET"

# Calculate checksum
CHECKSUM=$(calculate_checksum "$TARGET")
SIZE=$(stat -f%z "$TARGET" 2>/dev/null || stat -c%s "$TARGET")

# Generate file:// URL
URL="file://$(realpath "$TARGET")"

return_result true "File uploaded successfully" "$(jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    --arg path "$TARGET" \
    '{url: $url, size_bytes: ($size | tonumber), checksum: $checksum, local_path: $path}')"
```

**handler-storage-local/scripts/read.sh:**
```bash
#!/bin/bash
set -euo pipefail

REMOTE_PATH="$1"

CONFIG=$(load_handler_config "" "local")
BASE_PATH=$(echo "$CONFIG" | jq -r '.base_path // "./storage"')
FILE_PATH="$BASE_PATH/$REMOTE_PATH"

if [[ ! -f "$FILE_PATH" ]]; then
    echo "Error: File not found: $FILE_PATH" >&2
    exit 1
fi

# Stream file contents to stdout
cat "$FILE_PATH"
```

### 2. R2 Handler (Migrated)

**handler-storage-r2/scripts/upload.sh:**
```bash
#!/bin/bash
set -euo pipefail

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Load R2 config
CONFIG=$(load_handler_config "" "r2")
ACCOUNT_ID=$(echo "$CONFIG" | jq -r '.account_id' | envsubst)
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')
PUBLIC_URL=$(echo "$CONFIG" | jq -r '.public_url')

# Configure rclone for R2
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_ACCESS_KEY_ID=$(echo "$CONFIG" | jq -r '.access_key_id' | envsubst)
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=$(echo "$CONFIG" | jq -r '.secret_access_key' | envsubst)
export RCLONE_CONFIG_R2_ENDPOINT="https://$ACCOUNT_ID.r2.cloudflarestorage.com"

# Upload file
retry_operation 3 1 "rclone copy \"$LOCAL_PATH\" \"r2:$BUCKET/$(dirname \"$REMOTE_PATH\")\" --progress"

# Calculate checksum
CHECKSUM=$(calculate_checksum "$LOCAL_PATH")
SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null || stat -c%s "$LOCAL_PATH")

# Generate URL
if [[ "$PUBLIC" == "true" ]]; then
    URL="$PUBLIC_URL/$REMOTE_PATH"
else
    # Generate presigned URL (24 hours)
    URL=$(rclone link "r2:$BUCKET/$REMOTE_PATH" --expire 24h)
fi

return_result true "File uploaded to R2" "$(jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{url: $url, size_bytes: ($size | tonumber), checksum: $checksum}')"
```

**handler-storage-r2/scripts/read.sh:**
```bash
#!/bin/bash
set -euo pipefail

REMOTE_PATH="$1"

CONFIG=$(load_handler_config "" "r2")
ACCOUNT_ID=$(echo "$CONFIG" | jq -r '.account_id' | envsubst)
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')

# Configure rclone
export RCLONE_CONFIG_R2_TYPE=s3
export RCLONE_CONFIG_R2_PROVIDER=Cloudflare
export RCLONE_CONFIG_R2_ACCESS_KEY_ID=$(echo "$CONFIG" | jq -r '.access_key_id' | envsubst)
export RCLONE_CONFIG_R2_SECRET_ACCESS_KEY=$(echo "$CONFIG" | jq -r '.secret_access_key' | envsubst)
export RCLONE_CONFIG_R2_ENDPOINT="https://$ACCOUNT_ID.r2.cloudflarestorage.com"

# Stream file to stdout
rclone cat "r2:$BUCKET/$REMOTE_PATH"
```

### 3. S3 Handler

**handler-storage-s3/scripts/upload.sh:**
```bash
#!/bin/bash
set -euo pipefail

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Load S3 config
CONFIG=$(load_handler_config "" "s3")
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')
REGION=$(echo "$CONFIG" | jq -r '.region // "us-east-1"')

# Set AWS credentials from config or environment
export AWS_ACCESS_KEY_ID=$(echo "$CONFIG" | jq -r '.access_key_id // empty' | envsubst)
export AWS_SECRET_ACCESS_KEY=$(echo "$CONFIG" | jq -r '.secret_access_key // empty' | envsubst)
export AWS_DEFAULT_REGION="$REGION"

# Determine ACL
ACL="private"
[[ "$PUBLIC" == "true" ]] && ACL="public-read"

# Upload file
retry_operation 3 1 "aws s3 cp \"$LOCAL_PATH\" \"s3://$BUCKET/$REMOTE_PATH\" --acl \"$ACL\""

# Calculate checksum
CHECKSUM=$(calculate_checksum "$LOCAL_PATH")
SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null || stat -c%s "$LOCAL_PATH")

# Generate URL
if [[ "$PUBLIC" == "true" ]]; then
    URL="https://$BUCKET.s3.$REGION.amazonaws.com/$REMOTE_PATH"
else
    URL=$(aws s3 presign "s3://$BUCKET/$REMOTE_PATH" --expires-in 86400)
fi

return_result true "File uploaded to S3" "$(jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{url: $url, size_bytes: ($size | tonumber), checksum: $checksum}')"
```

**handler-storage-s3/scripts/read.sh:**
```bash
#!/bin/bash
set -euo pipefail

REMOTE_PATH="$1"

CONFIG=$(load_handler_config "" "s3")
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')
REGION=$(echo "$CONFIG" | jq -r '.region // "us-east-1"')

export AWS_ACCESS_KEY_ID=$(echo "$CONFIG" | jq -r '.access_key_id // empty' | envsubst)
export AWS_SECRET_ACCESS_KEY=$(echo "$CONFIG" | jq -r '.secret_access_key // empty' | envsubst)
export AWS_DEFAULT_REGION="$REGION"

# Stream file to stdout
aws s3 cp "s3://$BUCKET/$REMOTE_PATH" -
```

### 4. GCS Handler

**handler-storage-gcs/scripts/upload.sh:**
```bash
#!/bin/bash
set -euo pipefail

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Load GCS config
CONFIG=$(load_handler_config "" "gcs")
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')
PROJECT=$(echo "$CONFIG" | jq -r '.project_id')

# Set service account key if provided
SA_KEY=$(echo "$CONFIG" | jq -r '.service_account_key // empty' | envsubst)
if [[ -n "$SA_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SA_KEY"
fi

# Upload file
retry_operation 3 1 "gcloud storage cp \"$LOCAL_PATH\" \"gs://$BUCKET/$REMOTE_PATH\" --project=\"$PROJECT\""

# Make public if requested
if [[ "$PUBLIC" == "true" ]]; then
    gsutil acl ch -u AllUsers:R "gs://$BUCKET/$REMOTE_PATH"
fi

# Calculate checksum and size
CHECKSUM=$(calculate_checksum "$LOCAL_PATH")
SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null || stat -c%s "$LOCAL_PATH")

# Generate URL
if [[ "$PUBLIC" == "true" ]]; then
    URL="https://storage.googleapis.com/$BUCKET/$REMOTE_PATH"
else
    URL=$(gsutil signurl -d 24h "$GOOGLE_APPLICATION_CREDENTIALS" "gs://$BUCKET/$REMOTE_PATH" | tail -n1 | awk '{print $NF}')
fi

return_result true "File uploaded to GCS" "$(jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{url: $url, size_bytes: ($size | tonumber), checksum: $checksum}')"
```

**handler-storage-gcs/scripts/read.sh:**
```bash
#!/bin/bash
set -euo pipefail

REMOTE_PATH="$1"

CONFIG=$(load_handler_config "" "gcs")
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')

SA_KEY=$(echo "$CONFIG" | jq -r '.service_account_key // empty' | envsubst)
if [[ -n "$SA_KEY" ]]; then
    export GOOGLE_APPLICATION_CREDENTIALS="$SA_KEY"
fi

# Stream file to stdout
gcloud storage cat "gs://$BUCKET/$REMOTE_PATH"
```

### 5. Google Drive Handler

**handler-storage-gdrive/scripts/upload.sh:**
```bash
#!/bin/bash
set -euo pipefail

LOCAL_PATH="$1"
REMOTE_PATH="$2"
PUBLIC="${3:-false}"

# Load Google Drive config
CONFIG=$(load_handler_config "" "gdrive")
FOLDER_ID=$(echo "$CONFIG" | jq -r '.folder_id')

# Configure rclone for Google Drive
export RCLONE_CONFIG_GDRIVE_TYPE=drive
export RCLONE_CONFIG_GDRIVE_CLIENT_ID=$(echo "$CONFIG" | jq -r '.client_id' | envsubst)
export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET=$(echo "$CONFIG" | jq -r '.client_secret' | envsubst)
export RCLONE_CONFIG_GDRIVE_SCOPE=drive
export RCLONE_CONFIG_GDRIVE_ROOT_FOLDER_ID="$FOLDER_ID"

# Upload file
TARGET_DIR=$(dirname "$REMOTE_PATH")
retry_operation 3 1 "rclone copy \"$LOCAL_PATH\" \"gdrive:$TARGET_DIR\" --progress"

# Calculate checksum and size
CHECKSUM=$(calculate_checksum "$LOCAL_PATH")
SIZE=$(stat -f%z "$LOCAL_PATH" 2>/dev/null || stat -c%s "$LOCAL_PATH")

# Generate shareable link
if [[ "$PUBLIC" == "true" ]]; then
    URL=$(rclone link "gdrive:$REMOTE_PATH" --expire 87600h)  # ~10 years for "permanent"
else
    URL=$(rclone link "gdrive:$REMOTE_PATH" --expire 24h)
fi

return_result true "File uploaded to Google Drive" "$(jq -n \
    --arg url "$URL" \
    --arg size "$SIZE" \
    --arg checksum "$CHECKSUM" \
    '{url: $url, size_bytes: ($size | tonumber), checksum: $checksum}')"
```

**handler-storage-gdrive/scripts/read.sh:**
```bash
#!/bin/bash
set -euo pipefail

REMOTE_PATH="$1"

CONFIG=$(load_handler_config "" "gdrive")
FOLDER_ID=$(echo "$CONFIG" | jq -r '.folder_id')

export RCLONE_CONFIG_GDRIVE_TYPE=drive
export RCLONE_CONFIG_GDRIVE_CLIENT_ID=$(echo "$CONFIG" | jq -r '.client_id' | envsubst)
export RCLONE_CONFIG_GDRIVE_CLIENT_SECRET=$(echo "$CONFIG" | jq -r '.client_secret' | envsubst)
export RCLONE_CONFIG_GDRIVE_SCOPE=drive
export RCLONE_CONFIG_GDRIVE_ROOT_FOLDER_ID="$FOLDER_ID"

# Stream file to stdout
rclone cat "gdrive:$REMOTE_PATH"
```

## Handler SKILL.md Template

Each handler needs a SKILL.md:

```markdown
<CONTEXT>
You are the handler-storage-{provider} skill for the fractary-file plugin. You execute file operations specifically for {Provider Name} storage.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER expose credentials in outputs or logs
2. ALWAYS validate inputs before executing operations
3. ALWAYS return structured JSON results
4. NEVER fail silently - report all errors clearly
</CRITICAL_RULES>

<OPERATIONS>
Supported operations:
- upload: Upload file to {provider}
- download: Download file from {provider}
- delete: Delete file from {provider}
- list: List files in {provider}
- get-url: Generate accessible URL
- read: Stream file contents without downloading
</OPERATIONS>

<CONFIGURATION>
Required configuration in .fractary/plugins/file/config.json:
{provider-specific config example}
</CONFIGURATION>

<WORKFLOW>
1. Load handler configuration
2. Validate operation parameters
3. Execute provider-specific script
4. Return structured result
</WORKFLOW>

<OUTPUTS>
All operations return JSON:
{
  "success": true|false,
  "message": "...",
  "url": "...",
  "size_bytes": 1024,
  "checksum": "sha256:..."
}
</OUTPUTS>

<ERROR_HANDLING>
- Missing configuration: Return error with setup instructions
- Authentication failure: Return error with credential check steps
- Network error: Retry up to 3 times
- File not found: Return clear error message
</ERROR_HANDLING>

<DOCUMENTATION>
See docs/setup-guide.md for setup instructions
See docs/authentication.md for credential configuration
See docs/troubleshooting.md for common issues
</DOCUMENTATION>
```

## Testing Strategy

### Unit Tests (Per Handler)
- Upload with valid file
- Upload with invalid path
- Download existing file
- Download non-existent file
- Delete existing file
- Delete non-existent file
- List empty directory
- List with files
- Generate URL for existing file
- Read existing file
- Read non-existent file
- Handle missing credentials

### Integration Tests
- Upload large file (>100MB)
- Download large file
- Verify checksums match
- Test retry on transient failure
- Test timeout handling
- Cross-handler operation (future)

### Manual Tests
- Test each handler with real credentials
- Verify public vs private URLs
- Test read operation for archived content
- Performance testing with various file sizes

## Success Criteria

- [ ] All 5 handlers implemented
- [ ] All 6 operations work on all handlers
- [ ] Read operation enables transparent access to cloud files
- [ ] Common functions library created
- [ ] Error handling consistent across handlers
- [ ] Checksums validated on upload/download
- [ ] Documentation complete for each handler
- [ ] Tests passing for all handlers

## Open Questions

1. Should we support progress callbacks for large uploads/downloads?
   - **Decision**: Use --progress flag for rclone, aws cli shows progress by default

2. How do we handle rate limiting from providers?
   - **Decision**: Exponential backoff in retry logic

3. Should read operation support byte ranges (partial reads)?
   - **Decision**: Defer to future enhancement, full reads for now

4. How do we test without real credentials?
   - **Decision**: Use mock/stub scripts for CI, manual tests with real credentials

## Implementation Checklist

### Local Handler
- [ ] Implement upload.sh
- [ ] Implement download.sh
- [ ] Implement delete.sh
- [ ] Implement list.sh
- [ ] Implement get-url.sh
- [ ] Implement read.sh
- [ ] Create SKILL.md
- [ ] Write setup guide

### R2 Handler (Migration)
- [ ] Migrate existing scripts
- [ ] Add read.sh
- [ ] Create SKILL.md
- [ ] Update documentation

### S3 Handler
- [ ] Implement all 6 scripts
- [ ] Create SKILL.md
- [ ] Write setup guide
- [ ] Document IAM permissions needed

### GCS Handler
- [ ] Implement all 6 scripts
- [ ] Create SKILL.md
- [ ] Write setup guide
- [ ] Document service account setup

### Google Drive Handler
- [ ] Implement all 6 scripts
- [ ] Create SKILL.md
- [ ] Write OAuth2 setup guide
- [ ] Document rclone configuration

### Common
- [ ] Create common/functions.sh
- [ ] Implement retry logic
- [ ] Implement checksum validation
- [ ] Create error handling patterns
- [ ] Test all handlers

## Timeline

**Estimated Duration**: 2-3 weeks

**Breakdown**:
- Days 1-2: Common functions and local handler
- Days 3-4: R2 handler migration and testing
- Days 5-7: S3 handler implementation
- Days 8-10: GCS handler implementation
- Days 11-13: Google Drive handler implementation
- Days 14-15: Testing and documentation

## Dependencies

- SPEC-00029-01: Architecture must be in place
- External tools: rclone, aws cli, gcloud cli, gsutil

## Next Steps

After this spec is implemented, proceed to:
- **SPEC-00029-03**: Create /fractary-file:init command and configuration wizard
