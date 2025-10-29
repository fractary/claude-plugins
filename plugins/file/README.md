# Fractary File Manager Plugin

File storage operations across multiple platforms.

## Overview

The `fractary-file` plugin provides a unified interface for file storage operations across different storage platforms. It handles uploading, downloading, listing, deleting files, and generating public URLs while abstracting platform-specific differences.

## Platforms Supported

- ✅ **Cloudflare R2** (complete) - Full implementation with all storage operations
- 🚧 **AWS S3** (structure ready) - Framework in place, scripts need implementation
- 🚧 **Local Filesystem** (structure ready) - Framework in place, scripts need implementation

## Installation

```bash
claude plugin install fractary/file
```

## Components

### Agent

**`file-manager`** - Orchestrates file storage operations
- Uploads files to configured storage
- Downloads files from storage
- Lists files in storage
- Deletes files from storage
- Generates public/signed URLs for files

### Skill

**`file-manager`** - Platform adapter selection
- Reads configuration to determine active storage platform (R2/S3/local)
- Invokes appropriate platform-specific scripts
- Handles platform-specific authentication and formats

## Configuration

When used with `fractary-faber`, configure in `faber.yaml`:

```yaml
handlers:
  file_storage:
    active: "r2"
    r2:
      account_id: "your-account-id"
      bucket_name: "your-bucket"
      public_url: "https://your-domain.com"
```

## Usage

This plugin is primarily used by other Fractary plugins (especially `fractary-faber`) and typically not invoked directly by users.

**Agent invocation example:**
```bash
claude --agent fractary-file/file-manager "upload /path/to/file.txt remote/path.txt"
```

## Directory Structure

```
file/
├── .claude-plugin/
│   └── plugin.json          # Plugin manifest
├── agents/
│   └── file-manager.md      # File manager agent
├── skills/
│   └── file-manager/
│       ├── SKILL.md         # Skill definition
│       ├── scripts/
│       │   ├── r2/          # Cloudflare R2 adapter
│       │   ├── s3/          # AWS S3 adapter (future)
│       │   └── local/       # Local filesystem adapter (future)
│       └── docs/
│           ├── r2-api.md
│           └── s3-api.md
└── README.md                # This file
```

## Operations Supported

All platform adapters implement these operations:

- **upload.sh** - Upload file to storage
- **download.sh** - Download file from storage
- **delete.sh** - Delete file from storage
- **list.sh** - List files in storage
- **get-url.sh** - Generate public or signed URL

## Adding New Platforms

To add support for a new storage platform:

1. Create scripts directory: `skills/file-manager/scripts/{platform}/`
2. Implement required scripts (see operations list above)
3. Add API documentation: `skills/file-manager/docs/{platform}-api.md`
4. Update handler configuration in your project's `faber.yaml`

## License

Part of the Fractary plugin ecosystem.
