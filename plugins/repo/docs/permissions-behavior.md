# Permission System Behavior

## Overview

The repo plugin's permission management system uses Claude Code's project-specific `.claude/settings.json` file to configure three categories of command permissions.

## Permission Categories

### 1. **Allow** (Auto-Execute, No Prompts)

Commands in the `allow` list execute immediately without prompting the user.

**Use for**: Safe, read-only operations with no side effects

**Examples**:
```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "git log",
        "git diff",
        "cat",
        "grep",
        "jq"
      ]
    }
  }
}
```

### 2. **RequireApproval** (Prompt Before Execute)

Commands in the `requireApproval` list will prompt the user for approval before executing.

**Use for**: Risky write operations that might have side effects

**Examples**:
```json
{
  "permissions": {
    "bash": {
      "requireApproval": [
        "git commit",
        "git push",
        "git merge",
        "gh pr create",
        "gh pr merge"
      ]
    }
  }
}
```

**Behavior**: User sees command and can approve/deny before execution

### 3. **Deny** (Always Block)

Commands in the `deny` list are blocked and will not execute under any circumstances.

**Use for**: Dangerous operations that could cause catastrophic damage

**Examples**:
```json
{
  "permissions": {
    "bash": {
      "deny": [
        "rm -rf /",
        "git push --force origin main",
        "gh repo delete",
        "sudo",
        "shutdown"
      ]
    }
  }
}
```

## `--dangerously-skip-permissions` Mode

### ⚠️ CRITICAL WARNING ⚠️

When running Claude Code with the `--dangerously-skip-permissions` flag:

**ALL permission checks are bypassed**, including:
- ✗ `allow` list (not checked)
- ✗ `requireApproval` list (NOT PROMPTED)
- ✗ `deny` list (NOT ENFORCED)

This means:
- Commands that normally require approval will execute immediately
- Commands that are denied will execute anyway
- **There is NO safety net**

### When to Use Skip Mode

**ONLY use `--dangerously-skip-permissions` when**:
1. Running in a sandboxed/isolated environment
2. Testing automation scripts
3. CI/CD pipelines where you trust all commands
4. You fully understand the risks

**NEVER use skip mode**:
- On production systems
- When running untrusted code
- If you're unsure what commands will execute
- In shared environments

### Behavior Comparison

| Command | Normal Mode | Skip Mode |
|---------|------------|-----------|
| `git status` (allow) | ✅ Executes immediately | ✅ Executes immediately |
| `git commit` (requireApproval) | ⚠️ Prompts for approval | ⚠️ **Executes immediately** |
| `rm -rf /` (deny) | ❌ Blocked | ❌ **Executes anyway** |

## Settings File Location

The permission system uses the **project-specific** settings file:

```
<project-root>/.claude/settings.json
```

**NOT** the global `~/.claude/settings.json` or any other location.

### Why Project-Specific?

Different projects may have different security requirements:

```
my-safe-project/.claude/settings.json     # Relaxed permissions
critical-prod-app/.claude/settings.json   # Strict permissions
```

## Merging Behavior

### Conflict Resolution

When you run `/repo:init-permissions`, the script intelligently merges permissions:

#### ✅ **Preserved**: Custom User Permissions

If you have custom commands in your settings, they are **preserved**:

**Before**:
```json
{
  "permissions": {
    "bash": {
      "allow": ["git status", "my-custom-script.sh"],
      "deny": ["my-dangerous-tool"]
    }
  }
}
```

**After**:
```json
{
  "permissions": {
    "bash": {
      "allow": ["git status", "my-custom-script.sh", "git log", "..."],
      "requireApproval": ["git commit", "git push", "..."],
      "deny": ["my-dangerous-tool", "rm -rf /", "..."]
    }
  }
}
```

Your custom commands (`my-custom-script.sh`, `my-dangerous-tool`) are **preserved**.

#### ✅ **Deduplicated**: No Duplicate Entries

Commands are **never duplicated** within a category:

**Before**:
```json
{
  "permissions": {
    "bash": {
      "allow": ["git status", "git status", "git status"]
    }
  }
}
```

**After**:
```json
{
  "permissions": {
    "bash": {
      "allow": ["git status"]
    }
  }
}
```

#### ✅ **Conflict Detection**: Commands in Multiple Categories

If a command appears in multiple categories, the script **detects and reports it**:

**Problematic Settings**:
```json
{
  "permissions": {
    "bash": {
      "allow": ["git push"],
      "requireApproval": ["git push"],
      "deny": ["git push"]
    }
  }
}
```

**Output**:
```
⚠️  WARNING: Conflicts detected in existing settings
Some commands appear in multiple categories (allow/requireApproval/deny)
These will be resolved by removing duplicates, keeping the most restrictive.

Conflicts found:
  • git push (in allow, requireApproval, and deny)
```

**Resolution Strategy** (Most Restrictive Wins):
1. `deny` > `requireApproval` > `allow`
2. Command stays in most restrictive category
3. Removed from less restrictive categories

**Result**:
```json
{
  "permissions": {
    "bash": {
      "deny": ["git push"]
    }
  }
}
```

#### ✅ **Difference Reporting**: What's Changed

The script shows you differences from recommended settings:

**Output**:
```
📊 Comparing with Recommended Settings
───────────────────────────────────────

Custom Allows (not in repo recommendations):
  • my-custom-script.sh
  • npx
  • docker exec

Custom Denies (not in repo recommendations):
  • my-dangerous-tool

Potentially Misplaced Permissions:
  ⚠️  git commit (in allow, recommended: requireApproval)
  ⚠️  rm -rf / (in allow, should be denied)
  ℹ️  git push (in allow, recommended: requireApproval)
```

