# Branch-Aware Permission System

## Overview

The repo plugin implements a **branch-aware permission system** that provides:
- ✅ **Fast workflow** on feature branches (no prompts)
- ⚠️ **Protection** for production branches (approval required)
- ❌ **Safety net** for catastrophic operations (always blocked)

## Philosophy

Most developers work primarily on feature branches. You shouldn't be constantly interrupted by permission prompts for normal operations. However, operations targeting protected branches (main/master/production) deserve extra scrutiny.

## Permission Categories

### 1. Auto-Allowed (Fast Workflow)

These commands execute **immediately without prompts** on feature branches:

```bash
# All of these are auto-allowed
git commit -m "Add feature"
git push origin feat/123
git merge feat/other-feature
gh pr create
gh pr comment
gh pr review
```

**Includes** (~50 commands):
- All git read operations (`status`, `log`, `diff`, etc.)
- All git write operations on feature branches
- All GitHub CLI operations (pr, issue management)
- Safe utilities (`cat`, `grep`, `jq`, etc.)

### 2. Require Approval (Protected Branches Only)

These commands prompt for approval **ONLY when targeting protected branches**:

```bash
# THESE require approval
git push origin main
git push origin master
git push origin production
git push -u origin main
gh pr merge  # When merging TO protected branch
```

**Does NOT require approval**:
```bash
# These execute immediately (feature branches)
git push origin feat/123
git push origin bugfix/456
git push origin test/experiment
```

### 3. Always Denied (Catastrophic Operations)

These commands are **ALWAYS blocked**, regardless of branch:

```bash
# ALWAYS denied
rm -rf /
git push --force origin main
git push --force origin master
git push --force origin production
gh repo delete
sudo rm -rf /
shutdown
```

## How It Works

### Pattern Matching

The permission system uses **exact command matching** with branch patterns:

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git push"  // Allows: git push origin feat/123
      ],
      "requireApproval": [
        "git push origin main",      // Specific pattern
        "git push origin master",    // Specific pattern
        "git push origin production" // Specific pattern
      ],
      "deny": [
        "git push --force origin main"  // Always blocked
      ]
    }
  }
}
```

### Matching Rules

Claude Code's permission system checks commands in order:

1. **Exact match in deny** → Command blocked
2. **Exact match in requireApproval** → User prompted
3. **Prefix match in allow** → Command executes
4. **No match** → User prompted (default Claude Code behavior)

### Examples

| Command | Matches | Result |
|---------|---------|--------|
| `git push origin feat/123` | `"git push"` in allow | ✅ Executes immediately |
| `git push origin main` | `"git push origin main"` in requireApproval | ⚠️ Prompts for approval |
| `git push --force origin main` | `"git push --force origin main"` in deny | ❌ Blocked |
| `git commit -m "fix"` | `"git commit"` in allow | ✅ Executes immediately |

## Protected Branches

The system protects these branch names by default:
- `main`
- `master`
- `production`

### Customizing Protected Branches

To add more protected branches, manually edit `.claude/settings.json`:

```json
{
  "permissions": {
    "bash": {
      "requireApproval": [
        "git push origin main",
        "git push origin master",
        "git push origin production",
        "git push origin staging",        // Added
        "git push origin release",        // Added
        "git push -u origin staging",     // Added
        "git push -u origin release"      // Added
      ]
    }
  }
}
```

## Workflow Examples

### Feature Development (No Prompts)

```bash
# Create feature branch
git checkout -b feat/user-export

# Work on feature (all auto-allowed)
git add .
git commit -m "Add CSV export"
git push origin feat/user-export

# Create PR (auto-allowed)
gh pr create --title "Add user export"

# Review and comment (auto-allowed)
gh pr comment 123 "LGTM!"
gh pr review 123 --approve
```

**Result**: ✅ Zero prompts, fast workflow

### Production Deployment (Requires Approval)

```bash
# Ready to merge to production
git checkout main
git merge feat/user-export

