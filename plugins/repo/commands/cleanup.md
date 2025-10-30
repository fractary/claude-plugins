---
name: fractary-repo:cleanup
description: Clean up stale and merged branches safely
argument-hint: [--delete] [--merged] [--inactive] [--days <n>] [--location <where>] [--exclude <pattern>]
---

# /repo:cleanup - Branch Cleanup Command

Identify and safely delete stale, merged, or inactive branches to keep repositories clean.

## Usage

```bash
# List stale branches (dry run)
/repo:cleanup [options]

# Delete stale branches
/repo:cleanup --delete [options]
```

## Optional Flags

- `--delete`: Actually delete branches (default: dry-run/list only)
- `--merged`: Include fully merged branches
- `--inactive`: Include inactive branches (no commits in N days)
- `--days <n>`: Inactivity threshold in days (default: 30)
- `--location <where>`: Where to clean: local|remote|both (default: local)
- `--exclude <pattern>`: Exclude branches matching pattern

## Examples

```bash
# Dry run - list stale branches
/repo:cleanup --merged --inactive --days 30

# Delete merged branches locally
/repo:cleanup --delete --merged

# Delete inactive branches (60+ days)
/repo:cleanup --delete --inactive --days 60

# Clean up both local and remote
/repo:cleanup --delete --merged --location both

# Exclude release branches
/repo:cleanup --delete --merged --exclude "release/*"
```

## Command Implementation

This command identifies and optionally deletes stale branches.

### Default Behavior (Dry Run)

By default, the command lists stale branches WITHOUT deleting:

```bash
/repo:cleanup --merged
```

Result:
```
🔍 Scanning for stale branches...

Stale Branches Report
───────────────────────────────────────

Fully Merged (3):
  ✓ feat/123-old-feature
    Last commit: 2024-09-15 (45 days ago)
    Author: developer@example.com
    Status: Merged to main

  ✓ fix/456-auth-bug
    Last commit: 2024-08-31 (60 days ago)
    Author: developer@example.com
    Status: Merged to main

  ✓ chore/789-update-deps
    Last commit: 2024-08-01 (90 days ago)
    Author: developer@example.com
    Status: Merged to main

Inactive (1):
  ⚠ feat/999-experiment
    Last commit: 2024-07-01 (120 days ago)
    Author: developer@example.com
    Status: Unmerged (has unique commits)

Total: 4 stale branches
Safe to delete: 3 merged branches

To delete: /repo:cleanup --delete --merged
```

### Delete Mode

With `--delete` flag, the command actually removes branches:

```bash
/repo:cleanup --delete --merged
```

Result:
```
⚠️  DELETE MODE ACTIVE

Branches to delete (3):
  • feat/123-old-feature (merged)
  • fix/456-auth-bug (merged)
  • chore/789-update-deps (merged)

Protected branches excluded: main, master, production

⚠️  This action cannot be undone.
Continue? (yes/no): yes

🗑️  Deleting branches...

✓ Deleted: feat/123-old-feature (local)
✓ Deleted: fix/456-auth-bug (local)
✓ Deleted: chore/789-update-deps (local)

✅ Cleanup complete
Deleted: 3 branches
Kept: 1 unmerged branch

Tip: Run with --location both to also delete remote branches
```

## Cleanup Strategies

### Strategy 1: Conservative (Merged Only)

Delete only fully merged branches:

```bash
/repo:cleanup --delete --merged
```

**Pros**:
- Safest approach
- No risk of losing work
- Cleans up completed features

**Use when**:
- Regular maintenance
- Unsure about branch status
- Team has active development

### Strategy 2: Time-Based (Inactive)

Delete branches with no activity for N days:

```bash
/repo:cleanup --delete --inactive --days 60
```

**Pros**:
- Removes abandoned work
- Clears up stale experiments

**Cons**:
- May delete unmerged work
- Requires careful threshold selection

**Use when**:
- Long-term cleanup
- Known abandoned branches
- After communicating with team

### Strategy 3: Combined (Merged + Old Inactive)

Delete merged branches immediately, very old inactive branches:

```bash
# Delete merged branches
/repo:cleanup --delete --merged

# Then delete very old unmerged branches (with caution)
/repo:cleanup --delete --inactive --days 90
```

**Use when**:
- Comprehensive cleanup
- Regular maintenance schedule

### Strategy 4: Pattern-Based

Clean up specific branch types:

```bash
# Clean up old feature branches
/repo:cleanup --delete --merged --pattern "feat/*"

# Clean up old fix branches
/repo:cleanup --delete --merged --pattern "fix/*"
```

## Workflow

**1. Parse Arguments**:
- Extract --delete flag (default: false)
- Parse filter flags (--merged, --inactive, --days)
- Parse --location (default: local)
- Parse --exclude patterns

