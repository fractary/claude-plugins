# Fractary Plugins API Reference

Complete API reference for agent invocation patterns across fractary-file, fractary-docs, fractary-spec, and fractary-logs plugins.

## Overview

All plugins use **declarative agent invocation** - you state what you want the agent to do in natural language, and the plugin system routes the request appropriately.

**Invocation pattern**:
```
Use the @agent-PLUGIN:AGENT-NAME agent to OPERATION:
{
  "operation": "operation-name",
  "parameters": {
    ...
  }
}
```

## fractary-file API

**Agent**: `@agent-fractary-file:file-manager`

### upload

Upload a local file to cloud storage.

**Request**:
```
Use the @agent-fractary-file:file-manager agent to upload:
{
  "operation": "upload",
  "parameters": {
    "local_path": string,     // Required: Path to local file
    "remote_path": string,    // Required: Destination path in storage
    "public": boolean         // Optional: Make publicly accessible (default: false)
  },
  "handler_override": string  // Optional: Use specific handler (overrides active_handler)
}
```

**Response**:
```json
{
  "url": "https://storage.example.com/path/file.txt",
  "size_bytes": 1048576,
  "checksum": "sha256:abc123...",
  "uploaded_at": "2025-01-15T10:30:00Z"
}
```

**Example**:
```
Use @agent-fractary-file:file-manager to upload specification:
{
  "operation": "upload",
  "parameters": {
    "local_path": "/specs/spec-123.md",
    "remote_path": "archive/specs/2025/123.md",
    "public": false
  }
}
```

---

### download

Download a file from cloud storage to local filesystem.

**Request**:
```
Use the @agent-fractary-file:file-manager agent to download:
{
  "operation": "download",
  "parameters": {
    "remote_path": string,    // Required: Path in storage
    "local_path": string      // Required: Destination path locally
  }
}
```

**Response**:
```json
{
  "local_path": "./downloaded-file.txt",
  "size_bytes": 1048576,
  "checksum": "sha256:abc123..."
}
```

**Example**:
```
Use @agent-fractary-file:file-manager to download archived spec:
{
  "operation": "download",
  "parameters": {
    "remote_path": "archive/specs/2024/100.md",
    "local_path": "./old-specs/spec-100.md"
  }
}
```

---

### read

Stream file contents without downloading (max 50MB).

**Request**:
```
Use the @agent-fractary-file:file-manager agent to read:
{
  "operation": "read",
  "parameters": {
    "remote_path": string,    // Required: Path in storage
    "max_bytes": number       // Optional: Max bytes to read (default: 10MB, max: 50MB)
  }
}
```

**Response**: File contents to stdout (truncated if exceeds max_bytes)

**Example**:
```
Use @agent-fractary-file:file-manager to read archived spec:
{
  "operation": "read",
  "parameters": {
    "remote_path": "archive/specs/2025/123.md",
    "max_bytes": 10485760
  }
}
```

---

### delete

Delete a file from storage.

**Request**:
```
Use the @agent-fractary-file:file-manager agent to delete:
{
  "operation": "delete",
  "parameters": {
    "remote_path": string     // Required: Path to delete
  }
}
```

**Response**:
```json
{
  "deleted": true,
  "path": "path/to/file.txt"
}
```

**Example**:
```
Use @agent-fractary-file:file-manager to delete temporary file:
{
  "operation": "delete",
  "parameters": {
    "remote_path": "temp/old-file.txt"
  }
}
```

---

### list

List files in storage with optional filtering.

**Request**:
```
Use the @agent-fractary-file:file-manager agent to list:
{
  "operation": "list",
  "parameters": {
    "prefix": string,         // Optional: Filter by path prefix
    "max_results": number     // Optional: Limit results (default: 100)
  }
}
```

**Response**:
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

**Example**:
```
Use @agent-fractary-file:file-manager to list archived specs:
{
  "operation": "list",
  "parameters": {
    "prefix": "archive/specs/2025/",
    "max_results": 100
  }
}
```

---

### get-url

Generate an accessible URL for a file.

**Request**:
```
Use the @agent-fractary-file:file-manager agent to get URL:
{
  "operation": "get-url",
  "parameters": {
    "remote_path": string,    // Required: Path in storage
    "expires_in": number      // Optional: URL expiration in seconds (default: 3600)
  }
}
```