This helps you:
1. Identify custom permissions you've added
2. Spot potentially dangerous misconfigurations
3. Decide whether to keep or update settings

## Best Practices

### 1. Start with Recommended Settings

Run `/repo:init-permissions` to get safe defaults:
```bash
/repo:init-permissions --mode setup
```

### 2. Validate Regularly

Check your permissions periodically:
```bash
/repo:init-permissions --mode validate
```

### 3. Review Differences

Pay attention to the "Comparing with Recommended Settings" output:
- Custom permissions that aren't in repo recommendations
- Misplaced permissions (wrong category)

### 4. Keep Backups

Before making changes, backup your settings:
```bash
cp .claude/settings.json .claude/settings.json.manual-backup
```

The script creates automatic backups too:
```bash
.claude/settings.json.backup
```

### 5. Understand Your Custom Permissions

If you add custom commands, understand:
- What they do
- What category they should be in
- The security implications

### 6. Use Reset When Unsure

If settings become complex or problematic:
```bash
/repo:init-permissions --mode reset   # Remove repo permissions
/repo:init-permissions --mode setup   # Start fresh
```

## Example Workflow

### Initial Setup

```bash
cd my-project

# Setup permissions
/repo:init-permissions

# Review what was configured
cat .claude/settings.json

# Validate
/repo:init-permissions --mode validate
```

### Adding Custom Permissions

```bash
# Manually edit settings
vim .claude/settings.json

# Add your custom command
{
  "permissions": {
    "bash": {
      "allow": ["my-safe-script.sh"]
    }
  }
}

# Validate (repo plugin won't remove it)
/repo:init-permissions --mode validate

# Update with latest repo recommendations (preserves custom)
/repo:init-permissions --mode setup
```

### Fixing Conflicts

```bash
# Validate and detect conflicts
/repo:init-permissions --mode validate

# If conflicts detected, fix them
/repo:init-permissions --mode setup

# Review result
cat .claude/settings.json
```

## Security Implications

### Allow List (Low Risk)

✅ **Safe**: Read-only operations
- No side effects
- Can't modify system state
- Can't delete data

Examples: `git status`, `cat`, `grep`

### Require Approval (Medium Risk)

⚠️ **Moderate Risk**: Write operations with confirmation
- User sees command before execution
- Can review and deny
- Protection against unintended actions

Examples: `git commit`, `git push`, `gh pr create`

### Deny List (High Risk)

❌ **High Risk**: Dangerous operations
- Can cause data loss
- Can corrupt repositories
- Can damage system

Examples: `rm -rf /`, `git push --force origin main`, `gh repo delete`

### Skip Permissions (EXTREME RISK)

💀 **EXTREME RISK**: All protections disabled
- No prompts
- No blocks
- Full blind execution

**Only use in isolated environments**

## Troubleshooting

### Problem: Duplicate Commands

**Symptom**: Same command in multiple categories

**Solution**: Run setup mode to deduplicate
```bash
/repo:init-permissions --mode setup
```

### Problem: Lost Custom Permissions

**Symptom**: Your custom commands disappeared

**Solution**: Restore from backup
```bash
mv .claude/settings.json.backup .claude/settings.json
```

Custom permissions should NOT be lost if you run setup mode. If they are, file a bug report.

### Problem: Wrong Category

**Symptom**: Safe command in requireApproval, or dangerous command in allow

**Solution**: Manually edit or reset and reconfigure
```bash
# Option 1: Manual fix
vim .claude/settings.json

# Option 2: Reset and reconfigure
/repo:init-permissions --mode reset
/repo:init-permissions --mode setup
```

### Problem: Can't Execute Commands

**Symptom**: Commands you need are blocked or not allowed

**Solution**: Check current settings and update
```bash
# Check what's configured
cat .claude/settings.json

# If missing, add to appropriate category
vim .claude/settings.json

# Or re-run setup
/repo:init-permissions --mode setup
```

## Advanced: Manual Configuration

### Custom Project Needs

If you have specific security requirements:

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "custom-read-script.sh"
      ],
      "requireApproval": [
        "git push",
        "custom-deploy-script.sh"
      ],
      "deny": [
        "rm",
        "git push --force",
        "dangerous-legacy-tool"
      ]
    }
  }
}
```

### CI/CD Environments

For automated environments, you might use:

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "git commit",
        "git push",
        "gh pr create"
      ],
      "deny": [
        "rm -rf /",
        "sudo",
        "shutdown"
      ]
    }
  }
}
```

But **never** use `--dangerously-skip-permissions` unless you trust all code.

## Summary

| Feature | Behavior |
|---------|----------|
| **Project-specific** | ✅ `.claude/settings.json` in project root |
| **Preserves custom** | ✅ Your custom permissions kept |
| **Deduplicates** | ✅ No duplicate commands |
| **Conflict detection** | ✅ Warns about commands in multiple categories |
| **Difference reporting** | ✅ Shows custom and misplaced permissions |
| **Three categories** | ✅ allow, requireApproval, deny |
| **Smart merging** | ✅ Most restrictive wins |
| **Automatic backups** | ✅ `.backup` file before changes |
| **Skip mode bypass** | ⚠️ ALL checks disabled (use carefully) |

---

**Remember**: The permission system is designed to help you work efficiently while preventing catastrophic mistakes. Use it wisely!
