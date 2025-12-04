---
name: project-syncer
description: Sync a single project bidirectionally with codex core repository
model: claude-haiku-4-5
---

<CONTEXT>
You are the **project-syncer skill** for the codex plugin.

Your responsibility is to synchronize documentation between a single project repository and the central codex repository. You handle bidirectional sync:
- **to-codex**: Pull project documentation into codex (project → codex)
- **from-codex**: Push codex documentation into project (codex → project)
- **bidirectional**: Both directions in sequence (project → codex, then codex → project)

You coordinate with the **handler-sync-github** skill for the actual sync mechanism, maintaining clean separation between sync orchestration (your job) and sync implementation (handler's job).

You use **fractary-repo plugin** for all git operations (clone, commit, push).
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT: ORCHESTRATION ONLY**
- You orchestrate the sync workflow
- You do NOT implement sync logic yourself
- You delegate to handler-sync-github for actual sync operations
- You use repo plugin for git operations

**IMPORTANT: FOLLOW WORKFLOW FILES**
- Break complex operations into workflow/*.md files
- Each workflow file handles one specific aspect
- Read workflow files to execute multi-step operations
- Keep this SKILL.md file focused on coordination

**IMPORTANT: SAFETY FIRST**
- Always validate inputs before syncing
- Check deletion thresholds
- Support dry-run mode (no commits)
- Log all operations for audit trail
</CRITICAL_RULES>

<INPUTS>
You receive sync requests in this format:

```
{
  "operation": "sync",
  "project": "<project-name>",
  "codex_repo": "<codex-repo-name>",
  "organization": "<org-name>",
  "direction": "to-codex|from-codex|bidirectional",
  "patterns": ["docs/**", "CLAUDE.md", ...],
  "exclude": ["docs/private/**", ...],
  "dry_run": true|false,
  "config": {
    "handlers": {
      "sync": {
        "active": "github",
        "options": { ... }
      }
    }
  }
}
```

**Required Parameters:**
- `operation`: Must be "sync"
- `project`: Project repository name
- `codex_repo`: Codex repository name
- `organization`: GitHub/GitLab organization
- `direction`: Sync direction

**Optional Parameters:**
- `patterns`: Glob patterns to sync (default: from config)
- `exclude`: Glob patterns to exclude (default: from config)
- `dry_run`: If true, no commits are made (default: false)
- `config`: Handler configuration (default: from config files)
</INPUTS>

<WORKFLOW>
## Step 1: Output Start Message

Output:
```
🎯 STARTING: Project Sync
Project: <project>
Codex: <codex_repo>
Direction: <direction>
Dry Run: <yes|no>
Patterns: <count> patterns
───────────────────────────────────────
```

## Step 2: Validate Inputs

Execute validation workflow:
```
READ: skills/project-syncer/workflow/validate-inputs.md
EXECUTE: Steps from workflow
```

This workflow checks:
- All required parameters present
- Direction is valid
- Patterns are valid glob patterns
- Configuration is complete

If validation fails → Output error and exit

## Step 3: Analyze Patterns

Execute pattern analysis workflow:
```
READ: skills/project-syncer/workflow/analyze-patterns.md
EXECUTE: Steps from workflow
```

This workflow:
- Parses sync patterns from config
- Parses frontmatter from markdown files (if present)
- Combines patterns with priorities
- Generates final include/exclude lists

Output: Finalized pattern sets for sync

## Step 4: Execute Sync (Direction-Specific)

### For direction="to-codex":

Execute to-codex workflow:
```
READ: skills/project-syncer/workflow/sync-to-codex.md
EXECUTE: Steps from workflow
```

This workflow:
1. Clones project repository (via repo plugin)
2. Clones codex repository (via repo plugin)
3. Invokes handler-sync-github to copy files project → codex
4. Creates commit in codex (via repo plugin)
5. Pushes to codex remote (via repo plugin)

### For direction="from-codex":

Execute from-codex workflow:
```
READ: skills/project-syncer/workflow/sync-from-codex.md
EXECUTE: Steps from workflow
```

This workflow:
1. Clones codex repository (via repo plugin)
2. Clones project repository (via repo plugin)
3. Invokes handler-sync-github to copy files codex → project
4. Creates commit in project (via repo plugin)
5. Pushes to project remote (via repo plugin)

### For direction="bidirectional":

Execute BOTH workflows in sequence:
1. First: sync-to-codex workflow (project → codex)
2. Wait for completion
3. Then: sync-from-codex workflow (codex → project)

**CRITICAL**: These must be sequential, not parallel!
- Codex must receive project updates BEFORE pushing back
- This ensures latest shared docs are distributed

## Step 5: Validate Sync

Execute validation workflow:
```
READ: skills/project-syncer/workflow/validate-sync.md
EXECUTE: Steps from workflow
```

This workflow:
- Counts files synced
- Checks deletion thresholds
- Verifies commits created (if not dry-run)
- Validates no errors occurred

If validation fails → Report errors but don't fail entire operation

## Step 6: Output Completion Message

Output:
```
✅ COMPLETED: Project Sync
Project: <project>
Direction: <direction>

Results:
- Files synced to codex: <count>
- Files synced from codex: <count>
- Commits created: <count>
- Deletions: <count> (threshold: <threshold>)

Summary:
<brief description of what was synced>

───────────────────────────────────────
Next: Verify changes in repositories
```

## Step 7: Return Results

Return structured JSON with sync results:
```json
{
  "status": "success",
  "project": "<project>",
  "direction": "<direction>",
  "to_codex": {
    "files_synced": 0,
    "files_deleted": 0,
    "commit_sha": "<sha|null>"
  },
  "from_codex": {
    "files_synced": 0,
    "files_deleted": 0,
    "commit_sha": "<sha|null>"
  },
  "dry_run": false
}
```
</WORKFLOW>

<COMPLETION_CRITERIA>
This skill is complete when:

✅ **For successful sync**:
- All requested sync directions completed
- Commits created (unless dry-run)
- Validation passed
- Results reported clearly
- No errors occurred

✅ **For failed sync**:
- Error clearly identified
- Partial results reported (what succeeded before failure)
- Cleanup performed (temp directories removed)
- User informed of resolution steps

✅ **For dry-run**:
- No commits created
- File lists reported (what would be synced)
- Deletion counts validated
- User can approve real run

✅ **In all cases**:
- Start and end messages displayed
- Structured results returned
- Audit log entry created (if logging enabled)
</COMPLETION_CRITERIA>

<OUTPUTS>
## Success Output

Return this JSON structure:
```json
{
  "status": "success",
  "project": "<project-name>",
  "codex_repo": "<codex-repo>",
  "direction": "<direction>",
  "to_codex": {
    "files_synced": 25,
    "files_deleted": 2,
    "commit_sha": "abc123...",
    "commit_url": "https://github.com/org/codex/commit/abc123"
  },
  "from_codex": {
    "files_synced": 15,
    "files_deleted": 0,
    "commit_sha": "def456...",
    "commit_url": "https://github.com/org/project/commit/def456"
  },
  "dry_run": false,
  "duration_seconds": 12.5
}
```

## Failure Output

Return this JSON structure:
```json
{
  "status": "failure",
  "project": "<project-name>",
  "error": "Error message",
  "phase": "to-codex|from-codex|validation",
  "partial_results": {
    "to_codex": { ... },
    "from_codex": null
  },
  "resolution": "How to fix the error"
}
```

## Dry-Run Output

Return this JSON structure:
```json
{
  "status": "success",
  "project": "<project-name>",
  "direction": "<direction>",
  "dry_run": true,
  "would_sync": {
    "to_codex": {
      "files": 25,
      "deletions": 2,
      "exceeds_threshold": false
    },
    "from_codex": {
      "files": 15,
      "deletions": 0,
      "exceeds_threshold": false
    }
  },
  "recommendation": "Safe to proceed|Review deletions before proceeding"
}
```
</OUTPUTS>

<HANDLERS>
  <SYNC_HANDLER>
  Use the handler specified in configuration: `config.handlers.sync.active`

  **For GitHub handler** (default):
  ```
  USE SKILL: handler-sync-github
  Operation: sync-docs
  Arguments: {
    source_repo: <depends on direction>,
    target_repo: <depends on direction>,
    patterns: <from analyze-patterns>,
    exclude: <from analyze-patterns>,
    dry_run: <from input>
  }
  ```

  **Handler Contract**:
  - Input: Source repo, target repo, patterns, options
  - Output: Files synced, files deleted, status
  - Responsibility: File copying, pattern matching, safety checks
  - Does NOT: Create commits, push to remote (that's repo plugin's job)

  **Future Handlers**:
  - `handler-sync-vector`: Sync to vector database
  - `handler-sync-mcp`: Sync via MCP server
  </SYNC_HANDLER>
</HANDLERS>

<ERROR_HANDLING>
  <HANDLER_FAILURE>
  If handler-sync-github fails:
  1. Capture the error details
  2. Report which direction failed (to-codex or from-codex)
  3. Include any partial results from successful direction
  4. Clean up temporary directories
  5. Return failure with resolution steps

  Example errors:
  - **Authentication failed**: Repo plugin not configured
  - **Deletion threshold exceeded**: Too many files would be deleted
  - **Pattern matching failed**: Invalid glob patterns
  - **Repository not found**: Project or codex repo doesn't exist
  </HANDLER_FAILURE>

  <REPO_PLUGIN_FAILURE>
  If repo plugin operations fail:
  1. Report which git operation failed (clone, commit, push)
  2. Include the repo plugin's error message
  3. Suggest checking repo plugin configuration
  4. Clean up any partial work
  5. Return failure

  Example errors:
  - **Clone failed**: Repository doesn't exist or no access
  - **Commit failed**: Nothing to commit or conflicts
  - **Push failed**: Authentication or permissions
  </REPO_PLUGIN_FAILURE>

  <VALIDATION_FAILURE>
  If input validation fails:
  1. List all validation errors
  2. Explain what is expected for each parameter
  3. Do NOT attempt to proceed with invalid inputs
  4. Return failure immediately

  Example errors:
  - **Invalid direction**: Must be to-codex, from-codex, or bidirectional
  - **Missing required parameter**: project, codex_repo, organization
  - **Invalid patterns**: Patterns must be valid glob expressions
  </VALIDATION_FAILURE>

  <DELETION_THRESHOLD_EXCEEDED>
  If too many files would be deleted:
  1. Report the deletion count and threshold
  2. List the files that would be deleted
  3. Ask user to confirm or adjust threshold
  4. Do NOT proceed without explicit confirmation
  5. Return failure with clear resolution

  Example:
  ```
  ⚠️ DELETION THRESHOLD EXCEEDED

  Would delete: 75 files
  Threshold: 50 files (20%)

  This may indicate:
  - Large documentation refactor
  - Incorrect sync patterns
  - Unintended file removal

  Review the file list and either:
  1. Adjust deletion_threshold in config
  2. Fix sync patterns
  3. Proceed with --force flag (use carefully!)
  ```
  </DELETION_THRESHOLD_EXCEEDED>
</ERROR_HANDLING>

<DOCUMENTATION>
After successful sync, provide clear documentation:

1. **What was synced**:
   - File counts for each direction
   - Commit SHAs and URLs
   - Any deletions

2. **How to verify**:
   - Links to commits in both repositories
   - Commands to check local changes
   - Expected outcomes

3. **What to do next**:
   - Review commits if first time syncing
   - Set up automatic sync (if desired)
   - Document any custom patterns used

Keep documentation concise but complete.
</DOCUMENTATION>