**Response**:
```json
{
  "url": "https://storage.example.com/file.pdf?signature=...",
  "expires_at": "2025-01-15T11:30:00Z",
  "public": false
}
```

**Example**:
```
Use @agent-fractary-file:file-manager to get URL for report:
{
  "operation": "get-url",
  "parameters": {
    "remote_path": "reports/monthly-report.pdf",
    "expires_in": 7200
  }
}
```

---

## fractary-docs API

**Agent**: `@agent-fractary-docs:docs-manager`

### generate

Generate documentation from template.

**Request**:
```
Use the @agent-fractary-docs:docs-manager agent to generate:
{
  "operation": "generate",
  "doc_type": string,         // Required: adr, design, runbook, api-spec, etc.
  "parameters": {
    "title": string,          // Required: Document title
    "status": string,         // Optional: draft, review, approved (default: draft)
    "number": string,         // Optional: Document number (for ADRs)
    ...                       // Template-specific parameters
  },
  "options": {
    "validate_after": boolean, // Optional: Validate after generation (default: true)
    "commit_after": boolean   // Optional: Auto-commit to git (default: false)
  }
}
```

**Response**:
```json
{
  "file_path": "docs/architecture/adrs/ADR-001-use-postgresql.md",
  "doc_type": "adr",
  "front_matter": {
    "title": "ADR-001: Use PostgreSQL",
    "type": "adr",
    "status": "proposed",
    "date": "2025-01-15",
    "codex_sync": true
  },
  "validation": {
    "passed": true,
    "warnings": []
  }
}
```

**Example - ADR**:
```
Use @agent-fractary-docs:docs-manager to generate ADR:
{
  "operation": "generate",
  "doc_type": "adr",
  "parameters": {
    "title": "Use PostgreSQL for Data Storage",
    "number": "001",
    "status": "proposed",
    "context": "We need a reliable database with ACID guarantees",
    "decision": "We will use PostgreSQL 15 as our primary data store",
    "consequences": {
      "positive": ["Strong ACID compliance", "Rich query capabilities"],
      "negative": ["Operational overhead"]
    }
  }
}
```

**Example - Design Doc**:
```
Use @agent-fractary-docs:docs-manager to generate design doc:
{
  "operation": "generate",
  "doc_type": "design",
  "parameters": {
    "title": "User Authentication System",
    "status": "draft",
    "overview": "OAuth 2.0 authentication with multiple providers",
    "architecture": "Token bucket algorithm with Redis backend"
  }
}
```

---

### update

Update existing documentation while preserving structure.

**Request**:
```
Use the @agent-fractary-docs:docs-manager agent to update:
{
  "operation": "update",
  "file_path": string,        // Required: Path to document
  "section": string,          // Optional: Section heading to update
  "append_section": string,   // Optional: Add new section
  "content": string,          // Required: New content
  "metadata": object          // Optional: Update front matter
}
```

**Response**:
```json
{
  "file_path": "docs/architecture/adrs/ADR-001.md",
  "updated": true,
  "sections_modified": ["Status"],
  "front_matter_updated": true
}
```

**Example - Update Section**:
```
Use @agent-fractary-docs:docs-manager to update ADR status:
{
  "operation": "update",
  "file_path": "docs/architecture/adrs/ADR-001-postgresql.md",
  "section": "Status",
  "content": "## Status\n\nAccepted"
}
```

**Example - Append Section**:
```
Use @agent-fractary-docs:docs-manager to append troubleshooting section:
{
  "operation": "update",
  "file_path": "docs/guides/setup.md",
  "append_section": "Troubleshooting",
  "content": "## Troubleshooting\n\n### Issue: Connection timeout\n..."
}
```

**Example - Update Metadata**:
```
Use @agent-fractary-docs:docs-manager to update metadata:
{
  "operation": "update",
  "file_path": "docs/api/user-service.md",
  "metadata": {
    "status": "approved",
    "updated": "2025-01-15"
  }
}
```

---

### validate

Validate documentation quality.

**Request**:
```
Use the @agent-fractary-docs:docs-manager agent to validate:
{
  "operation": "validate",
  "path": string,             // Required: File or directory path
  "checks": [                 // Optional: Specific checks (default: all)
    "markdown-lint",
    "frontmatter",
    "structure",
    "links"
  ],
  "fix": boolean              // Optional: Auto-fix issues (default: false)
}
```

