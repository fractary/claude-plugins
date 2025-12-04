# Workflow: Archive Issue Specs

This workflow describes the detailed steps for archiving specifications when work completes.

## Step 1: Find All Specs for Issue

Search for all specs matching the issue number:

```bash
# Format issue number with leading zeros (5 digits)
PADDED_ISSUE=$(printf "%05d" "$ISSUE_NUMBER")
find /specs -type f -name "WORK-${PADDED_ISSUE}*.md" 2>/dev/null
```

Results can include:
- Single spec: `WORK-00123-feature.md`
- Multi-spec: `WORK-00123-01-auth.md`, `WORK-00123-02-oauth.md`

If no specs found:
- Return error
- Suggest generating spec first
- Exit

Store list of spec file paths for processing.

## Step 2: Load Configuration

Load plugin configuration from `.fractary/plugins/spec/config.json`:
- Get `storage.cloud_archive_path` pattern
- Get `storage.archive_index_file` location
- Get `archive.auto_archive_on` settings
- Get `archive.pre_archive` check settings
- Get `archive.post_archive` action settings
- Get `integration` settings

## Step 3: Fetch Issue and PR Data

Use fractary-work plugin or gh CLI:

```bash
# Get issue details
gh issue view $ISSUE_NUMBER --json title,url,state,closedAt

# Get linked PR (if exists)
gh issue view $ISSUE_NUMBER --json title | grep -o "PR #[0-9]*" || echo ""
```

Extract:
- Issue title
- Issue URL
- Issue state (open/closed)
- Issue closed date
- PR number (if linked)
- PR URL (if linked)
- PR state (if exists)

## Step 4: Check Pre-Archive Conditions

Unless `--force` flag provided, check:

### Required Checks (must pass)

**1. Issue Closed OR PR Merged**:
```bash
issue_closed=$(gh issue view $ISSUE_NUMBER --json state --jq '.state == "CLOSED"')
pr_merged=$(gh pr view $PR_NUMBER --json state --jq '.state == "MERGED"' 2>/dev/null || echo "false")

if [[ "$issue_closed" != "true" ]] && [[ "$pr_merged" != "true" ]]; then
    echo "Error: Issue not closed and PR not merged"
    exit 1
fi
```

**2. Specs Exist**:
- Already verified in Step 1

### Warning Checks (prompt if `--skip-warnings` not set)

**1. Documentation Updated**:
```bash
# Get spec creation date
spec_created=$(stat -c %Y "$SPEC_PATH")

# Check for doc updates after spec creation
doc_updates=$(git log --since="@$spec_created" --name-only --format="" |
    grep "\.md$" |
    grep -v "^specs/" |
    grep -v "^spec-" |
    wc -l)

if [[ $doc_updates -eq 0 ]]; then
    WARNINGS+=("Documentation not updated since spec creation")
fi
```

**2. Validation Status**:
```bash
validated=$(awk '/^validated:/ {print $2}' "$SPEC_PATH")

if [[ "$validated" != "true" ]]; then
    WARNINGS+=("Spec validation status: $validated")
fi
```

## Step 5: Prompt User if Warnings

If warnings exist and `--skip-warnings` not set:

```
⚠️  Pre-Archive Warnings

The following items may need attention:

1. Documentation hasn't been updated since spec creation
   → Consider updating docs to reflect current state

2. Spec validation status: partial
   → Some acceptance criteria may not be met

Do you want to:
1. Update documentation first
2. Archive anyway
3. Cancel

Enter selection [1-3]:
```

Handle user response:
- 1: Exit, let user update docs
- 2: Continue with archival
- 3: Cancel operation

## Step 6: Upload Specs to Cloud

For each spec file, upload to cloud via fractary-file plugin:

### Determine Cloud Path

Use `storage.cloud_archive_path` pattern:
```
archive/specs/{year}/{issue_number}-{phase}.md
```

Variables:
- `{year}`: Current year (e.g., "2025")
- `{issue_number}`: Issue number (e.g., "123")
- `{phase}`: Phase number if multi-spec (e.g., "phase1")

Examples:
- `archive/specs/2025/123.md` (single spec)
- `archive/specs/2025/123-phase1.md` (multi-spec phase 1)
- `archive/specs/2025/123-phase2.md` (multi-spec phase 2)

### Upload via fractary-file

```bash
# Use fractary-file plugin to upload
# (This would invoke the file-manager agent)

# For now, assuming direct upload capability:
cloud_url=$(fractary-file upload "$SPEC_PATH" "$CLOUD_PATH")
```

Store results:
- Original filename
- Cloud URL
- File size
- Checksum (SHA256)

If upload fails:
- Abort immediately
- Don't proceed to cleanup
- Return error with details
- Specs remain in local storage

## Step 7: Update Archive Index

Load archive index from `.fractary/plugins/spec/archive-index.json`:

```bash
INDEX_FILE=".fractary/plugins/spec/archive-index.json"

# Create if doesn't exist
if [[ ! -f "$INDEX_FILE" ]]; then
    echo '{"schema_version": "1.0", "last_updated": "", "archives": []}' > "$INDEX_FILE"
fi

# Load current index
INDEX_JSON=$(cat "$INDEX_FILE")
```

Add new entry:

```json
{
  "issue_number": "123",
  "issue_url": "https://github.com/org/repo/issues/123",
  "issue_title": "Implement user authentication",
  "pr_url": "https://github.com/org/repo/pull/456",
  "archived_at": "2025-01-15T14:30:00Z",
  "archived_by": "Claude Code",
  "specs": [
    {
      "filename": "WORK-00123-01-auth.md",
      "local_path": "/specs/WORK-00123-01-auth.md",
      "cloud_url": "s3://bucket/archive/specs/2025/123-phase1.md",
      "public_url": "https://storage.example.com/specs/2025/123-phase1.md",
      "size_bytes": 15420,
      "checksum": "sha256:abc123...",
      "validated": true,
      "created": "2025-01-10T09:00:00Z"
    },
    {
      "filename": "WORK-00123-02-oauth.md",
      "local_path": "/specs/WORK-00123-02-oauth.md",
      "cloud_url": "s3://bucket/archive/specs/2025/123-phase2.md",
      "public_url": "https://storage.example.com/specs/2025/123-phase2.md",
      "size_bytes": 18920,
      "checksum": "sha256:def456...",
      "validated": true,
      "created": "2025-01-12T11:00:00Z"
    }
  ],
  "documentation_updated": true,
  "archive_notes": "All phases complete, validated"
}
```

Update `last_updated` timestamp.

Write updated index:
```bash
echo "$UPDATED_JSON" > "$INDEX_FILE"
```

If index update fails:
- Critical error
- Don't remove local specs
- Return error

## Step 8: Comment on GitHub Issue

Build comment message:

```markdown
✅ Work Archived

This issue has been completed and archived!

**Specifications**:
- [Phase 1: Authentication](https://storage.example.com/specs/2025/123-phase1.md) (15.4 KB)
- [Phase 2: OAuth Integration](https://storage.example.com/specs/2025/123-phase2.md) (18.9 KB)

**Archived**: 2025-01-15 14:30 UTC
**Validation**: All specs validated ✓

These specifications are permanently stored in cloud archive for future reference.
```

Post comment:
```bash
gh issue comment $ISSUE_NUMBER --body "$COMMENT_BODY"
```

If comment fails:
- Log warning
- Continue (non-critical)

## Step 9: Comment on PR (if exists)

If PR linked to issue, comment there too:

```markdown
📦 Specifications Archived

Specifications for this PR have been archived:
- [WORK-00123-01-auth.md](https://storage.example.com/specs/2025/123-phase1.md)
- [WORK-00123-02-oauth.md](https://storage.example.com/specs/2025/123-phase2.md)

See issue #123 for complete archive details.
```

Post comment:
```bash
gh pr comment $PR_NUMBER --body "$COMMENT_BODY"
```

If comment fails:
- Log warning
- Continue (non-critical)

## Step 10: Remove Specs from Local

Only after successful upload and index update:

```bash
for spec in "${SPEC_FILES[@]}"; do
    rm "$spec"
done
```

Mark for git removal:
```bash
for spec in "${SPEC_FILES[@]}"; do
    git rm "$spec"
done
```

## Step 11: Git Commit

Commit both index update and spec removals:

```bash
git add .fractary/plugins/spec/archive-index.json

git commit -m "Archive specs for issue #${ISSUE_NUMBER}

- Archived ${#SPEC_FILES[@]} specifications to cloud storage
- Updated archive index
- Issue: #${ISSUE_NUMBER}
- PR: #${PR_NUMBER}

Specs archived:
$(for spec in "${SPEC_FILES[@]}"; do echo "  - $(basename $spec)"; done)

Archive URLs available in issue comment."
```

If commit fails:
- Report error
- User needs to resolve conflicts
- Specs already uploaded (safe state)

## Step 12: Return Confirmation

Return structured JSON output with:
- Status (success)
- Issue number
- Archive timestamp
- List of archived specs with URLs
- Archive index status
- GitHub comment status
- Local cleanup status
- Git commit status

## Error Recovery

At each critical step:

**Upload Failure**:
- Abort immediately
- Leave local specs intact
- Return error with details
- User can retry

**Index Update Failure**:
- Critical error
- Don't remove local specs
- Specs uploaded but not indexed
- User needs to manually update index or retry

**Cleanup Failure**:
- Specs uploaded and indexed (success)
- Local removal failed
- User can manually remove
- Still return success (archive complete)

**Git Commit Failure**:
- Specs uploaded and indexed (success)
- Local removed
- Commit failed
- User needs to commit manually
- Return partial success

## Example Execution

```
Input:
  issue_number: 123
  force: false
  skip_warnings: false

Steps:
  1. ✓ Found 2 specs for issue #123
  2. ✓ Config loaded
  3. ✓ Issue #123: closed
     ✓ PR #456: merged
  4. ⚠ Pre-archive checks:
     - Issue closed: ✓
     - PR merged: ✓
     - Docs updated: ⚠ (warning)
     - Validation: ✓
  5. → User prompted, selected "Archive anyway"
  6. ✓ Uploaded WORK-00123-01-auth.md
        → https://storage.example.com/specs/2025/123-phase1.md
     ✓ Uploaded WORK-00123-02-oauth.md
        → https://storage.example.com/specs/2025/123-phase2.md
  7. ✓ Archive index updated
  8. ✓ Issue #123 commented
  9. ✓ PR #456 commented
  10. ✓ Local specs removed
  11. ✓ Git commit created
  12. ✓ Success returned

Output:
  {
    "status": "success",
    "issue_number": "123",
    "specs_archived": 2,
    "cloud_urls": [...],
    "archive_index_updated": true,
    "github_comments": {"issue": true, "pr": true},
    "local_cleanup": true,
    "git_committed": true
  }
```

## Multi-Spec Considerations

When archiving multiple specs for one issue:
- Upload all specs before any removal
- Update index with all specs in one entry
- Comment once with all spec URLs
- Remove all local specs together
- Commit all changes atomically

This ensures consistency: either all specs archived or none.
