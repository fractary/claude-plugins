# Migrating to the Unified Git Status Cache

This guide helps users migrate from custom git status caching hooks to the built-in status cache provided by the fractary-repo plugin.

## Why Migrate?

### Problem with Custom Hooks

If you have custom hooks that query git status (e.g., for status line display), you may experience:

- **Hook conflicts** - Multiple hooks running `git status` concurrently on the same event
- **Race conditions** - Hooks competing for git repository access
- **Duplicate work** - Same git queries executed multiple times
- **Slow performance** - Multiple concurrent git operations

### Solution: Unified Status Cache

The fractary-repo plugin now provides:

✅ **Single source of truth** - One cache, updated once per event
✅ **No conflicts** - Coordinated updates via plugin hooks
✅ **Fast reads** - Cache reads are instant (~5ms)
✅ **Auto-refresh** - Falls back to live query if stale
✅ **Rich data** - 10 fields available (branch, changes, ahead/behind, stash, etc.)

## Migration Steps

### Step 1: Identify Custom Hooks

Check if you have custom git status hooks:

```bash
# Check for custom hooks
ls -la .claude/hooks/
cat .claude/hooks/*.sh

# Look for git status commands
grep -r "git status" .claude/hooks/
grep -r "git rev-list" .claude/hooks/
```

Common patterns to look for:
- `git status --porcelain`
- `git rev-list @{u}..HEAD`
- Custom cache files (`.git-status-cache`, etc.)

### Step 2: Document Your Current Setup

Before removing anything, document what your hooks do:

```bash
# What information do you track?
# - Uncommitted changes count? ✓
# - Commits ahead/behind? ✓
# - Branch name? ✓
# - Stash count? ✓

# Where do you store cache files?
# - ~/.git-status-cache
# - .git/status-cache
# - etc.

# What events trigger updates?
# - Stop hook? ✓
# - UserPromptSubmit? ✓
# - Other?
```

### Step 3: Backup Custom Hooks

Before removing, backup your custom hooks:

```bash
mkdir -p ~/claude-hooks-backup
cp -r .claude/hooks ~/claude-hooks-backup/
echo "Backup created: ~/claude-hooks-backup/"
```

### Step 4: Remove Custom Status Cache Hooks

Remove or disable custom hooks that cache git status:

```bash
# Option 1: Delete the hook
rm .claude/hooks/update-git-status.sh

# Option 2: Disable by renaming
mv .claude/hooks/update-git-status.sh .claude/hooks/update-git-status.sh.disabled

# Option 3: Comment out in hooks.json
# Edit .claude/hooks.json and comment out the hook entry
```

### Step 5: Verify Plugin Hooks Are Active

Ensure the fractary-repo plugin hooks are registered:

```bash
# Check if plugin hooks are loaded
cat ~/.claude/plugins/fractary-repo/hooks/hooks.json

# Expected hooks:
# - Stop: auto-commit-on-stop.sh (which updates cache)
# - UserPromptSubmit: update-status-cache.sh --quiet
```

If hooks are not active, reload the plugin:

```bash
# Reload Claude Code to pick up plugin hooks
# Or manually ensure plugin is installed
```

### Step 6: Update Status Line Configuration

Update `.claude/statusline.json` to use the plugin cache instead of custom scripts.

#### Example Migration

**Before (Custom)**:
```json
{
  "sections": [
    {
      "command": "cat ~/.git-status-cache | wc -l",
      "format": "Changes: %s",
      "color": "yellow"
    },
    {
      "command": "cat ~/.git-ahead-cache",
      "format": " ↑%s",
      "color": "green"
    }
  ]
}
```

**After (Plugin Cache)**:
```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted",
      "format": "Changes: %s",
      "color": "yellow"
    },
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh ahead",
      "format": " ↑%s",
      "color": "green"
    }
  ]
}
```

Or combine into a single command:
```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead",
      "format": "Changes: %s ↑%s",
      "color": "yellow"
    }
  ]
}
```

### Step 7: Clean Up Old Cache Files

Remove old cache files that are no longer needed:

```bash
# Remove custom cache files
rm -f ~/.git-status-cache
rm -f ~/.git-ahead-cache
rm -f ~/.git-behind-cache
rm -f .git/status-cache  # Or wherever you stored them

# The plugin cache location:
# ~/.fractary/repo/status.cache
```

### Step 8: Test the New Setup

Test that the status cache is working:

```bash
# 1. Make some changes
echo "test" >> README.md

# 2. Manually update cache
~/.fractary/repo/scripts/update-status-cache.sh

# 3. Read the cache
~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead behind

# 4. Check cache file
cat ~/.fractary/repo/status.cache
```

Test status line display:

```bash
# Submit a command in Claude Code and check if status line updates
# The UserPromptSubmit hook should update the cache automatically
```

### Step 9: Verify No Conflicts

Monitor for conflicts after migration:

```bash
# Run a Claude Code session and check logs for:
# - No git lock errors
# - No hook failures
# - Status line displaying correctly

# Check that both hooks run without conflict:
# - UserPromptSubmit: Updates cache
# - Stop: Commits changes + updates cache
```

## Migration Examples

### Example 1: Simple Change Counter

**Custom Hook (`update-status.sh`)**:
```bash
#!/bin/bash
git status --porcelain > ~/.git-status-cache
```

**Custom Status Line**:
```json
{
  "command": "cat ~/.git-status-cache | wc -l",
  "format": "Git: %s"
}
```

**Migrated Status Line**:
```json
{
  "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted",
  "format": "Git: %s"
}
```

**Actions**:
1. Remove `update-status.sh`
2. Update status line config
3. Delete `~/.git-status-cache`

---

