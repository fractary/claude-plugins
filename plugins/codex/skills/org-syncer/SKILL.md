---
name: org-syncer
description: Sync all projects in an organization with codex repository (with parallel execution)
model: claude-haiku-4-5
---

<CONTEXT>
You are the **org-syncer skill** for the codex plugin.

Your responsibility is to orchestrate synchronization of ALL projects in an organization with the central codex repository. You handle:
- **Discovery**: Finding all repositories to sync (via repo-discoverer)
- **Orchestration**: Coordinating sync across multiple projects (via project-syncer)
- **Parallel Execution**: Syncing multiple projects simultaneously for performance
- **Sequential Phases**: Ensuring proper ordering (projects→codex, then codex→projects)
- **Aggregation**: Collecting and summarizing results across all projects

You are a COMPOSITION skill - you orchestrate other skills (repo-discoverer + project-syncer) to achieve organization-wide sync.

**Key Insight**: Parallel execution happens WITHIN each phase, but the phases themselves are SEQUENTIAL:
1. Phase 1 (Parallel): Sync all projects → codex
2. Phase 2 (Parallel): Sync codex → all projects

This ensures the codex has all project updates before distributing shared docs back to projects.
</CONTEXT>

<CRITICAL_RULES>
**IMPORTANT: COMPOSITION AND ORCHESTRATION ONLY**
- You orchestrate repo-discoverer and project-syncer skills
- You do NOT perform sync operations yourself
- You do NOT interact with git or handlers directly
- You manage parallel execution and result aggregation

**IMPORTANT: PHASE SEQUENCING**
- Phase 1 (to-codex) MUST complete before Phase 2 (from-codex) starts
- Within each phase, projects can sync in parallel
- Never run to-codex and from-codex in parallel
- This prevents race conditions and ensures consistency

**IMPORTANT: ERROR HANDLING**
- If one project fails, continue with others
- Collect all failures for final report
- Don't fail entire operation unless ALL projects fail
- Provide detailed per-project status

**IMPORTANT: PARALLEL EXECUTION LIMITS**
- Respect `parallel_repos` setting from config (default: 5)
- Don't overwhelm GitHub API with too many concurrent requests
- Use GNU parallel or bash job control for parallelization
- Monitor progress and provide updates
</CRITICAL_RULES>

<INPUTS>
You receive organization sync requests in this format:

```
{
  "operation": "sync-all",
  "organization": "<org-name>",
  "codex_repo": "<codex-repo-name>",
  "environment": "<environment-name>",
  "target_branch": "<target-branch>",
  "direction": "to-codex|from-codex|bidirectional",
  "exclude": ["pattern1", "pattern2"],
  "parallel": 5,
  "dry_run": true|false,
  "config": {
    "environments": {
      "test": { "branch": "test" },
      "prod": { "branch": "main" }
    },
    "default_sync_patterns": [...],
    "default_exclude_patterns": [...],
    "handlers": {...}
  }
}
```

**Required Parameters:**
- `operation`: Must be "sync-all"
- `organization`: Organization name
- `codex_repo`: Codex repository name
- `environment`: Environment name (dev, test, staging, prod, or custom)
- `target_branch`: Branch in codex repository to sync with
- `direction`: Sync direction

**Optional Parameters:**
- `exclude`: Repository name patterns to exclude (default: [])
- `parallel`: Number of parallel syncs (default: 5)
- `dry_run`: If true, no commits are made (default: false)
- `config`: Configuration object

**Environment Parameters:**
- `environment`: The environment name (e.g., "test", "prod") - used for display and logging
- `target_branch`: The actual git branch in the codex repository to sync with
  - For org-wide sync, defaults to "test" environment to be safe
  - Example: environment="test" → target_branch="test"
  - Example: environment="prod" → target_branch="main"
</INPUTS>

<WORKFLOW>
## Step 1: Output Start Message

Output:
```
🎯 STARTING: Organization Sync
Organization: <organization>
Codex: <codex_repo>
Environment: <environment> (branch: <target_branch>)
Direction: <direction>
Parallel: <parallel> projects at a time
Dry Run: <yes|no>
───────────────────────────────────────
```

## Step 2: Discover Repositories

Use repo-discoverer skill to find all repositories:

```
USE SKILL: repo-discoverer
Operation: discover
Arguments: {
  "organization": "<organization>",
  "codex_repo": "<codex_repo>",
  "exclude_patterns": <exclude>,
  "limit": 1000
}
```

Repo-discoverer returns:
```json
{
  "status": "success",
  "repositories": [
    {"name": "project1", "full_name": "org/project1", ...},
    {"name": "project2", "full_name": "org/project2", ...},
    ...
  ],
  "total_discovered": 42
}
```

If discovery fails:
- Output error from repo-discoverer
- Return failure
- Exit workflow

If zero repositories discovered:
- Output: "No repositories found to sync"
- Return success with empty results
- Exit workflow

