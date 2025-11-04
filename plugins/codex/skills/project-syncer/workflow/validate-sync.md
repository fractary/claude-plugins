# Workflow: Validate Sync

**Purpose**: Validate sync results and check for issues after sync operation

## Steps

### 1. Collect Sync Results

Gather results from completed sync operations:
- `to_codex_results`: Results from sync-to-codex workflow (if executed)
- `from_codex_results`: Results from sync-from-codex workflow (if executed)
- `dry_run`: Whether this was a dry-run

### 2. Validate File Counts

For each completed sync direction:

Check that:
- `files_synced` is a non-negative number
- `files_deleted` is a non-negative number
- If NOT dry-run: `files_synced + files_deleted > 0` OR operation explicitly had no changes
- Total file count makes sense (synced + deleted ≤ reasonable limit)

If validation fails:
- Output warning: "Unexpected file counts in results"
- Include in validation report
- Don't fail (this is informational)

### 3. Check Deletion Thresholds

For each completed sync direction:

Compare deletions against thresholds:
- Absolute threshold: `config.handlers.sync.options.github.deletion_threshold` (default: 50)
- Percentage threshold: `config.handlers.sync.options.github.deletion_threshold_percent` (default: 20%)

Calculate:
```
deletion_count = files_deleted
total_files = files_synced + files_deleted
deletion_percent = (files_deleted / total_files) * 100
```

Check if exceeded:
```
exceeded_absolute = deletion_count > absolute_threshold
exceeded_percent = deletion_percent > percent_threshold
threshold_exceeded = exceeded_absolute OR exceeded_percent
```

If threshold exceeded:
- Output warning: "⚠️ Deletion threshold exceeded"
- Show: "Deleted <count> files (<percent>%)"
- Show: "Thresholds: <absolute> files or <percent>%"
- Recommendation: "Review deletions before proceeding with real sync"
- Mark validation as WARNING (not failure)

If within threshold:
- Output: "✓ Deletion threshold check passed"

### 4. Verify Commits Created

If NOT dry-run:

For each completed sync direction:
- Check that `commit_sha` is present and non-empty
- Check that `commit_url` is present and valid URL format
- If missing: Output warning "No commit created (may indicate no changes)"

If dry-run:
- Verify NO commits were created
- Check that `commit_sha` is null or empty
- If commit exists in dry-run: **ERROR** - this is a bug

### 5. Check for Errors

Review any errors from sync operations:
- Handler errors
- Repo plugin errors
- Pattern matching errors
- Authentication errors

If errors present:
- List each error clearly
- Categorize: CRITICAL (sync failed) vs WARNING (sync succeeded with issues)
- Include resolution steps for each

### 6. Generate Validation Report

Create summary report:

```
Validation Report
═════════════════

To Codex:
  Status: <success|failure|skipped>
  Files synced: <count>
  Files deleted: <count>
  Deletion threshold: <passed|exceeded|N/A>
  Commit: <sha or "none (dry-run)">

From Codex:
  Status: <success|failure|skipped>
  Files synced: <count>
  Files deleted: <count>
  Deletion threshold: <passed|exceeded|N/A>
  Commit: <sha or "none (dry-run)">

Overall Status: <SUCCESS|WARNING|FAILURE>

Issues Found: <count>
<List of issues if any>

Recommendations:
<List of recommendations if any>
```

### 7. Determine Overall Status

Calculate overall validation status:

- **SUCCESS**: Both directions succeeded, no warnings, all checks passed
- **SUCCESS_WITH_WARNINGS**: Sync succeeded but has warnings (e.g., high deletions, no changes)
- **PARTIAL_SUCCESS**: One direction succeeded, one failed
- **FAILURE**: All sync operations failed

### 8. Return Validation Results

Return validation object:
```json
{
  "validation_status": "success|success_with_warnings|partial_success|failure",
  "checks": {
    "file_counts": "passed|warning|failed",
    "deletion_thresholds": "passed|warning|exceeded",
    "commits_created": "passed|warning|failed",
    "errors": "none|warnings|critical"
  },
  "issues": [
    {
      "severity": "info|warning|error",
      "category": "deletions|commits|files|errors",
      "message": "Description of issue",
      "resolution": "How to fix"
    }
  ],
  "recommendations": [
    "Review deletion list before production sync",
    "Verify commit URLs to ensure changes are correct",
    ...
  ],
  "summary": {
    "total_files_synced": 40,
    "total_files_deleted": 2,
    "total_commits": 2,
    "sync_directions": 2
  }
}
```

## Validation Rules

### File Count Validation

- **PASS**: Reasonable file counts (0-10,000 per direction)
- **WARNING**: Very high file counts (>10,000) - may indicate pattern issue
- **FAIL**: Negative counts or impossible numbers

### Deletion Threshold Validation

- **PASS**: Deletions within both absolute and percentage thresholds
- **WARNING**: Deletions exceed threshold - user should review
- **EXCEEDED**: Deletions significantly exceed threshold - operation should be blocked (unless --force)

### Commit Validation

- **PASS**: Commit created when expected (not dry-run), or no commit when expected (dry-run or no changes)
- **WARNING**: No commit but files were synced - may indicate issue
- **FAIL**: Commit exists in dry-run mode - this is a bug

### Error Validation

- **NONE**: No errors occurred
- **WARNINGS**: Minor issues that didn't prevent sync
- **CRITICAL**: Errors that caused sync to fail

## Outputs

**Success (No Issues)**:
```json
{
  "validation_status": "success",
  "checks": {
    "file_counts": "passed",
    "deletion_thresholds": "passed",
    "commits_created": "passed",
    "errors": "none"
  },
  "issues": [],
  "recommendations": [],
  "summary": {
    "total_files_synced": 40,
    "total_files_deleted": 2,
    "total_commits": 2
  }
}
```

**Success with Warnings**:
```json
{
  "validation_status": "success_with_warnings",
  "checks": {
    "file_counts": "passed",
    "deletion_thresholds": "warning",
    "commits_created": "passed",
    "errors": "warnings"
  },
  "issues": [
    {
      "severity": "warning",
      "category": "deletions",
      "message": "High deletion count: 45 files (18%)",
      "resolution": "Review deletion list to ensure it's intentional"
    }
  ],
  "recommendations": [
    "Review commit diffs before merging",
    "Consider running with lower deletion threshold for safety"
  ],
  "summary": {
    "total_files_synced": 200,
    "total_files_deleted": 45,
    "total_commits": 2
  }
}
```

**Failure**:
```json
{
  "validation_status": "failure",
  "checks": {
    "file_counts": "passed",
    "deletion_thresholds": "passed",
    "commits_created": "failed",
    "errors": "critical"
  },
  "issues": [
    {
      "severity": "error",
      "category": "errors",
      "message": "Sync operation failed: Authentication required",
      "resolution": "Configure repo plugin authentication with: /fractary-repo:init"
    }
  ],
  "recommendations": [
    "Fix authentication issues and retry",
    "Verify you have access to both repositories"
  ],
  "summary": {
    "total_files_synced": 0,
    "total_files_deleted": 0,
    "total_commits": 0
  }
}
```
