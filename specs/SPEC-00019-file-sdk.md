# SPEC-00019: File Storage SDK

| Field | Value |
|-------|-------|
| **Status** | Draft |
| **Created** | 2025-12-11 |
| **Author** | Claude (with human direction) |
| **Related** | SPEC-00016-sdk-architecture, plugins/file/ |

## 1. Executive Summary

This specification details the **File Storage SDK** implementation within `@fractary/core`. It maps the file plugin's 6 core operations across 5 storage providers to SDK methods and CLI commands.

### 1.1 Scope

- Implementation of `FileStorage` interface (defined in SPEC-00016)
- Provider implementations: Local, S3, R2, GCS, Google Drive
- All operations: upload, download, read, delete, list, get-url
- CLI command mappings
- Plugin migration path

### 1.2 Current Plugin Summary

| Metric | Value |
|--------|-------|
| Skills | 2 (file-manager, config-wizard) |
| Commands | 4 |
| Handlers | 5 (Local, S3, R2, GCS, Google Drive) |
| Operations | 6 |

## 2. SDK Implementation

### 2.1 Module Structure

```
@fractary/core/
└── file/
    ├── types.ts              # FileStorage interface, data types
    ├── index.ts              # Public exports
    ├── registry.ts           # Provider registry
    ├── local.ts              # Local filesystem
    ├── s3.ts                 # AWS S3
    ├── r2.ts                 # Cloudflare R2
    ├── gcs.ts                # Google Cloud Storage
    └── gdrive.ts             # Google Drive
```

### 2.2 Provider Registry

```typescript
// file/registry.ts

import { FileStorage } from './types';
import { LocalFileStorage } from './local';
import { S3FileStorage } from './s3';
import { R2FileStorage } from './r2';
import { GCSFileStorage } from './gcs';
import { GoogleDriveFileStorage } from './gdrive';

export type FileStorageType = 'local' | 's3' | 'r2' | 'gcs' | 'gdrive';

export interface FileStorageConfig {
  provider: FileStorageType;
  local?: {
    basePath: string;
  };
  s3?: {
    bucket: string;
    region: string;
    accessKeyId: string;
    secretAccessKey: string;
    endpoint?: string;  // For S3-compatible services
  };
  r2?: {
    accountId: string;
    bucket: string;
    accessKeyId: string;
    secretAccessKey: string;
  };
  gcs?: {
    bucket: string;
    projectId: string;
    credentials: string;  // Path to credentials JSON or JSON string
  };
  gdrive?: {
    folderId: string;
    credentials: string;  // Path to credentials JSON or JSON string
  };
}

export function createFileStorage(config: FileStorageConfig): FileStorage {
  switch (config.provider) {
    case 'local':
      return new LocalFileStorage(config.local || { basePath: './storage' });
    case 's3':
      if (!config.s3) throw new ConfigurationError('S3 config required');
      return new S3FileStorage(config.s3);
    case 'r2':
      if (!config.r2) throw new ConfigurationError('R2 config required');
      return new R2FileStorage(config.r2);
    case 'gcs':
      if (!config.gcs) throw new ConfigurationError('GCS config required');
      return new GCSFileStorage(config.gcs);
    case 'gdrive':
      if (!config.gdrive) throw new ConfigurationError('Google Drive config required');
      return new GoogleDriveFileStorage(config.gdrive);
    default:
      throw new ConfigurationError(`Unknown provider: ${config.provider}`);
  }
}
```

## 3. Operation Mappings

### 3.1 Core Operations

| Plugin Operation | SDK Method | CLI Command |
|-----------------|------------|-------------|
| upload | `upload(localPath, remotePath, options?)` | `fractary file upload <local> <remote>` |
| download | `download(remotePath, localPath, options?)` | `fractary file download <remote> <local>` |
| read | `read(remotePath, options?)` | `fractary file read <remote>` |
| delete | `delete(remotePath)` | `fractary file delete <remote>` |
| list | `list(remotePath, options?)` | `fractary file list [path]` |
| get-url | `getUrl(remotePath, options?)` | `fractary file url <remote>` |