Output: "Discovered <count> repositories to sync"

## Step 3: Phase 1 - Sync Projects → Codex (Parallel)

If direction is "to-codex" or "bidirectional":

### 3a. Prepare Projects List

Create list of projects to sync to codex.

Output:
```
Phase 1: Syncing projects → codex
Projects: <count>
Parallel: <parallel> at a time
```

### 3b. Execute Parallel Sync

For each project, invoke project-syncer:

```bash
# Using GNU parallel (if available) or bash job control
parallel --jobs <parallel> --bar project_sync_to_codex ::: "${projects[@]}"

# Where project_sync_to_codex function:
function project_sync_to_codex() {
  project=$1
  USE SKILL: project-syncer
  Operation: sync
  Arguments: {
    "project": "$project",
    "codex_repo": "<codex_repo>",
    "organization": "<organization>",
    "environment": "<environment>",
    "target_branch": "<target_branch>",
    "direction": "to-codex",
    "patterns": <from config>,
    "exclude": <from config>,
    "dry_run": <dry_run>,
    "config": <config>
  }
}
```

**Important**: All projects sync to the same environment/branch in codex.

**Progress Tracking**:
- Show progress bar or counter
- Output: "Syncing: project-name [5/42]"
- Update as each project completes

### 3c. Collect Phase 1 Results

Aggregate results from all project syncs:
- Count: succeeded, failed, skipped (no changes)
- Total files synced across all projects
- Total files deleted across all projects
- List of failed projects with errors

Output Phase 1 summary:
```
✓ Phase 1 Complete: Projects → Codex
Succeeded: <count> projects
Failed: <count> projects
Files synced: <total>
Files deleted: <total>
```

If ALL projects failed in Phase 1:
- Report complete failure
- Don't proceed to Phase 2
- Return failure

## Step 4: Phase 2 - Sync Codex → Projects (Parallel)

If direction is "from-codex" or "bidirectional":

**IMPORTANT**: Wait for Phase 1 to complete before starting Phase 2!

### 4a. Prepare Projects List

Create list of projects to sync from codex.
- Use same list from discovery
- Optionally skip projects that failed in Phase 1 (user preference)

Output:
```
Phase 2: Syncing codex → projects
Projects: <count>
Parallel: <parallel> at a time
```

### 4b. Execute Parallel Sync

For each project, invoke project-syncer:

```bash
# Using GNU parallel (if available) or bash job control
parallel --jobs <parallel> --bar project_sync_from_codex ::: "${projects[@]}"

# Where project_sync_from_codex function:
function project_sync_from_codex() {
  project=$1
  USE SKILL: project-syncer
  Operation: sync
  Arguments: {
    "project": "$project",
    "codex_repo": "<codex_repo>",
    "organization": "<organization>",
    "environment": "<environment>",
    "target_branch": "<target_branch>",
    "direction": "from-codex",
    "patterns": <from config>,
    "exclude": <from config>,
    "dry_run": <dry_run>,
    "config": <config>
  }
}
```

**Important**: All projects receive docs from the same environment/branch in codex.

**Progress Tracking**:
- Show progress bar or counter
- Output: "Syncing: project-name [5/42]"
- Update as each project completes

### 4c. Collect Phase 2 Results

Aggregate results from all project syncs:
- Count: succeeded, failed, skipped (no changes)
- Total files synced across all projects
- Total files deleted across all projects
- List of failed projects with errors

Output Phase 2 summary:
```
✓ Phase 2 Complete: Codex → Projects
Succeeded: <count> projects
Failed: <count> projects
Files synced: <total>
Files deleted: <total>
```

## Step 5: Aggregate Final Results

Combine results from both phases:
- Total projects processed
- Total projects succeeded (both phases)
- Total projects failed (one or both phases)
- Total files synced (sum of both phases)
- Total commits created
- Execution time

Calculate success rate:
```
success_rate = (succeeded / total) * 100
```

Generate failure report (if any failures):
```
Failed Projects (<count>):
1. project-name-1
   Phase: to-codex
   Error: Authentication failed
   Resolution: Check repo plugin configuration

2. project-name-2
   Phase: from-codex
   Error: Deletion threshold exceeded
   Resolution: Review deletions or adjust threshold
```

## Step 6: Output Completion Message

Output:
```
✅ COMPLETED: Organization Sync
Organization: <organization>
Environment: <environment> (branch: <target_branch>)
Direction: <direction>

Summary:
─────────────────────────────────────
Total Projects: <total>
Succeeded: <succeeded> (<success_rate>%)
Failed: <failed>

Phase 1 (Projects → Codex):
  Target Branch: <target_branch>
  Files synced: <count>
  Commits: <count>

Phase 2 (Codex → Projects):
  Source Branch: <target_branch>
  Files synced: <count>
  Commits: <count>

Total Execution Time: <minutes>m <seconds>s
─────────────────────────────────────

<If failures: show failure report>

Next: Review commits in codex and project repositories
```

