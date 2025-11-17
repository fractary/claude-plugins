# Fractary File Plugin - Comprehensive Guide

Complete guide to using the fractary-file plugin for multi-provider cloud storage in your FABER workflows.

## Table of Contents

1. [Overview](#overview)
2. [Quick Start](#quick-start)
3. [Storage Providers](#storage-providers)
4. [Operations](#operations)
5. [Configuration](#configuration)
6. [Integration](#integration)
7. [Advanced Topics](#advanced-topics)
8. [Troubleshooting](#troubleshooting)

## Overview

The fractary-file plugin provides a unified interface for file storage operations across multiple cloud providers. It abstracts provider-specific details while offering flexibility and performance.

### Key Concepts

**Handler Pattern**: Each storage provider has a dedicated handler skill that implements the same 6 operations. The file-manager agent routes requests to the appropriate handler based on configuration.

**Zero-Config Default**: Works immediately with local filesystem storage. No configuration needed for development.

**Provider Abstraction**: Switch providers by changing configuration, not code. Your workflows remain the same.

**Security First**: Support for IAM roles, environment variables, secure credentials, and path validation.

### When to Use

- **Archive old specs**: Remove clutter from local workspace
- **Store build artifacts**: Keep binaries out of git
- **Backup configurations**: Preserve historical configs
- **Share files**: Generate accessible URLs
- **Read archived content**: Access without downloading

### When Not to Use

- **Living documentation**: Use fractary-docs instead
- **Active specifications**: Keep in /specs until archived
- **Source code**: Belongs in git
- **Secrets**: Use secrets management (Vault, etc.)

## Quick Start

### 1. Default Setup (Local)

No configuration needed! Start using immediately:

```
Use the @agent-fractary-file:file-manager agent to upload a file:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

Files stored in `./storage` by default.

### 2. Cloud Setup (5 minutes)

#### Step 1: Choose Provider

| Provider | Best For | Cost | Setup Complexity |
|----------|----------|------|------------------|
| **Local** | Development, testing | Free | None |
| **R2** | Production, cost-sensitive | Lowest | Easy |
| **S3** | AWS ecosystem | Medium | Easy |
| **GCS** | Google Cloud ecosystem | Medium | Medium |
| **Google Drive** | Personal projects | Free (15GB) | Medium (OAuth) |

#### Step 2: Create Configuration

```bash
# Create config directory
mkdir -p .fractary/plugins/file

# Copy example config
cp plugins/file/config/config.example.json .fractary/plugins/file/config.json

# Secure permissions
chmod 0600 .fractary/plugins/file/config.json
```

#### Step 3: Configure Provider

Edit `.fractary/plugins/file/config.json`:

```json
{
  "schema_version": "1.0",
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-project-archive",
      "public_url": "https://pub-xxxxx.r2.dev"
    }
  }
}
```

#### Step 4: Set Environment Variables

```bash
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
```

#### Step 5: Test

```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./test.txt",
    "remote_path": "test/test.txt"
  }
}
```

## Storage Providers

### Local Filesystem

**Best for**: Development, testing, offline work

**Setup**: None required

**Features**:
- ✓ Zero configuration
- ✓ Works offline
- ✓ Fast operations
- ✓ No costs
- ⚠️ No redundancy
- ⚠️ Machine-specific

**Configuration**:
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

**Use cases**:
- Local development
- Testing workflows
- Offline work
- Privacy-sensitive content

---

### Cloudflare R2

**Best for**: Production, cost-sensitive projects

**Setup complexity**: ⭐⭐☆☆☆ (Easy)

**Features**:
- ✓ S3-compatible API
- ✓ Zero egress fees
- ✓ Global CDN
- ✓ Public URLs
- ✓ Low cost ($0.015/GB/month)

**Setup Steps**:

1. **Create R2 Bucket** (Cloudflare Dashboard):
   - Go to R2 in Cloudflare Dashboard
   - Create bucket (e.g., "my-project-archive")
   - Note bucket name

2. **Generate API Token**:
   - Go to R2 API Tokens
   - Create token with Read + Write permissions
   - Note Account ID, Access Key, Secret Key

3. **Configure Public Access** (optional):
   - Enable public bucket URL
   - Note public URL (e.g., `https://pub-xxxxx.r2.dev`)

4. **Configure Plugin**:
```json
{
  "active_handler": "r2",
  "handlers": {
    "r2": {
      "account_id": "${R2_ACCOUNT_ID}",
      "access_key_id": "${R2_ACCESS_KEY_ID}",
      "secret_access_key": "${R2_SECRET_ACCESS_KEY}",
      "bucket_name": "my-project-archive",
      "public_url": "https://pub-xxxxx.r2.dev",
      "region": "auto"
    }
  }
}
```

5. **Set Environment Variables**:
```bash
export R2_ACCOUNT_ID="your-account-id"
export R2_ACCESS_KEY_ID="your-access-key"
export R2_SECRET_ACCESS_KEY="your-secret-key"
```

**Cost Example**:
- 10 GB storage: $0.15/month
- 1 million operations: $4.50/month
- Egress: $0 (free!)

---

### AWS S3

**Best for**: AWS ecosystem, enterprise projects

**Setup complexity**: ⭐⭐☆☆☆ (Easy with IAM) | ⭐⭐⭐☆☆ (Medium with keys)

**Features**:
- ✓ IAM role support (no credentials!)
- ✓ Extensive ecosystem
- ✓ Versioning, lifecycle policies
- ✓ Cross-region replication
- ⚠️ Egress fees

**Setup with IAM Roles** (Recommended for EC2/ECS/EKS):

1. **Create S3 Bucket** (AWS Console/CLI):
```bash
aws s3 mb s3://my-project-archive --region us-east-1
```

2. **Create IAM Policy**:
```json
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Action": [
      "s3:PutObject",
      "s3:GetObject",
      "s3:DeleteObject",
      "s3:ListBucket"
    ],
    "Resource": [
      "arn:aws:s3:::my-project-archive",
      "arn:aws:s3:::my-project-archive/*"
    ]
  }]
}
```

3. **Attach Policy to IAM Role** (EC2 instance profile / ECS task role)

4. **Configure Plugin** (No credentials needed!):
```json
{
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-project-archive"
    }
  }
}
```

**Setup with Access Keys**:

1. **Create IAM User** with policy above

2. **Generate Access Keys**

3. **Configure Plugin**:
```json
{
  "active_handler": "s3",
  "handlers": {
    "s3": {
      "region": "us-east-1",
      "bucket_name": "my-project-archive",
      "access_key_id": "${AWS_ACCESS_KEY_ID}",
      "secret_access_key": "${AWS_SECRET_ACCESS_KEY}"
    }
  }
}
```

4. **Set Environment Variables**:
```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
```

---

### Google Cloud Storage

**Best for**: Google Cloud ecosystem

**Setup complexity**: ⭐⭐⭐☆☆ (Medium)

**Features**:
- ✓ Workload Identity (GKE)
- ✓ Application Default Credentials
- ✓ Multi-regional storage
- ✓ Lifecycle management

**Setup with Application Default Credentials** (Recommended for GCE/GKE):

1. **Create GCS Bucket**:
```bash
gsutil mb -l us-central1 gs://my-project-archive
```

2. **Grant Permissions** (to service account):
```bash
gsutil iam ch \
  serviceAccount:my-sa@my-project.iam.gserviceaccount.com:roles/storage.objectAdmin \
  gs://my-project-archive
```

3. **Configure Plugin**:
```json
{
  "active_handler": "gcs",
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-project-archive",
      "region": "us-central1"
    }
  }
}
```

**Setup with Service Account Key**:

1. Create service account with Storage Object Admin role

2. Generate JSON key file

3. **Configure Plugin**:
```json
{
  "active_handler": "gcs",
  "handlers": {
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-project-archive",
      "service_account_key": "${GOOGLE_APPLICATION_CREDENTIALS}",
      "region": "us-central1"
    }
  }
}
```

4. **Set Environment Variable**:
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/service-account-key.json"
```

---

### Google Drive

**Best for**: Personal projects, small teams

**Setup complexity**: ⭐⭐⭐⭐☆ (Complex - OAuth setup)

**Features**:
- ✓ Free 15GB storage
- ✓ Familiar interface
- ✓ Easy sharing
- ⚠️ OAuth complexity
- ⚠️ Slower than object storage

**Setup** (See `plugins/file/skills/handler-storage-gdrive/docs/oauth-setup-guide.md`):

1. **Create OAuth Credentials** (Google Cloud Console)
2. **Install rclone**: `brew install rclone`
3. **Configure rclone**: `rclone config` (interactive OAuth)
4. **Configure Plugin**:
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

**Note**: OAuth setup is complex but only needed once. See detailed guide in plugin.

## Operations

### Upload

Store a local file in cloud storage.

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./report.pdf",
    "remote_path": "reports/2025/01/report.pdf",
    "public": false
  }
}
```

**Parameters**:
- `local_path` (required): Path to local file
- `remote_path` (required): Destination path in storage
- `public` (optional): Make file publicly accessible (default: false)

**Returns**:
```json
{
  "url": "https://storage.example.com/reports/2025/01/report.pdf",
  "size_bytes": 1048576,
  "checksum": "sha256:abc123...",
  "uploaded_at": "2025-01-15T10:30:00Z"
}
```

**Use cases**:
- Archive completed specs
- Store build artifacts
- Backup configurations
- Upload reports

---

### Download

Retrieve a file from cloud storage to local filesystem.

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to download:
{
  "operation": "download",
  "parameters": {
    "remote_path": "reports/2025/01/report.pdf",
    "local_path": "./downloaded-report.pdf"
  }
}
```

**Parameters**:
- `remote_path` (required): Path in storage
- `local_path` (required): Destination path locally

**Returns**:
```json
{
  "local_path": "./downloaded-report.pdf",
  "size_bytes": 1048576,
  "checksum": "sha256:abc123..."
}
```

**Use cases**:
- Restore archived content
- Access old artifacts
- Review historical specs

---

### Read

Stream file contents without downloading (NEW in v2.0).

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to read:
{
  "operation": "read",
  "parameters": {
    "remote_path": "specs/2024/spec-123.md",
    "max_bytes": 10485760
  }
}
```

**Parameters**:
- `remote_path` (required): Path in storage
- `max_bytes` (optional): Maximum bytes to read (default: 10MB, max: 50MB)

**Returns**: File contents to stdout (truncated if exceeds max_bytes)

**Use cases**:
- Read archived specs without downloading
- Preview large files
- Extract specific content
- Search archived files

**Limits**:
- Default: 10MB
- Maximum: 50MB
- Files larger should use `download` operation

---

### Delete

Remove a file from storage.

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to delete:
{
  "operation": "delete",
  "parameters": {
    "remote_path": "temporary/old-file.txt"
  }
}
```

**Parameters**:
- `remote_path` (required): Path to delete

**Returns**: Confirmation message

**Use cases**:
- Clean up temporary files
- Remove outdated content
- Free storage space

**Warning**: Deletion is permanent! Ensure file is backed up if needed.

---

### List

List files in storage with optional filtering.

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "specs/2025/",
    "max_results": 100
  }
}
```

**Parameters**:
- `prefix` (optional): Filter by path prefix
- `max_results` (optional): Limit results (default: 100)

**Returns**:
```json
{
  "files": [
    {
      "path": "specs/2025/01/spec-123.md",
      "size_bytes": 45678,
      "modified_at": "2025-01-15T10:30:00Z"
    },
    ...
  ],
  "count": 42
}
```

**Use cases**:
- Browse archived content
- Verify uploads
- Audit storage usage
- Build file indexes

---

### Get URL

Generate an accessible URL for a file.

**Agent Invocation**:
```
Use @agent-fractary-file:file-manager to get URL:
{
  "operation": "get-url",
  "parameters": {
    "remote_path": "reports/report.pdf",
    "expires_in": 3600
  }
}
```

**Parameters**:
- `remote_path` (required): Path in storage
- `expires_in` (optional): URL expiration in seconds (default: 3600)

**Returns**:
```json
{
  "url": "https://storage.example.com/reports/report.pdf?signature=...",
  "expires_at": "2025-01-15T11:30:00Z",
  "public": false
}
```

**URL Types**:
- **Public**: Permanent URL if file uploaded with `public: true`
- **Presigned**: Temporary URL with expiration for private files

**Use cases**:
- Share reports
- Link in GitHub comments
- Embed in documentation
- Provide download links

## Configuration

### Configuration File Location

**Priority order** (first found wins):

1. **Project**: `.fractary/plugins/file/config.json` (highest priority)
2. **Global**: `~/.config/fractary/file/config.json`
3. **Default**: Local handler with `./storage`

### Complete Configuration Schema

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
      "endpoint": null
    },
    "gcs": {
      "project_id": "my-project",
      "bucket_name": "my-bucket",
      "service_account_key": "${GOOGLE_APPLICATION_CREDENTIALS}",
      "region": "us-central1"
    },
    "gdrive": {
      "client_id": "${GDRIVE_CLIENT_ID}",
      "client_secret": "${GDRIVE_CLIENT_SECRET}",
      "folder_id": "root",
      "rclone_remote_name": "gdrive"
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

### Environment Variables

**R2**:
- `R2_ACCOUNT_ID`
- `R2_ACCESS_KEY_ID`
- `R2_SECRET_ACCESS_KEY`

**S3**:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_REGION` (optional, overrides config)

**GCS**:
- `GOOGLE_APPLICATION_CREDENTIALS` (path to JSON key)

**Google Drive**:
- `GDRIVE_CLIENT_ID`
- `GDRIVE_CLIENT_SECRET`

### Handler Override

Use specific handler for one operation (overrides active_handler):

```
Use @agent-fractary-file:file-manager to upload using S3:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./file.txt",
    "remote_path": "backup/file.txt"
  },
  "handler_override": "s3"
}
```

**Use cases**:
- Backup to multiple providers
- Testing different providers
- Provider-specific operations

## Integration

### With fractary-spec

Specs use file plugin for archival:

```
# Spec plugin internally calls:
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "/specs/spec-123.md",
    "remote_path": "archive/specs/2025/123.md"
  }
}
```

You don't call this directly - spec plugin handles it.

### With fractary-logs

Logs use file plugin for archival:

```
# Logs plugin internally calls:
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "/logs/session-123.md.gz",
    "remote_path": "archive/logs/2025/01/123.md.gz"
  }
}
```

You don't call this directly - logs plugin handles it.

### With FABER Workflows

File plugin is a dependency but typically used indirectly via spec and logs plugins.

Direct usage example (custom artifact archival):

```markdown
<!-- In your custom FABER skill -->
<WORKFLOW>
1. Build completes, artifacts in ./dist
2. Use @agent-fractary-file:file-manager to upload:
   {
     "operation": "upload",
     "parameters": {
       "local_path": "./dist/app.tar.gz",
       "remote_path": "builds/2025/01/app-v1.2.3.tar.gz"
     }
   }
