# Fractary File Plugin

Multi-provider file storage plugin with unified interface across Local, R2, S3, GCS, and Google Drive.

## Overview

The `fractary-file` plugin provides a unified interface for file storage operations across multiple storage providers. It uses a **handler pattern** architecture to support different storage backends while maintaining a consistent API.

### Key Features

- **5 Storage Providers**: Local filesystem, Cloudflare R2, AWS S3, Google Cloud Storage, Google Drive
- **Multiple Handlers Simultaneously**: Configure multiple storage providers and choose per-operation
- **6 Core Operations**: Upload, download, delete, list, get-url, read
- **Handler Pattern**: Easy to add new storage providers
- **Configuration-Driven**: Switch providers via configuration without code changes
- **Per-Operation Override**: Route specific files to specific storage locations
- **Environment Variables**: Secure credential management
- **Zero-Config Default**: Local handler works out of the box
- **IAM Role Support**: S3 and GCS work without credentials
- **OAuth2 Integration**: Google Drive with automatic token refresh

## Storage Providers

| Provider | Status | Auth Method | CLI Tool | Operations |
|----------|--------|-------------|----------|------------|
| **Local Filesystem** | ✅ Complete | None | Native bash | 6/6 |
| **Cloudflare R2** | ✅ Complete | API Key | rclone/aws | 6/6 |
| **AWS S3** | ✅ Complete | IAM Roles/Keys | aws cli | 6/6 |
| **Google Cloud Storage** | ✅ Complete | ADC/SA Key | gcloud | 6/6 |
| **Google Drive** | ✅ Complete | OAuth2 | rclone | 6/6 |

## Quick Start

### 1. Default (Local Storage) - Zero Configuration

No configuration needed! Works immediately with local filesystem:

```bash
# Files stored in ./storage/ by default
Use the @agent-fractary-file:file-manager agent to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./document.pdf",
    "remote_path": "docs/document.pdf"
  }
}
```

**Perfect for**: Development, testing, temporary files

### 2. Single Cloud Storage Provider

Configure one cloud provider as your default storage:

1. **Run init wizard**:
```bash
/fractary-file:init --handlers s3
```

2. **Set environment variables**:
```bash
# For S3 (or use IAM roles)
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

3. **Use immediately**:
```bash
Use the @agent-fractary-file:file-manager agent:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "folder/file.txt"
  }
}
# → Uploads to S3
```

**Perfect for**: Production deployments with single storage backend

### 3. Multiple Storage Providers (Advanced)

Configure multiple providers and route different files to different locations.

**Use Cases**:
- Local for working files, S3 for backups
- R2 for public CDN content, S3 for archival
- GCS for Google services integration, local for dev

1. **Initialize with multiple handlers**:
```bash
# Interactive setup for multiple providers
/fractary-file:init

# Or specify handlers directly
/fractary-file:init --handlers local,s3,r2
```

2. **Use default handler** (configured as `active_handler`):
```bash
Use the @agent-fractary-file:file-manager agent:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./document.pdf",
    "remote_path": "docs/document.pdf"
  }
}
# → Uses active_handler (e.g., local)
```

3. **Override to specific handler** for specific files:
```bash
# Store backups on S3
{
  "operation": "upload",
  "parameters": {
    "local_path": "./backup.tar.gz",
    "remote_path": "backups/2025-01-15.tar.gz"
  },
  "handler_override": "s3"
}

# Store specs on R2 for global CDN
{
  "operation": "upload",
  "parameters": {
    "local_path": "./spec-123.md",
    "remote_path": "specs/spec-123.md"
  },
  "handler_override": "r2"
}
```

**Perfect for**: Complex workflows needing different storage for different file types

## Migrating from Single to Multi-Handler

Already have a config with one handler? You can add more without reconfiguring:

**Option 1: Re-run Init with Multiple Handlers**
```bash
# This will prompt to overwrite existing config
/fractary-file:init --handlers local,s3,r2
```

**Option 2: Manually Edit Config**
```bash
# Edit your existing config
vim .fractary/plugins/file/config.json

