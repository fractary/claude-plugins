# Status Cache Integration with Claude Code Status Line

The fractary-repo plugin maintains a git status cache that can be consumed by the Claude Code status line for real-time display of repository status without triggering concurrent git operations.

## Overview

The status cache is automatically updated:
- **On command submission** (`UserPromptSubmit` hook) - Keeps cache fresh during active development
- **On session end** (`Stop` hook, via auto-commit) - Updates after commits are made

Cache location: `~/.fractary/repo/status.cache`

## Status Line Configuration

To display git status in your Claude Code status line, edit `.claude/statusline.json`:

### Example 1: Basic Git Status

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted_changes commits_ahead",
      "format": "Git: %s↑%s",
      "color": "yellow"
    }
  ]
}
```

**Output**: `Git: 3↑5` (3 uncommitted changes, 5 commits ahead)

### Example 2: Detailed Status

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh branch uncommitted_changes commits_ahead commits_behind",
      "format": "[%s] %s↑%s ↓%s",
      "color": "cyan"
    }
  ]
}
```

**Output**: `[main] 3↑5 ↓0` (on main branch, 3 uncommitted, 5 ahead, 0 behind)

### Example 3: Clean Status Indicator

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh clean uncommitted_changes",
      "format": "Git: %s changes",
      "color": "green",
      "condition": "[ \"$1\" = \"false\" ]"
    },
    {
      "command": "echo '✓'",
      "format": "Git: %s",
      "color": "green",
      "condition": "[ $(~/.fractary/repo/scripts/read-status-cache.sh clean) = \"true\" ]"
    }
  ]
}
```

**Output**: Shows `Git: ✓` when clean, `Git: 3 changes` when dirty

### Example 4: Comprehensive Status

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh branch",
      "format": "[%s]",
      "color": "blue"
    },
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted_changes",
      "format": " %s△",
      "color": "yellow",
      "condition": "[ \"$1\" != \"0\" ]"
    },
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh commits_ahead",
      "format": " ↑%s",
      "color": "green",
      "condition": "[ \"$1\" != \"0\" ]"
    },
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh commits_behind",
      "format": " ↓%s",
      "color": "red",
      "condition": "[ \"$1\" != \"0\" ]"
    },
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh stash_count",
      "format": " ⚑%s",
      "color": "magenta",
      "condition": "[ \"$1\" != \"0\" ]"
    }
  ]
}
```

**Output**: `[main] 3△ ↑5 ⚑2` (main branch, 3 uncommitted, 5 ahead, 2 stashes)

## Available Fields

The `read-status-cache.sh` script supports the following fields:

| Field | Aliases | Type | Description |
|-------|---------|------|-------------|
| `timestamp` | - | string | ISO 8601 timestamp of last cache update |
| `repo_path` | - | string | Absolute path to repository root |
| `branch` | - | string | Current branch name |
| `uncommitted_changes` | `uncommitted`, `changes` | number | Count of uncommitted changes (staged + unstaged) |
| `untracked_files` | `untracked` | number | Count of untracked files |
| `commits_ahead` | `ahead` | number | Commits ahead of remote |
| `commits_behind` | `behind` | number | Commits behind remote |
| `has_conflicts` | `conflicts` | boolean | Whether there are merge conflicts |
| `stash_count` | `stash` | number | Number of stashes |
| `clean` | - | boolean | Whether working tree is clean |

## Usage Tips

### Multiple Fields

You can request multiple fields in a single invocation:

```bash
~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead behind
# Output: 3 5 0
```

### Field Aliases

Use shorter aliases for brevity:

```bash
~/.fractary/repo/scripts/read-status-cache.sh changes ahead behind
# Same as: uncommitted_changes commits_ahead commits_behind
```

### Shell Integration

The cache can be used in any shell script:

```bash
UNCOMMITTED=$(~/.fractary/repo/scripts/read-status-cache.sh uncommitted)
if [ "$UNCOMMITTED" -gt 0 ]; then
    echo "You have uncommitted changes!"
fi
```

## Cache Freshness

- **Max Age**: 30 seconds (configurable in `read-status-cache.sh`)
- **Auto-Refresh**: If cache is stale, `read-status-cache.sh` automatically updates it
- **Manual Update**: Run `~/.fractary/repo/scripts/update-status-cache.sh` to force update

