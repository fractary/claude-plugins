---
description: Configure Claude Code permissions for repo plugin operations
---

# /repo:init-permissions - Permission Management

Configure Claude Code permissions in `.claude/settings.json` to allow repository operations while preventing dangerous commands.

## What This Does

This command:
1. **Allows** safe git and GitHub CLI commands the repo plugin needs
2. **Denies** dangerous operations that could harm your system or repository
3. **Eliminates** permission prompts during repo operations
4. **Protects** against catastrophic mistakes

## Usage

```bash
# Initial setup (creates or updates .claude/settings.json)
/repo:init-permissions

# Setup with explicit mode
/repo:init-permissions --mode setup

# Validate existing permissions
/repo:init-permissions --mode validate

# Reset to defaults (remove repo permissions)
/repo:init-permissions --mode reset
```

## Parameters

- `--mode <setup|validate|reset>` (optional, default: `setup`)
  - `setup` - Configure permissions (first time or update)
  - `validate` - Check if permissions are correctly configured
  - `reset` - Remove repo-specific permissions

## What Gets Allowed

The following commands are explicitly allowed (no prompts):

### Git Operations
- `git status`, `branch`, `checkout`, `switch`
- `git commit`, `push`, `pull`, `fetch`
- `git tag`, `log`, `diff`, `stash`
- `git merge`, `rebase`, `rev-parse`
- `git for-each-ref`, `ls-remote`, `show-ref`
- `git add`, `reset`, `show`, `config`

### GitHub CLI Operations
- `gh pr create`, `view`, `list`, `comment`, `review`, `merge`, `close`, `status`
- `gh issue create`, `view`, `list`, `comment`, `close`
- `gh repo view`, `clone`
- `gh auth status`, `login`
- `gh api` (safe API calls)

### Safe Utilities
- `cat`, `head`, `tail`, `grep`, `find`, `ls`, `pwd`
- `jq`, `sed`, `awk`, `sort`, `uniq`, `wc`

## What Gets Denied

The following dangerous commands are explicitly blocked:

### Destructive File Operations
- `rm -rf /`, `rm -rf *`, `rm -rf .`, `rm -rf ~`
- `dd if=`, `mkfs`, `format`
- Writing to device files (`> /dev/sd`)

### Dangerous Git Operations
- `git push --force origin main` (or master, production)
- `git reset --hard origin/`
- `git clean -fdx`
- `git filter-branch`, `git rebase --onto`

### Dangerous GitHub Operations
- `gh repo delete`, `gh repo archive`
- `gh secret delete`

### System Operations
- `sudo`, `su`, `chmod 777`, `chown`
- `kill -9`, `pkill`
- `shutdown`, `reboot`, `init`, `systemctl`

### Dangerous Network Operations
- `curl | sh`, `wget | sh` (pipe to shell)

## Examples

### Example 1: First-time Setup

```bash
/repo:init-permissions
```

**Output:**
```
🔐 Permission Manager
Mode: setup
No existing settings found

ALLOWING (repo operations):
  ✓ git status, branch, commit, push...
  ✓ gh pr create, view, comment...

DENYING (dangerous operations):
  ✗ rm -rf /
  ✗ git push --force origin main
  ✗ sudo, shutdown

These permissions will:
  ✓ Eliminate prompts for repo operations
  ✓ Prevent accidental catastrophic commands
  ✓ Allow safe git and GitHub operations

✅ Created .claude/settings.json
   50 commands allowed
   25 commands denied
```

### Example 2: Validate Permissions

```bash
/repo:init-permissions --mode validate
```

**Output:**
```
🔐 Validating Permissions

✓ Git commands: allowed
✓ GitHub CLI commands: allowed
✓ Dangerous commands: denied
✓ Settings file: valid JSON

All permissions correctly configured
```

### Example 3: Reset Permissions

```bash
/repo:init-permissions --mode reset
```

**Output:**
```
⚠ Resetting Permissions
This will remove all repo-specific permissions

✅ Reset complete
   Removed repo-specific permissions
   Backup: .claude/settings.json.backup
```

## Safety Features

### Automatic Backups
Every change creates a backup:
- `.claude/settings.json.backup` - Before any modifications

### Rollback Support
If something goes wrong:
```bash
# Restore from backup
mv .claude/settings.json.backup .claude/settings.json

# Or reset and start over
/repo:init-permissions --mode reset
```