3. Artifact archived, local ./dist can be cleaned
</WORKFLOW>
```

## Advanced Topics

### Multi-Region Setup

Use different regions for different content:

```json
{
  "handlers": {
    "s3-us": {
      "region": "us-east-1",
      "bucket_name": "my-bucket-us"
    },
    "s3-eu": {
      "region": "eu-west-1",
      "bucket_name": "my-bucket-eu"
    }
  }
}
```

Use handler override per operation to choose region.

### Custom Endpoints

For S3-compatible services (MinIO, DigitalOcean Spaces):

```json
{
  "handlers": {
    "s3": {
      "endpoint": "https://nyc3.digitaloceanspaces.com",
      "region": "nyc3",
      "bucket_name": "my-spaces"
    }
  }
}
```

### Encryption

**Server-side** (recommended):
- Enable on bucket (S3, GCS)
- Transparent to client
- No config needed

**Client-side**:
- Encrypt before upload
- Use `gpg` or similar
- Decrypt after download

### Compression

For large files, compress before upload:

```bash
# Compress
gzip large-file.log

# Upload compressed
Use @agent-fractary-file:file-manager to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": "./large-file.log.gz",
    "remote_path": "logs/large-file.log.gz"
  }
}

# Later: read and decompress
Use @agent-fractary-file:file-manager to read:
{
  "operation": "read",
  "parameters": {
    "remote_path": "logs/large-file.log.gz"
  }
}