**Response**:
```json
{
  "path": "docs/architecture/adrs/ADR-001.md",
  "passed": true,
  "checks": {
    "markdown-lint": {"passed": true, "issues": []},
    "frontmatter": {"passed": true, "issues": []},
    "structure": {"passed": true, "issues": []},
    "links": {"passed": true, "issues": []}
  },
  "warnings": ["Status should be lowercase"],
  "errors": []
}
```

**Example**:
```
Use @agent-fractary-docs:docs-manager to validate docs:
{
  "operation": "validate",
  "path": "docs/",
  "fix": true
}
```

---

### link

Manage cross-references and documentation relationships.

**Request**:
```
Use the @agent-fractary-docs:docs-manager agent to manage links:
{
  "operation": "link",
  "action": string,           // Required: index, check, fix, graph
  "path": string,             // Optional: Specific path (default: all docs)
  "output": string            // Optional: Output file for index/graph
}
```

**Response**:
```json
{
  "action": "check",
  "broken_links": [
    {
      "file": "docs/api/auth.md",
      "line": 45,
      "link": "/docs/old-design.md",
      "reason": "File not found"
    }
  ],
  "total_links": 127,
  "broken_count": 1
}
```

**Example - Create Index**:
```
Use @agent-fractary-docs:docs-manager to create index:
{
  "operation": "link",
  "action": "index",
  "output": "docs/INDEX.md"
}
```

**Example - Check Links**:
```
Use @agent-fractary-docs:docs-manager to check links:
{
  "operation": "link",
  "action": "check",
  "path": "docs/"
}
```

---

## fractary-spec API

**Agent**: `@agent-fractary-spec:spec-manager`

### generate

Generate specification from GitHub issue.

**Request**:
```
Use the @agent-fractary-spec:spec-manager agent to generate:
{
  "operation": "generate",
  "issue_number": string,     // Required: GitHub issue number
  "template": string,         // Optional: Template (auto-classified if omitted)
  "phase": number,            // Optional: Phase number for multi-phase specs
  "title": string             // Optional: Custom title (overrides issue title)
}
```

**Response**:
```json
{
  "spec_file": "/specs/spec-123-oauth-authentication.md",
  "issue_number": "123",
  "template": "feature",
  "github_comment_added": true,
  "spec_content": {
    "title": "OAuth 2.0 Authentication",
    "requirements": 6,
    "acceptance_criteria": 7
  }
}
```

**Example**:
```
Use @agent-fractary-spec:spec-manager to generate spec:
{
  "operation": "generate",
  "issue_number": "123"
}
```

**Example - Multi-Phase**:
```
Use @agent-fractary-spec:spec-manager to generate phase 1 spec:
{
  "operation": "generate",
  "issue_number": "123",
  "phase": 1,
  "title": "Authentication"
}
```

---

### validate

Validate implementation against specification.

**Request**:
```
Use the @agent-fractary-spec:spec-manager agent to validate:
{
  "operation": "validate",
  "issue_number": string      // Required: Issue number
}
```

**Response**:
```json
{
  "issue_number": "123",
  "spec_file": "/specs/spec-123-oauth.md",
  "validation_status": "complete",
  "checks": {
    "requirements_coverage": {"passed": true, "count": "5/5"},
    "acceptance_criteria": {"passed": true, "count": "7/7"},
    "files_modified": {"passed": true, "expected_files_present": true},
    "tests_added": {"passed": true, "test_files_found": 2},
    "docs_updated": {"passed": true, "doc_files_updated": 2}
  },
  "overall": "complete"
}
```

**Example**:
```
Use @agent-fractary-spec:spec-manager to validate implementation:
{
  "operation": "validate",
  "issue_number": "123"
}
```

---

### archive

Archive specification to cloud storage.

**Request**:
```
Use the @agent-fractary-spec:spec-manager agent to archive:
{
  "operation": "archive",
  "issue_number": string,     // Required: Issue number
  "force": boolean            // Optional: Skip pre-checks (default: false)
}
```