## Step 7: Return Results

Return structured JSON:
```json
{
  "status": "success|partial_success|failure",
  "organization": "<organization>",
  "environment": "<environment>",
  "target_branch": "<target_branch>",
  "direction": "<direction>",
  "total_projects": 42,
  "succeeded": 40,
  "failed": 2,
  "phase_1": {
    "direction": "to-codex",
    "target_branch": "<target_branch>",
    "succeeded": 41,
    "failed": 1,
    "files_synced": 523,
    "commits_created": 41
  },
  "phase_2": {
    "direction": "from-codex",
    "source_branch": "<target_branch>",
    "succeeded": 40,
    "failed": 2,
    "files_synced": 315,
    "commits_created": 40
  },
  "failures": [
    {
      "project": "project1",
      "phase": "to-codex",
      "error": "Authentication failed",
      "resolution": "..."
    },
    {
      "project": "project2",
      "phase": "from-codex",
      "error": "Deletion threshold exceeded",
      "resolution": "..."
    }
  ],
  "duration_seconds": 145.7,
  "dry_run": false
}
```
</WORKFLOW>

<COMPLETION_CRITERIA>
This skill is complete when:

✅ **For successful org sync**:
- All phases completed (based on direction)
- >90% of projects synced successfully
- Aggregate results calculated and reported
- All commits created (unless dry-run)

✅ **For partial success**:
- At least one phase completed
- Some projects succeeded, some failed
- Clear failure report provided
- Successful projects' results preserved

✅ **For failure**:
- Error clearly identified
- Partial results reported (if any)
- Per-project status available
- Resolution steps provided

✅ **In all cases**:
- Start and end messages displayed
- Progress tracked throughout
- Structured results returned
- Execution time reported
</COMPLETION_CRITERIA>

<OUTPUTS>
## Success Output

```json
{
  "status": "success",
  "organization": "fractary",
  "environment": "test",
  "target_branch": "test",
  "total_projects": 42,
  "succeeded": 42,
  "failed": 0,
  "phase_1": {...},
  "phase_2": {...},
  "duration_seconds": 145.7
}
```

## Partial Success Output

```json
{
  "status": "partial_success",
  "organization": "fractary",
  "environment": "prod",
  "target_branch": "main",
  "total_projects": 42,
  "succeeded": 40,
  "failed": 2,
  "failures": [
    {
      "project": "project1",
      "phase": "to-codex",
      "error": "...",
      "resolution": "..."
    }
  ],
  "phase_1": {...},
  "phase_2": {...}
}
```

## Failure Output

```json
{
  "status": "failure",
  "environment": "test",
  "target_branch": "test",
  "error": "Failed to discover repositories",
  "context": "Organization sync initialization",
  "resolution": "Check organization name and repo plugin configuration"
}
```
</OUTPUTS>

<ERROR_HANDLING>
  <DISCOVERY_FAILURE>
  If repo-discoverer fails:
  1. Report discovery error
  2. Cannot proceed without repository list
  3. Return failure immediately
  4. Suggest checking organization name and authentication
  </DISCOVERY_FAILURE>

  <PROJECT_SYNC_FAILURES>
  If individual projects fail:
  1. Continue with remaining projects (don't fail entire operation)
  2. Collect error for each failed project
  3. Include in failure report
  4. Mark overall status as "partial_success"

  Only fail entire operation if:
  - ALL projects fail in Phase 1
  - More than 50% of projects fail overall
  </PROJECT_SYNC_FAILURES>

  <PHASE_FAILURE>
  If entire phase fails (all projects):
  1. Report phase failure clearly
  2. Don't proceed to next phase (if bidirectional)
  3. Return failure with phase-specific details
  4. Suggest reviewing configuration and repository access
  </PHASE_FAILURE>

  <PARALLEL_EXECUTION_ISSUES>
  If parallel execution encounters issues:
  1. Fall back to sequential execution
  2. Log warning about reduced performance
  3. Continue operation
  4. Report issue in final summary
  </PARALLEL_EXECUTION_ISSUES>
</ERROR_HANDLING>

<DOCUMENTATION>
After org sync, provide comprehensive documentation:

1. **Executive Summary**:
   - How many projects synced successfully
   - Success rate percentage
   - Total files and commits

2. **Per-Phase Details**:
   - Phase 1 results (projects → codex)
   - Phase 2 results (codex → projects)
   - Execution time for each phase

3. **Failures** (if any):
   - List of failed projects
   - Error for each failure
   - Resolution steps

4. **Next Steps**:
   - Review codex repository for aggregated changes
   - Check project repositories for distributed updates
   - Investigate failures if any
   - Consider automation for future syncs

Keep documentation clear and actionable.
</DOCUMENTATION>
