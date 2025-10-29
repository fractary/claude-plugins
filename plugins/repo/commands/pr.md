---
name: repo:pr
description: Create, comment, review, and merge pull requests
---

# /repo:pr - Pull Request Management Command

Manage the complete pull request lifecycle: create, comment, review, and merge PRs.

## Usage

```bash
# Create a pull request
/repo:pr create <title> [options]

# Add comment to PR
/repo:pr comment <pr_number> <comment>

# Review PR
/repo:pr review <pr_number> <action> [--comment <text>]

# Merge PR
/repo:pr merge <pr_number> [options]
```

## Subcommand: create

Create a new pull request.

### Syntax

```bash
/repo:pr create <title> [options]
```

### Required Arguments

- `title`: PR title (should follow conventional commit format)

### Optional Flags

- `--body <text>`: PR description (markdown supported)
- `--base <branch>`: Target branch (default: main)
- `--head <branch>`: Source branch (default: current branch)
- `--work-id <id>`: Work item to link (auto-closes issue)
- `--draft`: Create as draft PR

### Examples

```bash
# Simple PR from current branch
/repo:pr create "feat: Add CSV export functionality"

# PR with full details
/repo:pr create "feat: Add user authentication" \
  --body "Implements JWT-based auth with refresh tokens" \
  --work-id 123 \
  --base main

# Draft PR for early feedback
/repo:pr create "WIP: Refactor database layer" \
  --draft \
  --work-id 456
```

### Workflow

1. Parse title and options
2. Determine head branch (current if not specified)
3. Validate branches exist
4. Format PR body with FABER metadata if present
5. Invoke agent: create-pr operation
6. Display PR URL

### Example Flow

```
User: /repo:pr create "feat: Add CSV export" --work-id 123

1. Validate:
   - Current branch: feat/123-add-export ✓
   - Base branch: main ✓
   - Work ID: 123 ✓

2. Format PR body:
   ## Summary
   Add CSV export functionality

   ## Changes
   - Implemented CSV export endpoint
   - Added export configuration options
   - Included comprehensive error handling

   ## Work Item
   Closes #123

   ## Metadata
   - Branch: feat/123-add-export
   - Base: main
   - Created: 2025-10-29

3. Create PR:
   {
     "operation": "create-pr",
     "parameters": {
       "title": "feat: Add CSV export",
       "head_branch": "feat/123-add-export",
       "base_branch": "main",
       "work_id": "123",
       "body": "...",
       "draft": false
     }
   }

4. Display:
   ✅ Pull request created

   PR #456: feat: Add CSV export
   URL: https://github.com/owner/repo/pull/456
   Base: main ← feat/123-add-export
   Status: Open

   Closes: #123
```

## Subcommand: comment

Add a comment to an existing PR.

### Syntax

```bash
/repo:pr comment <pr_number> <comment>
```

### Arguments

- `pr_number`: PR number
- `comment`: Comment text (markdown supported)

### Examples

```bash
# Simple comment
/repo:pr comment 456 "LGTM! Tests are passing."

# Detailed comment
/repo:pr comment 456 "Great work! A few suggestions:
- Consider adding error handling for edge case X
- Update documentation for the new API endpoint"
```

### Workflow

1. Parse PR number and comment
2. Validate PR exists
3. Invoke agent: comment-pr operation
4. Display comment URL

## Subcommand: review

Submit a formal PR review.

### Syntax

```bash
/repo:pr review <pr_number> <action> [--comment <text>]
```

### Arguments

- `pr_number`: PR number
- `action`: Review action (approve|request_changes|comment)

### Optional Flags

- `--comment <text>`: Review comment (required for request_changes)

### Examples

```bash
# Approve PR
/repo:pr review 456 approve

# Approve with comment
/repo:pr review 456 approve --comment "Great work! Code looks good."

# Request changes
/repo:pr review 456 request_changes \
  --comment "Please address the following: ..."

# Comment-only review
/repo:pr review 456 comment \
  --comment "Looks good, just a few minor suggestions"
```

### Review Actions

- **approve**: Approve the changes
- **request_changes**: Request changes before merging
- **comment**: Comment without explicit approval/rejection

### Workflow

1. Parse PR number and action
2. Validate action is valid
3. Check comment provided if request_changes
4. Invoke agent: review-pr operation
5. Display review status

## Subcommand: merge

Merge a pull request.

### Syntax

```bash
/repo:pr merge <pr_number> [options]
```

