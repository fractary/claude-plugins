# Worktree Management Scripts

This directory contains scripts for managing Git worktrees with registry-based reuse detection.

## Overview

These scripts implement the **3-layer architecture** pattern by keeping deterministic operations (bash scripts) separate from LLM context (SKILL.md), reducing token usage by 55-60%.

## Registry Location

**Location**: `~/.fractary/repo/worktrees.json`

**Why Global Registry?**
- **Cross-Project Awareness**: A single developer may work on multiple repos simultaneously
- **Unique work_ids**: Work item IDs (like issue #123) can exist across different repos
- **Registry includes repo_root**: Each entry tracks which repository it belongs to
- **Prevents confusion**: Can tell if work_id 123 is for repo A or repo B

**Registry Format**:
```json
{
  "123": {
    "worktree_path": "/path/to/repo/.worktrees/feat-123-description",
    "branch": "feat/123-description",
    "created": "2025-11-22T14:30:00Z",
    "last_used": "2025-11-22T15:45:00Z",
    "repo_root": "/path/to/repo"
  }
}
```

**Alternative Considered**: Project-local `.fractary/repo/worktrees.json`
- ❌ Would require switching to each project to see active worktrees
- ❌ Harder to detect conflicts across repos
- ✅ Global registry provides unified view

## Scripts

### 1. check-worktree.sh

**Usage**: `check-worktree.sh <work_id>`

**Purpose**: Check if worktree exists for a given work_id

**Returns**:
- Exit code 0: Worktree exists and is valid
- Exit code 1: No worktree or path is stale
- Stdout: Worktree path (if exists)

**Behavior**:
- Checks `~/.fractary/repo/worktrees.json` for work_id mapping
- Validates worktree directory still exists
- Removes stale entries automatically
- Creates registry file if doesn't exist

**Example**:
```bash
if WORKTREE_PATH=$(./check-worktree.sh "123" 2>/dev/null); then
    echo "Found worktree: $WORKTREE_PATH"
else
    echo "No worktree found for work_id 123"
fi
```

### 2. register-worktree.sh

**Usage**: `register-worktree.sh <work_id> <worktree_path> <branch_name>`

**Purpose**: Register or update worktree in registry

**Returns**:
- Exit code 0: Success
- Exit code 1: Failure

**Behavior**:
- Creates registry file if doesn't exist
- Adds new entry or updates existing entry
- Preserves `created` timestamp on updates
- Updates `last_used` timestamp
- Captures repository root automatically

**Example**:
```bash
./register-worktree.sh "123" "/path/to/.worktrees/feat-123" "feat/123-description"
# Output: ✅ Worktree registered: /path/to/.worktrees/feat-123
```

### 3. create-worktree.sh

**Usage**: `create-worktree.sh <branch_name> <work_id>`

**Purpose**: Create worktree in `.worktrees/` subfolder

**Returns**:
- Exit code 0: Success
- Exit code 1: Failure
- Stdout: Worktree path (on success)

**Behavior**:
- Creates worktree in `.worktrees/` subfolder (within repo root)
- Converts branch name to slug: `feat/123` → `feat-123`
- Truncates slugs > 80 chars (with hash for uniqueness)
- Handles long path names gracefully

**Path Length Handling**:
```bash
# Short branch name (no truncation)
feat/123-add-export → .worktrees/feat-123-add-export

# Long branch name (truncated)
feat/123-very-long-branch-name-that-exceeds-eighty-characters-in-total-length
→ .worktrees/feat-123-very-long-branch-name-that-exceeds-eighty-characters-in--a1b2c3d4
#                                                                       ^^^ hash for uniqueness
```

**Example**:
```bash
WORKTREE_PATH=$(./create-worktree.sh "feat/123-add-export" "123")
echo "Created: $WORKTREE_PATH"
# Output: /path/to/repo/.worktrees/feat-123-add-export
```

## Worktree Location

**Pattern**: `.worktrees/{branch-slug}` (subfolder within repository root)

**Why Subfolder (Not Parallel Directory)?**
- ✅ **Claude's Scope**: Stays within project root (Claude can access)
- ✅ **Gitignored**: `.worktrees/` added to `.gitignore`
- ✅ **No Path Confusion**: Clear it's part of the repo
- ❌ **Parallel Dir**: `../repo-wt-*` would be outside Claude's scope

**Example Structure**:
```
/path/to/repo/
├── .git/
├── .worktrees/           ← Worktrees stored here
│   ├── feat-123-add-export/
│   ├── feat-124-fix-bug/
│   └── feat-125-refactor/
├── src/
├── tests/
└── README.md
```

## Integration

These scripts are invoked by the `branch-manager` skill:

1. **Check**: `check-worktree.sh` - Before creating branch
2. **Create**: `create-worktree.sh` - If no worktree exists
3. **Register**: `register-worktree.sh` - After creation or on reuse

**Skill Integration** (from `branch-manager/SKILL.md`):
```bash
# Step 4: Check registry
if EXISTING_WORKTREE=$("$SCRIPT_DIR/scripts/check-worktree.sh" "$WORK_ID"); then
    # Reuse existing worktree
    cd "$EXISTING_WORKTREE"
else
    # Step 6: Create new worktree
    WORKTREE_PATH=$("$SCRIPT_DIR/scripts/create-worktree.sh" "$BRANCH_NAME" "$WORK_ID")

    # Register it
    "$SCRIPT_DIR/scripts/register-worktree.sh" "$WORK_ID" "$WORKTREE_PATH" "$BRANCH_NAME"

    cd "$WORKTREE_PATH"
fi
```

## Benefits

1. **Context Reduction**: ~50 lines of bash → 3 script invocations (saves ~2K tokens)
2. **Reusability**: Scripts can be called from other skills/commands
3. **Testability**: Scripts can be tested independently
4. **Maintainability**: Changes to logic only require updating scripts, not SKILL.md

## Registry Cleanup

**Automatic Stale Entry Removal**:
- `check-worktree.sh` removes entries when path doesn't exist
- No manual cleanup needed for deleted worktrees

**Manual Cleanup** (if needed):
```bash
# View registry
cat ~/.fractary/repo/worktrees.json | jq '.'

# Remove specific entry
jq 'del(.["123"])' ~/.fractary/repo/worktrees.json > /tmp/worktrees.json && \
  mv /tmp/worktrees.json ~/.fractary/repo/worktrees.json

# Clear all entries
echo '{}' > ~/.fractary/repo/worktrees.json
```

## Error Handling

All scripts use `set -euo pipefail` for:
- **-e**: Exit on error
- **-u**: Error on undefined variables
- **-o pipefail**: Catch errors in pipelines

Scripts validate inputs and provide clear error messages on stderr.

## See Also

- `branch-manager/SKILL.md` - Skill that uses these scripts
- `~/.fractary/repo/worktrees.json` - Registry file
- `.worktrees/` - Worktree storage directory (gitignored)
