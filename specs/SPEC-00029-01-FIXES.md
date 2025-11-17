# SPEC-00029-01 Code Review Fixes

## Critical Issue #1: Agent Invocation Pattern

### Problem
Specs incorrectly use: `@agent-fractary-file:handler-storage-{provider}`
- Mixes agent and skill naming
- Handlers are skills, not agents

### Solution
**Correct pattern**: Always invoke the file-manager agent, never invoke handler skills directly.

```markdown
# CORRECT
Use the @agent-fractary-file:file-manager agent to upload file:
{
  "operation": "upload",
  "local_path": "/path/to/file",
  "remote_path": "archive/file.txt",
  "handler": "s3"  // Optional override
}

# INCORRECT
Use the @agent-fractary-file:handler-storage-s3 skill to upload...
```

**Rationale**:
- file-manager agent is the orchestrator
- Handler skills are internal implementation details
- Agent handles routing, validation, error handling
- Maintains clean abstraction

### Files to Update
- SPEC-00029-01: Lines 293, agent specification section
- SPEC-00029-02: All handler invocation examples
- SPEC-00029-03: Configuration wizard examples
- SPEC-00029-08, 09, 10, 11: Spec plugin integration
- SPEC-00029-12, 13, 14, 15: Logs plugin integration
- SPEC-00029-16, 17: FABER integration examples

---

## Critical Issue #2: Script Execution Context

### Problem
Scripts contain logic that should be in skills:
- Configuration loading
- Decision making
- Parameter preparation
- Error routing

### Solution
**Three-Layer Architecture Enforcement**:

**Layer 1: Agent (file-manager)**
- Receives user request
- Validates operation
- Loads configuration
- Determines handler
- Invokes skill with prepared parameters

**Layer 2: Skill (handler-storage-{provider})**
- Receives operation + parameters from agent
- Prepares provider-specific parameters
- Invokes script with all parameters
- Interprets script output
- Returns structured result to agent

**Layer 3: Script**
- Receives ALL parameters as arguments
- NO configuration loading
- NO decision making
- Pure execution
- Returns status code + output

### Example Refactor

**BEFORE (Incorrect)**:
```bash
#!/bin/bash
# upload.sh
CONFIG=$(load_handler_config "" "s3")
BUCKET=$(echo "$CONFIG" | jq -r '.bucket_name')
REGION=$(echo "$CONFIG" | jq -r '.region')
aws s3 cp "$1" "s3://$BUCKET/$2"
```

**AFTER (Correct)**:
```bash
#!/bin/bash
# upload.sh - Pure execution, no config loading
set -euo pipefail

# All parameters passed by skill
BUCKET="$1"
REGION="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
LOCAL_PATH="$5"
REMOTE_PATH="$6"

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="$REGION"

aws s3 cp "$LOCAL_PATH" "s3://$BUCKET/$REMOTE_PATH"
```

**Skill prepares parameters**:
```markdown
<WORKFLOW>
1. Receive operation request from agent
2. Extract handler configuration from request
3. Prepare all script parameters:
   - bucket = config.bucket_name
   - region = config.region
   - access_key = expand_env(config.access_key_id)
   - secret_key = expand_env(config.secret_access_key)
   - local_path, remote_path from request
4. Invoke script: upload.sh "$bucket" "$region" "$access_key" "$secret_key" "$local_path" "$remote_path"
5. Parse script output
6. Return structured result
</WORKFLOW>
```

### Files to Update
- SPEC-00029-02: All handler script examples (upload, download, delete, list, get-url, read)

---

## Critical Issue #3: Common Functions Error Handling

### Problem
- No file existence validation
- Platform-specific commands (sha256sum vs shasum)
- No error handling

### Solution