### Validation
All changes are validated:
- JSON structure checked before write
- Malformed files rejected
- Backup restored on failure

### Preservation of Existing Settings
- Existing non-repo permissions preserved
- Only repo-specific rules added/removed
- No impact on other tool permissions

## When to Use This

### Required Before First Use
Run this before using repo plugin commands:
```bash
/repo:init-permissions
/repo:branch create 123 "my feature"  # Now works without prompts
```

### After Plugin Updates
If new commands are added to the plugin:
```bash
/repo:init-permissions --mode setup  # Updates to latest permissions
```

### If Prompts Return
If you start seeing permission prompts again:
```bash
/repo:init-permissions --mode validate  # Check what's wrong
/repo:init-permissions --mode setup     # Fix it
```

### Security Review
Periodically validate permissions:
```bash
/repo:init-permissions --mode validate
cat .claude/settings.json  # Review manually
```

## Security Considerations

### Why This Is Safe

1. **Explicit Allow List** - Only commands repo plugin needs
2. **Explicit Deny List** - Dangerous operations blocked
3. **User Confirmation** - Changes shown before applying
4. **Automatic Backups** - Easy to rollback
5. **Preservation** - Existing settings untouched

### What This Prevents

- Accidental `rm -rf /` commands
- Force pushing to protected branches (main, master, production)
- Repository deletion via `gh repo delete`
- System shutdown commands
- Privilege escalation via `sudo`
- Remote code execution via `curl | sh`

### What This Allows

- Normal git workflow operations
- Pull request management
- Issue tracking
- Safe file reading operations
- Repository cloning and viewing

### Permission Philosophy

Following security best practices:
1. **Principle of Least Privilege** - Only necessary permissions
2. **Defense in Depth** - Multiple layers of protection
3. **User Transparency** - Always show what's changing
4. **Easy Audit** - Settings file is human-readable JSON
5. **Simple Rollback** - Backups for every change

## Files Created

- `.claude/settings.json` - Main settings file
- `.claude/settings.json.backup` - Backup before changes

## Integration with Other Commands

This command works seamlessly with other repo commands:

```bash
# Setup permissions first
/repo:init-permissions

# Then use repo commands without prompts
/repo:branch create 123 "add export"
/repo:commit "Add CSV export" --type feat --work-id 123
/repo:push --set-upstream
/repo:pr create "feat: Add CSV export" --work-id 123
```

## Troubleshooting

### Permission Denied Error
```
ERROR: Cannot write to .claude/settings.json
```

**Solution:**
```bash
# Check directory permissions
ls -la .claude/

# Create directory with proper permissions
mkdir -p .claude && chmod 755 .claude
```

### Invalid JSON Error
```
ERROR: Existing settings.json contains invalid JSON
```

**Solution:**
```bash
# Restore backup
mv .claude/settings.json.backup .claude/settings.json

# Or reset to defaults
/repo:init-permissions --mode reset

# Or fix manually
vim .claude/settings.json
```

### Still Getting Prompts
```bash
# Validate configuration
/repo:init-permissions --mode validate

# Re-run setup
/repo:init-permissions --mode setup

# Check if command matches allow list
cat .claude/settings.json | jq '.permissions.bash.allow'
```

## Technical Details

### Implementation

The command invokes the `permission-manager` skill which:
1. Reads existing `.claude/settings.json` (if any)
2. Creates backup
3. Merges repo permissions with existing rules
4. Validates JSON structure
5. Writes updated settings
6. Verifies success

### Settings Structure

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "git commit",
        "gh pr create",
        "..."
      ],
      "deny": [
        "rm -rf /",
        "git push --force origin main",
        "..."
      ]
    }
  }
}
```

### Script Location

`plugins/repo/skills/permission-manager/scripts/update-settings.sh`

## Related Commands

- `/repo:init` - Initial repo plugin setup (includes optional permission setup)
- `/repo:branch` - Create and manage branches (benefits from permissions)
- `/repo:commit` - Create commits (benefits from permissions)
- `/repo:pr` - Manage pull requests (benefits from permissions)

## See Also

- [Repo Plugin README](../README.md) - Full plugin documentation
- [Security Best Practices](../docs/security.md) - Security guidelines
- [Configuration Guide](../docs/configuration-guide.md) - Advanced configuration

---

**Pro Tip:** Run `/repo:init-permissions` immediately after installing the repo plugin to have a smooth, prompt-free experience with repository operations.