### Arguments

- `pr_number`: PR number

### Optional Flags

- `--strategy <strategy>`: Merge strategy (no-ff|squash|ff-only) (default: no-ff)
- `--delete-branch`: Delete branch after merge
- `--no-delete-branch`: Keep branch after merge (default)

### Examples

```bash
# Merge with no-ff (preserves history)
/repo:pr merge 456

# Squash merge (single commit)
/repo:pr merge 456 --strategy squash --delete-branch

# Fast-forward merge
/repo:pr merge 456 --strategy ff-only
```

### Merge Strategies

- **no-ff** (No Fast-Forward): Creates merge commit, preserves branch history
- **squash**: Combines all commits into one, clean linear history
- **ff-only**: Only merges if fast-forward possible, no merge commit

### Workflow

1. Parse PR number and options
2. Validate PR exists and is mergeable
3. Check CI status (must be passing)
4. Check review approvals (must meet requirements)
5. Warn if merging to protected branch
6. Invoke agent: merge-pr operation
7. Display merge status

### Example Flow

```
User: /repo:pr merge 456 --strategy no-ff --delete-branch

1. Pre-merge checks:
   - PR exists: #456 ✓
   - CI status: passing ✓
   - Reviews: 2 approvals ✓
   - Conflicts: none ✓
   - Target: main (protected) ⚠️

2. Protected branch warning:
   ⚠️  Merging to protected branch: main
   - CI checks: passing
   - Required reviews: met (2/1)
   - Proceed? (yes/no)

3. Merge:
   {
     "operation": "merge-pr",
     "parameters": {
       "pr_number": 456,
       "strategy": "no-ff",
       "delete_branch": true
     }
   }

4. Display:
   ✅ Pull request merged

   PR #456: feat: Add CSV export
   Merge SHA: abc123def456...
   Strategy: no-ff
   Branch deleted: feat/123-add-export

   Closed: #123
```

## Error Handling

**PR Creation Errors**:
```
Error: No commits between base and head branches
The branches are already in sync
```

**Authentication Error**:
```
Error: GitHub API authentication failed
Set GITHUB_TOKEN environment variable
Generate token at: https://github.com/settings/tokens
```

**CI Failure**:
```
Error: Cannot merge PR #456
CI checks are failing:
- build: failed
- tests: passed
- lint: passed

Fix failing checks before merging
```

**Review Requirements Not Met**:
```
Error: Cannot merge PR #456
Required reviews: 2 approvals needed (currently: 1)
```

**Merge Conflict**:
```
Error: Cannot merge PR #456
Pull request has merge conflicts
Resolve conflicts first:
1. git checkout feat/123-branch
2. git merge main
3. Resolve conflicts
4. git push
```

**Protected Branch Warning**:
```
⚠️  Warning: Merging to protected branch: main
- Target branch is protected
- Ensure all checks pass
- Requires explicit confirmation
Proceed with merge? (yes/no)
```

## PR Body Template

When creating PRs, the command uses this template:

```markdown
## Summary
Brief description of what this PR does

## Changes
Detailed list of changes:
- Change 1
- Change 2
- Change 3

## Testing
How this was tested:
- Test scenario 1
- Test scenario 2

## Work Item
Closes #<work_id>

## Review Checklist
- [ ] Code follows project standards
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] No breaking changes (or documented)

## Metadata
- **Branch**: <head_branch>
- **Base**: <base_branch>
- **Created**: <timestamp>

---
*Generated by FABER workflow*
```

## FABER Integration

When used within FABER workflows:
- Automatically creates PRs during Release phase
- Includes complete workflow metadata in PR body
- Links to work item being released
- Adds phase and context information
- Formats for full traceability

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operations:
- create-pr
- comment-pr
- review-pr
- merge-pr

**Returns**: Human-readable output with PR URLs and status

## Best Practices

1. **Use conventional commit format**: PR titles should follow semantic format
2. **Include work item references**: Always link to issues/tickets
3. **Write clear descriptions**: Explain what and why, not just how
4. **Wait for CI**: Don't merge while checks are running
5. **Get reviews**: Follow team review requirements
6. **Choose correct strategy**: no-ff for features, squash for fixes
7. **Clean up branches**: Use --delete-branch after merge

## Notes

- PRs automatically close linked work items on merge
- Protected branches require additional checks
- Draft PRs don't trigger CI until marked ready
- All operations respect platform-specific settings
- Merge strategies affect commit history
