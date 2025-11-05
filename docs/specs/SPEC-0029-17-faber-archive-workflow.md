# SPEC-0029-17: FABER Archive Workflow

**Issue**: #29
**Phase**: 5 (FABER Integration)
**Dependencies**: SPEC-0029-16
**Status**: Draft
**Created**: 2025-01-15

## Overview

Detailed implementation of the unified FABER archive workflow that coordinates fractary-spec and fractary-logs to archive all artifacts when work completes.

## Archive Command Implementation

**faber/commands/archive.md**:

```markdown
---
name: faber:archive
description: Archive all FABER workflow artifacts for completed work
---

This command archives specifications, logs, and sessions for a completed FABER workflow, cleaning local context while preserving everything in cloud storage.

## Invocation

Invoke the faber:archive-workflow skill to archive artifacts:

Use the @agent-fractary-faber:workflow-manager agent:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}"
}
```

**Create new skill**: `faber/skills/archive-workflow/`

**SKILL.md**:
```markdown
<CONTEXT>
You are the archive-workflow skill for the FABER plugin. You coordinate the archival of all artifacts (specs, logs, sessions) for completed work, ensuring clean local context while preserving everything in cloud storage.
</CONTEXT>

<CRITICAL_RULES>
1. ALWAYS check pre-conditions before archiving
2. ALWAYS warn if documentation not updated
3. ALWAYS archive specs before logs (dependency order)
4. ALWAYS comment on GitHub with archive URLs
5. NEVER delete local files without successful cloud upload
6. ALWAYS commit archive index changes
</CRITICAL_RULES>

<WORKFLOW>

## Phase 1: Pre-Archive Checks

1. Verify issue status:
   - Is issue closed? OR
   - Is PR merged?
   - If neither: prompt user to confirm force archive

2. Check documentation status:
   - When was documentation last updated?
   - If before spec creation: WARN user
   - Prompt: "Update docs first?" → Yes/No/Cancel

3. Check spec validation:
   - Are specs validated?
   - If not: WARN user
   - Continue anyway (non-blocking)

4. Confirm with user:
   ```
   Ready to archive issue #{{issue_number}}

   Status:
   ✓ Issue closed
   ⚠ Documentation not updated since 2025-01-10
   ✓ Specs validated

   Continue with archive? (y/n/update-docs-first)
   ```

## Phase 2: Archive Specifications

Use @agent-fractary-spec:spec-manager:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "skip_checks": true  # Already checked in Phase 1
}

Expected result:
- Specs uploaded to cloud
- Archive index updated
- Spec URLs returned

## Phase 3: Archive Logs

Use @agent-fractary-logs:log-manager:
{
  "operation": "archive",
  "issue_number": "{{issue_number}}",
  "skip_checks": true  # Already checked in Phase 1
}

Expected result:
- Logs compressed if needed
- Logs uploaded to cloud
- Archive index updated
- Log URLs returned

## Phase 4: GitHub Updates

1. Comment on issue #{{issue_number}}:
   ```markdown
   ✅ FABER Workflow Archived

   All artifacts for this work have been permanently archived!

   **Specifications** ({{spec_count}}):
   {{#specs}}
   - [{{filename}}]({{url}}) ({{size}})
   {{/specs}}

   **Logs** ({{log_count}}):
   {{#logs}}
   - [{{type}}: {{filename}}]({{url}}) ({{size}})
   {{/logs}}

   **Total Size**: {{total_size}} (compressed)
   **Archived**: {{timestamp}}

   These artifacts are searchable via:
   - `/fractary-spec:read {{issue_number}}`
   - `/fractary-logs:read {{issue_number}}`
   - `/fractary-logs:search "query"`
   ```

2. Comment on PR (if exists):
   ```markdown
   📦 Artifacts Archived

   Specifications and logs for this PR have been archived to cloud storage.
   See issue #{{issue_number}} for complete archive details.
   ```

## Phase 5: Return Summary

Return structured result:
{
  "success": true,
  "issue_number": "{{issue_number}}",
  "specs_archived": {{count}},
  "logs_archived": {{count}},
  "total_size_bytes": {{size}},
  "archive_urls": {
    "specs": [...],
    "logs": [...]
  },
  "local_cleaned": true,
  "github_updated": true
}

</WORKFLOW>

<ERROR_HANDLING>

- Pre-check failures: Show clear error, don't proceed
- Spec archive fails: Stop, don't archive logs (maintain consistency)
- Log archive fails: Specs already archived, warn user, manual retry needed
- GitHub comment fails: Archive succeeded, warn about missing comment
- Network errors: Retry up to 3 times before failing

</ERROR_HANDLING>

<COMPLETION_CRITERIA>

- All specs uploaded to cloud
- All logs uploaded to cloud
- Archive indexes updated
- GitHub issue/PR commented
- Local files removed
- User notified of completion

</COMPLETION_CRITERIA>
```

## Archive Workflow Diagram

```
/faber:archive 123
    ↓
┌─────────────────────────┐
│ Phase 1: Pre-Checks     │
├─────────────────────────┤
│ ✓ Issue closed?         │
│ ⚠ Docs updated?         │
│ ✓ Specs validated?      │
│ → Prompt user           │
└────────┬────────────────┘
         ↓ [Confirmed]
┌─────────────────────────┐
│ Phase 2: Archive Specs  │
├─────────────────────────┤
│ Collect specs           │
│ Upload to cloud         │
│ Update index            │
│ Get URLs                │
└────────┬────────────────┘
         ↓ [Success]
┌─────────────────────────┐
│ Phase 3: Archive Logs   │
├─────────────────────────┤
│ Collect logs            │
│ Compress if needed      │
│ Upload to cloud         │
│ Update index            │
│ Get URLs                │
└────────┬────────────────┘
         ↓ [Success]
┌─────────────────────────┐
│ Phase 4: GitHub Updates │
├─────────────────────────┤
│ Comment on issue        │
│ Comment on PR           │
└────────┬────────────────┘
         ↓ [Complete]
┌─────────────────────────┐
│ Phase 5: Return Summary │
└─────────────────────────┘
```

## Integration with FABER Release Phase

**faber/skills/release/workflow/basic.md**:

Update the release workflow to include archival:

```markdown
## Step 5: Archive Artifacts

After PR is merged and before closing issue:

1. Update documentation (current state)
2. **Archive workflow artifacts**:
   - Invoke archive-workflow skill
   - Archives specs and logs to cloud
   - Comments on issue/PR
   - Cleans local storage
3. Delete feature branch
4. Close issue
```

## Configuration Options

**Archive behavior in .faber.config.toml**:

```toml
[workflow.release.archive]
enabled = true
auto_on_pr_merge = true
check_docs_updated = "warn"  # warn|block|skip
prompt_before_archive = true
archive_specs = true
archive_logs = true

[workflow.release.archive.pre_checks]
require_issue_closed = false  # PR merge sufficient
require_spec_validated = false  # warn only
require_docs_updated = false  # warn only
```

## Error Recovery

### Partial Archive Failure

If specs archived but logs fail:

```
⚠️  Partial Archive Failure

Specs: ✓ Archived successfully
Logs: ✗ Failed to archive

Specs are safe in cloud storage. You can retry log archival:
/fractary-logs:archive 123

Or complete archive:
/faber:archive 123 --logs-only
```

### Cleanup After Failure

If upload succeeds but local cleanup fails:

```
⚠️  Upload successful, cleanup failed

All artifacts uploaded to cloud, but local files remain.

Manual cleanup required:
git rm /specs/spec-123-*.md
git rm /logs/*123*.log
git add /specs/.archive-index.json /logs/.archive-index.json
git commit -m "Archive cleanup for issue #123"
```

## Testing Strategy

### Integration Tests

1. **Complete successful archive**:
   - Issue closed, docs updated, specs validated
   - All files archived
   - Indexes updated
   - GitHub commented
   - Local cleaned

2. **Archive with warnings**:
   - Docs not updated
   - User prompted
   - Proceeds after confirmation

3. **Archive failure scenarios**:
   - Network failure during upload
   - GitHub API failure
   - Local file permission issues

### Manual Tests

1. Run `/faber:archive` on completed issue
2. Verify cloud storage has files
3. Verify local files removed
4. Verify GitHub comments present
5. Verify can read archived files

## Success Criteria

- [ ] Unified /faber:archive command
- [ ] Pre-checks with user prompts
- [ ] Coordinates spec and log archival
- [ ] Comments on GitHub issue/PR
- [ ] Handles partial failures gracefully
- [ ] Integrates with FABER Release phase
- [ ] Configuration options
- [ ] Error recovery documented

## Timeline

**Estimated**: 3-4 days

## Next Steps

- **SPEC-0029-18**: Migration strategy for existing plugins
- **SPEC-0029-19**: Comprehensive documentation plan