# Add new handlers to the "handlers" object:
{
  "active_handler": "s3",
  "handlers": {
    "s3": { /* your existing S3 config */ },
    "r2": { /* add R2 config */ },
    "local": { /* add local config */ }
  }
}
```

**Option 3: Keep Existing Config, Override When Needed**
- Don't change config at all
- Use `handler_override` in requests to route specific files elsewhere
- Great for gradual migration or occasional use

**Backwards Compatibility**:
- Existing single-handler configs work unchanged
- `--handler` flag still works (converted to `--handlers` internally)
- No breaking changes

## Architecture

The plugin uses a **three-layer architecture** for context efficiency and maintainability:

```
┌─────────────────────────────────────┐
│  Layer 1: file-manager Agent       │  ← Decision logic, validation
│  (agents/file-manager.md)          │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Layer 2: file-manager Skill        │  ← Handler routing, config loading
│  (skills/file-manager/SKILL.md)    │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Layer 3: Handler Skills            │  ← Provider-specific operations
│  (skills/handler-storage-*)        │
│  - handler-storage-local            │
│  - handler-storage-r2               │
│  - handler-storage-s3               │
│  - handler-storage-gcs              │
│  - handler-storage-gdrive           │
└──────────────┬──────────────────────┘
               │
               ▼
┌─────────────────────────────────────┐
│  Scripts (Pure Execution)           │  ← NOT in LLM context
│  (skills/handler-storage-*/scripts)│
│  - upload.sh, download.sh, etc.     │
└─────────────────────────────────────┘
```

**Benefits**:
- **55-60% context reduction** (scripts outside LLM context)
- **Easy to extend** (add new handler = add new skill + scripts)
- **Clear separation** of concerns (routing vs execution)
- **Independent handlers** (providers don't affect each other)

## Operations

All handlers implement these 6 operations:

### 1. Upload

Upload a file to storage.

```json
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "folder/file.txt",
    "public": false
  }
}
```

**Returns**: URL, size, checksum

### 2. Download

Download a file from storage.

```json
{
  "operation": "download",
  "parameters": {
    "remote_path": "folder/file.txt",
    "local_path": "./downloaded-file.txt"
  }
}
```

**Returns**: Local path, size, checksum

### 3. Delete

Delete a file from storage.

```json
{
  "operation": "delete",
  "parameters": {
    "remote_path": "folder/file.txt"
  }
}
```

**Returns**: Confirmation

### 4. List

List files in storage.

```json
{
  "operation": "list",
  "parameters": {
    "prefix": "folder/",
    "max_results": 100
  }
}
```

**Returns**: Array of file metadata (path, size, modified_at)

### 5. Get URL

Generate an accessible URL for a file.

```json
{
  "operation": "get-url",
  "parameters": {
    "remote_path": "folder/file.txt",
    "expires_in": 3600
  }
}
```

**Returns**: URL (public or presigned), expiration

### 6. Read

Stream file contents without downloading (NEW).

```json
{
  "operation": "read",
  "parameters": {
    "remote_path": "folder/file.txt",
    "max_bytes": 10485760
  }
}
```

**Returns**: File contents to stdout (truncated if > max_bytes)

**Use Cases**: Read archived specs, logs, configs without downloading.
**Limits**: Default 10MB, max 50MB. Files larger should be downloaded.

## Configuration

Configuration is stored in `.fractary/plugins/file/config.json`.

**Multi-Handler Support**: You can configure multiple storage providers in a single configuration file. Set `active_handler` to your default, and override per-operation as needed.

### Configuration File Location (Priority Order)

1. **Project config**: `.fractary/plugins/file/config.json` (highest priority)
2. **Global config**: `~/.config/fractary/file/config.json` (fallback)
3. **Default**: Local handler with `./storage` base path

### Configuration Schema

```json
{
  "schema_version": "1.0",
  "active_handler": "local",
  "handlers": {
    "local": { /* local config */ },
    "r2": { /* r2 config */ },
    "s3": { /* s3 config */ },
    "gcs": { /* gcs config */ },
    "gdrive": { /* gdrive config */ }
  },
  "global_settings": {
    "retry_attempts": 3,
    "retry_delay_ms": 1000,
    "timeout_seconds": 300,
    "verify_checksums": true
  }
}
```

**Example: Multi-Handler Configuration**

Configure local for working files and S3 for backups:

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
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-backups",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
    }
  }
}
```

Now you can use `local` by default, and override to `s3` for specific files.

### Handler Configurations

#### Local Filesystem

