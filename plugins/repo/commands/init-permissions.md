---
name: fractary-repo:init-permissions
description: Configure Claude Code permissions for repo plugin operations
---

# /repo:init-permissions - Permission Management

Configure Claude Code permissions in `.claude/settings.json` to allow repository operations while preventing dangerous commands.

## What This Does

This command:
1. **Analyzes** your current permission settings and shows detailed changes
2. **Explains** the reasoning behind each permission category with clear examples
3. **Categorizes** permissions by type (git read/write, GitHub operations, utilities, dangerous commands)
4. **Shows deltas** - what's NEW, what's PRESERVED, and what's CUSTOM
5. **Requests confirmation** - ALWAYS asks for explicit "yes" before applying changes
6. **Allows** safe git and GitHub CLI commands the repo plugin needs
7. **Denies** dangerous operations that could harm your system or repository
8. **Eliminates** permission prompts during repo operations
9. **Protects** against catastrophic mistakes

**Philosophy**: This configuration carefully balances agent autonomy with safety - maximizing productivity while protecting against catastrophic mistakes.

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
- `gh auth status`, `login`, `refresh`
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
╔════════════════════════════════════════════════════════════════════╗
║  Permission Configuration Philosophy                               ║
╚════════════════════════════════════════════════════════════════════╝

We carefully balance agent autonomy with safety:

✓ MAXIMIZE AUTONOMY: Auto-approve safe operations so you're not
  constantly clicking 'yes' for routine git/GitHub commands.

⚠️  PROTECT CRITICAL PATHS: Require explicit approval for operations
  on protected branches (main/master/production) to prevent accidents.

✗ BLOCK CATASTROPHIC MISTAKES: Deny destructive operations that could
  destroy your repo, system, or execute remote code.

This configuration lets the agent work efficiently while keeping you safe.

───────────────────────────────────────────────────────────────────
📊 Permission Changes Summary
───────────────────────────────────────────────────────────────────

New Permissions to Add:
  ✅ 10 safe git read operations (status, log, diff, etc.)
  ✅ 13 git write operations (commit, push, merge, etc.)
  ✅ 7 GitHub read operations (view PRs/issues)
  ✅ 11 GitHub write operations (create PRs/comments)
  ✅ 15 safe utility commands (cat, grep, jq, etc.)
  ⚠️  9 protected branch operations (require approval)
  ❌ 7 destructive file operations (rm -rf /, dd, mkfs)
  ❌ 12 dangerous git operations (force push to main, etc.)
  ❌ 3 dangerous GitHub operations (repo delete, etc.)
  ❌ 10 system operations (sudo, shutdown, etc.)
  ❌ 4 remote code execution patterns (curl | sh, etc.)

───────────────────────────────────────────────────────────────────
📋 Detailed Permission Breakdown
───────────────────────────────────────────────────────────────────

══════ NEW AUTO-ALLOWED COMMANDS (No prompts) ══════

Git Read Operations (10 commands)
  Check repository state without modifying anything
  Why: These are 100% safe - they only read info, never modify your repo
    • git status
    • git branch
    • git log
    ... and 7 more

[... additional detailed categories ...]

───────────────────────────────────────────────────────────────────
Benefits of This Configuration:

  ✓ Smooth workflow - No interruptions for routine operations
  ✓ Smart protection - Approval required only for risky operations
  ✓ Safety net - Catastrophic mistakes blocked automatically
  ✓ Team friendly - Prevents accidentally breaking shared branches
  ✓ Security first - Blocks common attack patterns and dangerous commands

───────────────────────────────────────────────────────────────────

Do you want to apply these permission changes?
Type yes to apply, or no to cancel: yes

Applying changes...

✅ Updated settings
  Settings file: .claude/settings.json
  Backup: .claude/settings.json.backup

  Commands auto-allowed: 56
  Protected branch operations (require approval): 9
  Dangerous operations (denied): 40