## Troubleshooting

### Cache Not Updating

1. **Check hooks are active**:
   ```bash
   cat ~/.claude/hooks.json
   # Should include fractary-repo plugin hooks
   ```

2. **Manually update cache**:
   ```bash
   ~/.fractary/repo/scripts/update-status-cache.sh
   ```

3. **Check cache file exists**:
   ```bash
   ls -la ~/.fractary/repo/status.cache
   cat ~/.fractary/repo/status.cache
   ```

### Status Line Not Showing

1. **Check script is executable**:
   ```bash
   ls -la ~/.fractary/repo/scripts/read-status-cache.sh
   ```

2. **Test script manually**:
   ```bash
   ~/.fractary/repo/scripts/read-status-cache.sh uncommitted ahead
   ```

3. **Check Claude Code status line config**:
   ```bash
   cat .claude/statusline.json
   ```

### Stale Data

The cache refreshes automatically when stale (>30s), but you can force refresh:

```bash
~/.fractary/repo/scripts/update-status-cache.sh
```

## Migration from Custom Hooks

If you previously had custom git status caching hooks:

### Before (Custom Hook)

```bash
# .claude/hooks/stop.sh
git status --porcelain > ~/.git-status-cache
git rev-list @{u}..HEAD | wc -l > ~/.git-ahead-cache
```

```json
// .claude/statusline.json
{
  "sections": [
    {
      "command": "cat ~/.git-status-cache | wc -l",
      "format": "Git: %s changes"
    }
  ]
}
```

### After (Using Plugin Cache)

1. **Remove custom hook** (no longer needed - plugin handles it)

2. **Update status line config**:
   ```json
   {
     "sections": [
       {
         "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted",
         "format": "Git: %s changes"
       }
     ]
   }
   ```

### Benefits

✅ **No hook conflicts** - Single update per event
✅ **Richer data** - More fields than custom implementation
✅ **Auto-refresh** - Falls back to live query if stale
✅ **Atomic updates** - Thread-safe cache writes
✅ **Maintained** - Updates with plugin

## Examples by Use Case

### Use Case 1: Simple Change Counter

**Goal**: Show number of uncommitted changes

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh uncommitted",
      "format": "Git: %s",
      "color": "yellow"
    }
  ]
}
```

### Use Case 2: Push Reminder

**Goal**: Show when you have commits to push

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh ahead",
      "format": "⬆ %s to push",
      "color": "green",
      "condition": "[ \"$1\" != \"0\" ]"
    }
  ]
}
```

### Use Case 3: Pull Reminder

**Goal**: Show when remote has new commits

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh behind",
      "format": "⬇ %s to pull",
      "color": "red",
      "condition": "[ \"$1\" != \"0\" ]"
    }
  ]
}
```

### Use Case 4: Conflict Warning

**Goal**: Show alert when there are merge conflicts

```json
{
  "sections": [
    {
      "command": "~/.fractary/repo/scripts/read-status-cache.sh conflicts",
      "format": "⚠️  CONFLICTS",
      "color": "red",
      "condition": "[ \"$1\" = \"true\" ]"
    }
  ]
}
```

## Performance

- **Cache Read**: ~5ms (no git commands)
- **Cache Update**: ~50ms (git status, rev-list, stash list)
- **Status Line Refresh**: Near-instant with cached data

Compare to running git commands directly:
- **Direct `git status`**: ~50-200ms per query
- **Multiple concurrent queries**: Can cause conflicts and slowdowns

## Configuration

The cache behavior can be customized by editing the scripts:

### Cache Location

Edit `update-status-cache.sh` and `read-status-cache.sh`:

```bash
CACHE_DIR="${HOME}/.fractary/repo"
CACHE_FILE="${CACHE_DIR}/status.cache"
```

To use per-repo cache (stored in `.git/`):

```bash
CACHE_DIR="$(git rev-parse --git-dir)/fractary"
CACHE_FILE="${CACHE_DIR}/status.cache"
```

### Cache Max Age

Edit `read-status-cache.sh`:

```bash
MAX_AGE_SECONDS=30  # Increase for less frequent updates
```

## See Also

- [fractary-repo Plugin README](../README.md)
- [Hook Configuration](hooks/hooks.json)
- [Auto-Commit Hook](../scripts/auto-commit-on-stop.sh)
