# SPEC-0029-01: File Plugin Architecture & Handler Pattern Refactor

**Issue**: #29
**Phase**: 1 (fractary-file Enhancement)
**Dependencies**: None
**Status**: Draft
**Created**: 2025-01-15

## Overview

Refactor the fractary-file plugin to use the handler pattern (consistent with work and repo plugins) and establish the architectural foundation for multi-provider cloud storage support. This spec covers the core architecture, handler abstraction, and routing logic that will enable support for Local, R2, S3, GCS, and Google Drive storage providers.

## Requirements

### Functional Requirements

1. **Handler Pattern Implementation**
   - Refactor existing R2 implementation into handler-storage-r2
   - Create file-manager skill that routes to appropriate handler
   - Support configuration-based handler selection
   - Enable runtime handler switching without code changes

2. **Storage Operations**
   - Support 6 core operations: upload, download, delete, list, get-url, read
   - All handlers must implement all 6 operations
   - Consistent interface across all storage providers
   - Graceful error handling with provider-specific context

3. **Configuration Management**
   - Support global configuration (~/.config/fractary/file/config.json)
   - Support project configuration (.fractary/plugins/file/config.json)
   - Project config overrides global config
   - Default to local handler if no configuration exists

4. **Agent Orchestration**
   - file-manager agent coordinates all file operations
   - Agent validates operations before delegating to handlers
   - Agent aggregates results from handler operations
   - Agent handles cross-handler operations (future: copy between providers)

### Non-Functional Requirements

1. **Performance**
   - Minimal overhead from handler abstraction (<50ms)
   - Support files up to 5GB
   - Efficient streaming for large files

2. **Reliability**
   - Retry logic for transient failures (3 attempts)
   - Atomic operations where possible
   - Validation of file integrity (checksums)

3. **Security**
   - Credentials never logged or exposed
   - Support for environment variable credentials
   - Support for cloud provider IAM roles (AWS, GCS)
   - Secure credential storage with restricted file permissions (0600)
   - Credential rotation support
   - See "Security Considerations" section below for detailed guidance

4. **Maintainability**
   - Clear separation between routing and implementation
   - Handler implementations are independent
   - Easy to add new handlers without changing core logic

## Architecture

### Current Structure (R2 Only)
```
plugins/file/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── file-manager.md
├── skills/
│   └── file-manager/
│       ├── SKILL.md
│       └── scripts/
│           └── r2/
│               ├── upload.sh
│               ├── download.sh
│               ├── delete.sh
│               ├── list.sh
│               └── get-url.sh
└── README.md
```

### Target Structure (Handler Pattern)
```
plugins/file/
├── .claude-plugin/
│   └── plugin.json
├── agents/
│   └── file-manager.md
├── commands/
│   └── init.md
├── skills/
│   ├── file-manager/
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   ├── handler-development.md
│   │   │   └── operations.md
│   │   └── workflow/
│   │       ├── route-operation.md
│   │       └── validate-config.md
│   ├── handler-storage-local/
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── local-storage-guide.md
│   │   └── scripts/
│   │       ├── upload.sh
│   │       ├── download.sh
│   │       ├── delete.sh
│   │       ├── list.sh
│   │       ├── get-url.sh
│   │       └── read.sh
│   ├── handler-storage-r2/
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── r2-setup-guide.md
│   │   └── scripts/
│   │       ├── upload.sh
│   │       ├── download.sh
│   │       ├── delete.sh
│   │       ├── list.sh
│   │       ├── get-url.sh
│   │       └── read.sh
│   ├── handler-storage-s3/
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── s3-setup-guide.md
│   │   └── scripts/
│   │       └── (6 operation scripts)
│   ├── handler-storage-gcs/
│   │   ├── SKILL.md
│   │   ├── docs/
│   │   │   └── gcs-setup-guide.md
│   │   └── scripts/
│   │       └── (6 operation scripts)
│   └── handler-storage-gdrive/
│       ├── SKILL.md
│       ├── docs/
│       │   └── gdrive-setup-guide.md
│       └── scripts/
│           └── (6 operation scripts)
├── config/
│   └── config.example.json
└── README.md
```

### Handler Selection Flow

```
User Request
    ↓
@agent-fractary-file:file-manager
    ↓
Validate operation & parameters
    ↓
Load configuration
    ↓
Determine active handler
    ↓
Invoke handler-storage-{provider} skill
    ↓
Execute provider-specific script
    ↓
Return result to agent
    ↓
Agent formats and returns to user
```

### Handler Interface (Standardized Operations)

