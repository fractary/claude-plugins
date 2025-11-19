# Local Filesystem Storage Handler Guide

## Overview

The local filesystem handler provides file storage using the local filesystem. This is the default handler and requires no external dependencies or credentials.

## Use Cases

- **Development and testing**: Quick setup with no cloud provider needed
- **Local workflows**: When files don't need cloud storage
- **Temporary storage**: For short-lived workflow artifacts
- **Offline development**: Works without internet connection

## Configuration

### Minimal Configuration (Default)

No configuration needed! The local handler works out of the box with defaults:

```json
{
  "active_handler": "local"
}
```

Default settings:
- **base_path**: `.` (project root)
- **create_directories**: `true` (auto-create directories)
- **permissions**: `0755` (standard directory permissions)

### Custom Configuration

Customize the local handler in `.fractary/plugins/file/config.json`:

```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "/var/fractary/storage",
      "create_directories": true,
      "permissions": "0755"
    }
  }
}
```

**Configuration Fields**:

- **base_path**: Base directory for file storage
  - Can be relative (`.` for project root, `./storage` for subdirectory) or absolute (`/var/fractary/storage`)
  - Created automatically if it doesn't exist
  - Example: `"."` (project root), `"./storage"` (subdirectory), `"/tmp/fractary"`, `"~/fractary-files"`

- **create_directories**: Auto-create directories for uploads
  - `true`: Automatically create parent directories (recommended)
  - `false`: Fail if directory doesn't exist

- **permissions**: Directory permissions in octal notation
  - `"0755"`: Owner read/write/execute, group/others read/execute (default)
  - `"0750"`: Owner read/write/execute, group read/execute, others none
  - `"0700"`: Owner read/write/execute only (most restrictive)

## Operations

### Upload File

Upload a file to local storage:

```bash
# Via agent
Use the @agent-fractary-file:file-manager agent to upload:
{
  "operation": "upload",
  "local_path": "./document.pdf",
  "remote_path": "docs/document.pdf",
  "public": false
}
```

**Result**:
```json
{
  "success": true,
  "message": "File uploaded successfully",
  "url": "file:///absolute/path/to/storage/docs/document.pdf",
  "size_bytes": 1024,
  "checksum": "sha256:abc123...",
  "local_path": "/absolute/path/to/storage/docs/document.pdf"
}
```

### Download File

Download a file from local storage:

```bash
Use the @agent-fractary-file:file-manager agent to download:
{
  "operation": "download",
  "remote_path": "docs/document.pdf",
  "local_path": "./downloaded-document.pdf"
}
```

### Delete File

Delete a file from local storage:

```bash
Use the @agent-fractary-file:file-manager agent to delete:
{
  "operation": "delete",
  "remote_path": "docs/old-document.pdf"
}
```

### List Files

List files in local storage:

```bash
Use the @agent-fractary-file:file-manager agent to list:
{
  "operation": "list",
  "prefix": "docs/",
  "max_results": 50
}
```

**Result**:
```json
{
  "success": true,
  "message": "Found 3 files",
  "files": [
    {
      "path": "docs/document.pdf",
      "size_bytes": 1024,
      "modified_at": 1642457123
    },
    {
      "path": "docs/report.txt",
      "size_bytes": 512,
      "modified_at": 1642457456
    }
  ]
}
```

### Get URL

Get a file:// URL for a file:

```bash
Use the @agent-fractary-file:file-manager agent to get URL:
{
  "operation": "get-url",
  "remote_path": "docs/document.pdf"
}
```

**Result**:
```json
{
  "success": true,
  "message": "URL generated successfully",
  "url": "file:///absolute/path/to/storage/docs/document.pdf",
  "note": "file:// URLs do not expire"
}
```

**Note**: file:// URLs work only on the local machine and don't support remote access.

### Read File

Read file contents without downloading:

```bash
Use the @agent-fractary-file:file-manager agent to read:
{
  "operation": "read",
  "remote_path": "docs/document.txt",
  "max_bytes": 10485760
}
```

Returns file contents to stdout. Truncates if file exceeds max_bytes.

## Security

### File Permissions

The local handler respects standard filesystem permissions:

- **Directory permissions**: Set via `permissions` config (default: `0755`)
- **File permissions**: Inherited from source file during upload
- **User/Group**: Files owned by user running the process

### Access Control

- No authentication/authorization built into local handler
- Relies on OS-level file permissions
- Consider using `0700` permissions for sensitive data
- Files accessible to any user with filesystem access

### Best Practices

1. **Use restrictive permissions** for sensitive data:
   ```json
   {
     "handlers": {
       "local": {
         "base_path": "~/.fractary/private-storage",
         "permissions": "0700"
       }
     }
   }
   ```

2. **Don't commit config** with local paths to version control

3. **Use absolute paths** for production deployments

4. **Regular cleanup**: Remove old files to save disk space

5. **Backup important files**: Local storage is not backed up automatically

## Limitations

1. **No remote access**: Files only accessible on local machine
2. **No URL expiration**: file:// URLs never expire
3. **No presigned URLs**: Cannot generate time-limited access URLs
4. **No built-in backup**: Files not automatically backed up
5. **Disk space**: Limited by local disk space
6. **No versioning**: Overwrites files with same path

## Troubleshooting

### Permission Denied

**Error**: `Error: Failed to create directory: /var/fractary/storage`

**Solutions**:
- Check directory permissions: `ls -la /var/fractary/`
- Use a directory you have write access to
- Use relative path: `./storage`
- Create directory manually: `mkdir -p /var/fractary/storage && chmod 755 /var/fractary/storage`

### Disk Space

**Error**: `Error: No space left on device`

**Solutions**:
- Check disk space: `df -h`
- Clean up old files: List and delete unneeded files
- Use different base_path on another disk
- Switch to cloud storage handler (S3, R2, GCS)

### File Not Found

**Error**: `Error: Remote file not found`

**Solutions**:
- Verify file exists: Check base_path directory
- Check remote_path spelling
- Use list operation to see available files

### Path Traversal

**Error**: `Error: Path contains '..' (path traversal attempt)`

**Solution**: Don't use `..` in paths. Use proper remote paths without traversal.

## Migration to Cloud Storage

When ready to move from local to cloud storage:

1. **Choose cloud provider**: S3, R2, GCS, or Google Drive
2. **Run init command**: `/fractary-file:init --handler <provider>`
3. **Upload existing files**: Use upload operation for each file
4. **Update configuration**: Switch active_handler
5. **Test**: Verify operations work with new handler
6. **Clean up**: Remove local files if no longer needed

## Examples

### Development Setup (Project Root)

```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": ".",
      "create_directories": true,
      "permissions": "0755"
    }
  }
}
```

### Development Setup (Storage Directory)

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

### Production Setup (Unix Socket)

```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "/var/lib/fractary/storage",
      "create_directories": true,
      "permissions": "0750"
    }
  }
}
```

### User Home Directory

```json
{
  "active_handler": "local",
  "handlers": {
    "local": {
      "base_path": "~/.fractary/storage",
      "create_directories": true,
      "permissions": "0700"
    }
  }
}
```

## Support

For issues with the local handler:
1. Check file and directory permissions
2. Verify disk space available
3. Check base_path accessibility
4. Review audit log: `~/.config/fractary/file/audit.log`