```bash
#!/bin/bash
# common/functions.sh

# Load handler-specific configuration
load_handler_config() {
    local config_file="$1"
    local handler="$2"

    # Try project config first
    if [[ -z "$config_file" ]]; then
        config_file=".fractary/plugins/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        # Try global config
        config_file="$HOME/.config/fractary/file/config.json"
    fi

    if [[ ! -f "$config_file" ]]; then
        echo "{}" # Return empty config
        return 0
    fi

    if ! jq -r ".handlers.$handler // {}" "$config_file" 2>/dev/null; then
        echo "Error: Invalid JSON in config file" >&2
        return 1
    fi
}

# Expand environment variables in config values
expand_env_vars() {
    local value="$1"

    if [[ -z "$value" ]]; then
        echo ""
        return 0
    fi

    # Replace ${VAR_NAME} with actual value
    echo "$value" | envsubst
}

# Calculate checksum (cross-platform)
calculate_checksum() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Try sha256sum (Linux)
    if command -v sha256sum >/dev/null 2>&1; then
        sha256sum "$file" | awk '{print $1}'
        return 0
    fi

    # Try shasum (macOS)
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 "$file" | awk '{print $1}'
        return 0
    fi

    echo "Error: No checksum command available (tried sha256sum, shasum)" >&2
    return 1
}

# Get file size (cross-platform)
get_file_size() {
    local file="$1"

    if [[ ! -f "$file" ]]; then
        echo "Error: File not found: $file" >&2
        return 1
    fi

    # Try GNU stat (Linux)
    if stat -c%s "$file" 2>/dev/null; then
        return 0
    fi

    # Try BSD stat (macOS)
    if stat -f%z "$file" 2>/dev/null; then
        return 0
    fi

    echo "Error: Cannot determine file size" >&2
    return 1
}

# Retry operation with exponential backoff
retry_operation() {
    local max_attempts="${1:-3}"
    local initial_delay="${2:-1}"
    shift 2
    local command="$*"

    if [[ -z "$command" ]]; then
        echo "Error: No command specified for retry" >&2
        return 1
    fi

    local attempt=1
    local delay="$initial_delay"

    while (( attempt <= max_attempts )); do
        if eval "$command"; then
            return 0
        fi

        if (( attempt < max_attempts )); then
            echo "Attempt $attempt failed, retrying in ${delay}s..." >&2
            sleep "$delay"
            delay=$((delay * 2))  # Exponential backoff
        fi

        attempt=$((attempt + 1))
    done

    echo "Error: Command failed after $max_attempts attempts" >&2
    return 1
}

# Return JSON result (safe JSON construction)
return_result() {
    local success="$1"
    local message="$2"
    shift 2
    local extra="${*:-{}}"

    # Validate extra is valid JSON
    if ! echo "$extra" | jq empty 2>/dev/null; then
        extra="{}"
    fi

    jq -n \
        --arg success "$success" \
        --arg message "$message" \
        --argjson extra "$extra" \
        '{success: ($success == "true"), message: $message} + $extra'
}

# Validate required tools are available
check_required_tools() {
    local tools=("$@")
    local missing=()

    for tool in "${tools[@]}"; do
        if ! command -v "$tool" >/dev/null 2>&1; then
            missing+=("$tool")
        fi
    done

    if (( ${#missing[@]} > 0 )); then
        echo "Error: Missing required tools: ${missing[*]}" >&2
        echo "Please install them before continuing." >&2
        return 1
    fi

    return 0
}
```

### Files to Update
- SPEC-00029-02: Common functions section

---

## High Priority Issue #4: Template Truncation

### Problem
Handler SKILL.md template cuts off at:
```markdown
<WORKFLOW>
1. Loa
```

### Solution
Complete template:

```markdown
<WORKFLOW>
1. Load handler configuration from request
2. Validate operation parameters
3. Prepare provider-specific parameters
4. Execute provider-specific script
5. Parse script output
6. Return structured result to agent
</WORKFLOW>

<OUTPUTS>
All operations return JSON:
{
  "success": true|false,
  "message": "Operation completed successfully",
  "url": "https://storage.example.com/path/to/file",
  "size_bytes": 1024,
  "checksum": "sha256:abc123..."
}
</OUTPUTS>

<ERROR_HANDLING>
- Missing configuration: Return error with setup instructions
- Authentication failure: Return error with credential check steps
- Network error: Retry up to 3 times with exponential backoff
- File not found: Return clear error message
- Script execution failure: Capture stderr and return to agent
</ERROR_HANDLING>

<DOCUMENTATION>
See docs/setup-guide.md for setup instructions
See docs/authentication.md for credential configuration
See docs/troubleshooting.md for common issues
</DOCUMENTATION>
```

### Files to Update
- SPEC-00029-02: Handler SKILL.md template section

---

## High Priority Issue #5: Google Drive OAuth Flow

### Problem
OAuth2 flow not documented:
- Where does initial token come from?
- How is refresh token stored?
- What happens on token expiration?

### Solution
Add dedicated OAuth setup section:

```markdown
### Google Drive OAuth2 Setup

**handler-storage-gdrive/docs/oauth-setup-guide.md**:

## Prerequisites

1. Google Cloud Project with Drive API enabled
2. OAuth 2.0 Client ID (Desktop application type)
3. rclone installed (`brew install rclone` or `apt install rclone`)

## Initial Setup

### Step 1: Create OAuth Credentials

1. Go to https://console.cloud.google.com/apis/credentials
2. Create OAuth 2.0 Client ID
3. Application type: Desktop app
4. Note Client ID and Client Secret

### Step 2: Configure rclone

```bash
# Interactive OAuth flow
rclone config