Fast workflow enabled! Most operations won't prompt.
Protected: Operations on main/master/production require approval.
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

### How It Works

The command invokes the `repo-manager` agent with a `configure-permissions` operation, which routes to the `permission-manager` skill. The skill then:
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

- `/repo:init` - Initial repo plugin setup (creates config.json only, prompts to run this command afterward)
- `/repo:branch` - Create and manage branches (benefits from permissions)
- `/repo:commit` - Create commits (benefits from permissions)
- `/repo:pr` - Manage pull requests (benefits from permissions)

## See Also

- [Repo Plugin README](../README.md) - Full plugin documentation
- [Security Best Practices](../docs/security.md) - Security guidelines
- [Configuration Guide](../docs/configuration-guide.md) - Advanced configuration

---

**Pro Tip:** Run `/repo:init-permissions` immediately after installing the repo plugin to have a smooth, prompt-free experience with repository operations.

---

## Implementation

<CONTEXT>
You are the /repo:init-permissions command for the Fractary repo plugin.
Your role is to parse user input and invoke the repo-manager agent to configure Claude Code permissions.
</CONTEXT>

<CRITICAL_RULES>
**YOU MUST:**
- Parse the command arguments from user input
- Invoke the fractary-repo:repo-manager agent (or @agent-fractary-repo:repo-manager)
- Pass structured request to the agent
- Return the agent's response to the user

**YOU MUST NOT:**
- Perform any operations yourself
- Invoke skills directly (the repo-manager agent handles skill invocation)
- Modify .claude/settings.json directly
- Skip user confirmation prompts

**THIS COMMAND IS ONLY A ROUTER.**
</CRITICAL_RULES>

<WORKFLOW>
1. **Parse user input**
   - Extract `--mode` argument (default: "setup")
   - Validate mode is one of: setup, validate, reset

2. **Build structured request**
   - Map to "configure-permissions" operation
   - Package parameters with mode and project path

3. **Invoke agent**
   - Invoke fractary-repo:repo-manager agent with the request

4. **Return response**
   - The repo-manager agent will handle the operation and return results
   - Display results to the user
</WORKFLOW>

<ARGUMENT_PARSING>
## Arguments

- `--mode <setup|validate|reset>` (optional, default: "setup")
  - `setup` - Configure permissions for first time or update
  - `validate` - Check current permissions are sufficient
  - `reset` - Remove repo-specific permissions

### Maps to Operation
All modes map to: `configure-permissions` operation in permission-manager skill
</ARGUMENT_PARSING>

<AGENT_INVOCATION>
## Invoking the Agent

After parsing arguments, invoke the repo-manager agent using declarative syntax:

**Agent**: fractary-repo:repo-manager (or @agent-fractary-repo:repo-manager)

**Request structure**:
```json
{
  "operation": "configure-permissions",
  "parameters": {
    "mode": "setup|validate|reset",
    "project_path": "/path/to/current/directory"
  }
}
```

The repo-manager agent will:
1. Receive the request
2. Route to fractary-repo:permission-manager skill based on operation
3. Display what permissions will be changed
4. Request user confirmation
5. Create/update .claude/settings.json
6. Return structured response with completion status and next steps

## Supported Operations

- `configure-permissions` - Configure Claude Code permissions for repo operations
</AGENT_INVOCATION>

<ERROR_HANDLING>
Common errors to handle:

**Invalid mode**:
```
Error: Invalid mode '{mode}'
Valid modes: setup, validate, reset
Usage: /repo:init-permissions [--mode <setup|validate|reset>]
```

**Permission denied**:
```
Error: Cannot write to .claude/settings.json
Run: mkdir -p .claude && chmod 755 .claude
```

**Invalid JSON in existing settings**:
```
Error: Existing settings.json contains invalid JSON
Solutions:
  1. Restore backup: mv .claude/settings.json.backup .claude/settings.json
  2. Reset: /repo:init-permissions --mode reset
```
</ERROR_HANDLING>