All handlers must implement these 6 operations:

```bash
# Upload file to storage
upload <local_path> <remote_path> [--public]
  Returns: cloud URL, size, checksum

# Download file from storage
download <remote_path> <local_path>
  Returns: local path, size, checksum

# Delete file from storage
delete <remote_path>
  Returns: confirmation

# List files in storage
list [prefix] [--max-results=100]
  Returns: JSON array of file metadata

# Get URL for file (public or presigned)
get-url <remote_path> [--expires-in=3600]
  Returns: accessible URL

# Read file content without downloading (NEW)
read <remote_path> [--max-bytes=10485760] [--offset=0]
  Returns: file contents to stdout (truncated if exceeds max_bytes)
  Default max: 10MB, Hard limit: 50MB
  Use cases: Read archived specs/logs without downloading
  WARNING: Files > 50MB should be downloaded, not read
```

### Configuration Schema

```json
{
  "schema_version": "1.0",
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "./storage",
      "create_directories": true,
      "permissions": "0755"
    },
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-bucket",
      "public_url": "https://pub-xxxxx.r2.dev",
      "region": "auto"
    },
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}",
      "public_url": "https://s3.amazonaws.com/my-bucket"
    },
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      "service_account_key": "${GCS_SERVICE_ACCOUNT_KEY}",
      "region": "us-central1"
    },
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "folder_id": "1234567890abcdefg",
      "auth_method": "oauth2"
    }
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true
  }
}
```

### Agent Specification

**agents/file-manager.md:**

```markdown
<CONTEXT>
You are the file-manager agent for the fractary-file plugin. You coordinate all file storage operations across multiple cloud providers (Local, R2, S3, GCS, Google Drive) by routing requests to appropriate handler skills.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER expose credentials in logs or outputs
2. ALWAYS validate operation parameters before invoking handlers
3. ALWAYS use the configured active handler unless explicitly overridden
4. NEVER bypass handler skills - all operations must go through handlers
5. ALWAYS verify file paths are safe (no path traversal)
</CRITICAL_RULES>

<INPUTS>
You receive file operation requests with:
- operation: upload | download | delete | list | get-url | read
- parameters: operation-specific (paths, options)
- handler_override: (optional) use specific handler instead of configured
</INPUTS>

<WORKFLOW>
1. Parse and validate operation request
2. Load configuration (project → global → defaults)
3. Determine target handler (configured or overridden)
4. Validate handler exists and is configured
5. Prepare handler-specific parameters
6. Invoke handler skill using declarative call
7. Process handler response
8. Return formatted result
</WORKFLOW>

<HANDLERS>
Available handler skills:
- handler-storage-local (default)
- handler-storage-r2
- handler-storage-s3
- handler-storage-gcs
- handler-storage-gdrive

Handler invocation pattern:
**IMPORTANT**: Always invoke file-manager agent, NOT handler skills directly.

CORRECT:
Use the @agent-fractary-file:file-manager agent to {operation}:
{
  "operation": "{operation}",
  "parameters": {
    "local_path": "...",
    "remote_path": "..."
  }
}

INCORRECT:
Use the @agent-fractary-file:handler-storage-s3 skill...  ❌

The agent routes to handler skills internally. Handler skills are implementation details.
</HANDLERS>

<OUTPUTS>
Return structured results:
{
  "success": true|false,
  "operation": "upload",
  "handler": "r2",
  "result": {
    "url": "https://...",
    "size_bytes": 1024,
    "checksum": "sha256:..."
  },
  "error": null|"error message"
}
</OUTPUTS>

<ERROR_HANDLING>
- Configuration not found: Use local handler with defaults
- Handler not configured: Return clear error with setup instructions
- Operation failed: Retry up to 3 times, then return error
- Invalid parameters: Return validation error without attempting operation
</ERROR_HANDLING>
```

### Core Skill Specification

**skills/file-manager/SKILL.md:**

```markdown
<CONTEXT>
You are the file-manager skill, responsible for routing file operations to appropriate storage handler skills based on configuration.
</CONTEXT>

<CRITICAL_RULES>
1. NEVER implement storage operations directly
2. ALWAYS delegate to handler skills
3. ALWAYS validate configuration before routing
4. NEVER expose credentials
</CRITICAL_RULES>

<WORKFLOW>
See workflow/route-operation.md for routing logic
See workflow/validate-config.md for configuration validation
</WORKFLOW>

<HANDLERS>
This skill routes to handler-storage-* skills:
- handler-storage-local
- handler-storage-r2
- handler-storage-s3
- handler-storage-gcs
- handler-storage-gdrive

Each handler implements 6 operations: upload, download, delete, list, get-url, read
</HANDLERS>

<COMPLETION_CRITERIA>
- Operation successfully routed to handler
- Handler result received and validated
- Result returned to agent
</COMPLETION_CRITERIA>
```