### Example 2: Ahead/Behind Tracking

**Custom Hook (`update-git-info.sh`)**:
```bash
#!/bin/bash
git rev-list --count @{u}..HEAD > ~/.git-ahead
git rev-list --count HEAD..@{u} > ~/.git-behind
```

**Custom Status Line**:
```json
{
  "sections": [
    {"command": "cat ~/.git-ahead", "format": "↑%s"},
    {"command": "cat ~/.git-behind", "format": "↓%s"}
  ]
}
```

**Migrated Status Line**:
```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh ahead behind",
      "format": "↑%s ↓%s"
    }
  ]
}
```

**Actions**:
1. Remove `update-git-info.sh`
2. Update status line config
3. Delete `~/.git-ahead` and `~/.git-behind`

---

### Example 3: Comprehensive Status

**Custom Hook (`git-status-full.sh`)**:
```bash
#!/bin/bash
{
  git status --porcelain | wc -l
  git rev-list --count @{u}..HEAD
  git stash list | wc -l
  git rev-parse --abbrev-ref HEAD
} > ~/.git-status-full
```

**Custom Status Line**:
```json
{
  "command": "awk 'NR==1{changes=$1} NR==2{ahead=$1} NR==3{stash=$1} NR==4{branch=$1} END{print branch \" \" changes \"△ ↑\" ahead \" ⚑\" stash}' ~/.git-status-full",
  "format": "%s"
}
```

**Migrated Status Line**:
```json
{
  "command": "~/.fractary/repo/scripts/read-status-cache.sh branch uncommitted ahead stash",
  "format": "%s %s△ ↑%s ⚑%s"
}
```

**Actions**:
1. Remove `git-status-full.sh`
2. Update status line config (much simpler!)
3. Delete `~/.git-status-full`

## Troubleshooting Migration

### Status Line Not Updating

**Issue**: Status line shows stale data

**Solution**:
1. Check cache exists:
   ```bash
   ls -la ~/.fractary/repo/status.cache
   ```

2. Manually update cache:
   ```bash
   ~/.fractary/repo/scripts/update-status-cache.sh
   ```

3. Check script permissions:
   ```bash
   ls -la ~/.fractary/repo/scripts/*.sh
   # Should be executable (-rwxr-xr-x)
   ```

4. Test script manually:
   ```bash
   ~/.fractary/repo/scripts/read-status-cache.sh uncommitted
   ```

### Hook Conflicts Still Occurring

**Issue**: Still getting git lock errors

**Solution**:
1. Verify all custom hooks are removed:
   ```bash
   grep -r "git status" .claude/hooks/
   grep -r "git rev-list" .claude/hooks/
   ```

2. Check for hooks on same events:
   ```bash
   cat .claude/hooks.json
   # Look for multiple hooks on Stop or UserPromptSubmit
   ```

3. Disable conflicting hooks temporarily:
   ```bash
   mv .claude/hooks.json .claude/hooks.json.backup
   # Test with only plugin hooks
   ```

### Cache Not Found

**Issue**: `read-status-cache.sh` reports cache not found

**Solution**:
1. Ensure cache directory exists:
   ```bash
   mkdir -p ~/.fractary/repo
   ```

2. Manually create cache:
   ```bash
   ~/.fractary/repo/scripts/update-status-cache.sh
   ```

3. Check you're in a git repository:
   ```bash
   git rev-parse --git-dir
   ```

### Wrong Data in Cache

**Issue**: Cache shows incorrect information

**Solution**:
1. Force cache refresh:
   ```bash
   ~/.fractary/repo/scripts/update-status-cache.sh
   ```

2. Check cache contents:
   ```bash
   cat ~/.fractary/repo/status.cache
   ```

3. Compare with live git:
   ```bash
   git status --porcelain | wc -l  # Compare to uncommitted_changes
   git rev-list --count @{u}..HEAD  # Compare to commits_ahead
   ```

## Rollback Plan

If you need to revert to your custom hooks:

```bash
# 1. Restore custom hooks
cp -r ~/claude-hooks-backup/hooks .claude/

# 2. Restore custom cache files
# (Recreate or restore from backup)

# 3. Restore old status line config
# (Edit .claude/statusline.json)

# 4. Disable plugin hooks (if needed)
# Edit ~/.claude/hooks.json to remove fractary-repo entries
```

## Benefits After Migration

After migration, you should experience:

✅ **Faster status line updates** - Cache reads are instant
✅ **No hook conflicts** - Single coordinated update
✅ **More information** - 10 fields available vs custom limited set
✅ **Auto-refresh** - Falls back to live query if stale
✅ **Maintained** - Updates automatically with plugin
✅ **Simpler config** - Less custom scripting needed

## Support

If you encounter issues during migration:

1. Check [Status Cache Status Line Examples](status-cache-statusline-examples.md)
2. Review [fractary-repo Plugin README](../README.md)
3. File an issue: [GitHub Issues](https://github.com/fractary/claude-plugins/issues)

## Advanced: Per-Repo Cache

If you want separate caches per repository (instead of global):

Edit both scripts and change:

```bash
# Global cache (default)
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"
```

To:

```bash
# Per-repo cache
CACHE_DIR="$(git rev-parse --git-dir 2>/dev/null || echo "$HOME/.fractary/repo")/fractary"
CACHE_FILE="${CACHE_DIR}/status.cache"
```

This stores cache in `.git/fractary/status.cache` for each repo.

## See Also

- [Status Cache Status Line Examples](status-cache-statusline-examples.md)
- [fractary-repo Plugin README](../README.md)
- [Hook Configuration](../hooks/hooks.json)
- [Auto-Commit Hook](../scripts/auto-commit-on-stop.sh)