**Response**:
```json
{
  "issue_number": "123",
  "specs_archived": [
    {
      "local_path": "spec-123-oauth.md",
      "cloud_path": "archive/specs/2025/123.md",
      "url": "https://storage.example.com/specs/2025/123.md",
      "size_bytes": 24576
    }
  ],
  "archive_index_updated": true,
  "github_comment_added": true,
  "local_specs_removed": true
}
```

**Example**:
```
Use @agent-fractary-spec:spec-manager to archive completed spec:
{
  "operation": "archive",
  "issue_number": "123"
}
```

---

### read

Read archived specification from cloud.

**Request**:
```
Use the @agent-fractary-spec:spec-manager agent to read:
{
  "operation": "read",
  "issue_number": string      // Required: Issue number
}
```

**Response**: Spec contents streamed to stdout

**Example**:
```
Use @agent-fractary-spec:spec-manager to read archived spec:
{
  "operation": "read",
  "issue_number": "123"
}
```

---

## fractary-logs API

**Agent**: `@agent-fractary-logs:log-manager`

### capture

Start capturing session log.

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to capture:
{
  "operation": "capture",
  "issue_number": string,     // Required: Issue number
  "type": string              // Optional: session, build, deployment, debug (default: session)
}
```

**Response**:
```json
{
  "session_id": "session-123-2025-01-15-0900",
  "issue_number": "123",
  "log_file": "/logs/sessions/session-123-2025-01-15-0900.md",
  "started_at": "2025-01-15T09:00:00Z",
  "capturing": true
}
```

**Example**:
```
Use @agent-fractary-logs:log-manager to start session capture:
{
  "operation": "capture",
  "issue_number": "123"
}
```

---

### stop

Stop active session capture.

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to stop:
{
  "operation": "stop"
}
```

**Response**:
```json
{
  "session_id": "session-123-2025-01-15-0900",
  "stopped_at": "2025-01-15T11:30:00Z",
  "duration_minutes": 150,
  "log_file": "/logs/sessions/session-123-2025-01-15-0900.md",
  "size_bytes": 45678
}
```

**Example**:
```
Use @agent-fractary-logs:log-manager to stop capture:
{
  "operation": "stop"
}
```

---

### log

Add entry to log (without full capture).

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to log:
{
  "operation": "log",
  "issue_number": string,     // Required: Issue number
  "message": string,          // Required: Log message
  "level": string             // Optional: info, warn, error (default: info)
}
```

**Response**:
```json
{
  "logged": true,
  "timestamp": "2025-01-15T10:30:00Z",
  "log_file": "/logs/sessions/session-123.md"
}
```

**Example**:
```
Use @agent-fractary-logs:log-manager to log deployment:
{
  "operation": "log",
  "issue_number": "123",
  "message": "Deployed to staging - 5 min downtime during migration",
  "level": "info"
}
```

---

### archive

Archive logs for completed issue.

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to archive:
{
  "operation": "archive",
  "issue_number": string      // Required: Issue number
}
```

**Response**:
```json
{
  "issue_number": "123",
  "logs_archived": [
    {
      "type": "session",
      "local_path": "session-123.md",
      "cloud_path": "archive/logs/2025/01/123/session.md.gz",
      "url": "https://storage.example.com/logs/...",
      "size_bytes": 45678,
      "compressed": true
    },
    {
      "type": "build",
      "local_path": "build-123.log",
      "cloud_path": "archive/logs/2025/01/123/build.log.gz",
      "url": "https://storage.example.com/logs/...",
      "size_bytes": 12345,
      "compressed": true
    }
  ],
  "archive_index_updated": true,
  "github_comment_added": true
}
```

**Example**:
```
Use @agent-fractary-logs:log-manager to archive logs:
{
  "operation": "archive",
  "issue_number": "123"
}
```

---

### search