**2. Scan for Stale Branches**:
```json
{
  "operation": "list-stale-branches",
  "parameters": {
    "merged": true,
    "inactive_days": 30,
    "exclude_protected": true,
    "location": "local"
  }
}
```

**3. Display Report**:
- Group by status (merged vs unmerged)
- Show last commit date and author
- Calculate days inactive
- Display safe vs risky deletions

**4. If --delete Flag Present**:
- Show branches to be deleted
- Require explicit confirmation
- Delete branches one by one
- Report results

**5. Display Summary**:
- Count deleted branches
- List any errors
- Suggest next steps

## Safety Features

### Protected Branches

Protected branches are NEVER deleted:
- main
- master
- production
- staging
- (configured in repo.example.json)

### Confirmation Prompt

Delete mode requires explicit confirmation:
```
⚠️  About to delete 5 branches
Protected branches excluded: main, master
Continue? (yes/no):
```

### Merge Status Check

Unmerged branches show warning:
```
⚠ feat/999-experiment
  Status: Unmerged (has 3 unique commits)
  ⚠️  Deleting this will LOSE WORK
```

### Dry Run First

Always run without --delete first to preview:
```bash
# 1. Preview
/repo:cleanup --merged

# 2. Review output

# 3. Delete if safe
/repo:cleanup --delete --merged
```

## Error Handling

**No Stale Branches**:
```
✅ Repository is clean
No stale branches found

Filters:
- Merged: yes
- Inactive: no
- Protected excluded: yes
```

**Protected Branch Attempted**:
```
Error: Cannot delete protected branch: main
Protected branches: main, master, production, staging
```

**Unmerged Branch Warning**:
```
⚠️  Warning: feat/999-experiment has unmerged commits

This branch has 3 commits not in main:
- abc123: WIP: New feature
- def456: Add tests
- ghi789: Fix bugs

Deleting will LOSE this work.
Skip this branch? (yes/no):
```

**Network Error (Remote Cleanup)**:
```
Error: Failed to delete remote branch: feat/old
Could not connect to remote: origin
Check network and authentication
```

## Advanced Usage

### Clean Up Specific Patterns

```bash
# Old feature branches only
/repo:cleanup --delete --merged --pattern "feat/*"

# Experimental branches
/repo:cleanup --delete --inactive --days 45 --pattern "experiment/*"
```

### Remote Cleanup

Clean up remote branches (requires authentication):

```bash
# Delete remote merged branches
/repo:cleanup --delete --merged --location remote

# Clean up both local and remote
/repo:cleanup --delete --merged --location both
```

### Exclude Patterns

Keep certain branches:

```bash
# Keep release branches
/repo:cleanup --delete --merged --exclude "release/*"

# Keep multiple patterns
/repo:cleanup --delete --merged \
  --exclude "release/*" \
  --exclude "hotfix/*" \
  --exclude "v*"
```

## Automation

### Scheduled Cleanup

Set up regular cleanup with cron:

```bash
# Weekly cleanup of merged branches
0 0 * * 0 /repo:cleanup --delete --merged --location local

# Monthly aggressive cleanup
0 0 1 * * /repo:cleanup --delete --inactive --days 90
```

### CI/CD Integration

Add to CI pipeline:

```yaml
cleanup:
  schedule:
    - cron: '0 0 * * 0'  # Weekly
  script:
    - /repo:cleanup --delete --merged --location both
```

## Report Details

The report shows for each branch:

**Branch Information**:
- Branch name
- Last commit date
- Days since last activity
- Last author
- Merge status

**Status Indicators**:
- ✓ Merged (safe to delete)
- ⚠ Unmerged (review before deleting)
- 🔒 Protected (never deleted)

**Grouping**:
- Fully Merged Branches
- Inactive But Unmerged Branches
- Protected Branches (excluded)

## FABER Integration

When used within FABER workflows:
- Automatically cleans up after PR merges
- Respects FABER branch naming
- Excludes active workflow branches
- Logs cleanup operations

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operations:
- list-stale-branches
- delete-branch (when --delete used)

**Returns**: Human-readable report with deletion results

## Best Practices

1. **Always dry run first**: Preview before deleting
2. **Regular schedule**: Clean weekly or monthly
3. **Communicate with team**: Warn before major cleanup
4. **Keep protected list updated**: Add important branches to config
5. **Use conservative thresholds**: Start with 60+ days for inactive
6. **Back up important work**: Ensure unmerged work is pushed or saved
7. **Clean local and remote**: Use --location both for complete cleanup

## Notes

- Deleted branches can sometimes be recovered (contact admin)
- Protected branches list is configurable
- Merge status is checked against default branch
- Remote cleanup requires authentication
- All operations are logged for audit
- Dry run mode is the default for safety