**Zero configuration needed!** Works with defaults.

```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "./storage",
      "create_directories": true,
      "permissions": "0755"
    }
  }
}
```

**Features**:
- No credentials needed
- Works offline
- Fast operations
- Good for development/testing

**Guide**: `skills/handler-storage-local/docs/local-storage-guide.md`

#### Cloudflare R2

```json
{
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-bucket",
      "public_url": "https://pub-xxxxx.r2.dev",
      "region": "auto"
    }
  }
}
```

**Features**:
- S3-compatible API
- No egress fees
- Public and presigned URLs
- Global distribution

**Requirements**: AWS CLI configured for R2, R2 API credentials

#### AWS S3

**With IAM Roles** (Recommended for EC2/ECS/EKS):
```json
{
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket"
    }
  }
}
```

**With Credentials**:
```json
{
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-bucket",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
    }
  }
}
```

**Features**:
- IAM role support (no credentials needed)
- S3-compatible services (MinIO, etc.)
- Public and presigned URLs
- Extensive ecosystem

**Requirements**: AWS CLI, optional IAM role or credentials

**IAM Policy Required**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject", "s3:ListBucket"],
    "Resource": ["arn:aws:s3:::my-bucket", "arn:aws:s3:::my-bucket/*"]
  }]
}
```

#### Google Cloud Storage

**With Application Default Credentials** (Recommended for GCE/GKE):
```json
{
  "active_handler": "gcs",
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      "region": "us-central1"
    }
  }
}
```

**With Service Account Key**:
```json
{
  "active_handler": "gcs",
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      "service_account_key": "${GOOGLE_APPLICATION_CREDENTIALS}",
      "region": "us-central1"
    }
  }
}
```

**Features**:
- Application Default Credentials support
- Workload Identity for GKE
- Signed URLs
- Regional/multi-regional storage

**Requirements**: gcloud CLI, optional service account key

**IAM Roles Required**:
- `roles/storage.objectCreator` - Upload
- `roles/storage.objectViewer` - Download/read
- `roles/storage.objectAdmin` - Full access

#### Google Drive

```json
{
  "active_handler": "gdrive",
  "handlers": {
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "folder_id": "root",
      "rclone_remote_name": "gdrive"
    }
  }
}
```

**Features**:
- OAuth2 authentication
- Automatic token refresh
- Shareable links
- Folder organization
- 15GB free storage

**Requirements**: rclone with OAuth2 setup

**Setup Guide**: `skills/handler-storage-gdrive/docs/oauth-setup-guide.md` (**REQUIRED READING**)

**Quick Setup**:
1. Install rclone: `brew install rclone`
2. Create OAuth credentials in Google Cloud Console
3. Run `rclone config` for interactive OAuth flow
4. Configure fractary-file with client ID/secret

## Usage Examples

### Agent Invocation (Declarative)

```
Use the @agent-fractary-file:file-manager agent to upload specification:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./spec-123.md",
    "remote_path": "specs/2025/01/spec-123.md",
    "public": false
  }
}
```

### Multiple Operations

```
# Upload file
Use @agent-fractary-file:file-manager to upload:
{ "operation": "upload", "parameters": {"local_path": "./doc.pdf", "remote_path": "docs/doc.pdf"} }

# List files
Use @agent-fractary-file:file-manager to list:
{ "operation": "list", "parameters": {"prefix": "docs/", "max_results": 50} }

# Get URL
Use @agent-fractary-file:file-manager to get URL:
{ "operation": "get-url", "parameters": {"remote_path": "docs/doc.pdf", "expires_in": 7200} }

