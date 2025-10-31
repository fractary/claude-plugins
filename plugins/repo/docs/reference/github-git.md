# GitHub + Git Reference for Repo Manager

This document describes the GitHub integration for the repo-manager skill.

## Authentication

The GitHub adapter uses both Git CLI and GitHub CLI (`gh`).

### Setup

1. Install Git:
   ```bash
   # Should already be installed on most systems
   git --version
   ```

2. Install GitHub CLI:
   ```bash
   # macOS
   brew install gh

   # Linux
   curl -sS https://webi.sh/gh | sh

   # Windows
   winget install GitHub.cli
   ```

3. Authenticate GitHub CLI:
   ```bash
   gh auth login
   ```

4. Or set token environment variable:
   ```bash
   export GITHUB_TOKEN="ghp_..."
   ```

## Configuration

In `.faber.config.toml`:

```toml
[project]
source_control = "github"

[systems.repo_config]
default_branch = "main"
protected_branches = ["main", "master", "production"]
require_signed_commits = false

[defaults]
branch_naming = "feat/{issue_id}-{slug}"
```

## Operations

### generate-branch-name.sh

Generates semantic branch names from work metadata.

**Branch Naming Convention:**
- Feature: `feat/123-description`
- Bug: `fix/123-description`
- Chore: `chore/123-description`
- Patch: `hotfix/123-description`

**Slug Generation:**
- Converts title to lowercase
- Replaces spaces with hyphens
- Removes special characters
- Limits to 50 characters

**Example:**
```bash
./scripts/github/generate-branch-name.sh abc12345 123 /feature "Add Export Feature"
# Output: feat/123-add-export-feature
```

### create-branch.sh

Creates a new git branch from a base branch.

**Git Command:**
```bash
git branch <branch_name> <base_branch>
```

**Notes:**
- Doesn't automatically switch to the new branch
- Checks if branch already exists before creating
- Default base branch: main

**Example:**
```bash
./scripts/github/create-branch.sh feat/123-add-export main
```

### create-commit.sh

Creates a semantic commit with FABER metadata.

**Commit Message Format:**
```
<type>: <description>

Refs: #<issue_id>
Work-ID: <work_id>
Author: <author>

🤖 Generated with [Claude Code](https://claude.com/claude-code)

Co-Authored-By: Claude <noreply@anthropic.com>
```

**Commit Types:**
- `feat`: New feature
- `fix`: Bug fix
- `chore`: Maintenance
- `hotfix`: Critical patch

**Author Contexts:**
- `architect`: Specification commits
- `implementor`: Implementation commits
- `tester`: Test commits
- `reviewer`: Review/refine commits

**Git Command:**
```bash
git commit -m "<message>"
```

**Example:**
```bash
./scripts/github/create-commit.sh abc12345 implementor 123 /feature "Implement export functionality"
# Returns: a1b2c3d4... (commit SHA)
```

### push-branch.sh

Pushes branch to remote repository.

**Git Commands:**
```bash
# Standard push
git push origin <branch_name>

# With upstream tracking
git push -u origin <branch_name>

# Force push (safe)
git push --force-with-lease origin <branch_name>
```

**Parameters:**
- `force`: Uses `--force-with-lease` (safer than `--force`)
- `set_upstream`: Sets upstream tracking with `-u`

**Example:**
```bash
./scripts/github/push-branch.sh feat/123-add-export false true
```

### create-pr.sh

Creates a pull request using gh CLI.

**GitHub CLI Command:**
```bash
gh pr create --head <branch> --title "<title>" --body "<body>"
```

**PR Body Format:**
```markdown
## Summary

<description>

## Related

- Closes #<issue_id>
- Work ID: `<work_id>`

---
🤖 Generated with [Claude Code](https://claude.com/claude-code)
```

**Example:**
```bash
./scripts/github/create-pr.sh abc12345 feat/123-add-export 123 "Add export feature" "Implements CSV/JSON export"
# Returns: https://github.com/owner/repo/pull/45
```

### merge-pr.sh

Merges a pull request or branch directly.

**Merge Strategies:**

1. **no-ff** (No Fast-Forward):
   ```bash
   git merge <source> --no-ff -m "Merge message"
   ```
   - Creates a merge commit
   - Preserves branch history
   - **Recommended for features**

2. **squash**:
   ```bash
   git merge <source> --squash
   git commit -m "Squashed merge message"
   ```
   - Combines all commits into one
   - Clean linear history
   - **Good for small features**

3. **ff-only** (Fast-Forward Only):
   ```bash
   git merge <source> --ff-only
   ```
   - Only merges if fast-forward possible
   - No merge commit
   - **Good for simple updates**

**Safety Features:**
- Warns when merging to protected branches
- Saves and restores current branch
- Aborts merge on conflict
- Fetches latest before merging

**Example:**
```bash
./scripts/github/merge-pr.sh feat/123-add-export main no-ff abc12345 123
```

## Error Codes

- `0`: Success
- `1`: General error
- `2`: Invalid arguments
- `3`: Configuration error (not in git repo, gh CLI not found)
- `10`: Branch already exists
- `11`: Authentication error
- `12`: Network error (push/fetch failed)
- `13`: Merge conflict

## Git Configuration

Recommended git config for FABER workflows:

```bash
# User identity
git config user.name "Your Name"
git config user.email "your.email@example.com"

# Default branch
git config init.defaultBranch main

# Pull strategy
git config pull.rebase false

# Push default
git config push.default current
```

## GitHub CLI Reference

- **Create PR**: `gh pr create [flags]`
- **Merge PR**: `gh pr merge <number> [flags]`
- **List PRs**: `gh pr list`
- **View PR**: `gh pr view <number>`
- **Check status**: `gh pr checks <number>`

Full documentation: https://cli.github.com/manual/gh_pr

## Permissions Required

The GitHub token needs these permissions:
- `repo` (full repository access)
- `workflow` (if updating GitHub Actions)

## Best Practices

1. **Always fetch before merging** - Avoid merge conflicts
2. **Use --force-with-lease not --force** - Safer force pushing
3. **Set upstream when first pushing** - Enables `git pull` without arguments
4. **Create merge commits for features** - Better history tracking
5. **Squash small fixes** - Cleaner commit history
6. **Test before merging** - Run CI/CD checks first

## Troubleshooting

### Issue: "gh: command not found"
**Solution**: Install GitHub CLI

### Issue: "authentication failed"
**Solution**: Run `gh auth login` or set `GITHUB_TOKEN`

### Issue: "branch already exists"
**Solution**: Use a different branch name or delete existing branch

### Issue: "merge conflict"
**Solution**: Resolve conflicts manually, then re-run merge

### Issue: "push rejected"
**Solution**: Pull latest changes first, then push

## Examples

```bash
# Complete workflow
branch_name=$(./scripts/github/generate-branch-name.sh abc12345 123 /feature "Add export")
./scripts/github/create-branch.sh "$branch_name" main
git checkout "$branch_name"
# ... make changes ...
git add .
commit_sha=$(./scripts/github/create-commit.sh abc12345 implementor 123 /feature)
./scripts/github/push-branch.sh "$branch_name" false true
pr_url=$(./scripts/github/create-pr.sh abc12345 "$branch_name" 123 "Add export feature")
echo "PR created: $pr_url"

# After review and approval
./scripts/github/merge-pr.sh "$branch_name" main no-ff abc12345 123
```