# Save to file and decompress
gunzip downloaded-file.log.gz
```

### Monitoring and Auditing

Track storage usage:

```
Use @agent-fractary-file:file-manager to list:
{
  "operation": "list",
  "parameters": {
    "prefix": "",
    "max_results": 10000
  }
}
```

Calculate total size from results.

**Cloud provider dashboards**:
- CloudFlare R2: Analytics tab
- AWS S3: CloudWatch metrics
- GCS: Cloud Console monitoring

## Troubleshooting

See [Troubleshooting Guide](./troubleshooting.md) for common issues across all plugins.

**File plugin specific**:

### Configuration not found

Use defaults (local handler). Create config if needed:
```bash
mkdir -p .fractary/plugins/file
cp plugins/file/config/config.example.json .fractary/plugins/file/config.json
```

### Handler not configured

Add handler to config.json and set environment variables.

### Permission denied on config file

```bash
chmod 0600 .fractary/plugins/file/config.json
```

### Upload fails with "access denied"

Check:
- Environment variables set correctly
- Cloud credentials valid
- IAM permissions sufficient
- Bucket exists

### rclone not found (Google Drive only)

```bash
# macOS
brew install rclone

# Linux
curl https://rclone.org/install.sh | sudo bash
```

## Best Practices

1. **Use IAM roles over keys** (S3, GCS)
2. **Secure config files** (chmod 0600)
3. **Environment variables for credentials** (never commit)
4. **Enable server-side encryption** (on bucket)
5. **Compress large files** before upload
6. **Use public URLs sparingly** (security)
7. **Monitor storage costs** regularly
8. **Test disaster recovery** periodically
9. **Document your setup** for team
10. **Rotate credentials** every 90 days

## Further Reading

- Plugin README: `plugins/file/README.md`
- Configuration example: `plugins/file/config/config.example.json`
- Handler docs: `plugins/file/skills/handler-storage-*/docs/`
- Specs: `specs/SPEC-00029-01.md`, `SPEC-00029-02.md`, `SPEC-00029-03.md`

---

**Version**: 1.0 (2025-01-15)