# Read file
Use @agent-fractary-file:file-manager to read:
{ "operation": "read", "parameters": {"remote_path": "docs/config.json", "max_bytes": 1048576} }
```

### Handler Override

Use a specific handler for one operation:

```json
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "backup/file.txt"
  },
  "handler_override": "s3"
}
```

## Security

### Credentials

**Best Practices** (in order of preference):

1. **Cloud Provider IAM Roles** (Best)
   - AWS: EC2 instance profiles, ECS task roles
   - GCP: Workload Identity, ADC
   - No credentials in config
   - Automatic rotation

2. **Environment Variables** (Good)
   - Store in environment, reference in config
   - Never commit actual values
   - Use secrets management (AWS Secrets Manager, etc.)

3. **Config Files with Restricted Permissions** (Acceptable)
   - Permissions: `chmod 0600`
   - Outside version control
   - Encrypted at rest

4. **Hardcoded** (Never - Development Only)
   - Only for local testing
   - Never commit

### File Permissions

```bash
# Automatically set by plugin
chmod 0600 .fractary/plugins/file/config.json
chmod 0600 ~/.config/fractary/file/config.json
```

### Path Security

- Path traversal prevention (`..` blocked)
- Validation before operations
- Audit logging available

### Credential Rotation

- **IAM Roles**: Automatic (hourly)
- **API Tokens**: Every 90 days recommended
- **OAuth Tokens**: Automatic refresh via rclone

## Integration

### With FABER Plugins

Used by fractary-faber workflows:
- **fractary-spec**: Archive specifications
- **fractary-logs**: Archive session logs
- **fractary-docs**: Store documentation
- **fractary-faber**: Workflow artifacts

### With Codex

The fractary-codex plugin can read archived content via the `read` operation without downloading.

## Directory Structure

```
plugins/file/
├── .claude-plugin/
│   └── plugin.json               # Plugin manifest
├── agents/
│   └── file-manager.md           # Orchestration agent (Layer 1)
├── commands/
│   └── (future: init, show-config, test-connection)
├── config/
│   └── config.example.json       # Configuration template
├── skills/
│   ├── common/
│   │   └── functions.sh          # Shared utilities (19 functions)
│   ├── file-manager/             # Routing skill (Layer 2)
│   │   ├── SKILL.md
│   │   ├── workflow/
│   │   │   ├── route-operation.md      # 9-step routing process
│   │   │   └── validate-config.md      # 8-step validation
│   │   └── docs/
│   ├── handler-storage-local/    # Local filesystem handler
│   │   ├── SKILL.md
│   │   ├── scripts/              # 6 operations
│   │   └── docs/
│   ├── handler-storage-r2/       # Cloudflare R2 handler
│   │   ├── SKILL.md
│   │   ├── scripts/              # 6 operations
│   │   └── docs/
│   ├── handler-storage-s3/       # AWS S3 handler
│   │   ├── SKILL.md
│   │   ├── scripts/              # 6 operations
│   │   └── docs/
│   ├── handler-storage-gcs/      # Google Cloud Storage handler
│   │   ├── SKILL.md
│   │   ├── scripts/              # 6 operations
│   │   └── docs/
│   └── handler-storage-gdrive/   # Google Drive handler
│       ├── SKILL.md
│       ├── scripts/              # 6 operations
│       └── docs/
│           └── oauth-setup-guide.md    # Comprehensive OAuth guide
└── README.md                     # This file
```

## Adding New Handlers

To add a new storage provider:

1. **Create handler directory**:
   ```bash
   mkdir -p plugins/file/skills/handler-storage-{provider}/{scripts,docs}
   ```

2. **Create SKILL.md** with handler metadata

3. **Implement 6 operation scripts**:
   - `upload.sh`
   - `download.sh`
   - `delete.sh`
   - `list.sh`
   - `get-url.sh`
   - `read.sh`

4. **Follow the pattern**:
   - Pure execution (no config loading in scripts)
   - All parameters passed from skill
   - Return structured JSON
   - Cross-platform compatible

5. **Add documentation**:
   - Setup guide in `docs/`
   - Configuration examples
   - Authentication instructions

6. **Update routing**: Add handler case to `skills/file-manager/workflow/route-operation.md`

See existing handlers for reference.

## Troubleshooting

### Configuration Not Found

**Error**: No configuration file found, using defaults

**Solution**: Configuration is optional! Local handler works with defaults. To configure:
```bash
cp plugins/file/config/config.example.json .fractary/plugins/file/config.json
```

### Handler Not Configured

**Error**: Handler 'r2' is not configured

**Solution**: Add handler configuration to config.json and set environment variables:
```bash
export R2_ACCOUNT_ID="..."
export R2_ACCESS_KEY_ID="..."
export R2_SECRET_ACCESS_KEY="..."
```

### Environment Variable Not Set

**Error**: R2 access_key_id references undefined environment variable: R2_ACCESS_KEY_ID

**Solution**: Set the environment variable:
```bash
export R2_ACCESS_KEY_ID="your-access-key"
```

### Permission Denied

**Error**: Config file permissions too open (644)

**Solution**: Set secure permissions:
```bash
chmod 0600 .fractary/plugins/file/config.json
```

### rclone Not Found (Google Drive)

**Error**: rclone not found

**Solution**: Install rclone:
```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash
```

### OAuth Token Expired (Google Drive)

**Error**: Token expired and refresh not working

**Solution**: Reconnect rclone:
```bash
rclone config reconnect gdrive:
```

## Performance

### Context Efficiency

- **Agent**: ~300 lines in context
- **Skill**: ~200 lines in context
- **Scripts**: 0 lines in context (executed outside LLM)
- **Total**: ~500 lines vs ~1200 lines (traditional approach)
- **Savings**: ~58% context reduction

### Operation Performance

- **Local**: Instant (filesystem speed)
- **Cloud**: Network-dependent
  - Upload/Download: Limited by bandwidth
  - List: Fast (<1s for hundreds of files)
  - Delete: Fast (<1s)
  - Get URL: Instant (generates locally)

### Retry Logic

All cloud handlers implement retry with exponential backoff:
- Attempts: 3 (configurable)
- Initial delay: 1s
- Backoff: Exponential (1s, 2s, 4s)

## Dependencies

### Core

- **bash** 4.0+
- **jq** (JSON processing)
- **envsubst** (environment variable expansion)

### Per Handler

| Handler | CLI Tool | Version | Install |
|---------|----------|---------|---------|
| Local   | Native bash | Any | Built-in |
| R2      | aws cli | 2.0+ | https://aws.amazon.com/cli/ |
| S3      | aws cli | 2.0+ | https://aws.amazon.com/cli/ |
| GCS     | gcloud  | Latest | https://cloud.google.com/sdk |
| Google Drive | rclone | 1.50+ | https://rclone.org/install/ |

## Testing

Test a handler:

```bash
# Test local handler (no setup needed)
echo "test content" > test.txt
Use @agent-fractary-file:file-manager to upload:
{ "operation": "upload", "parameters": {"local_path": "./test.txt", "remote_path": "test/test.txt"} }