Search logs (local and cloud).

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to search:
{
  "operation": "search",
  "query": string,            // Required: Search query
  "filters": {
    "issue": string,          // Optional: Filter by issue
    "type": string,           // Optional: session, build, deployment, debug
    "since": string,          // Optional: Date filter (YYYY-MM-DD)
    "until": string,          // Optional: Date filter (YYYY-MM-DD)
    "regex": boolean,         // Optional: Use regex (default: false)
    "local_only": boolean,    // Optional: Search local only (default: false)
    "cloud_only": boolean     // Optional: Search cloud only (default: false)
  },
  "max_results": number       // Optional: Limit results (default: 100)
}
```

**Response**:
```json
{
  "query": "OAuth error",
  "results": [
    {
      "file": "/logs/sessions/session-123.md",
      "location": "local",
      "line": 45,
      "context": "...OAuth callback failed with error: token undefined..."
    },
    {
      "file": "archive/logs/2024/12/100/session.md.gz",
      "location": "cloud",
      "line": 67,
      "context": "...OAuth provider returned error..."
    }
  ],
  "total_results": 2,
  "local_results": 1,
  "cloud_results": 1
}
```

**Example**:
```
Use @agent-fractary-logs:log-manager to search for errors:
{
  "operation": "search",
  "query": "OAuth error",
  "filters": {
    "issue": "123",
    "type": "session"
  }
}
```

---

### analyze

Analyze logs for insights.

**Request**:
```
Use the @agent-fractary-logs:log-manager agent to analyze:
{
  "operation": "analyze",
  "analysis_type": string,    // Required: errors, patterns, session, time
  "filters": {
    "issue": string,          // Optional: Filter by issue
    "since": string,          // Optional: Date filter
    "until": string           // Optional: Date filter
  }
}
```

**Response (errors)**:
```json
{
  "analysis_type": "errors",
  "errors_found": 2,
  "errors": [
    {
      "error": "TypeError: Cannot read property 'token' of undefined",
      "file": "src/auth/oauth.ts",
      "line": 45,
      "timestamp": "2025-01-15T10:23:15Z",
      "context": "OAuth callback handler",
      "solution": "Added null check"
    }
  ]
}
```

**Response (patterns)**:
```json
{
  "analysis_type": "patterns",
  "patterns_found": 3,
  "patterns": [
    {
      "pattern": "Database connection timeout",
      "occurrences": 8,
      "issues": ["#100", "#105", "#123"],
      "suggestion": "Implement connection pooling"
    }
  ]
}
```

**Example - Error Analysis**:
```
Use @agent-fractary-logs:log-manager to analyze errors:
{
  "operation": "analyze",
  "analysis_type": "errors",
  "filters": {
    "issue": "123"
  }
}
```

**Example - Pattern Detection**:
```
Use @agent-fractary-logs:log-manager to detect patterns:
{
  "operation": "analyze",
  "analysis_type": "patterns",
  "filters": {
    "since": "2024-01-01"
  }
}
```

---

## Error Codes

All plugins return standardized error responses:

```json
{
  "error": true,
  "code": "ERROR_CODE",
  "message": "Human-readable error message",
  "details": {
    "additional": "context"
  }
}
```

### Common Error Codes

- `INVALID_PARAMETERS`: Missing or invalid parameters
- `FILE_NOT_FOUND`: Requested file doesn't exist
- `PERMISSION_DENIED`: Insufficient permissions
- `CONFIGURATION_ERROR`: Plugin misconfigured
- `NETWORK_ERROR`: Network/connectivity issue
- `UPLOAD_FAILED`: Cloud upload failed
- `DOWNLOAD_FAILED`: Cloud download failed
- `VALIDATION_FAILED`: Validation checks failed
- `ARCHIVE_FAILED`: Archival operation failed
- `AGENT_ERROR`: Internal agent error

## Rate Limits

No explicit rate limits, but be aware:
- **Cloud providers** have their own rate limits
- **GitHub API** has rate limits (5000/hour authenticated)
- **Large operations** may take time (compress, upload)

## Best Practices

1. **Always check responses** for errors
2. **Use appropriate operation** for task
3. **Provide all required parameters**
4. **Handle errors gracefully**
5. **Test with small files first**
6. **Monitor cloud storage usage**
7. **Validate before archiving**
8. **Search local before cloud** (faster)

## Further Reading

- [fractary-file Guide](../guides/fractary-file-guide.md)
- [fractary-docs Guide](../guides/fractary-docs-guide.md)
- [fractary-spec Guide](../guides/fractary-spec-guide.md)
- [fractary-logs Guide](../guides/fractary-logs-guide.md)
- [Troubleshooting Guide](../guides/troubleshooting.md)

---

**API Version**: 1.0 (2025-01-15)