# Push to main (PROMPTS for approval)
git push origin main
```

**Prompt**:
```
⚠️  Permission Required
Command: git push origin main
This targets a protected branch.
Allow? (y/n)
```

**Result**: ⚠️ One prompt for critical operation

### Prevented Disaster (Always Blocked)

```bash
# Accidentally try to force push to main
git push --force origin main
```

**Result**: ❌ Blocked immediately, no prompt
```
ERROR: Command denied by permissions
"git push --force origin main" is in deny list
```

## `--dangerously-skip-permissions` Mode

### ⚠️ CRITICAL WARNING ⚠️

When running with `--dangerously-skip-permissions`:

**ALL permission checks are bypassed**, including:
- ❌ `allow` (not checked)
- ❌ `requireApproval` (NOT PROMPTED - executes immediately)
- ❌ `deny` (NOT ENFORCED - executes anyway)

### Dangerous Examples

| Command | Normal Mode | Skip Mode |
|---------|------------|-----------|
| `git push origin feat/123` | ✅ Auto-allowed | ✅ Auto-allowed |
| `git push origin main` | ⚠️ **Prompts user** | 💀 **Executes immediately** |
| `rm -rf /` | ❌ Blocked | 💀 **EXECUTES (destroys system)** |

### When to Use Skip Mode

**ONLY use `--dangerously-skip-permissions` when**:
1. ✅ Running in isolated Docker container
2. ✅ Testing in sandboxed VM
3. ✅ CI/CD with full code review
4. ✅ You trust 100% of the code being executed

**NEVER use skip mode**:
- ❌ On production systems
- ❌ On your development machine
- ❌ When running untrusted code
- ❌ If unsure what commands will execute

## Comparison: Old vs New System

### Old System (v2.1.0)

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "git log"
      ],
      "requireApproval": [
        "git commit",      // EVERY commit prompted
        "git push",        // EVERY push prompted
        "gh pr create"     // EVERY pr prompted
      ],
      "deny": [
        "rm -rf /"
      ]
    }
  }
}
```

**Experience**: 🐢 Slow, constant interruptions

### New System (v2.2.0)

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git status",
        "git commit",           // Auto-allowed now!
        "git push",             // Auto-allowed (feature branches)!
        "gh pr create"          // Auto-allowed now!
      ],
      "requireApproval": [
        "git push origin main",        // Only protected branches
        "git push origin master",
        "git push origin production"
      ],
      "deny": [
        "rm -rf /",
        "git push --force origin main" // Force push to protected
      ]
    }
  }
}
```

**Experience**: ⚡ Fast, only protected branches prompt

## Benefits

### 1. Developer Velocity

**Before**:
```
git commit -m "fix bug"
  ⚠️  Approve? (y/n) y
git push origin feat/123
  ⚠️  Approve? (y/n) y
gh pr create
  ⚠️  Approve? (y/n) y
```
**3 prompts for normal workflow** 🐢

**After**:
```
git commit -m "fix bug"  ✅ Done
git push origin feat/123 ✅ Done
gh pr create             ✅ Done
```
**0 prompts for feature branch workflow** ⚡

### 2. Protection Where It Matters

You still get protection for operations that actually matter:

```
git push origin main
  ⚠️  This targets protected branch 'main'
  ⚠️  Approve? (y/n)
```

This prompt is **meaningful** because it's rare and important.

### 3. Prevents Catastrophic Mistakes

```
git push --force origin main
  ❌ DENIED
  This operation targets protected branch and is always blocked.
```

No prompt needed - just blocked.

## Customization

### Adding Custom Protected Branches

Edit `.claude/settings.json`:

```json
{
  "permissions": {
    "bash": {
      "requireApproval": [
        "git push origin main",
        "git push origin master",
        "git push origin production",
        "git push origin develop",        // Add custom
        "git push -u origin develop"      // Add with -u flag
      ]
    }
  }
}
```

### Allowing Force Push to Feature Branches

Force push is auto-allowed to feature branches:

```bash
# These are allowed (not in deny list)
git push --force origin feat/123
git push --force-with-lease origin bugfix/456
```

Only force push to protected branches is denied:

```bash
# These are denied
git push --force origin main
git push --force origin master
git push --force origin production
```

### Making Specific Operations Stricter

To require approval for ALL pushes (not recommended):

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git commit",
        // Removed "git push" from allow
      ],
      "requireApproval": [
        "git push"  // Now ALL pushes require approval
      ]
    }
  }
}
```

### Making Specific Operations More Permissive

To auto-allow push to staging:

```json
{
  "permissions": {
    "bash": {
      "allow": [
        "git push origin staging"  // Explicitly allow
      ],
      "requireApproval": [
        // Remove staging from requireApproval
      ]
    }
  }
}
```

## Troubleshooting

