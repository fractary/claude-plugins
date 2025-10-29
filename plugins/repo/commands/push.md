---
name: repo:push
description: Push branches to remote repository with safety checks
---

# /repo:push - Branch Push Command

Push branches to remote repository with safety checks and upstream tracking.

## Usage

```bash
# Push current branch
/repo:push

# Push specific branch
/repo:push <branch_name> [options]
```

## Optional Flags

- `--remote <name>`: Remote name (default: origin)
- `--set-upstream`: Set upstream tracking branch
- `--force`: Force push with lease (safe force push)

## Examples

```bash
# Push current branch
/repo:push

# Push specific branch with upstream tracking
/repo:push feat/123-add-export --set-upstream

# Push to different remote
/repo:push feat/456-fix --remote upstream

# Force push (safe)
/repo:push feat/789-refactor --force
```

## Command Implementation

This command pushes branches safely to remote repositories.

### Workflow

**1. Parse Arguments**:
- Extract branch_name (optional, defaults to current branch)
- Parse --remote flag (default: "origin")
- Parse --set-upstream flag (boolean)
- Parse --force flag (boolean)

**2. Validate Inputs**:
- Check branch exists locally
- Verify remote exists
- Check authentication
- Validate not force pushing to protected branch

**3. Protected Branch Check**:
```
If branch is protected (main, master, production) AND force=true:
  ERROR: Cannot force push to protected branch
  Exit with error
```

**4. Invoke Agent**:
```json
{
  "operation": "push-branch",
  "parameters": {
    "branch_name": "feat/123-add-export",
    "remote": "origin",
    "set_upstream": true,
    "force": false
  }
}
```

**5. Display Result**:
```
✅ Branch pushed successfully

Branch: feat/123-add-export
Remote: origin
Upstream: origin/feat/123-add-export (tracking enabled)
Commits pushed: 3

Next: /repo:pr to create pull request
```

## Force Push Safety

The command uses **--force-with-lease** instead of bare --force:

### What is force-with-lease?

- Checks if remote ref matches your last fetch
- Only proceeds if remote hasn't changed
- Prevents accidentally overwriting others' work
- Fails gracefully if remote was updated

### When to Use Force Push

✅ **Safe scenarios**:
- Rebasing feature branches
- Amending commits after review
- Cleaning up commit history on your branch

❌ **Never force push**:
- Protected branches (main, master, production)
- Shared branches with multiple developers
- Without communicating to team

### Example Force Push Flow

```
User: /repo:push feat/123-cleanup --force

1. Safety checks:
   - Branch not protected ✓
   - Using --force-with-lease ✓
   - Remote ref up to date ✓

2. Push with lease:
   {
     "operation": "push-branch",
     "parameters": {
       "branch_name": "feat/123-cleanup",
       "force": true
     }
   }

3. Display:
   ⚠️  Force push completed
   Branch: feat/123-cleanup
   Strategy: force-with-lease
   Previous commits were overwritten
```

## Error Handling

**Authentication Error**:
```
Error: Authentication failed
Check your Git credentials: git credential fill
Or set GITHUB_TOKEN environment variable
```

**Protected Branch**:
```
Error: Cannot force push to protected branch: main
Protected branches: main, master, production, staging
```

**Network Error**:
```
Error: Failed to connect to remote: origin
Check your network connection and remote URL
View remotes: git remote -v
```

**Branch Doesn't Exist**:
```
Error: Branch not found: feat/nonexistent
Current branch: develop
Use /repo:branch list to see available branches
```

**Remote Ref Changed**:
```
Error: Remote branch has new commits
Someone else pushed to feat/123-work since your last fetch

Options:
1. Pull latest changes: git pull
2. Force push anyway: /repo:push feat/123-work --force
```

**No Commits to Push**:
```
Branch is up to date with remote
No new commits to push
```

## Upstream Tracking

### First Push (No Upstream)

```bash
/repo:push feat/123-new-feature --set-upstream
```

Result:
```
✅ Branch pushed and tracking enabled

Branch: feat/123-new-feature → origin/feat/123-new-feature
You can now use: git push (without arguments)
```

### Subsequent Pushes

```bash
/repo:push
```

Result:
```
✅ Branch pushed

Branch: feat/123-new-feature
Remote: origin (tracking already set)
Commits pushed: 2
```

## FABER Integration

When used within FABER workflows:
- Automatically pushes before PR creation in Release phase
- Sets upstream tracking on first push
- Respects autonomy settings for force push
- Includes push status in workflow documentation

## Advanced Usage

**Push Multiple Branches**:
```bash
# Push main branch
/repo:push main

# Push feature branch
/repo:push feat/123-export --set-upstream

# Push fix branch
/repo:push fix/456-bug
```

**Push to Fork**:
```bash
# Add fork remote
git remote add fork https://github.com/username/repo.git

# Push to fork
/repo:push feat/123-contrib --remote fork --set-upstream
```

**Force Push After Rebase**:
```bash
# After rebasing feature branch
git rebase main

# Safe force push
/repo:push feat/123-rebased --force
```

## Integration

**Called By**: User via CLI

**Calls**: repo-manager agent with operation:
- push-branch

**Returns**: Human-readable output with push status

## Best Practices

1. **Always fetch first**: `git fetch` before pushing to avoid conflicts
2. **Use --set-upstream**: On first push to enable simple `git push` later
3. **Communicate force pushes**: Tell team members before force pushing shared branches
4. **Check branch status**: `git status` to see if you're ahead/behind remote
5. **Avoid bare --force**: Always use the command's safe force-with-lease

## Safety Features

- **Protected branch blocking**: Cannot force push to main, master, production
- **Force-with-lease**: Prevents overwriting others' work
- **Authentication check**: Verifies credentials before attempting push
- **Network validation**: Tests remote connectivity
- **Confirmation prompts**: For destructive operations (when not in autonomous mode)

## Notes

- Default remote is "origin" (configurable)
- Upstream tracking persists after being set
- Force push uses --force-with-lease for safety
- All operations respect FABER workflow context
- Push status is logged for audit trail
