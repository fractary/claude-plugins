# Workflow: Sync From Codex

**Purpose**: Sync documentation from codex repository to project repository (codex → project)

## Steps

### 1. Prepare Sync Environment

Output: "Preparing to sync codex → project..."

Set up variables:
- `CODEX_REPO`: Full codex repository name (org/codex.org.tld)
- `PROJECT_REPO`: Full repository name (org/project)
- `INCLUDE_PATTERNS`: From analyze-patterns workflow
- `EXCLUDE_PATTERNS`: From analyze-patterns workflow
- `DRY_RUN`: From input

### 2. Delegate to Sync Handler

Invoke the handler-sync-github skill:

```
USE SKILL: handler-sync-github
Operation: sync-docs
Arguments: {
  "source_repo": "<org>/<codex>",
  "target_repo": "<org>/<project>",
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
    "commit_message": "sync: Update docs from codex",
    "push": true
  },
  "repo_plugin": {
    "use_for_git_ops": true
  }
}
```

The handler will:
1. Clone both repositories (via repo plugin)
2. Copy files matching patterns from codex → project
3. Check deletion thresholds
4. Create commit in project (via repo plugin) if not dry-run
5. Push to project remote (via repo plugin) if not dry-run

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
  "commit_sha": "def456...",
  "commit_url": "https://github.com/org/project/commit/def456",
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
✓ Sync from codex completed
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
  "direction": "from-codex",
  "files_synced": 15,
  "files_deleted": 0,
  "files_modified": 8,
  "files_added": 7,
  "commit_sha": "def456...",
  "commit_url": "https://github.com/org/project/commit/def456",
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

The handler must understand this structure to copy files correctly.

## Outputs

**Success**:
```json
{
  "status": "success",
  "direction": "from-codex",
  "files_synced": 15,
  "files_deleted": 0,
  "commit_sha": "def456...",
  "commit_url": "https://github.com/org/project/commit/def456",
  "dry_run": false
}
```

**Failure**:
```json
{
  "status": "failure",
  "direction": "from-codex",
  "error": "Error message",
  "phase": "clone|copy|commit|push",
  "partial_results": { ... }
}
```