# Select: n (New remote)
# Name: gdrive
# Storage: drive (Google Drive)
# Client ID: <paste from step 1>
# Client Secret: <paste from step 1>
# Scope: drive (Full access)
# Root folder ID: leave empty for root
# Service Account: No
# Auto config: Yes (opens browser)
```

Browser will open for Google OAuth consent. After approval, rclone stores token in:
- Linux/macOS: `~/.config/rclone/rclone.conf`
- Windows: `%USERPROFILE%\.config\rclone\rclone.conf`

### Step 3: Extract Token for fractary-file

```bash
# View rclone config
rclone config show gdrive

# Copy token value to environment variable
export GDRIVE_TOKEN="<token from config>"
```

### Step 4: Configure fractary-file

```json
{
  "handlers": {
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "token": "${GDRIVE_TOKEN}",
      "folder_id": "root"
    }
  }
}
```

## Token Refresh

Google OAuth tokens expire after 1 hour. rclone handles refresh automatically using refresh_token.

**Token storage**:
- Access token: Short-lived (1 hour)
- Refresh token: Long-lived (doesn't expire unless revoked)
- Both stored in rclone config

**Automatic refresh**:
rclone checks token expiration before each operation and refreshes if needed.

**Manual refresh** (if needed):
```bash
rclone config reconnect gdrive:
```

## Troubleshooting

**Token expired and refresh failed**:
- Re-run `rclone config` OAuth flow
- Update GDRIVE_TOKEN environment variable

**Permission denied**:
- Check OAuth scope includes Drive API
- Verify folder_id exists and is accessible

**Rate limiting**:
- Google Drive API has quotas
- fractary-file implements exponential backoff
```

### Files to Update
- SPEC-00029-02: Google Drive handler section
- Add new docs/oauth-setup-guide.md reference

---

## High Priority Issue #6: Credential Security

### Problem
No detailed guidance on:
- Secure credential storage options
- IAM roles integration
- Credential rotation

### Solution
Add comprehensive security section:

```markdown
## Security Considerations

### Credential Storage Best Practices

**Priority Order** (most secure to least):

1. **Cloud Provider IAM Roles** (Best)
   - AWS: EC2 instance profiles, ECS task roles
   - GCS: Workload Identity, service account impersonation
   - No credentials in config files
   - Automatic rotation by cloud provider

2. **Environment Variables**
   - Store credentials in environment, reference in config
   - Config file: `"access_key": "${AWS_ACCESS_KEY_ID}"`
   - Never commit actual credentials
   - Use secrets management (AWS Secrets Manager, etc.)

3. **Config Files with Restricted Permissions** (Acceptable)
   - File permissions: 0600 (owner read/write only)
   - Located outside version control
   - Encrypted at rest (OS-level encryption)

4. **Hardcoded in Config** (Not Recommended)
   - Only for local development
   - Never commit to version control
   - Add to .gitignore

### Handler-Specific Security

#### AWS S3
**Best Practice**: Use IAM roles

```json
{
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket",
      // No access_key_id or secret_access_key = use IAM role
    }
  }
}
```

**IAM Policy Required**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

#### Google Cloud Storage
**Best Practice**: Use Workload Identity or ADC

```json
{
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      // No service_account_key = use Application Default Credentials
    }
  }
}
```

**Service Account Permissions Required**:
- roles/storage.objectCreator
- roles/storage.objectViewer
- roles/storage.objectAdmin (if delete needed)

#### Cloudflare R2
**Best Practice**: API tokens with restricted permissions

- Create API token in Cloudflare dashboard
- Permissions: Object Read, Object Write (minimal required)
- Scope to specific bucket
- Set expiration date

#### Local Filesystem
**Security**:
- Directory permissions: 0755 (default)
- File permissions: 0644 (default)
- Consider: encryption at rest (OS-level)

### Credential Rotation Strategy

**Automated Rotation** (Recommended):
1. Cloud provider rotates credentials automatically (IAM roles)
2. Application uses SDK to fetch current credentials
3. No manual intervention needed

**Manual Rotation**:
1. Generate new credentials in cloud provider
2. Update environment variables
3. Test new credentials
4. Revoke old credentials
5. Update documentation

**Rotation Schedule**:
- IAM roles: Automatic (hourly)
- API tokens: Every 90 days
- Service account keys: Every 90 days
- Passwords: Never use passwords for API access

### Audit and Monitoring

**Log Security Events**:
- Failed authentication attempts
- Credential changes
- Unusual access patterns

**Never Log**:
- Actual credential values
- Full API tokens
- Secret keys

**Redaction Pattern**:
```bash
# Log: "Using access key: AKIA****EXAMPLE"
# Not: "Using access key: AKIAIOSFODNN7EXAMPLE"
```

### Compliance Considerations

**PCI-DSS / SOC 2 / HIPAA**:
- Use encryption in transit (HTTPS/TLS)
- Use encryption at rest
- Implement access logging
- Regular credential rotation
- Principle of least privilege

**GDPR**:
- Don't log personally identifiable information
- Implement data retention policies
- Support data deletion requests
```

