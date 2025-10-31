---
name: file-manager
description: File storage operations across R2, S3, local filesystem, etc.
---

# File Manager Skill

Provides file storage operations for FABER workflows. This skill is platform-agnostic and supports multiple storage backends through adapters.

## Purpose

Handle all interactions with file storage systems:
- Upload files to storage
- Download files from storage
- Delete files from storage
- List files in storage
- Get public URLs for files

## Configuration

Reads `project.file_system` from configuration to determine which adapter to use:

```toml
[project]
file_system = "r2"  # r2 | s3 | local
```

## Operations

### Upload File

Upload a file to storage.

```bash
./scripts/<adapter>/upload.sh <local_path> <remote_path> [public]
```

**Parameters:**
- `local_path`: Local file path
- `remote_path`: Remote storage path
- `public` (optional): Make file publicly accessible (true/false, default: false)

**Returns:** Remote path or URL

**Example:**
```bash
url=$(./scripts/r2/upload.sh ./spec.md faber/specs/abc12345-spec.md true)
```

### Download File

Download a file from storage.

```bash
./scripts/<adapter>/download.sh <remote_path> <local_path>
```

**Parameters:**
- `remote_path`: Remote storage path
- `local_path`: Local destination path

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/r2/download.sh faber/specs/abc12345-spec.md ./downloaded-spec.md
```

### Delete File

Delete a file from storage.

```bash
./scripts/<adapter>/delete.sh <remote_path>
```

**Parameters:**
- `remote_path`: Remote storage path to delete

**Returns:** Success/failure indicator

**Example:**
```bash
./scripts/r2/delete.sh faber/specs/abc12345-spec.md
```

### List Files

List files in storage with optional prefix filter.

```bash
./scripts/<adapter>/list.sh [prefix] [max_results]
```

**Parameters:**
- `prefix` (optional): Path prefix to filter by
- `max_results` (optional): Maximum number of results (default: 100)

**Returns:** JSON array of file information

**Example:**
```bash
files=$(./scripts/r2/list.sh faber/specs/ 50)
```

### Get URL

Get a public or signed URL for a file.

```bash
./scripts/<adapter>/get-url.sh <remote_path> [expires_in]
```

**Parameters:**
- `remote_path`: Remote storage path
- `expires_in` (optional): URL expiration time in seconds (default: 3600)

**Returns:** URL string

**Example:**
```bash
url=$(./scripts/r2/get-url.sh faber/specs/abc12345-spec.md 7200)
```

## Adapters

### Cloudflare R2 Adapter

Located in: `scripts/r2/`

Uses AWS CLI (`aws`) with R2-compatible endpoints.

**Requirements:**
- `aws` CLI installed and configured
- R2 credentials in environment or AWS config
- Configured bucket in `.faber.config.toml`

**See:** `docs/r2-api.md` for details

### AWS S3 Adapter (Future)

Located in: `scripts/s3/`

Will use AWS CLI (`aws`) for S3 operations.

**See:** `docs/s3-api.md` for future implementation

### Local Filesystem Adapter (Future)

Located in: `scripts/local/`

Will use standard filesystem operations.

## Error Handling

All scripts follow these conventions:
- Exit code 0: Success
- Exit code 1: General error
- Exit code 2: Invalid arguments
- Exit code 3: Configuration error
- Exit code 10: File not found
- Exit code 11: Authentication error
- Exit code 12: Network error
- Exit code 13: Permission denied

Error messages are written to stderr, results to stdout.

## Usage in Agents

Agents should invoke this skill for file storage operations:

```bash
# From file-manager agent
SCRIPT_DIR="$(dirname "$0")/../skills/file-manager/scripts"

# Determine adapter from config
ADAPTER=$(get_file_system_from_config)  # Returns: r2, s3, local

# Upload file
url=$("$SCRIPT_DIR/$ADAPTER/upload.sh" "./spec.md" "faber/specs/abc12345.md" true)

# Download file
"$SCRIPT_DIR/$ADAPTER/download.sh" "faber/specs/abc12345.md" "./local-spec.md"

# Get URL
url=$("$SCRIPT_DIR/$ADAPTER/get-url.sh" "faber/specs/abc12345.md" 3600)
```

## Dependencies

### All Adapters
- `bash` (4.0+)
- `jq` (for JSON parsing)

### R2 Adapter
- `aws` CLI (configured for R2)
- R2 credentials (access key, secret key, account ID)

### S3 Adapter (Future)
- `aws` CLI
- AWS credentials

### Local Adapter (Future)
- Standard filesystem access

## Script Locations

```
skills/file-manager/
├── SKILL.md (this file)
├── scripts/
│   ├── r2/
│   │   ├── upload.sh
│   │   ├── download.sh
│   │   ├── delete.sh
│   │   ├── list.sh
│   │   └── get-url.sh
│   ├── s3/
│   │   └── (future)
│   └── local/
│       └── (future)
└── docs/
    ├── r2-api.md
    └── s3-api.md
```

## File Path Conventions

Storage paths follow these conventions:

- **Specifications**: `faber/specs/{work_id}-{type}.md`
- **Artifacts**: `faber/artifacts/{work_id}/{filename}`
- **Logs**: `faber/logs/{work_id}/{stage}-{timestamp}.log`
- **Backups**: `faber/backups/{date}/{work_id}.tar.gz`

Example:
```
faber/
├── specs/
│   ├── abc12345-spec.md
│   └── def67890-spec.md
├── artifacts/
│   ├── abc12345/
│   │   ├── build.log
│   │   └── test-results.json
│   └── def67890/
│       └── coverage.html
└── logs/
    ├── abc12345/
    │   ├── frame-2025-01-22.log
    │   └── build-2025-01-22.log
    └── def67890/
        └── evaluate-2025-01-22.log
```

## Testing

Test scripts independently:

```bash
# Test R2 adapter
export AWS_ACCESS_KEY_ID="..."
export AWS_SECRET_ACCESS_KEY="..."
export R2_ACCOUNT_ID="..."

# Upload test file
echo "test" > test.txt
./scripts/r2/upload.sh test.txt faber/test/test.txt true

# List files
./scripts/r2/list.sh faber/test/

# Get URL
./scripts/r2/get-url.sh faber/test/test.txt

# Download
./scripts/r2/download.sh faber/test/test.txt downloaded.txt

# Delete
./scripts/r2/delete.sh faber/test/test.txt
```

## Notes

- Scripts are stateless where possible
- All JSON output is minified (single line) for easy parsing
- Public files are accessible without authentication
- Signed URLs expire after specified time
- File paths are case-sensitive
- Storage paths should use forward slashes
