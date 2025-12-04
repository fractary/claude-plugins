# Workflow: Sync Files

**Purpose**: Copy files from codex repository to local cache based on patterns using the sync-docs.sh script

> **Note (v3.0)**: This workflow now supports `cache_mode` which writes to the local cache directory
> instead of a target git repository. When `cache_mode: true`, no git operations are performed
> on the target side - files are written directly to `.fractary/plugins/codex/cache/`.

## Steps

### 1. Prepare Sync Environment

Determine mode and prepare workspace:

**If cache_mode = true**:
```bash
SYNC_WORKSPACE=$(mktemp -d /tmp/codex-sync.XXXXXX)
SOURCE_DIR="$SYNC_WORKSPACE/source"
TARGET_DIR="<target_path>"  # e.g., .fractary/plugins/codex/cache/org/project
CACHE_MODE=true
```

**If cache_mode = false** (legacy):
```bash
SYNC_WORKSPACE=$(mktemp -d /tmp/codex-sync.XXXXXX)
SOURCE_DIR="$SYNC_WORKSPACE/source"
TARGET_DIR="$SYNC_WORKSPACE/target"
CACHE_MODE=false
```

Output: "Workspace created: $SYNC_WORKSPACE (mode: ${CACHE_MODE ? 'cache' : 'git'})"

### 2. Clone Source Repository

Use repo plugin or git to clone source (codex) repository:
- If sparse_checkout enabled: clone only patterns needed
- Otherwise: full clone

Output: "Cloning source: <source_repo>"

**Note**: Actual git clone is handled by repo plugin or lib/fetch-github.sh

### 3. Prepare Target Directory

**If cache_mode = true**:
- Ensure cache directory exists: `mkdir -p "$TARGET_DIR"`
- No git clone needed (local directory)
- Output: "Using cache directory: $TARGET_DIR"

**If cache_mode = false** (legacy):
- Use repo plugin to clone target repository
- Output: "Cloning target: <target_repo>"

### 4. Execute Sync Script

Run the sync-docs.sh script:

```bash
./skills/handler-sync-github/scripts/sync-docs.sh \
  --source "$SOURCE_DIR" \
  --target "$TARGET_DIR" \
  --include "$(echo "${include_patterns[@]}" | tr ' ' ',')" \
  --exclude "$(echo "${exclude_patterns[@]}" | tr ' ' ',')" \
  --dry-run "$DRY_RUN" \
  --deletion-threshold "$DELETION_THRESHOLD" \
  --deletion-threshold-percent "$DELETION_THRESHOLD_PERCENT" \
  --cache-mode "$CACHE_MODE" \
  --json
```

The script will:
1. Find all files in source matching include patterns
2. Exclude files matching exclude patterns
3. Compare with target directory
4. Copy new/modified files to target
5. Track deletions (files in target not in source)
6. Check deletion thresholds
7. Apply changes (unless dry-run)
8. Return JSON results

### 5. Parse Script Results

Script returns JSON:
```json
{
  "success": true,
  "files_synced": 25,
  "files_added": 10,
  "files_modified": 15,
  "files_deleted": 2,
  "deletion_threshold_exceeded": false,
  "deletion_count": 2,
  "deletion_threshold": 50,
  "deletion_percent": 7.4,
  "deletion_threshold_percent": 20,
  "files": {
    "added": ["docs/new.md", ...],
    "modified": ["CLAUDE.md", ...],
    "deleted": ["docs/old.md", ...]
  },
  "dry_run": false,
  "cache_mode": true,
  "error": null
}
```

If success is false:
- Extract error message
- Clean up workspace
- Return failure to handler skill

### 6. Update Cache Index (if cache_mode)

**If cache_mode = true AND not dry-run**:

For each synced file, update the cache index:
```bash
for file in ${files_added[@]} ${files_modified[@]}; do
  uri="codex://${org}/${project}/${file}"
  lib/cache-manager.sh put "$uri" \
    --content-file "$TARGET_DIR/$file" \
    --source "github" \
    --synced-via "sync-project"
done
```

