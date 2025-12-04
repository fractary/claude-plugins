# Workflow: Sync From Codex

**Purpose**: Sync documentation from codex repository to local cache (codex → cache)

> **Note**: As of v3.0, sync-from-codex writes to the ephemeral cache directory at
> `.fractary/plugins/codex/cache/` instead of the project root. This cache is
> gitignored and serves as the source for MCP server `codex://` resource access.

## Steps

### 1. Prepare Sync Environment

Output: "Preparing to sync codex → cache..."

Set up variables:
- `CODEX_REPO`: Full codex repository name (org/codex.org.tld)
- `PROJECT_REPO`: Full repository name (org/project)
- `ORGANIZATION`: Organization name (from config)
- `INCLUDE_PATTERNS`: From analyze-patterns workflow
- `EXCLUDE_PATTERNS`: From analyze-patterns workflow
- `DRY_RUN`: From input
- `CACHE_MODE`: true (always enabled for sync-from-codex in v3.0)
- `CACHE_PATH`: `.fractary/plugins/codex/cache/{org}/{project}`

Ensure cache directory exists:
```bash
scripts/setup-cache-dir.sh
```

### 2. Delegate to Sync Handler

Invoke the handler-sync-github skill:

```
USE SKILL: handler-sync-github
Operation: sync-docs
Arguments: {
  "source_repo": "<org>/<codex>",
  "target_path": ".fractary/plugins/codex/cache/<org>/<project>",
  "direction": "to-cache",
  "patterns": {
    "include": <INCLUDE_PATTERNS>,
    "exclude": <EXCLUDE_PATTERNS>
  },
  "options": {
    "dry_run": <DRY_RUN>,
    "deletion_threshold": <from config>,
    "deletion_threshold_percent": <from config>,
    "sparse_checkout": <from config>,
    "cache_mode": true,
    "update_cache_index": true
  }
}
```

The handler will:
1. Clone codex repository (sparse checkout)
2. Copy files matching patterns from codex → cache directory
3. Check deletion thresholds
4. Update cache index via `lib/cache-manager.sh`
5. NO git commit/push (cache is ephemeral, gitignored)

### 3. Process Handler Results

Handler returns:
```json
{
  "status": "success|failure",
  "files_synced": 15,
  "files_deleted": 0,
  "files_modified": 8,
  "files_added": 7,
  "deletion_threshold_exceeded": false,
  "cache_path": ".fractary/plugins/codex/cache/org/project",
  "cache_index_updated": true,
  "dry_run": false
}
```

If handler status is "failure":
- Output error from handler
- Return failure to parent skill
- Exit workflow

If handler status is "success":
- Continue to step 4

### 4. Validate Sync Results

Check the results:
- Files synced > 0 OR dry_run = true (okay if no changes in dry-run)
- Deletion threshold not exceeded
- Cache index updated (if not dry-run)

If validation fails:
- Output warning (may not be critical)
- Include in results but don't fail

### 5. Output Sync Summary

Output:
```
✓ Sync from codex to cache completed
Files synced: <files_synced>
Files added: <files_added>
Files modified: <files_modified>
Files deleted: <files_deleted>
Cache path: <cache_path>
Cache index: updated
```

If dry-run:
```
✓ Dry-run completed (no changes made)
Would sync: <files_synced> files
Would delete: <files_deleted> files
Threshold check: <passed|exceeded>
```

### 6. Return Results

Return to parent skill:
```json
{
  "status": "success",
  "direction": "from-codex",
  "mode": "cache",
  "files_synced": 15,
  "files_deleted": 0,
  "files_modified": 8,
  "files_added": 7,
  "cache_path": ".fractary/plugins/codex/cache/org/project",
  "cache_index_updated": true,
  "dry_run": false,
  "duration_seconds": 6.5
}
```

## Error Handling

### Handler Fails

If handler-sync-github fails:
- Capture error message
- Return failure to parent skill
- Include partial results if any

Common errors:
- **Repository not found**: Check organization and repo names
- **Authentication failed**: Configure GITHUB_TOKEN or repo plugin
- **Deletion threshold exceeded**: Adjust threshold or review deletions
- **Cache directory inaccessible**: Check permissions on `.fractary/` directory

### Cache Index Update Fails

If cache index update fails:
- Files may still be synced to cache
- Warn user that MCP server may not see new files
- Suggest running `/fractary-codex:cache-health` to diagnose

## Special Considerations

### Codex Structure

The codex repository typically has this structure:
```
codex.org.com/
├── projects/
│   ├── project1/
│   │   ├── docs/
│   │   └── CLAUDE.md
│   ├── project2/
│   │   ├── docs/
│   │   └── CLAUDE.md
├── shared/
│   ├── standards/
│   ├── guides/
│   └── templates/
└── systems/
    └── interfaces/
```

When syncing FROM codex:
- Project-specific docs come from `projects/<project>/`
- Shared docs come from `shared/`
- System interfaces come from `systems/`

The handler must understand this structure to copy files correctly to the cache.

### Cache Mode (v3.0)

In v3.0, sync-from-codex always uses cache mode:
- Files are written to `.fractary/plugins/codex/cache/{org}/{project}/`
- Cache index is updated with file metadata and TTL
- No git commit/push (cache is ephemeral, gitignored)
- MCP server reads from cache using `codex://` URIs

This approach:
- Keeps project repository clean (no codex files committed)
- Enables on-demand fetch for documents not in cache
- Supports TTL-based expiration and refresh

## Outputs

**Success**:
```json
{
  "status": "success",
  "direction": "from-codex",
  "mode": "cache",
  "files_synced": 15,
  "files_deleted": 0,
  "cache_path": ".fractary/plugins/codex/cache/org/project",
  "cache_index_updated": true,
  "dry_run": false
}
```

**Failure**:
```json
{
  "status": "failure",
  "direction": "from-codex",
  "mode": "cache",
  "error": "Error message",
  "phase": "clone|copy|cache-index",
  "partial_results": { ... }
}
```