## Migration Path

### Step 1: Create Handler Structure
1. Create handler-storage-r2/ directory
2. Move existing scripts/r2/* to handler-storage-r2/scripts/
3. Create handler-storage-r2/SKILL.md
4. Create handler-storage-r2/docs/

### Step 2: Update file-manager Skill
1. Add routing logic to file-manager/SKILL.md
2. Create workflow/route-operation.md
3. Create workflow/validate-config.md
4. Update documentation

### Step 3: Update Agent
1. Modify agent to use new routing pattern
2. Add configuration loading logic
3. Add handler validation

### Step 4: Create Placeholder Handlers
1. Create directory structure for s3, gcs, gdrive, local
2. Add SKILL.md for each with handler metadata
3. Create empty script files (to be implemented in SPEC-0029-02)

### Step 5: Update Configuration
1. Create config.example.json
2. Update existing configs to new schema
3. Add migration notes to README

### Step 6: Testing
1. Test R2 handler with existing functionality
2. Verify configuration loading
3. Test handler routing logic
4. Verify error handling

## Security Considerations

### Credential Storage Best Practices

**Priority Order** (most secure to least):

1. **Cloud Provider IAM Roles** (BEST - Recommended for Production)
   - AWS: EC2 instance profiles, ECS task roles, EKS service accounts
   - GCS: Workload Identity, service account impersonation
   - No credentials in config files
   - Automatic rotation by cloud provider (hourly)
   - Zero credential management overhead

2. **Environment Variables** (GOOD - Recommended for Development/CI)
   - Store credentials in environment, reference in config
   - Config: `"access_key": "${AWS_ACCESS_KEY_ID}"`
   - Never commit actual credentials to version control
   - Use secrets management (AWS Secrets Manager, HashiCorp Vault)
   - Enable easier rotation and auditing

3. **Config Files with Restricted Permissions** (ACCEPTABLE - Last Resort)
   - File permissions: 0600 (owner read/write only)
   - Located outside version control (add to .gitignore)
   - Encrypted at rest (OS-level encryption)
   - Automatic permission check on plugin init

4. **Hardcoded in Config** (NEVER - Development Only)
   - Only acceptable for local development testing
   - Must never be committed to version control
   - Add `.fractary/plugins/file/config.json` to .gitignore

### Handler-Specific Security

#### AWS S3
**IAM Role Configuration (Recommended)**:
```json
{
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket"
      // No access_key_id or secret_access_key = use IAM role
    }
  }
}
```

**Required IAM Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "FractaryFilePlugin",
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket",
        "s3:GetObjectMetadata"
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
**Workload Identity (Recommended)**:
```json
{
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket"
      // No service_account_key = use Application Default Credentials
    }
  }
}
```

**Required IAM Roles**:
- `roles/storage.objectCreator` - Upload files
- `roles/storage.objectViewer` - Download/read files
- `roles/storage.objectAdmin` - Full access (if delete needed)

#### Cloudflare R2
**API Token Best Practices**:
- Create API token with minimal permissions
- Scope: Object Read & Write only (not Admin)
- Restrict to specific bucket
- Set expiration date (90 days recommended)
- Rotate regularly

#### Local Filesystem
**Security**:
- Directory permissions: 0755 (default)
- File permissions: 0644 (default)
- Consider OS-level encryption (FileVault, BitLocker, LUKS)
- Restrict access to specific users/groups

### Credential Rotation Strategy

**Automated Rotation** (Recommended):
- Cloud provider rotates IAM role credentials automatically
- Application uses SDK to fetch current credentials
- Rotation happens transparently (hourly for IAM roles)
- No manual intervention required

**Manual Rotation Schedule**:
- IAM role credentials: Automatic (no action needed)
- API tokens: Every 90 days
- Service account keys: Every 90 days
- Emergency rotation: Immediate if compromise suspected

**Rotation Process**:
1. Generate new credentials in cloud provider console
2. Update environment variables or secrets manager
3. Test new credentials with read-only operation
4. Update production configuration
5. Revoke old credentials after verification period (7 days)
6. Document rotation in audit log

### Audit and Monitoring

**Log Security Events** (Do):
- Failed authentication attempts
- Unusual access patterns (volume, location, time)
- Credential configuration changes
- Permission errors
- File access by user/session

**Never Log** (Don't):
- Actual credential values
- Full API tokens or keys
- Secret keys or passwords
- Raw authentication headers

**Redaction Pattern**:
```bash
# Good: "Using access key: AKIA****EXAMPLE"
# Bad:  "Using access key: AKIAIOSFODNN7EXAMPLE"

# Implementation
access_key="${ACCESS_KEY:0:4}****${ACCESS_KEY: -7}"
```

### Compliance Considerations

**PCI-DSS / SOC 2 / HIPAA Requirements**:
- ✓ Encryption in transit (HTTPS/TLS 1.2+)
- ✓ Encryption at rest (provider-managed or customer-managed keys)
- ✓ Access logging and monitoring
- ✓ Regular credential rotation (90 days max)
- ✓ Principle of least privilege (minimal IAM permissions)
- ✓ Audit trail of all file operations

**GDPR Compliance**:
- Don't log personally identifiable information in file paths
- Implement data retention policies
- Support data deletion requests (delete operation)
- Document data processing activities
- Ensure data residency requirements (region selection)

### File Permissions

**Configuration Files**:
```bash
# Automatically set by init command
chmod 0600 .fractary/plugins/file/config.json
chmod 0600 ~/.config/fractary/file/config.json
```

**Verification Check**:
```bash
# Plugin automatically checks on load
if [[ $(stat -c %a "$CONFIG_FILE") != "600" ]]; then
    echo "Warning: Config file permissions too open"
    echo "Run: chmod 0600 $CONFIG_FILE"
fi
```

## Integration Points

### With Other Plugins
- **fractary-docs**: Will use file plugin for large doc storage (future)
- **fractary-spec**: Will use file plugin for spec archival
- **fractary-logs**: Will use file plugin for log archival
- **fractary-codex**: Will use file plugin to read archived content

### With Configuration System
- Global config: `~/.config/fractary/file/config.json`
- Project config: `.fractary/plugins/file/config.json`
- Environment variables: Support ${VAR_NAME} syntax

## Testing Strategy

### Unit Tests
- Configuration loading and merging
- Handler selection logic
- Parameter validation
- Error handling paths

### Integration Tests
- R2 handler after refactor (ensure no regression)
- Configuration override behavior
- Handler routing with multiple configs
- Error messages for missing handlers

### Manual Testing
- Upload/download/delete operations with R2
- Configuration switching between handlers
- Invalid configuration handling
- Missing credential handling

## Success Criteria

- [ ] R2 handler works exactly as before (no regression)
- [ ] Handler pattern implemented with clear separation
- [ ] Configuration loading works (global, project, defaults)
- [ ] Agent successfully routes to handlers
- [ ] All 5 handlers have directory structure created
- [ ] Documentation updated to reflect new architecture
- [ ] Existing R2 users can migrate without breaking changes

## Open Questions

1. Should we support multiple handlers active simultaneously for different operations?
   - **Decision**: No, one active handler per project. Users switch via config.

2. Should we support handler aliases (e.g., "production" → "s3", "dev" → "local")?
   - **Decision**: Defer to Phase 2, keep simple for now.

3. How do we handle handler-specific options that don't fit the standard interface?
   - **Decision**: Use "options" object in parameters, handler-specific.

4. Should we support handler fallback (if primary fails, try secondary)?
   - **Decision**: Defer to future enhancement.

## Implementation Checklist

- [ ] Create directory structure for all handlers
- [ ] Move R2 scripts to handler-storage-r2/scripts/
- [ ] Create SKILL.md for handler-storage-r2
- [ ] Update file-manager skill with routing logic
- [ ] Update file-manager agent with config loading
- [ ] Create workflow files (route-operation, validate-config)
- [ ] Create config.example.json
- [ ] Update plugin README.md
- [ ] Create handler development guide
- [ ] Test R2 handler functionality
- [ ] Document migration path for existing users
- [ ] Create placeholder structure for other handlers

## Timeline

**Estimated Duration**: 1 week

**Breakdown**:
- Days 1-2: Create handler structure, move R2 code
- Days 3-4: Update agent and skill routing logic
- Day 5: Configuration and documentation
- Days 6-7: Testing and validation

## Dependencies

None - this is the foundation for all other phases.

## Next Steps

After this spec is implemented, proceed to:
- **SPEC-0029-02**: Implement all handler operations (upload, download, delete, list, get-url, read)
- **SPEC-0029-03**: Create /fractary-file:init command and configuration wizard
