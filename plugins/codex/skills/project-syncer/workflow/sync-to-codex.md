# Workflow: Sync To Codex

**Purpose**: Sync documentation from project repository to codex repository (project → codex)

## Steps

### 1. Prepare Sync Environment

Output: "Preparing to sync project → codex..."

Set up variables:
- `PROJECT_REPO`: Full repository name (org/project)
- `CODEX_REPO`: Full codex repository name (org/codex.org.tld)
- `INCLUDE_PATTERNS`: From analyze-patterns workflow
- `EXCLUDE_PATTERNS`: From analyze-patterns workflow
- `DRY_RUN`: From input

### 2. Delegate to Sync Handler

Invoke the handler-sync-github skill:

```
USE SKILL: handler-sync-github
Operation: sync-docs
Arguments: {
  "source_repo": "<org>/<project>",
  "target_repo": "<org>/<codex>",
  "direction": "to-target",
  "patterns": {
    "include": <INCLUDE_PATTERNS>,
    "exclude": <EXCLUDE_PATTERNS>
  },
  "options": {
    "dry_run": <DRY_RUN>,
    "deletion_threshold": <from config>,
    "deletion_threshold_percent": <from config>,
    "sparse_checkout": <from config>,
    "create_commit": true,
    "commit_message": "sync: Update docs from <project>",
    "push": true
  },
  "repo_plugin": {
    "use_for_git_ops": true
  }
}
```

The handler will:
1. Clone both repositories (via repo plugin)
2. Copy files matching patterns from project → codex
3. Check deletion thresholds
4. Create commit in codex (via repo plugin) if not dry-run
5. Push to codex remote (via repo plugin) if not dry-run

### 3. Process Handler Results

Handler returns:
```json
{
  "status": "success|failure",
  "files_synced": 25,
  "files_deleted": 2,
  "files_modified": 15,
  "files_added": 10,
  "deletion_threshold_exceeded": false,
  "commit_sha": "abc123...",
  "commit_url": "https://github.com/org/codex/commit/abc123",
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
- Commit created (if not dry-run)

If validation fails:
- Output warning (may not be critical)
- Include in results but don't fail

### 5. Output Sync Summary

Output:
```
✓ Sync to codex completed
Files synced: <files_synced>
Files added: <files_added>
Files modified: <files_modified>
Files deleted: <files_deleted>
Commit: <commit_sha>
URL: <commit_url>
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
  "direction": "to-codex",
  "files_synced": 25,
  "files_deleted": 2,
  "files_modified": 15,
  "files_added": 10,
  "commit_sha": "abc123...",
  "commit_url": "https://github.com/org/codex/commit/abc123",
  "dry_run": false,
  "duration_seconds": 8.2
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
- **Authentication failed**: Configure repo plugin
- **Deletion threshold exceeded**: Adjust threshold or review deletions
- **Merge conflict**: Resolve conflicts manually

### Repo Plugin Fails

If repo plugin operations fail:
- Capture error from repo plugin
- Return failure to parent skill
- Suggest checking repo plugin configuration

Common errors:
- **Clone failed**: No access to repository
- **Commit failed**: Nothing to commit or invalid state
- **Push failed**: Permission denied or conflicts

## Outputs

**Success**:
```json
{
  "status": "success",
  "direction": "to-codex",
  "files_synced": 25,
  "files_deleted": 2,
  "commit_sha": "abc123...",
  "commit_url": "https://github.com/org/codex/commit/abc123",
  "dry_run": false
}
```

**Failure**:
```json
{
  "status": "failure",
  "direction": "to-codex",
  "error": "Error message",
  "phase": "clone|copy|commit|push",
  "partial_results": { ... }
}
```