### 3.2 upload

**SDK Method**:
```typescript
async upload(
  localPath: string,
  remotePath: string,
  options?: UploadOptions
): Promise<UploadResult>
```

**CLI**:
```bash
fractary file upload <local-path> <remote-path> [options]

Options:
  --public               Make file publicly accessible
  --content-type <type>  Override content type
  --metadata <json>      JSON metadata to attach
  --json                 Output as JSON
```

**Implementation Notes**:
- Auto-detects content type from file extension
- Validates local file exists
- Path safety validation (no traversal)
- Returns URL for uploaded file

### 3.3 download

**SDK Method**:
```typescript
async download(
  remotePath: string,
  localPath: string,
  options?: DownloadOptions
): Promise<void>
```

**CLI**:
```bash
fractary file download <remote-path> <local-path> [options]

Options:
  --max-bytes <n>        Limit download size
  --force                Overwrite existing local file
```

**Implementation Notes**:
- Creates parent directories if needed
- Optional size limit
- Warns before overwriting existing files

### 3.4 read

**SDK Method**:
```typescript
async read(remotePath: string, options?: ReadOptions): Promise<string>
```

**CLI**:
```bash
fractary file read <remote-path> [options]

Options:
  --max-bytes <n>        Limit read size (default: 1MB)
  --encoding <enc>       Encoding: utf-8, base64 (default: utf-8)
```

**Implementation Notes**:
- Reads file content without downloading to disk
- Good for small files, configs, specs
- Size limit to prevent memory issues

### 3.5 delete

**SDK Method**:
```typescript
async delete(remotePath: string): Promise<void>
```

**CLI**:
```bash
fractary file delete <remote-path> [options]

Options:
  --force                Skip confirmation
```