### Still Getting Prompted on Feature Branches

**Problem**: `git push origin feat/123` still prompts

**Possible causes**:
1. `git push` not in allow list
2. Specific pattern in requireApproval matching
3. Settings not loaded correctly

**Solution**:
```bash
# Validate settings
/repo:init-permissions --mode validate

# Check what's configured
cat .claude/settings.json | jq '.permissions.bash'

# Re-run setup
/repo:init-permissions --mode setup
```

### Protected Branch Not Protected

**Problem**: `git push origin main` doesn't prompt

**Possible causes**:
1. Running in `--dangerously-skip-permissions` mode
2. Pattern not in requireApproval list
3. Settings file not in project root

**Solution**:
```bash
# Check if settings exist
ls -la .claude/settings.json

# Validate settings
/repo:init-permissions --mode validate

# Check for specific pattern
cat .claude/settings.json | jq '.permissions.bash.requireApproval | index("git push origin main")'
```

### Dangerous Command Not Blocked

**Problem**: `rm -rf /` doesn't get blocked

**This is EXTREMELY DANGEROUS** if happening.

**Possible causes**:
1. **Running in `--dangerously-skip-permissions` mode** (most likely)
2. Pattern not exactly matching deny list
3. Settings file corrupted

**Immediate action**:
```bash
# Stop whatever you're doing
# Check if in skip mode (look at Claude Code startup flags)

# Validate settings
/repo:init-permissions --mode validate

# Re-run setup to ensure deny rules in place
/repo:init-permissions --mode setup

# Verify deny rules
cat .claude/settings.json | jq '.permissions.bash.deny'
```

## Best Practices

### 1. Run Setup On Every Project

```bash
cd my-project
/repo:init-permissions
```

Each project gets its own settings.

### 2. Never Use Skip Mode On Dev Machine

```bash
# ❌ NEVER do this on your main computer
claude-code --dangerously-skip-permissions

# ✅ Only in Docker/VM
docker run --rm -it my-sandbox bash
claude-code --dangerously-skip-permissions  # OK in container
```

### 3. Customize Protected Branches For Your Team

If your team uses different branch naming:

```bash
# Edit settings to match your workflow
vim .claude/settings.json
# Add your protected branches
```

### 4. Validate After Manual Edits

```bash
# After editing settings manually
/repo:init-permissions --mode validate
```

### 5. Keep Backups Updated

```bash
# Before major changes
cp .claude/settings.json .claude/settings.json.manual-backup

# Automatic backup is created at:
.claude/settings.json.backup
```

## FAQ

### Q: Will I get prompted for every commit?

**A**: No! `git commit` is auto-allowed. You only get prompted for pushes to protected branches.

### Q: What if I need to force push to a feature branch?

**A**: That's auto-allowed! Only force push to main/master/production is denied.

### Q: Can I add more protected branches?

**A**: Yes! Edit `.claude/settings.json` and add patterns to `requireApproval`.

### Q: Does this work with `--dangerously-skip-permissions`?

**A**: No - skip mode bypasses ALL checks, including deny rules. Use with extreme caution.

### Q: What happens if I try `git push --force origin main`?

**A**: Blocked immediately. It's in the deny list - no prompt, just blocked.

### Q: Do I need to set this up for every project?

**A**: Yes, each project has its own `.claude/settings.json`.

### Q: Can I share settings across projects?

**A**: Yes, copy `.claude/settings.json` between projects, or use a template.

### Q: What if my branch is named `main-feature`?

**A**: Auto-allowed! The pattern `git push origin main` doesn't match `git push origin main-feature`.

## Summary

| Operation | Feature Branch | Protected Branch |
|-----------|---------------|------------------|
| `git commit` | ✅ Auto-allowed | ✅ Auto-allowed |
| `git push` | ✅ Auto-allowed | ⚠️ Requires approval |
| `git push --force` | ✅ Auto-allowed | ❌ Always denied |
| `gh pr create` | ✅ Auto-allowed | ✅ Auto-allowed |
| `gh pr merge` | ⚠️ Requires approval | ⚠️ Requires approval |
| `rm -rf /` | ❌ Always denied | ❌ Always denied |

**Key insight**: Most operations are fast (no prompts). Protection applied where it matters (production branches). Safety net always active (catastrophic operations blocked).

---

**Ready to enable fast, safe workflows?**

```bash
/repo:init-permissions
```