Output: "Cache index updated with ${files_synced} entries"

**If cache_mode = false** (legacy):
- Skip this step

### 7. Validate Results

Check the results:
- Files synced >= 0
- Deletion count <= deletion threshold (if not exceeded flag set)
- Files list makes sense
- Cache index updated (if cache_mode)
- No unexpected errors

If validation fails:
- Output warning
- Include in results
- Don't fail unless critical

### 8. Cleanup Workspace

If dry-run:
- Keep workspace for inspection
- Output: "Workspace preserved for review: $SYNC_WORKSPACE"

If not dry-run:
- Remove temporary directories (source clone only)
- **If cache_mode**: Keep target (cache) directory
- Output: "Workspace cleaned up"

### 9. Return Results to Handler

Return the parsed JSON results to handler skill:

**If cache_mode = true**:
```json
{
  "status": "success",
  "files_synced": 25,
  "files_deleted": 2,
  "cache_path": ".fractary/plugins/codex/cache/org/project",
  "cache_index_updated": true,
  "dry_run": false
}
```

**If cache_mode = false** (legacy):
The handler will pass results to project-syncer.
The project-syncer will use repo plugin to commit and push.

## Script Behavior

### Pattern Matching

**Include Patterns** (all must match):
- `docs/**` - All files in docs/ recursively
- `CLAUDE.md` - Specific file in root
- `.claude/**` - All files in .claude/ recursively

**Exclude Patterns** (any match excludes):
- `**/.git/**` - Git directories
- `**/node_modules/**` - Node modules
- `**/*.log` - Log files
- `**/.env*` - Environment files

### Deletion Handling

Files are considered for deletion if:
1. They exist in target
2. They match include patterns
3. They don't exist in source (after applying patterns)

Deletions are BLOCKED if:
- Deletion count > deletion_threshold (absolute)
- OR deletion percent > deletion_threshold_percent

User must:
- Review deletion list
- Adjust thresholds if intentional
- Fix patterns if unintentional

### Dry-Run Mode

When dry_run = true:
- No files are actually copied
- No files are actually deleted
- Results show what WOULD happen
- Workspace is preserved for inspection
- User can review before real sync

## Error Handling

### Source Repository Issues

If source clone fails:
- Error: "Failed to clone source repository"
- Possible causes: Authentication, repository not found, network error
- Resolution: Check repo plugin configuration

### Target Repository Issues

If target clone fails:
- Error: "Failed to clone target repository"
- Possible causes: Authentication, repository not found, network error
- Resolution: Check repo plugin configuration

### Pattern Matching Issues

If pattern matching fails:
- Error: "Invalid glob pattern: <pattern>"
- Possible causes: Invalid syntax, unsupported pattern
- Resolution: Fix pattern in configuration

### File Copy Issues

If file copy fails:
- Error: "Failed to copy file: <file>"
- Possible causes: Permission denied, disk full, path too long
- Resolution: Check permissions and disk space

### Deletion Threshold Issues

If deletion threshold exceeded:
- Warning: "Deletion threshold exceeded"
- Details: Show deletion count and threshold
- List: Show files that would be deleted
- Resolution: Review deletions or adjust threshold

## Outputs

**Success (cache_mode = true)**:
```json
{
  "status": "success",
  "files_synced": 25,
  "files_deleted": 2,
  "deletion_threshold_exceeded": false,
  "files_list": {...},
  "cache_path": ".fractary/plugins/codex/cache/org/project",
  "cache_index_updated": true,
  "dry_run": false
}
```

**Success (cache_mode = false, legacy)**:
```json
{
  "status": "success",
  "files_synced": 25,
  "files_deleted": 2,
  "deletion_threshold_exceeded": false,
  "files_list": {...},
  "dry_run": false
}
```

**Failure**:
```json
{
  "status": "failure",
  "error": "Error message",
  "phase": "clone|sync|cache-index|validate"
}
```