**Implementation Notes**:
- Confirmation prompt unless --force
- Idempotent (no error if file doesn't exist)

### 3.6 list

**SDK Method**:
```typescript
async list(remotePath: string, options?: ListOptions): Promise<FileInfo[]>
```

**CLI**:
```bash
fractary file list [path] [options]

Arguments:
  [path]                 Remote path to list (default: root)

Options:
  --max-results <n>      Limit results (default: 100)
  --prefix <prefix>      Filter by prefix
  --recursive            Include subdirectories
  --json                 Output as JSON
```

**Output**:
```
Files in archive/specs/:
NAME                          SIZE      MODIFIED
WORK-00123-feature.md         15.2 KB   2025-11-15 10:30
WORK-00124-bugfix.md          8.7 KB    2025-11-14 14:22
WORK-00125-infrastructure.md  22.1 KB   2025-11-13 09:15

Total: 3 files, 46.0 KB
```

### 3.7 getUrl

**SDK Method**:
```typescript
async getUrl(remotePath: string, options?: GetUrlOptions): Promise<string>
```

**CLI**:
```bash
fractary file url <remote-path> [options]

Options:
  --expires-in <seconds> URL expiration time (default: 3600)
  --download             Force download (Content-Disposition)
```

**Implementation Notes**:
- Returns presigned URL for private files
- Returns public URL for public files
- Configurable expiration

## 4. Provider Implementations

### 4.1 Local Filesystem

**File**: `@fractary/core/file/local.ts`

**Dependencies**: Node.js `fs/promises`

```typescript
// local.ts

import { promises as fs } from 'fs';
import path from 'path';
import { FileStorage, UploadResult, FileInfo } from './types';

export class LocalFileStorage implements FileStorage {
  readonly name = 'local';
  private basePath: string;

  constructor(config: { basePath: string }) {
    this.basePath = path.resolve(config.basePath);
  }

  async upload(localPath: string, remotePath: string, options?: UploadOptions): Promise<UploadResult> {
    const fullPath = this.resolvePath(remotePath);
    await fs.mkdir(path.dirname(fullPath), { recursive: true });
    await fs.copyFile(localPath, fullPath);

    const stats = await fs.stat(fullPath);
    return {
      remotePath,
      url: `file://${fullPath}`,
      size: stats.size,
      contentType: this.detectContentType(remotePath),
    };
  }

  async download(remotePath: string, localPath: string): Promise<void> {
    const fullPath = this.resolvePath(remotePath);
    await fs.mkdir(path.dirname(localPath), { recursive: true });
    await fs.copyFile(fullPath, localPath);
  }

  async read(remotePath: string, options?: ReadOptions): Promise<string> {
    const fullPath = this.resolvePath(remotePath);
    const encoding = options?.encoding || 'utf-8';
    return fs.readFile(fullPath, encoding as BufferEncoding);
  }

  async delete(remotePath: string): Promise<void> {
    const fullPath = this.resolvePath(remotePath);
    await fs.unlink(fullPath).catch(() => {}); // Ignore if doesn't exist
  }

  async list(remotePath: string, options?: ListOptions): Promise<FileInfo[]> {
    const fullPath = this.resolvePath(remotePath);
    const entries = await fs.readdir(fullPath, { withFileTypes: true });

    const results: FileInfo[] = [];
    for (const entry of entries) {
      const entryPath = path.join(fullPath, entry.name);
      const stats = await fs.stat(entryPath);
      results.push({
        name: entry.name,
        path: path.join(remotePath, entry.name),
        size: stats.size,
        contentType: entry.isDirectory() ? 'directory' : this.detectContentType(entry.name),
        lastModified: stats.mtime,
        isDirectory: entry.isDirectory(),
      });
    }

    return results.slice(0, options?.maxResults || 100);
  }

  async getUrl(remotePath: string): Promise<string> {
    const fullPath = this.resolvePath(remotePath);
    return `file://${fullPath}`;
  }

  async exists(remotePath: string): Promise<boolean> {
    const fullPath = this.resolvePath(remotePath);
    try {
      await fs.access(fullPath);
      return true;
    } catch {
      return false;
    }
  }

  async getInfo(remotePath: string): Promise<FileInfo> {
    const fullPath = this.resolvePath(remotePath);
    const stats = await fs.stat(fullPath);
    return {
      name: path.basename(remotePath),
      path: remotePath,
      size: stats.size,
      contentType: stats.isDirectory() ? 'directory' : this.detectContentType(remotePath),
      lastModified: stats.mtime,
      isDirectory: stats.isDirectory(),
    };
  }

  private resolvePath(remotePath: string): string {
    const resolved = path.resolve(this.basePath, remotePath);
    // Security: Ensure path is within basePath
    if (!resolved.startsWith(this.basePath)) {
      throw new ValidationError('Path traversal detected', ['remotePath'], remotePath);
    }
    return resolved;
  }

  private detectContentType(filename: string): string {
    const ext = path.extname(filename).toLowerCase();
    const types: Record<string, string> = {
      '.md': 'text/markdown',
      '.json': 'application/json',
      '.txt': 'text/plain',
      '.html': 'text/html',
      '.css': 'text/css',
      '.js': 'application/javascript',
      '.ts': 'application/typescript',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.gif': 'image/gif',
      '.pdf': 'application/pdf',
      '.gz': 'application/gzip',
    };
    return types[ext] || 'application/octet-stream';
  }
}
```

### 4.2 AWS S3

**File**: `@fractary/core/file/s3.ts`

**Dependencies**: `@aws-sdk/client-s3`, `@aws-sdk/s3-request-presigner`

```typescript
// s3.ts

import {
  S3Client,
  PutObjectCommand,
  GetObjectCommand,
  DeleteObjectCommand,
  ListObjectsV2Command,
  HeadObjectCommand,
} from '@aws-sdk/client-s3';
import { getSignedUrl } from '@aws-sdk/s3-request-presigner';
import { FileStorage, UploadResult, FileInfo } from './types';

export class S3FileStorage implements FileStorage {
  readonly name = 's3';
  private client: S3Client;
  private bucket: string;