### Files to Update
- SPEC-00029-01: Non-functional requirements section
- SPEC-00029-02: Add security section to each handler

---

## High Priority Issue #7: Read Operation Size Limits

### Problem
- No size limits on read operation
- Could exhaust LLM context
- Performance issues with large files

### Solution

```markdown
### Read Operation (NEW)

**Purpose**: Stream file contents without local download, enabling transparent access to archived content.

**Signature**:
```bash
read <remote_path> [--max-bytes=10485760] [--offset=0]

Returns: File contents to stdout (truncated if exceeds max_bytes)
```

**Parameters**:
- `remote_path`: Path to file in storage
- `--max-bytes`: Maximum bytes to read (default: 10MB)
- `--offset`: Start reading from byte offset (default: 0)

**Size Limits**:
- Default max: 10 MB (10,485,760 bytes)
- Hard limit: 50 MB (52,428,800 bytes)
- Files > max truncated with warning

**Use Cases**:
- ✅ Read archived specs (~50-200 KB)
- ✅ Read session logs (~100-500 KB)
- ✅ Read small deployment logs (<10 MB)
- ⚠️ Read large build logs (paginate or download)
- ❌ Read binary files (use download instead)

**Example Output**:
```bash
# File within limit
$ fractary-file read "archive/specs/2025/spec-123.md"
[full file contents]

# File exceeds limit
$ fractary-file read "archive/logs/2025/01/large-build.log"
[Warning: File size 52 MB exceeds max 10 MB, truncated]
[first 10 MB of content]
...
[Truncated. Use --max-bytes=52428800 or download full file]
```

**Implementation**:

```bash
# scripts/read.sh (S3 example)
#!/bin/bash
set -euo pipefail

BUCKET="$1"
REGION="$2"
ACCESS_KEY="$3"
SECRET_KEY="$4"
REMOTE_PATH="$5"
MAX_BYTES="${6:-10485760}"  # 10MB default

export AWS_ACCESS_KEY_ID="$ACCESS_KEY"
export AWS_SECRET_ACCESS_KEY="$SECRET_KEY"
export AWS_DEFAULT_REGION="$REGION"

# Get file size first
SIZE=$(aws s3api head-object --bucket "$BUCKET" --key "$REMOTE_PATH" --query ContentLength --output text)

if (( SIZE > MAX_BYTES )); then
    echo "[Warning: File size $SIZE bytes exceeds max $MAX_BYTES bytes, truncating]" >&2
fi

# Stream file, limit with head
aws s3 cp "s3://$BUCKET/$REMOTE_PATH" - | head -c "$MAX_BYTES"

if (( SIZE > MAX_BYTES )); then
    echo "" >&2
    echo "[Truncated. Use --max-bytes=$SIZE or download full file with: fractary-file download]" >&2
fi
```

**Agent Handling**:

```markdown
<WORKFLOW>
## Read Operation

1. Validate parameters
2. Check file size if possible (via metadata)
3. If size > 50MB: Warn user and suggest download
4. If 10MB < size < 50MB: Offer to read with higher limit
5. If size < 10MB: Read normally
6. Stream content to user
7. If truncated: Notify and suggest alternatives
</WORKFLOW>
```

### Files to Update
- SPEC-00029-01: Operations section
- SPEC-00029-02: All read.sh script examples
- Add size limit documentation

---

## Summary of Changes Required

### Immediate (Before Merge)
1. ✅ Fix agent invocation pattern (all specs)
2. ✅ Complete truncated template (SPEC-00029-02)
3. ✅ Add credential security section (SPEC-00029-01, 02)

### Phase 1 Implementation
4. ✅ Refactor script execution context (SPEC-00029-02)
5. ✅ Improve common functions (SPEC-00029-02)
6. ✅ Document OAuth flow (SPEC-00029-02)
7. ✅ Add read operation limits (SPEC-00029-01, 02)

### Additional Recommendations
8. Add 25% buffer to timeline estimates (SPEC-00029-01 through 19)
9. Add codex configuration section (SPEC-00029-04)
10. Add migration testing strategy (SPEC-00029-18)