Use @agent-fractary-file:file-manager to list:
{ "operation": "list", "parameters": {"prefix": "test/"} }

Use @agent-fractary-file:file-manager to read:
{ "operation": "read", "parameters": {"remote_path": "test/test.txt"} }

Use @agent-fractary-file:file-manager to delete:
{ "operation": "delete", "parameters": {"remote_path": "test/test.txt"} }
```

## Status

**Current Version**: 2.0.0

**Implementation Status**:
- ✅ SPEC-00029-01 (Architecture): 100% Complete
- ✅ SPEC-00029-02 (Handlers): 100% Complete
- ⏸️ SPEC-00029-03 (Init Command): Deferred (manual setup documented)

**All Core Features Complete!**

## Documentation

- **Configuration Example**: `config/config.example.json`
- **Common Functions**: `skills/common/functions.sh`
- **Routing Logic**: `skills/file-manager/workflow/route-operation.md`
- **Validation**: `skills/file-manager/workflow/validate-config.md`
- **Local Guide**: `skills/handler-storage-local/docs/local-storage-guide.md`
- **Google Drive OAuth**: `skills/handler-storage-gdrive/docs/oauth-setup-guide.md`

## Support

For issues or questions:
1. Check troubleshooting section above
2. Review handler-specific documentation
3. Check specifications in `specs/SPEC-00029-*.md`
4. Report issues on GitHub

## License

Part of the Fractary plugin ecosystem.

## Changelog

### v2.0.0 (2025-01-15)

**Major Rewrite** - Handler pattern architecture

- ✅ Implemented handler pattern for multi-provider support
- ✅ All 5 handlers complete: local, R2, S3, GCS, Google Drive
- ✅ All 6 operations on all handlers
- ✅ New `read` operation for streaming file contents
- ✅ Configuration system with fallback chain
- ✅ Environment variable support
- ✅ IAM role support (S3, GCS)
- ✅ OAuth2 integration (Google Drive)
- ✅ Comprehensive documentation
- ✅ 58% context reduction

### v1.0.0 (2024-XX-XX)

Initial release
- Basic R2 support only
- Monolithic architecture