  constructor(config: S3Config) {
    this.bucket = config.bucket;
    this.client = new S3Client({
      region: config.region,
      credentials: {
        accessKeyId: config.accessKeyId,
        secretAccessKey: config.secretAccessKey,
      },
      ...(config.endpoint && { endpoint: config.endpoint }),
    });
  }

  async upload(localPath: string, remotePath: string, options?: UploadOptions): Promise<UploadResult> {
    const fileContent = await fs.readFile(localPath);
    const contentType = options?.contentType || this.detectContentType(remotePath);

    await this.client.send(new PutObjectCommand({
      Bucket: this.bucket,
      Key: remotePath,
      Body: fileContent,
      ContentType: contentType,
      ACL: options?.public ? 'public-read' : 'private',
      Metadata: options?.metadata,
    }));

    const url = options?.public
      ? `https://${this.bucket}.s3.amazonaws.com/${remotePath}`
      : await this.getUrl(remotePath);

    return {
      remotePath,
      url,
      size: fileContent.length,
      contentType,
    };
  }

  async download(remotePath: string, localPath: string, options?: DownloadOptions): Promise<void> {
    const response = await this.client.send(new GetObjectCommand({
      Bucket: this.bucket,
      Key: remotePath,
      ...(options?.maxBytes && { Range: `bytes=0-${options.maxBytes - 1}` }),
    }));

    const content = await response.Body?.transformToByteArray();
    if (content) {
      await fs.mkdir(path.dirname(localPath), { recursive: true });
      await fs.writeFile(localPath, content);
    }
  }

  async read(remotePath: string, options?: ReadOptions): Promise<string> {
    const response = await this.client.send(new GetObjectCommand({
      Bucket: this.bucket,
      Key: remotePath,
      ...(options?.maxBytes && { Range: `bytes=0-${options.maxBytes - 1}` }),
    }));

    const content = await response.Body?.transformToString(options?.encoding || 'utf-8');
    return content || '';
  }

  async getUrl(remotePath: string, options?: GetUrlOptions): Promise<string> {
    const command = new GetObjectCommand({
      Bucket: this.bucket,
      Key: remotePath,
      ...(options?.download && { ResponseContentDisposition: 'attachment' }),
    });

    return getSignedUrl(this.client, command, {
      expiresIn: options?.expiresIn || 3600,
    });
  }

  // ... other methods
}
```

### 4.3 Cloudflare R2

**File**: `@fractary/core/file/r2.ts`

R2 is S3-compatible, so it extends S3 with R2-specific endpoint:

```typescript
// r2.ts

import { S3FileStorage } from './s3';

export class R2FileStorage extends S3FileStorage {
  readonly name = 'r2';

  constructor(config: R2Config) {
    super({
      bucket: config.bucket,
      region: 'auto',
      accessKeyId: config.accessKeyId,
      secretAccessKey: config.secretAccessKey,
      endpoint: `https://${config.accountId}.r2.cloudflarestorage.com`,
    });
  }
}
```

### 4.4 Google Cloud Storage

**File**: `@fractary/core/file/gcs.ts`

**Dependencies**: `@google-cloud/storage`

### 4.5 Google Drive

**File**: `@fractary/core/file/gdrive.ts`

**Dependencies**: `googleapis`

## 5. CLI Implementation

### 5.1 Command Structure

```
@fractary/cli/
└── src/tools/file/
    ├── index.ts              # File command group
    └── commands/
        ├── upload.ts
        ├── download.ts
        ├── read.ts
        ├── delete.ts
        ├── list.ts
        ├── url.ts
        ├── init.ts
        ├── show-config.ts
        └── switch-handler.ts
```

### 5.2 Example Command Implementation

```typescript
// src/tools/file/commands/upload.ts

import { Command } from 'commander';
import chalk from 'chalk';
import { createFileStorage, loadFileConfig } from '@fractary/core/file';

export function uploadCommand(): Command {
  return new Command('upload')
    .description('Upload file to storage')
    .argument('<local-path>', 'Local file path')
    .argument('<remote-path>', 'Remote storage path')
    .option('--public', 'Make file publicly accessible')
    .option('--content-type <type>', 'Override content type')
    .option('--metadata <json>', 'JSON metadata to attach')
    .option('--json', 'Output as JSON')
    .action(async (localPath, remotePath, options) => {
      try {
        const config = await loadFileConfig();
        const storage = createFileStorage(config);

        const metadata = options.metadata ? JSON.parse(options.metadata) : undefined;

        const result = await storage.upload(localPath, remotePath, {
          public: options.public,
          contentType: options.contentType,
          metadata,
        });

        if (options.json) {
          console.log(JSON.stringify(result, null, 2));
        } else {
          console.log(chalk.green('✓ File uploaded successfully'));
          console.log(`  Path: ${result.remotePath}`);
          console.log(`  Size: ${formatBytes(result.size)}`);
          console.log(`  Type: ${result.contentType}`);
          console.log(`  URL: ${result.url}`);
        }

      } catch (error: any) {
        console.error(chalk.red('Error:'), error.message);
        process.exit(1);
      }
    });
}
```

## 6. Configuration

### 6.1 Configuration Schema

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "properties": {
    "schema_version": { "type": "string", "const": "1.0" },
    "provider": { "type": "string", "enum": ["local", "s3", "r2", "gcs", "gdrive"] },
    "local": {
      "type": "object",
      "properties": {
        "base_path": { "type": "string", "default": "./storage" }
      }
    },
    "s3": {
      "type": "object",
      "properties": {
        "bucket": { "type": "string" },
        "region": { "type": "string" },
        "access_key_id_env": { "type": "string", "default": "AWS_ACCESS_KEY_ID" },
        "secret_access_key_env": { "type": "string", "default": "AWS_SECRET_ACCESS_KEY" }
      }
    },
    "r2": {
      "type": "object",
      "properties": {
        "account_id": { "type": "string" },
        "bucket": { "type": "string" },
        "access_key_id_env": { "type": "string", "default": "R2_ACCESS_KEY_ID" },
        "secret_access_key_env": { "type": "string", "default": "R2_SECRET_ACCESS_KEY" }
      }
    },
    "gcs": {
      "type": "object",
      "properties": {
        "bucket": { "type": "string" },
        "project_id": { "type": "string" },
        "credentials_path": { "type": "string" }
      }
    },
    "gdrive": {
      "type": "object",
      "properties": {
        "folder_id": { "type": "string" },
        "credentials_path": { "type": "string" }
      }
    }
  },
  "required": ["schema_version", "provider"]
}
```

### 6.2 Example Configuration

```json
{
  "schema_version": "1.0",
  "provider": "r2",
  "r2": {
    "account_id": "abc123",
    "bucket": "fractary-storage",
    "access_key_id_env": "R2_ACCESS_KEY_ID",
    "secret_access_key_env": "R2_SECRET_ACCESS_KEY"
  }
}
```

## 7. Plugin Migration

### 7.1 What Gets Removed

- `skills/file-manager/` - Logic moves to SDK
- All handler skills (`handler-storage-*`)
- All shell scripts

### 7.2 What Stays

- Commands (Claude UX)
- Agent (thin router to CLI)
- Config templates

## 8. Security

### 8.1 Path Safety

All providers validate paths to prevent traversal:

```typescript
private validatePath(remotePath: string): void {
  if (remotePath.includes('..') || remotePath.startsWith('/')) {
    throw new ValidationError('Invalid path', ['remotePath'], remotePath);
  }
}
```

### 8.2 Credential Management

- Credentials from environment variables only
- Never logged or stored in config files
- Validated at provider initialization

## 9. References

- [SPEC-00016: SDK Architecture](./SPEC-00016-sdk-architecture.md) - Core interfaces
- [AWS S3 SDK](https://docs.aws.amazon.com/AWSJavaScriptSDK/v3/latest/client/s3/)
- [Cloudflare R2 Documentation](https://developers.cloudflare.com/r2/)
- [Google Cloud Storage](https://cloud.google.com/storage/docs)
- [Google Drive API](https://developers.google.com/drive/api)
